BeforeAll {
    . $PSScriptRoot/../DllLoad.ps1
    . $PSScriptRoot/../Listener.ps1

    # Suppress logging
    Mock WriteLogMessage {}

    # Suppress actual notification firing
    Mock ShowNotification {}

    # Mock the calls we want to instrument
    Mock NotifyFromFile {}
    Mock NotifyFromDir {}
}


Describe "ListenerTests" {
    BeforeAll {
        $global:app_context = @{}
        $test_dir = Join-Path $TestDrive "ListenerTests"  # "TestDrive:\" won't work in the FileSystemWatcher
        New-Item -Path $test_dir -ItemType Directory
    }

    Context "ListenerUnitTests" {
        AfterEach {
            Get-EventSubscriber | % {Unregister-Event $_.SourceIdentifier}
            $test_dir | Get-ChildItem -Directory -Recurse | Remove-Item -Force -Recurse
        }

        It "LiveListenersAreSetUp" -TestCases @(
            @{RelativeDirs = @("Test1"); Pattern = "*.tst"; Recurse = $true},
            @{RelativeDirs = @("Test1", "Test2", "Test3"); Pattern = "*.tst"; Recurse = $false}
        ) {
            $directories = $RelativeDirs | % { Join-Path $test_dir $_ }
            $directories | % { New-Item -Path $_ -ItemType Directory }
            CreateToastListeners $directories $Pattern -recurse:$Recurse
            $subs = Get-EventSubscriber
            $subs | Should -HaveCount ($directories.Count * 2)
            foreach ($dir in $directories) {
                $subs | Where-Object { ($_.SourceObject.Path -eq $dir) -and ($_.EventName -eq "Created") } | Should -HaveCount 1
                $subs | Where-Object { ($_.SourceObject.Path -eq $dir) -and ($_.EventName -eq "Renamed") } | Should -HaveCount 1
            }
            foreach ($sub in $subs) {
                $sub.SourceObject.Filter | Should -Be $Pattern
                $sub.SourceObject.EnableRaisingEvents | Should -BeTrue
                $sub.SourceObject.IncludeSubdirectories | Should -Be $Recurse
            }
        }

        It "DirectorySweepersAreSetUp" {
            $relativeDirs = @("Test1", "Test2", "Test3")
            $directories = $relativeDirs | % { Join-Path $test_dir $_ }
            $directories | % { New-Item -Path $_ -ItemType Directory }
            $pattern = "*.tst"
            $interval = 60
            CreateToastDirectorySweeper $directories -interval_sec:$interval -file_pattern:$pattern
            $subs = Get-EventSubscriber
            $subs | Should -HaveCount 2

            $subs | Where-Object { $_.EventName -eq "Elapsed" } | Should -HaveCount 1
            $timer_sub = ($subs | Where-Object { $_.EventName -eq "Elapsed" })[0]
            $timer_sub.SourceObject | Should -BeOfType [System.Timers.Timer]
            $timer_sub.SourceObject.Interval | Should -Be ($interval * 1000)
            $timer_sub.SourceObject.AutoReset | Should -BeTrue
            $timer_sub.SourceObject.Enabled | Should -BeTrue

            $subs | Where-Object {$null -eq $_.EventName} | Should -HaveCount 1
        }
    }

    Context "ListenerIntegrationTests" {
        BeforeAll {
            $relativeDirs = @("Test10", "Test20")
            $test_pattern = "*.tst"
            $test_app_id = "12345"
            $test_default_directives = @{Scenario = "urgent"}
            $test_min_age = 2.5
            $test_enable_web_images = $true
            $test_max_web_image_size_bytes = 16000
            $directories = $relativeDirs | % { Join-Path $test_dir $_ }
            $directories | % { New-Item -Path $_ -ItemType Directory }
            $subdirs = $directories | % { Join-Path $_ "subdir" }
            $subdirs | % { New-Item -Path $_ -ItemType Directory }
        }

        BeforeEach {
            $global:app_context = @{app_id = $test_app_id; log_file_path = ""; default_directives = $test_default_directives;
                                    enable_web_images=$test_enable_web_images; max_web_image_size_bytes = $test_max_web_image_size_bytes;
                                    timestamp_from_file=$false}
        }

        AfterAll {
            $test_dir | Get-ChildItem -Directory -Recurse | Remove-Item -Force -Recurse
        }

        Context "LiveListenerBasicSettingsIntegrationTests" {
            BeforeAll {
                CreateToastListeners $directories -file_pattern:$test_pattern
            }

            AfterAll {
                Get-EventSubscriber | % { Unregister-Event $_.SourceIdentifier }
            }

            AfterEach {
                $test_dir | Get-ChildItem -File -Recurse | Remove-Item -Force
            }

            It "LiveListenerCreatesNotifications" -TestCases @(
                @{TimestampFromFile = $true; DirIndex = 0},
                @{TimestampFromFile = $false; DirIndex = 1}
            ) {
                $app_context.timestamp_from_file = $TimestampFromFile
                $test_path = Join-Path $directories[$DirIndex] "test.tst"
                Set-Content $test_path -Value "testtext"
                Should -Invoke -CommandName NotifyFromFile -Times 1 -Exactly -ParameterFilter {
                    ($file_path -eq $test_path) -and ($app_id -eq $test_app_id) -and ($default_directives -eq $test_default_directives) `
                    -and ($timestamp_from_file -eq $TimestampFromFile) -and ($enable_web_images -eq $test_enable_web_images) `
                    -and ($max_web_image_size_bytes -eq $test_max_web_image_size_bytes)
                }
            }

            It "LiveListenerIgnoresFilesOutOfPattern" {
                $test_path = Join-Path $directories[0] "test.txt"
                Set-Content $test_path -Value "testtext"
                Should -Not -Invoke -CommandName NotifyFromFile
            }

            It "LiveListenerDetectsRenamedFiles" {
                $test_path_out = Join-Path $directories[0] "test.txt"
                $test_path_in = Join-Path $directories[0] "test.tst"
                Set-Content $test_path_out -Value "testtext"
                Rename-Item -Path $test_path_out -NewName $test_path_in
                Should -Invoke -CommandName NotifyFromFile -Times 1 -Exactly -ParameterFilter { $file_path -eq $test_path_in }
            }
        }

        Context "LiveListenerRecurseTests" {
            AfterEach {
                Get-EventSubscriber | % { Unregister-Event $_.SourceIdentifier }
                $test_dir | Get-ChildItem -File -Recurse | Remove-Item -Force
            }

            It "LiveListenerFollowsRecurseSetting" -TestCases @(
                @{Recurse = $true; Expected = 1},
                @{Recurse = $false; Expected = 0}
            ) {
                CreateToastListeners $directories -file_pattern:$test_pattern -recurse:$Recurse
                $test_path = "$($directories[0])/subdir/test.tst"
                Set-Content $test_path -Value "testtext"
                Should -Invoke -CommandName NotifyFromFile -Times $Expected -Exactly
            }
        }

        Context "SweepListenerIntegrationTests" {
            AfterEach {
                Get-EventSubscriber | % { Unregister-Event $_.SourceIdentifier }
            }

            It "ForceSweepEventIsProcessedCorrectly" -TestCases @(
                @{TimestampFromFile = $true; Recurse = $false},
                @{TimestampFromFile = $false; Recurse = $false},
                @{TimestampFromFile = $true; Recurse = $true},
                @{TimestampFromFile = $false; Recurse = $true}
            ) {
                $app_context.timestamp_from_file = $TimestampFromFile
                CreateToastDirectorySweeper $directories -interval_sec:1000 -file_pattern:$test_pattern -recurse:$Recurse
                New-Event -SourceIdentifier "LightlyToastedSweepForce" -MessageData @{Directories = $directories; Pattern = $test_pattern; MinAgeSec = $test_min_age}
                Should -Invoke -CommandName NotifyFromDir -Times $directories.Count -Exactly -ParameterFilter {
                    ($directory -in $directories) -and ($app_id -eq $test_app_id) -and ($file_pattern -eq $test_pattern) `
                    -and ($default_directives -eq $test_default_directives) -and ($timestamp_from_file -eq $TimestampFromFile) `
                    -and ($min_age_sec -eq $test_min_age) -and ($recurse -eq $Recurse) `
                    -and ($enable_web_images -eq $test_enable_web_images) -and ($max_web_image_size_bytes -eq $test_max_web_image_size_bytes)
                }
            }

            It "TimerEventFiresCorrectly" -TestCases @(
                @{TimestampFromFile = $true; Recurse = $false},
                @{TimestampFromFile = $false; Recurse = $false},
                @{TimestampFromFile = $true; Recurse = $true},
                @{TimestampFromFile = $false; Recurse = $true}
            ) {
                $app_context.timestamp_from_file = $TimestampFromFile
                CreateToastDirectorySweeper $directories -interval_sec:0.2 -file_pattern:$test_pattern -min_age_sec:$test_min_age -recurse:$Recurse
                Start-Sleep -Seconds 1  # These timings can be made tighter on PowerShell 7
                Should -Invoke -CommandName NotifyFromDir -Times (2 * $directories.Count) -ParameterFilter {
                    ($directory -in $directories) -and ($app_id -eq $test_app_id) -and ($file_pattern -eq $test_pattern) `
                    -and ($default_directives -eq $test_default_directives) -and ($timestamp_from_file -eq $TimestampFromFile) `
                    -and ($min_age_sec -eq $test_min_age) -and ($recurse -eq $Recurse) `
                    -and ($enable_web_images -eq $test_enable_web_images) -and ($max_web_image_size_bytes -eq $test_max_web_image_size_bytes)
                }
            }
        }
    }
}