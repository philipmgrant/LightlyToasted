. $PSScriptRoot/DllLoad.ps1
. $PSScriptRoot/ImageCache.ps1
. $PSScriptRoot/Logging.ps1


function GetNode ([Windows.Data.Xml.Dom.XmlDocument]$xml, [string]$tag) {
    $elems = $xml.GetElementsByTagName($tag)
    if ($elems.Count) {
        return $elems[0]
    }
}


function FetchImage ([string]$uri, [string]$log_file_path = "", [nullable[int]]$max_size_bytes = $null) {
    # Proxy to work around problems with parse-time resolution of dependencies
    return [ImageCache]::FetchImage($uri, $log_file_path, $max_size_bytes)
}


class NotificationXmlBuilder {
    [string[]]$text_content
    [hashtable]$directives
    [Nullable[datetime]]$timestamp
    [string]$log_file_path
    [object]$xml  # Can't declare the "real" type here because: https://github.com/PowerShell/PowerShell/issues/3641
    [bool]$enable_web_images
    [int]$max_web_image_size_bytes

    NotificationXmlBuilder ([string[]]$text_content, [hashtable]$directives, [Nullable[datetime]]$timestamp,
                            [string]$log_file_path = "", [bool]$enable_web_images, [int]$max_web_image_size_bytes) {
        $this.text_content = $text_content
        $this.directives = $directives
        $this.timestamp = $timestamp
        $this.log_file_path = $log_file_path
        $this.enable_web_images = $enable_web_images
        $this.max_web_image_size_bytes = $max_web_image_size_bytes
        $this.xml = $null
    }

    [object]GetNotificationData () {
        if ($null -eq $this.xml) {
            $this.BuildXml()
        }
        return @{Xml = $this.xml; Source_App_Id = $this.directives.SourceAppId}
    }

    [void]BuildXml () {
        $this.InitializeFromTemplate()
        $this.SetTimestamp()
        $this.SetText()
        $this.SetAttributionText()
        $this.SetHeader()
        $this.SetScenario()
        $this.SetDuration()
        $this.SetImage()
        $this.SetActions()
    }

    [void]InitializeFromTemplate () {
        $mgr = [Windows.UI.Notifications.ToastNotificationManager]
        $ttt = [Windows.UI.Notifications.ToastTemplateType]

        # Pick a template according to how many lines of text content we have
        $tpl = $null
        switch ($this.text_content.Count) {
            1 { $tpl = $mgr::GetTemplateContent($ttt::ToastImageAndText01) }
            2 { $tpl = $mgr::GetTemplateContent($ttt::ToastImageAndText02) }
            default { $tpl = $mgr::GetTemplateContent($ttt::ToastImageAndText04) }
        }
        $this.xml = $tpl
    }

    [void]SetText () {
        $text_nodes = $this.xml.GetElementsByTagName("text")
        $i = 0
        $this.text_content[0..2] | % { $text_nodes.Item($i++).InnerText = $_ }
    }

    [void]SetTimestamp () {
        if ($this.timestamp) {
            (GetNode $this.xml "toast").SetAttribute("displayTimestamp", $this.timestamp.ToString("yyyy-MM-dd\THH:mm:ssK"))
        }
    }

    [void]SetHeader () {
        if ($this.directives.Header) {
            $header_node = $this.xml.CreateElement("header")
            $header_node.SetAttribute("id", $this.directives.Header)
            $header_node.SetAttribute("title", $this.directives.Header)
            $header_node.SetAttribute("arguments", "")
            (GetNode $this.xml "toast").AppendChild($header_node)
        }
    }

    [void]SetScenario () {
        if ($this.directives.Scenario) {
            foreach ($v in @("reminder", "alarm", "incomingCall", "urgent")) {
                if ($v.ToLower() -eq $this.directives.Scenario.ToLower()) {
                    (GetNode $this.xml "toast").SetAttribute("scenario", $v)
                    break
                }
            }
        }
    }

    [void]SetDuration () {
        if ($this.directives.Duration) {
            foreach ($v in @("short", "long")) {
                if ($v.ToLower() -eq $this.directives.Duration.ToLower()) {
                    (GetNode $this.xml "toast").SetAttribute("duration", $v)
                    break
                }
            }
        }
    }

