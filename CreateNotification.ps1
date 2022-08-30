. $PSScriptRoot/DllLoad.ps1
. $PSScriptRoot/Logging.ps1
. $PSScriptRoot/NotificationXmlBuilder.ps1


function ShowNotification ([Windows.Data.Xml.Dom.XmlDocument]$xml, [string]$source_app_id) {
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($source_app_id).Show($toast)
}


function GetMessageParts ([string[]]$file_content) {
    $directives = @{}
    $content = @()
    foreach ($line in $file_content) {
        if ($line.StartsWith("#")) {
            # comment
        } elseif ($line.StartsWith("||") -or $line.StartsWith("|#") ) {
            # escape sequence, remove the initial | and interpret the rest as text
            $content += $line.Substring(1, $line.Length - 1)
        } elseif ($line.StartsWith("|")) {
            # directive
            $parts = $line.Substring(1, $line.Length - 1) -Split ":", 2
            $k = $parts[0].Trim()
            if ($k.StartsWith("!")) {
                # negative boolean directive
                $k = $k.Substring(1, $k.Length - 1)
                $directives[$k] = $false
            } else {
                $v = if ($parts.Count -gt 1) {$parts[1].Trim()} else {$true}
                $directives[$k] = $v 
            }
        } else {
            # message text
            $content += $line
        }
    }
    return (@{Directives=$directives; Content=$content})
}


function BuildToastDataFromContent ([string[]] $file_content, [string]$log_file_path = $null,
                                    [Nullable[datetime]]$timestamp = $null,
                                    [bool]$enable_web_images = $false, [int]$max_web_image_size_bytes = 0,
                                    [hashtable]$default_directives = @{}) {
    $message = GetMessageParts($file_content)
    $text_content = $message.Content
    $directives = $default_directives.Clone()
    foreach ($k in $message.Directives.Keys) {
        $directives[$k] = $message.Directives.$k
    }
    $builder = [NotificationXmlBuilder]::new($text_content, $directives, $timestamp, $log_file_path, $enable_web_images, $max_web_image_size_bytes)
    return $builder.GetNotificationData()
}


function NotifyFromFile ([string]$file_path, [string]$app_id, [string]$log_file_path,
                                    [switch]$timestamp_from_file = $false,
                                    [switch]$enable_web_images = $false, [int]$max_web_image_size_bytes = 0,
                                    [hashtable]$default_directives = @{}) {
    try {
        WriteLogMessage "Attempting to process $file_path" $log_file_path
        if ($timestamp_from_file) {
            $private:file_time = (Get-Item -Path $file_path).LastWriteTime
        } else {
            $private:file_time = $null
        }
        
        $private:file_content = Get-Content -Path $file_path
        if ($null -eq $file_content) {
            WriteLogMessage "Got no content for $file_path" $log_file_path
            return
        }
        if ($file_content.GetType().Name -eq "String") {
            $file_content = @($file_content)
        }
        
        $toast_data = BuildToastDataFromContent $file_content -log_file_path:$log_file_path -timestamp:$file_time `
                                                -default_directives:$default_directives `
                                                -enable_web_images:$enable_web_images -max_web_image_size_bytes:$max_web_image_size_bytes
        if (!$toast_data.Source_App_Id) {
            $toast_data['Source_App_Id'] = $app_id
        }
        WriteLogMessage "Firing toast with XML:" $log_file_path
        WriteLogMessage $toast_data.Xml.GetXml() $log_file_path
        ShowNotification @toast_data

        Remove-Item -Path $file_path
        WriteLogMessage "Processed and deleted $file_path" $log_file_path
    } catch {
        WriteLogMessage "Error raising toast for $file_path" $log_file_path
        WriteLogMessage $_ $log_file_path
    }
}


function NotifyFromDir ([string]$directory, [string]$app_id, [string]$log_file_path,
                                    [double]$min_age_sec = 5, [string]$file_pattern = "*.*",
                                    [hashtable]$default_directives = @{}, [switch]$timestamp_from_file = $false,
                                    [switch]$enable_web_images = $false, [int]$max_web_image_size_bytes = 0,
                                    [switch]$recurse = $false) {
    if (!($directory)) {
        WriteLogMessage "NotifyFromDir called with empty directory: pass '.' if you really want to use the working dir" $log_file_path
        return
    }
    $ts = Get-Date
    WriteLogMessage "Sweeping $directory" $log_file_path
    if ($recurse) {
        $files = Get-ChildItem -Path $directory -Filter $file_pattern -File -Recurse
    } else {
        $files = Get-ChildItem -Path $directory -Filter $file_pattern -File
    }
    
    $files | ForEach-Object {
        $age = (New-TimeSpan -Start $_.LastWriteTime -End $ts).TotalSeconds
        if ($age -ge $min_age_sec) {
            NotifyFromFile $_.FullName $app_id $log_file_path -default_directives:$default_directives -timestamp_from_file:$timestamp_from_file `
                            -enable_web_images:$enable_web_images -max_web_image_size_bytes:$max_web_image_size_bytes
        } else {
            WriteLogMessage "Ignoring too recent file: $($_.FullPath)" $log_file_path
        }
    }
    WriteLogMessage "Sweep complete for $directory" $log_file_path
}