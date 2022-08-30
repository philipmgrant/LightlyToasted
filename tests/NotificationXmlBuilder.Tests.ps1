BeforeAll {
    . $PSScriptRoot/../CreateNotification.ps1
    . $PSScriptRoot/../NotificationXmlBuilder.ps1

    # Test helper functions
    function GetNodeAttr ([Windows.Data.Xml.Dom.XmlDocument]$xml, [string]$tag, [string]$attr) {
        $node = GetNode $xml $tag
        return $node.GetAttribute($attr)
    }

    function ToastXmlFromContent {
        return (BuildToastDataFromContent @args).Xml
    }

    # Suppress logging
    Mock WriteLogMessage {}
}


Describe "ToastXmlIntegrationTests" {
    BeforeDiscovery {
        $cases = Get-ChildItem -Path "$PSScriptRoot/input" -Filter "*.toa" | % { @{Name = $_.BaseName} }
    }

    It "TextFileGivesExpectedXml" -TestCases $cases {
        $input_path = "$PSScriptRoot\input\$Name.toa"
        $expected_path = "$PSScriptRoot\expected\$Name.xml"
        $input_content = Get-Content -Path $input_path
        (ToastXmlFromContent $input_content).GetXml() | Should -BeExactly (Get-Content -Path $expected_path) -Because "<Expected XML for $Name>"
    }
}


