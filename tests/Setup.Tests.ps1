BeforeAll {
    . $PSScriptRoot/../SetupUtil.ps1

    Mock Write-Host{}

    # Mock calls to be instrumented
    Mock Register-ScheduledTask {}
    Mock Unregister-ScheduledTask {}
    Mock Start-ScheduledTask {}

    # Helper function
    function IsNumeric ([object]$val) {
        return (($val -is [int]) -or ($val -is [double]) -or ($val -is [float]) -or ($val -is [decimal]))
    }
}


Describe "SetupConfigFileTests" {
    BeforeAll {
        $config_path = "TestDrive:\test\configs\cfg.json"
    }

    AfterEach {
        Remove-Item -Path $config_path -ErrorAction SilentlyContinue
    }

    Context "ConfigFileCreationTests" {
        BeforeAll {
            # Assume the user confirms everything
            Mock ConfirmDirs { return $true; }
        }

        It "ConfigFileIsCreatedFromFullArgs"{
            . $PSScriptRoot/../Setup.ps1 -NoTask -ConfigPath $config_path `
                                            -WatchedDirs TestDrive:\foo,TestDrive:\bar -LogsDir TestDrive:\logs `
                                            -SweepIntervalSec 300 -FilePattern "*.xyz" -PurgeLogsOlderThan 7 `
                                            -TimestampFromFile -Recurse -EnableWebImages -MaxWebImageSizeKb 128
            $config_path | Should -Exist
            $config_obj = Get-Content $config_path | ConvertFrom-Json
            $config_obj.WatchedDirs | Should -BeExactly @("TestDrive:\foo", "TestDrive:\bar")
            $config_obj.LogsDir | Should -BeExactly "TestDrive:\logs"
            $config_obj.SweepIntervalSec | Should -BeExactly 300
            $config_obj.FilePattern | Should -BeExactly "*.xyz"
            $config_obj.PurgeLogsOlderThan | Should -BeExactly 7
            $config_obj.TimestampFromFile | Should -BeTrue
            $config_obj.Recurse | Should -BeTrue
            $config_obj.EnableWebImages | Should -BeTrue
            $config_obj.MaxWebImageSizeKb | Should -BeExactly 128
            Should -Not -Invoke -CommandName Register-ScheduledTask
            Should -Not -Invoke -CommandName Start-ScheduledTask
        }

        It "ConfigFileIsCreatedWithDefaults" {
            . $PSScriptRoot/../Setup.ps1 -NoTask -ConfigPath $config_path
            $config_path | Should -Exist
            $config_obj = Get-Content $config_path | ConvertFrom-Json
            $config_obj.WatchedDirs | Should -Not -BeNullOrEmpty
            Should -ActualValue $config_obj.WatchedDirs -BeOfType Object[]  # Pipeline syntax wouldn't work here
            $config_obj.LogsDir | Should -Not -BeNullOrEmpty
            $config_obj.LogsDir | Should -BeOfType string
            IsNumeric($config_obj.SweepIntervalSec) | Should -BeTrue
            $config_obj.FilePattern | Should -Not -BeNullOrEmpty
            $config_obj.FilePattern | Should -BeOfType string
            IsNumeric($config_obj.PurgeLogsOlderThan) | Should -BeTrue
            $config_obj.TimestampFromFile | Should -BeFalse
            $config_obj.Recurse | Should -BeFalse
            $config_obj.EnableWebImages | Should -BeFalse
            IsNumeric($config_obj.MaxWebImageSizeKb) | Should -BeTrue
        }

        It "ConfigFileOverwrittenOnlyWhenRequested" -TestCases @(
            @{Overwrite = $true},
            @{Overwrite = $false}
        ) {
            Set-Content $config_path -Value "initial"
            . $PSScriptRoot/../Setup.ps1 -NoTask -ConfigPath $config_path -OverwriteConfig:$Overwrite
            if ($Overwrite) {
                (Get-Content $config_path).Count | Should -BeGreaterThan 1
            } else {
                Get-Content $config_path | Should -BeExactly "initial"
            }
        }
    }
    
    Context "ExistingDirectoryConfirmationTests" {
        BeforeDiscovery {
            $existing_dir_path = "TestDrive:\existing"
            $nonexisting_dir_path = "TestDrive:\nonexisting"
        }

        BeforeAll {
            $existing_dir_path = "TestDrive:\existing"
            $nonexisting_dir_path = "TestDrive:\nonexisting"
            New-Item $existing_dir_path -ItemType Directory
        }

        BeforeEach {
            Remove-Item -Path $nonexisting_dir_path -ErrorAction SilentlyContinue
        }

        It "UsingExistingDirsRequiresConfirmation" -TestCases @(
            @{WatchedDirs = @($existing_dir_path, $nonexisting_dir_path); ExpectedConfirmation = $true},
            @{WatchedDirs = @($existing_dir_path); ExpectedConfirmation = $true},
            @{WatchedDirs = @($nonexisting_dir_path); ExpectedConfirmation = $false}
        ) {
            Mock ConfirmDirs { return $false; }
            . $PSScriptRoot/../Setup.ps1 -WatchedDirs:$WatchedDirs -NoTask -OverwriteConfig
            if ($ExpectedConfirmation) {
                Should -Invoke -CommandName ConfirmDirs -Times 1 -Exactly -ParameterFilter { $existing -eq @($existing_dir_path) }
            } else {
                Should -Not -Invoke -CommandName ConfirmDirs
            }
        }

        It "UserResponseProcessedCorrectly" -TestCases @(
            @{Response = "Y"; ExpectedProceed = $true},
            @{Response = "N"; ExpectedProceed = $false}
        ) {
            Mock Read-Host { return $Response }
            Mock Set-Content {}
            . $PSScriptRoot/../Setup.ps1 -WatchedDirs:@($existing_dir_path) -NoTask -ConfigPath $config_path -OverwriteConfig
            if ($ExpectedProceed) {
                Should -Invoke -CommandName Set-Content -Times 1 -Exactly -ParameterFilter { $Path -eq $config_path}
            } else {
                Should -Not -Invoke -CommandName Set-Content
            }
        }
    }
}


Describe "SetupScheduledTaskTests" {
    BeforeAll {
        $config_path = "TestDrive:\sched.json"
        New-Item $config_path -ItemType File  # so these tests don't try to create config

        $task_name = "LT_Task"
        $task_path = "\LT_Path\"
        $bare_path = $task_path.Replace("\", "")

        Mock Get-ScheduledTask {
            return @([PSCustomObject]@{
                TaskName = $task_name; TaskPath = $task_path
            })
        }

        # Assume the user confirms everything
        Mock ConfirmDirs { return $true; }
    }

    It "ScheduledTaskSwitchesHandledCorrectly" -TestCases @(
        @{Disable = $false; DontStart = $true; ShouldDisable = $false; ShouldStart = $false},
        @{Disable = $false; DontStart = $false; ShouldDisable = $false; ShouldStart = $true},
        @{Disable = $true; DontStart = $true; ShouldDisable = $true; ShouldStart = $false},
        @{Disable = $true; DontStart = $false; ShouldDisable = $true; ShouldStart = $false}
    ) {
        . $PSScriptRoot/../Setup.ps1 -OverwriteTask -DisableTask:$Disable -DontStartImmediately:$DontStart -ConfigPath $config_path
        Should -Not -Invoke -CommandName Unregister-ScheduledTask
        Should -Invoke -CommandName Register-ScheduledTask -Times 1 -Exactly -ParameterFilter { $Settings.Enabled -eq !($ShouldDisable) }
        if ($ShouldStart) {
            Should -Invoke -CommandName Start-ScheduledTask -Times 1 -Exactly
        } else {
            Should -Not -Invoke -CommandName Start-ScheduledTask
        }
    }

    It "TaskOverwrittenOnlyWhenRequested" -TestCases @(
        @{Overwrite = $true},
        @{Overwrite = $false}
    ) {
        . $PSScriptRoot/../Setup.ps1 -OverwriteTask:$Overwrite -ConfigPath $config_path -TaskName $task_name -TaskPath $bare_path
        if ($overwrite) {
            Should -Invoke -CommandName Unregister-ScheduledTask -Times 1 -Exactly
            Should -Invoke -CommandName Register-ScheduledTask -Times 1 -Exactly
        } else {
            Should -Not -Invoke -CommandName Unregister-ScheduledTask
            Should -Not -Invoke -CommandName Register-ScheduledTask
        }
    }
}