    [void]SetAttributionText () {
        if ($this.directives.AttributionText) {
            $attribution_node = $this.xml.CreateElement("text")
            $attribution_node.SetAttribute("placement", "attribution")
            $attribution_node.InnerText = $this.directives.AttributionText
            (GetNode $this.xml "binding").AppendChild($attribution_node)
        }
    }

    [void]SetImage () {
        if ($this.directives.ImageSource) {
            $src = $this.directives.ImageSource
            if ($src.StartsWith("http:") -or $src.StartsWith("https:")) {
                # TODO make this configurable
                if ($this.enable_web_images) {
                    $src = FetchImage $src -log_file_path:$this.log_file_path -max_size_bytes:$this.max_web_image_size_bytes
                    if (!$src) {
                        WriteLogMessage "Could not get local copy of web image $src" $this.log_file_path
                        return
                    }
                } else {
                    WriteLogMessage "Web images downloads disabled: ignoring $src" $this.log_file_path
                    return
                }
            }

            $image_node = GetNode $this.xml "image"
            $binding_node = GetNode $this.xml "binding"
            $image_node.SetAttribute("src", $src)
            $can_crop = $true

            $alt_text = $this.directives.ImageAltText
            if ($alt_text) {
                $image_node.SetAttribute("alt", $alt_text)
            }

            $place = $this.directives.ImagePlacement
            if ($place) {
                switch ($place.ToLower()) {
                    "hero" {
                        $binding_node.SetAttribute("template", "ToastGeneric")
                        $image_node.SetAttribute("placement", "hero")
                        $can_crop = $false
                    }
                    "below" {
                        $binding_node.SetAttribute("template", "ToastGeneric")
                        $can_crop = $false
                    }
                    default {
                        WriteLogMessage "Ignoring unrecognised ImagePlacement: $place" $this.log_file_path
                    }
                }
            }

            $crop = $this.directives.ImageCrop
            if ($crop -and $can_crop) {
                if ($crop.ToLower() -eq "circle") { # only supported option at present
                    $image_node.SetAttribute("hint-crop", $crop.ToLower())
                } else {
                    WriteLogMessage "Ignoring unrecognised ImageCrop: $crop" $this.log_file_path
                }
            }
        }
    }

    [void]SetActions () {
        $action_nodes = @()

        $button_matches = $this.directives.Keys | Select-String -Pattern "^ButtonTarget(\d*)$"
        if ($button_matches) {
            $button_nodes = @{}
            foreach ($m in $button_matches) {
                $v = $m.Matches.groups[1].value  # Numerical suffix from the key (or "")
                $i = if ($v) { [int]$v } else { -1 }  # Integer index for sorting
                $target_directive = [string]$m
                $label_directive = "ButtonLabel$v"
                $label = if ($this.directives.$label_directive) { $this.directives.$label_directive } else { "Visit web page" }

                $button_node = $this.xml.CreateElement("action")
                $button_node.SetAttribute("arguments", $this.directives.$target_directive)
                $button_node.SetAttribute("activationType", "protocol")
                $button_node.SetAttribute("content", $label)
                $button_nodes[$i] = $button_node
            }
            foreach ($nv in $button_nodes.GetEnumerator() | Sort-Object -property:Name) {
                $action_nodes += $nv.Value
            }
        }

        $extras = @()
        if ($this.directives.SnoozeButton) {
            # Ordering isn't strictly necessary, but reproducibility is convenient for testing
            $extras += [ordered]@{arguments = "snooze"; activationType = "system"; content = "Snooze"}
        }
        if ($this.directives.DismissButton) {
            $extras += [ordered]@{arguments = "dismiss"; activationType = "system"; content = "Dismiss"}
        }
        foreach ($button in $extras) {
            $node = $this.xml.CreateElement("action")
            $button.GetEnumerator() | % { $node.SetAttribute($_.Key, $_.Value) }
            $action_nodes += $node
        }
        
        if ($action_nodes) {
            $actions_container_node = $this.xml.CreateElement("actions")
            (GetNode $this.xml "toast").AppendChild($actions_container_node)
            foreach ($an in $action_nodes) {
                if ($this.directives.ButtonsInContextMenu) {
                    $an.SetAttribute("placement", "contextMenu")
                }
                $actions_container_node.AppendChild($an)
            }
        }
    }
}