Describe "ToastXmlUnitTests" {
    BeforeDiscovery {
        $test_default_image_source = "C:\foo\bar.jpg"
        $mock_image_cache_path = "T:\TempFromWeb.tmp"
    }

    BeforeAll {
        $defaults = @{ImageSource = "C:\foo\bar.jpg"}

        # Mock the web image fetch to check it's used when needed
        $mock_image_cache_path = "T:\TempFromWeb.tmp"
        Mock FetchImage {return $mock_image_cache_path}
    }

    Context "DefaultDirectives" {
        It "DefaultsAreAppliedButOverridable" -TestCases @(
            @{Content = @("TestText"); Expected = $test_default_image_source},
            @{Content = @("TestText", "|ImageSource: C:\baz.jpg"); Expected = "C:\baz.jpg"}
        ) {
            $xml = ToastXmlFromContent $Content -default_directives:$defaults
            GetNodeAttr $xml "image" "src" | Should -Be $Expected
        }
    }

    Context "Header" {
        It "SetsHeader" {
            $input_content = @("TestText", "|Header: LT")
            $header_node = GetNode (ToastXmlFromContent $input_content) "header"
            $header_node.GetAttribute("id") | Should -BeExactly "LT"
            $header_node.GetAttribute("title") | Should -BeExactly "LT"
            $header_node.GetAttribute("arguments") | Should -BeExactly ""
        }

        It "NoHeaderByDefault" {
            $input_content = @("TestText")
            $header_node = GetNode (ToastXmlFromContent $input_content) "header"
            $header_node | Should -BeNullOrEmpty
        }
    }

    Context "Duration" {
        It "SetsDurationIffValueAllowed" -TestCases @(
            @{DurationDirective = "short"; DurationXml = "short"},
            @{DurationDirective = "long"; DurationXml = "long"},
            @{DurationDirective = "lOnG"; DurationXml = "long"},
            @{DurationDirective = "medium"; DurationXml = $null}
        ) {
            $input_content = @("|Duration: $DurationDirective", "TestText")
            $xml = ToastXmlFromContent $input_content
            if ($DurationXml) {
                GetNodeAttr $xml "toast" "duration" | Should -BeExactly $DurationXml
            } else {
                GetNodeAttr $xml "toast" "duration" | Should -BeNullOrEmpty
            }
        }
    }

    Context "Scenario" {
        It "SetsScenarioIffValueAllowed" -TestCases @(
            @{ScenarioDirective = "reminder"; ScenarioXml = "reminder"},
            @{ScenarioDirective = "REMINDER"; ScenarioXml = "reminder"},
            @{ScenarioDirective = "alarm"; ScenarioXml = "alarm"},
            @{ScenarioDirective = "incomingcall"; ScenarioXml = "incomingCall"},
            @{ScenarioDirective = "uRgEnT"; ScenarioXml = "urgent"},
            @{ScenarioDirective = "somethingElse"; ScenarioXml = $null}
        ) {
            $input_content = @("|Scenario: $ScenarioDirective", "TestText")
            $xml = ToastXmlFromContent $input_content
            if ($ScenarioXml) {
                GetNodeAttr $xml "toast" "scenario" | Should -BeExactly $ScenarioXml
            } else {
                GetNodeAttr $xml "toast" "scenario" | Should -BeNullOrEmpty
            }
        }
    }

    Context "AttributionText" {
        It "SetsAttributionText" {
            $input_content = @("TestText", "|AttributionText: via LightlyToasted")
            $xml = ToastXmlFromContent $input_content
            $attribution_nodes = $xml.GetElementsByTagName("text") | Where-Object { $_.GetAttribute("placement") -eq "attribution" }
            $attribution_nodes | Should -HaveCount 1
            $attribution_nodes[0].InnerText | Should -BeExactly "via LightlyToasted"
        }
    }

    Context "Image" {
        It "SetsImageSource" {
            $input_content = @("|ImageSource: file:///foo/bar", "TestText")
            GetNodeAttr (ToastXmlFromContent $input_content) "image" "src" | Should -BeExactly "file:///foo/bar"
        }

        It "SetsImageAltText" {
            $input_content = @("|ImageSource: file:///foo/bar", "|ImageAltText: description of image", "TestText")
            GetNodeAttr (ToastXmlFromContent $input_content) "image" "alt" | Should -BeExactly "description of image"
        }

        It "HandlesImagePlacement" -TestCases @(
            @{PlacementDirective = "Hero"; PlacementXml = "hero"},
            @{PlacementDirective = "Below"; PlacementXml = $null}
        ) {
            $input_content = @("|ImageSource: file:///foo/bar", "|ImagePlacement: $PlacementDirective", "|ImageCrop: circle", "TestText")
            $xml = ToastXmlFromContent $input_content
            if ($PlacementXml) {
                GetNodeAttr $xml "image" "placement" | Should -BeExactly $PlacementXml
            } else {
                GetNodeAttr $xml "image" "placement" | Should -BeNullOrEmpty
            }
            
            GetNodeAttr $xml "image" "hint-crop" | Should -BeNullOrEmpty
            GetNodeAttr $xml "binding" "template" | Should -BeExactly "ToastGeneric"
        }

        It "IgnoresOtherImageAttrsIfNoSource" {
            $input_content = @("|ImageCrop: circle", "|ImagePlacement: hero", "TestText")
            $image_node = GetNode (ToastXmlFromContent $input_content) "image"
            $image_node.GetAttribute("src") | Should -BeExactly ""
            $image_node.GetAttribute("placement") | Should -BeNullOrEmpty
            $image_node.GetAttribute("hint-crop") | Should -BeNullOrEmpty
        }

        It "FetchesRemoteImageAccordingToParameter" -TestCases @(
            @{Source = "C:\foo.jpg"; EnableWebImages = $true; Expected = "C:\foo.jpg"},
            @{Source = "http://example.com/foo.jpg"; EnableWebImages = $true; Expected = $mock_image_cache_path},
            @{Source = "http://example.com/foo.jpg"; EnableWebImages = $false; Expected = ""}
        ) {
            $input_content = @("|ImageSource: $Source", "TestText")
            $xml = ToastXmlFromContent $input_content -enable_web_images:$EnableWebImages
            GetNodeAttr $xml "image" "src" | Should -BeExactly $Expected
        }

        It "AppliesMaximumWebImageSize" {
            $input_content = @("|ImageSource: http://example.com/foo.jpg", "TestText")
            $test_max_web_image_size = 5000
            $xml = ToastXmlFromContent $input_content -enable_web_images:$true -max_web_image_size_bytes:$test_max_web_image_size
            Should -Invoke -CommandName FetchImage -Times 1 -Exactly -ParameterFilter { $max_size_bytes -eq $test_max_web_image_size }
        }
    }

    Context "Buttons" {
        It "SingleButton" {
            $input_content = @("|ButtonTarget1: https://www.example.com", "|ButtonLabel1: MyAction", "TestText")
            $actions_parent_node = GetNode (ToastXmlFromContent $input_content) "actions"
            $action_nodes = $actions_parent_node.ChildNodes
            $action_nodes | Should -HaveCount 1
            $action_nodes[0].GetAttribute("arguments") | Should -BeExactly "https://www.example.com"
            $action_nodes[0].GetAttribute("content") | Should -BeExactly "MyAction"
            $action_nodes[0].GetAttribute("activationType") | Should -BeExactly "protocol"
        }

        It "MultiButtonsWithOptionalDismissAndContextMenu" -TestCases @(
            @{Dismiss = $true; InContextMenu = $true; ExpectedCount = 4},
            @{Dismiss = $true; InContextMenu = $false; ExpectedCount = 4},
            @{Dismiss = $false; InContextMenu = $true; ExpectedCount = 3},
            @{Dismiss = $false; InContextMenu = $false; ExpectedCount = 3}
        ) {
            $input_content = @("|ButtonTarget2: https://2.example.com", "|ButtonLabel2: Action2",
                                "|ButtonTarget10: https://10.example.com",
                                "|ButtonTarget5: https://5.example.com", "|ButtonLabel5: Action5",
                                "TestText")
            if ($Dismiss) {
                $input_content += "|DismissButton"
            }
            if ($InContextMenu) {
                $input_content += "|ButtonsInContextMenu"
            }
            $actions_parent_node = GetNode (ToastXmlFromContent $input_content) "actions"
            $action_nodes = $actions_parent_node.ChildNodes
            $action_nodes | Should -HaveCount $ExpectedCount
            $action_nodes.Item(0).GetAttribute("content") | Should -BeExactly "Action2"
            $action_nodes.Item(1).GetAttribute("content") | Should -BeExactly "Action5"
            $action_nodes.Item(2).GetAttribute("content") | Should -BeExactly "Visit web page"  # the default label
            $action_nodes.Item(0).GetAttribute("arguments") | Should -BeExactly "https://2.example.com"
            $action_nodes.Item(1).GetAttribute("arguments") | Should -BeExactly "https://5.example.com"
            $action_nodes.Item(2).GetAttribute("arguments") | Should -BeExactly "https://10.example.com"
            $action_nodes[0..2] | % { $_.GetAttribute("activationType") | Should -BeExactly "protocol" }

            if ($Dismiss) {
                $dismiss_node = $action_nodes.Item($action_nodes.Count - 1)
                $dismiss_node.GetAttribute("content") | Should -BeExactly "Dismiss"
                $dismiss_node.GetAttribute("arguments") | Should -BeExactly "dismiss"
                $dismiss_node.GetAttribute("activationType") | Should -BeExactly "system"
            }

            if ($InContextMenu) {
                $action_nodes | % { $_.GetAttribute("placement") | Should -BeExactly "contextMenu" }
            } else {
                $action_nodes | % { $_.GetAttribute("placement") | Should -BeNullOrEmpty }
            }
        }

        It "SnoozeAndDismissButtonsWorkTogetherOrSeparately" -TestCases @(
            @{Dismiss = $true; Snooze = $true; ExpectedCount = 3},
            @{Dismiss = $false; Snooze = $true; ExpectedCount = 2},
            @{Dismiss = $true; Snooze = $false; ExpectedCount = 2}
        ) {
            $input_content = @("|ButtonTarget2: https://2.example.com", "|ButtonLabel2: Action2", "TestText")
            if ($Dismiss) {
                $input_content += "|DismissButton"
            }
            if ($Snooze) {
                $input_content += "|SnoozeButton"
            }

            $actions_parent_node = GetNode (ToastXmlFromContent $input_content) "actions"
            $actions_parent_node.ChildNodes | Should -HaveCount $ExpectedCount
            $dismiss_nodes = $actions_parent_node.ChildNodes | Where-Object { $_.GetAttribute("arguments") -eq "dismiss" }
            $snooze_nodes = $actions_parent_node.ChildNodes | Where-Object { $_.GetAttribute("arguments") -eq "snooze" }
            if ($Dismiss) {
                $dismiss_nodes | Should -HaveCount 1
                $dismiss_nodes[0].GetAttribute("content") | Should -BeExactly "Dismiss"
                $dismiss_nodes[0].GetAttribute("activationType") | Should -BeExactly "system"
            } else {
                $dismiss_nodes | Should -BeNullOrEmpty
            }
            if ($Snooze) {
                $snooze_nodes | Should -HaveCount 1
                $snooze_nodes[0].GetAttribute("content") | Should -BeExactly "Snooze"
                $snooze_nodes[0].GetAttribute("activationType") | Should -BeExactly "system"
            } else {
                $snooze_nodes | Should -BeNullOrEmpty
            }
        }
    }

    Context "Timestamp" {
        It "TimestampOptional" -TestCases @(
            @{Dt = Get-Date -Date "2022-07-31 12:34:56.789Z"},
            @{Dt = $null}
        ) {
            $input_content = @("TestText")
            $xml = ToastXmlFromContent $input_content -timestamp:$Dt
            if ($null -eq $Dt) {
                GetNodeAttr $xml "toast" "displayTimestamp" | Should -BeNullOrEmpty
            } else {
                $expected = Get-Date -Date $Dt -Format "yyyy-MM-dd\THH:mm:ssK"
                GetNodeAttr $xml "toast" "displayTimestamp" | Should -BeExactly $expected
            }
        }
    }
}
