BeforeAll {
    . $PSScriptRoot/../DllLoad.ps1
    . $PSScriptRoot/../Init.ps1

    # Suppress logging
    Mock WriteLogMessage {}

    # Mock the functions to be instrumented
    Mock CreateToastDirectorySweeper {}
    Mock CreateToastListeners {}
}


Describe "InitializeTests" {
    BeforeAll {
        $test_dir = "TestDrive:\InitTests"
        $test_dir_full = Join-Path $TestDrive "InitTests"
        $relative_dirs = @("TestA", "TestB")
        $test_directories = $relative_dirs | % { Join-Path $test_dir $_ }
        $test_directories_full = $relative_dirs | % { Join-Path $test_dir_full $_ }
        $test_logs_dir = Join-Path $TestDrive "Logs"
    }

    BeforeEach {
        $global:app_context = @{}
        $test_dir | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    AfterEach {
        Get-EventSubscriber | % { Unregister-Event $_.SourceIdentifier }
    }

    Context "InitializeIntegrationTests" {
        BeforeAll {
            $test_pattern = "*.abc"
            $test_timestamp_from_file = $true
            $test_sweep_interval = 456.78
            $test_sweep_min_age = 2.3
            $test_default_directives = @{ImageCrop = "circle"}
            $test_enable_web_images = $true
            $test_max_web_image_size_kb = 8
        }

        BeforeDiscovery {

        }

        It "InitializeCorrectlySetsUpSystem" -TestCases @(
            @{Logs_Dir = ""; Full_Paths = $true},
            @{Logs_Dir = $test_logs_dir; Full_Paths = $true},
            @{Logs_Dir = $test_logs_dir; Full_Paths = $false}  # Test the expansion of "special" paths
        ) {
            $Watched_Dirs = if ($Full_Paths) { $test_directories_full } else { $test_directories }
            Initialize $Watched_Dirs -FilePattern:$test_pattern -TimestampFromFile:$test_timestamp_from_file -SweepIntervalSec:$test_sweep_interval `
                        -SweepMinAgeSec:$test_sweep_min_age -DefaultDirectives:$test_default_directives -LogsDir:$Logs_Dir `
                        -EnableWebImages:$test_enable_web_images -MaxWebImageSizeKb:$test_max_web_image_size_kb

            foreach ($dir in $test_directories) {
                $dir | Should -Exist
            }
            $app_context["timestamp_from_file"] | Should -BeExactly $test_timestamp_from_file
            $app_context["default_directives"] | Should -Be $test_default_directives
            $app_context["enable_web_images"] | Should -Be $test_enable_web_images
            $app_context["max_web_image_size_bytes"] | Should -Be ($test_max_web_image_size_kb * 1000)
            $app_context["app_id"] | Should -Not -BeNullOrEmpty
            if ($logs_dir) {
                $logs_dir | Should -Exist
                $app_context["log_file_path"] | Split-Path -Parent | Should -Be $logs_dir
            }
            Should -Invoke -Command CreateToastListeners -Times 1 -Exactly -ParameterFilter {
                (!(Compare-Object $directories $test_directories_full)) -and ($file_pattern -eq $test_pattern)
            }
            Should -Invoke -Command CreateToastDirectorySweeper -Times 1 -Exactly -ParameterFilter {
                (!(Compare-Object $directories $test_directories_full)) -and ($file_pattern -eq $test_pattern) `
                -and ($interval_sec -eq $test_sweep_interval) -and ($min_age_sec -eq $test_sweep_min_age)
            }
        }
    }

    Context "InitializeUnitTests" {
        BeforeAll {
            New-Item -Path $test_logs_dir -ItemType Directory -ErrorAction SilentlyContinue
        }

        BeforeEach {
            $test_logs_dir | Get-ChildItem | Remove-Item -Force
        }

        It "OldLogFilesPurgedCorrectly" -TestCases @(
            @{Purge = -1},
            @{Purge = 0},
            @{Purge = 3},
            @{Purge = 100}
        ) {
            $ages = @(1, 2, 5, 10)
            foreach ($a in $ages) {
                $file_path = Join-Path $test_logs_dir "test$a.log"
                Set-Content $file_path -Value "."
                (Get-Item $file_path).CreationTime = (Get-Date).AddDays(-$a)
            }
            Initialize (Join-Path $TestDrive "InitializeUnitTestDirs") -LogsDir:$test_logs_dir -PurgeLogsOlderThan:$Purge
            if ($Purge -ge 0) {
                $test_logs_dir | Get-ChildItem | Should -HaveCount ($ages -lt $Purge).Count
            } else {
                $test_logs_dir | Get-ChildItem | Should -HaveCount $ages.Count
            }
        }
    }
}
    