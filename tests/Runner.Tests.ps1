BeforeAll {
    . $PSScriptRoot/../DllLoad.ps1
    . $PSScriptRoot/../Init.ps1
    . $PSScriptRoot/../Listener.ps1
    . $PSScriptRoot/../CreateNotification.ps1

    # Suppress and instrument actual notification firing
    Mock ShowNotification {}

    # Suppress logging
    Mock WriteLogMessage {}
    
    # Intercept the otherwise infinite event loop
    Mock Wait-Event { return New-MockObject -Type System.Management.Automation.PSEventArgs -Properties @{MessageData = @{TerminateLoop = $true}} }
}


Describe "RunnerTests" {
    BeforeAll {
        $json_config_str = '{"WatchedDirs":["TestDrive:\\D1", "TestDrive:\\D2"], "LogsDir":"TestDrive:\\Logs", "SweepIntervalSec":30}'
        $json_nested_config_str = '{"WatchedDirs":["TestDrive:\\D1", "TestDrive:\\D2"], "LogsDir":"TestDrive:\\Logs", "SweepIntervalSec":30, "DefaultDirectives":{"ImagePlacement":"below", "DismissButton":true}}'
        $json_bad_config_str = '{"WatchedDirs":["TestDrive:\\D1", "TestDrive:\\D2"], "LogsDir":"TestDrive:\\Logs", "EnableWebImages":{"IsPresent": true}}'
        $json_config_path = "TestDrive:\config.json"
        $json_nested_config_path = "TestDrive:\config_nested.json"
        $json_bad_config_path = "TestDrive:\config_bad.json"
        Set-Content $json_config_path -Value $json_config_str
        Set-Content $json_nested_config_path -Value $json_nested_config_str
        Set-Content $json_bad_config_path -Value $json_bad_config_str

        # Suppress event firing
        Mock New-Event {}
    }

    BeforeEach {
        $global:app_context = $null
    }

    Context "RunnerUnitTests" {
        BeforeAll {
            # Mock the calls we want to instrument
            Mock Initialize {}
        }

        It "JsonOnlyParametersPassedThrough" {
            . $PSScriptRoot/../Runner.ps1 -Config $json_config_path
            Should -Invoke -CommandName Initialize -Times 1 -Exactly -ParameterFilter {
                (!(Compare-Object $WatchedDirs @("TestDrive:\D1", "TestDrive:\D2"))) -and ($LogsDir -eq "TestDrive:\Logs") `
                -and ($SweepIntervalSec -eq 30)
            }
            Should -Invoke -CommandName Wait-Event
        }

        It "CommandLineParametersOnlyPassedThrough" {
            . $PSScriptRoot/../Runner.ps1 -WatchedDirs "TestDrive:\D5","TestDrive:\D6" -LogsDir "TestDrive:\Logs2" -FilePattern "*.xyz"
            Should -Invoke -CommandName Initialize -Times 1 -Exactly -ParameterFilter {
                (!(Compare-Object $WatchedDirs @("TestDrive:\D5", "TestDrive:\D6"))) -and ($LogsDir -eq "TestDrive:\Logs2") `
                -and ($FilePattern -eq "*.xyz")
            }
            Should -Invoke -CommandName Wait-Event
        }

        It "CommandLineParametersOverrideJson" {
            . $PSScriptRoot/../Runner.ps1 -Config $json_config_path -SweepIntervalSec 60
            Should -Invoke -CommandName Initialize -Times 1 -Exactly -ParameterFilter {
                (!(Compare-Object $WatchedDirs @("TestDrive:\D1", "TestDrive:\D2"))) -and ($LogsDir -eq "TestDrive:\Logs") -and ($SweepIntervalSec -eq 60)
            }
            Should -Invoke -CommandName Wait-Event
        }

        It "LoggingInitializedWithPartlyBrokenConfig" {
            . $PSScriptRoot/../Runner.ps1 -Config $json_bad_config_path
            $app_context.log_file_path | Should -Not -BeNullOrEmpty
            Should -Not -Invoke -CommandName Wait-Event
        }
    }

    Context "RunnerIntegrationTests" {
        BeforeAll {
            # Mock the calls we want to instrument
            Mock CreateToastListeners {}
            Mock CreateToastDirectorySweeper {}
        }

        It "DefaultValuesUsedForUnsuppliedParameters" {
            . $PSScriptRoot/../Runner.ps1 -Config $json_config_path -SweepIntervalSec 60
            Should -Invoke -Command CreateToastListeners -Times 1 -Exactly -ParameterFilter {
                $file_pattern -eq "*.toa"
            }
            Should -Invoke -Command CreateToastDirectorySweeper -Times 1 -Exactly -ParameterFilter {
                ($file_pattern -eq "*.toa") -and ($min_age_sec -eq 5) -and ($interval_sec -eq 60)
            }
        }

        It "DefaultDirectivesHandledCorrectly" {
            . $PSScriptRoot/../Runner.ps1 -Config $json_nested_config_path
            $app_context.default_directives.ImagePlacement | Should -BeExactly "below"
            $app_context.default_directives.DismissButton | Should -BeTrue
        }
    }
}

Describe "EndToEndSmokeTest" {
    BeforeAll {
        $directories = @("D1", "D2") | % { Join-Path $TestDrive $_ }
        $directories | % { New-Item -Path $_ -ItemType Directory }

        $config = @{WatchedDirs = $directories; LogsDir = "TestDrive:\\Logs"; SweepIntervalSec = 300}
        $json_config_str = $config | ConvertTo-Json
        $json_config_path = "TestDrive:\smokeconfig.json"
        Set-Content $json_config_path -Value $json_config_str
    }

    AfterEach {
        $directories | % { Get-ChildItem -Path $_ -File } | Remove-Item
    }

    AfterAll {
        Get-EventSubscriber | % { Unregister-Event $_.SourceIdentifier }
    }

    It "SweeperAndListenerHandleFilesCorrectly" {
        # Put a file ready for the sweeper
        $initial_file_path = Join-Path $directories[0] "toast.toa"
        Set-Content $initial_file_path -Value "PresentAtStartup"

        # Initialize
        . $PSScriptRoot/../Runner.ps1 -Config $json_config_path  # listeners are still present after this for the next part of the test
        Should -Invoke -CommandName ShowNotification -Times 1 -Exactly -ParameterFilter {
            $xml.GetElementsByTagName("text").Item(0).InnerText -eq "PresentAtStartup"
        }

        # Drop a new file and check it's processed in realtime
        $live_file_path = Join-Path $directories[1] "live.toa"
        Set-Content $live_file_path -Value "AddedLive"
        Should -Invoke -CommandName ShowNotification -Times 1 -Exactly -ParameterFilter {
            $xml.GetElementsByTagName("text").Item(0).InnerText -eq "AddedLive"
        }
    }
}