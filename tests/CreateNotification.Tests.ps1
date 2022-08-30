BeforeAll {
    . $PSScriptRoot/../CreateNotification.ps1

    # Test helper functions
    function GetNodeAttr ([Windows.Data.Xml.Dom.XmlDocument]$xml, [string]$tag, [string]$attr) {
        $node = GetNode $xml $tag
        return $node.GetAttribute($attr)
    }

    function HashItems ([hashtable]$h) {
        # Nicer to compare arrays than hashtables in Pester assertions
        return $h.GetEnumerator() | Sort-Object -property:Name | % { ( $_.Name, $_.Value ) }
    }

    # Suppress logging
    Mock WriteLogMessage {}

    # Remember current working directory
    $orig_wd = Get-Location
}


Describe "TextParsingUnitTests" {
    It "IgnoresComments" -TestCases @(
        @{Raw = @("TestText", "#comment"); Content = @("TestText")},
        @{Raw = @("TestText", "# comment"); Content = @("TestText")},
        @{Raw = @("TestText", " # comment"); Content = @("TestText", " # comment")},
        @{Raw = @("TestText", "|# comment"); Content = @("TestText", "# comment")}
    ) {
        (GetMessageParts $Raw).Content | Should -BeExactly $Content
    }

    It "ParsesDirectives" -TestCases @(
        @{Raw = @("TestText", "|foo: bar"); Directives = @{foo = "bar"}; Content = @("TestText")},
        @{Raw = @("|  abc:  def  ", "TestText", "#comment", "|foo: bar"); Directives = @{foo = "bar"; abc = "def"} ; Content = @("TestText")}
        @{Raw = @("TestText", "||escaped", "|foo: bar"); Directives = @{foo = "bar"}; Content = @("TestText", "|escaped")},
        @{Raw = @("|url: https://foo", "TestText"); Directives = @{url = "https://foo"}; Content = @("TestText")}
        @{Raw = @("|url: https://foo", "|boolfoo", "|!boolbar", "TestText"); Directives = @{url = "https://foo"; boolfoo=$true; boolbar=$false}; Content = @("TestText")}
    ) {
        $res = GetMessageParts $Raw
        $res.Content | Should -BeExactly $Content
        $actual_directives = HashItems $res.Directives
        $expected_directives = HashItems $Directives
        $actual_directives | Should -BeExactly $expected_directives
    }
}

Describe "FileProcessingIntegrationTests" {
    BeforeDiscovery {
        $test_default_image_source = "C:\foo\bar.jpg"
        $test_app_id = "0123abcd"
    }

    BeforeAll {
        $test_app_id = "0123abcd"
        $defaults = @{ImageSource = "C:\foo\bar.jpg"; DismissButton = $true}
        Mock ShowNotification {}
    }

    Context "SingleFileProcessing" {
        It "FileIsProcessedAndDeleted" {
            $test_file_path = "TestDrive:\test.toa"
            Set-Content $test_file_path -Value "TestText1`nTestText2"
            NotifyFromFile $test_file_path $test_app_id ""
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly
            $test_file_path | Should -Not -Exist
        }

        It "EmptyFileIsIgnored" {
            $test_file_path = "TestDrive:\emptytest.toa"
            New-Item -Path $test_file_path -ItemType File
            NotifyFromFile $test_file_path $test_app_id ""
            Should -Invoke -CommandName ShowNotification -Times 0 -Exactly
            $test_file_path | Should -Exist
        }

        It "DefaultDirectivesArePassedThrough" -TestCases @(
            @{Raw = "TestText"; Expected = $test_default_image_source},
            @{Raw = "TestText`n|ImageSource: C:\baz.jpg"; Expected = "C:\baz.jpg"}
        ) {
            $test_file_path = "TestDrive:\defaultstest.toa"
            Set-Content $test_file_path -Value $Raw
            NotifyFromFile $test_file_path $test_app_id "" -default_directives:$defaults
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly -ParameterFilter {GetNodeAttr $xml "image" "src" -eq $Expected}
        }

        It "BooleanDefaultDirectiveOverridesAreApplied" -TestCases @(
            @{Raw = "TestTest"; ExpectedDismiss = $true},
            @{Raw = "TestText`n|!DismissButton"; ExpectedDismiss = $false}
        ) {
            $default_dismiss = @{DismissButton = $true}
            $test_file_path = "TestDrive:\booldefaultstest.toa"
            Set-Content $test_file_path -Value $Raw
            NotifyFromFile $test_file_path $test_app_id "" -default_directives:$default_dismiss
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly -ParameterFilter {
                ([bool](GetNode $xml "action")) -eq $ExpectedDismiss
            }
        }

        It "DefaultSourceAppIdCanBeOverridden" -TestCases @(
            @{Raw = "Testtext`n|SourceAppId: APP-987"; Expected = "APP-987"},
            @{Raw = "Testtext"; Expected = $test_app_id}
        ) {
            $test_file_path = "TestDrive:\appidtest.toa"
            Set-Content $test_file_path -Value $Raw
            NotifyFromFile $test_file_path $test_app_id ""
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly -ParameterFilter {$source_app_id -eq $Expected}
        }
    }

    Context "DirectoryProcessing" {
        BeforeAll {
            $test_dir = Join-Path $TestDrive "testdir"
            $test_subdir = Join-Path $test_dir "subdir"
            New-Item -Path $test_dir -ItemType Directory
            New-Item -Path $test_subdir -ItemType Directory
        }

        AfterEach {
            Get-ChildItem -Path $test_dir -File -Recurse | Remove-Item
            Set-Location $orig_wd
        }

        It "FilenamePatternIsApplied" {
            $filenames = @("foo.abc", "bar.abc", "baz.xyz")
            foreach($fn in $filenames) {
                $file_path = "$test_dir\$fn"
                Set-Content $file_path -Value "TestText"
            }
            NotifyFromDir $test_dir $test_app_id "" -min_age_sec:0 -file_pattern:"*.abc"
            Should -Invoke -CommandName ShowNotification -Times 2 -Exactly
        }

        It "MinimumFileAgeIsApplied" {
            $test_file_path = "$test_dir\test.toa"
            Set-Content $test_file_path -Value "TestText3"
            NotifyFromDir $test_dir $test_app_id "" -min_age_sec:1000
            Should -Invoke -CommandName ShowNotification -Times 0 -Exactly
            NotifyFromDir $test_dir $test_app_id "" -min_age_sec:0
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly
        }

        It "EmptyDirectoryNameIsRejected" {
            $test_file_path = "$test_dir\test.toa"
            Set-Content $test_file_path -Value "TestText3"
            Set-Location $test_dir
            NotifyFromDir "" $test_app_id "" -min_age_sec:0
            Should -Invoke -CommandName ShowNotification -Times 0 -Exactly
            NotifyFromDir "." $test_app_id "" -min_age_sec:0
            Should -Invoke -CommandName ShowNotification -Times 1 -Exactly
        }

        It "RecurseSettingIsFollowed" -TestCases @(
            @{Recurse = $true; Expected = 1},
            @{Recurse = $false; Expected = 0}
        ) {
            $test_file_path = "$test_subdir\test.toa"
            Set-Content $test_file_path -Value "TestTextR"
            NotifyFromDir $test_dir $test_app_id "" -min_age_sec:0 -recurse:$Recurse
            Should -Invoke -CommandName ShowNotification -Times $Expected -Exactly
        }
    }
}