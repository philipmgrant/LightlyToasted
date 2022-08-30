. $PSScriptRoot/CreateNotification.ps1
. $PSScriptRoot/Logging.ps1


function global:HandleFileEvent ([System.Management.Automation.PSEventArgs]$ev) {
    NotifyFromFile $ev.SourceArgs.FullPath $app_context.app_id $app_context.log_file_path `
                            -default_directives:$app_context.default_directives -timestamp_from_file:$app_context.timestamp_from_file `
                            -enable_web_images:$app_context.enable_web_images -max_web_image_size_bytes:$app_context.max_web_image_size_bytes
}


function global:HandleDirectoriesEvent ([System.Management.Automation.PSEventArgs]$ev) {
    foreach($dir in $ev.MessageData.Directories) {
        NotifyFromDir $dir $app_context.app_id $app_context.log_file_path `
            -file_pattern:$ev.MessageData.Pattern -default_directives:$app_context.default_directives `
            -timestamp_from_file:$app_context.timestamp_from_file `
            -enable_web_images:$app_context.enable_web_images -max_web_image_size_bytes:$app_context.max_web_image_size_bytes `
            -min_age_sec:$ev.MessageData.MinAgeSec -recurse:$ev.MessageData.Recurse
    }
}


function CreateToastListeners ([string[]]$directories, [string]$file_pattern = "*.*", [switch]$recurse = $false) {
    $i = 0
    foreach($directory in $directories) {
        WriteLogMessage "Creating listener for: $directory" $app_context.log_file_path
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $directory
        $watcher.Filter = $file_pattern
        $watcher.EnableRaisingEvents = $true
        $watcher.IncludeSubdirectories = $recurse

        foreach ($ev_name in @("Created", "Renamed")) {
            Register-ObjectEvent -SourceIdentifier "LightlyToasted$i" `
                                    -InputObject $watcher `
                                    -EventName $ev_name `
                                    -Action { try { HandleFileEvent $event } catch { WriteLogMessage $_.Exception.Message $app_context.log_file_path } }
            $i++
        }
    }
}


function CreateToastDirectorySweeper([string[]]$directories, [double]$interval_sec = 300, [string]$file_pattern = "*.*",
                                    [double]$min_age_sec = 5, [switch]$recurse = $false) {
    WriteLogMessage "Creating directory sweeper for $( $directories.Length ) directories:" $app_context.log_file_path
    $directories | % { WriteLogMessage "    $_" $app_context.log_file_path }
    $timer = New-Object System.Timers.Timer
    $timer.Interval = $interval_sec * 1000
    $timer.AutoReset = $true
    $timer.Enabled = $true

    Register-ObjectEvent -SourceIdentifier "LightlyToastedSweep" `
                            -InputObject $timer `
                            -EventName "Elapsed" `
                            -MessageData @{Directories = $directories; Pattern = $file_pattern; MinAgeSec = $min_age_sec; Recurse = $recurse} `
                            -Action { try { HandleDirectoriesEvent $event } catch { WriteLogMessage $_.Exception.Message $app_context.log_file_path } }

    Register-EngineEvent -SourceIdentifier "LightlyToastedSweepForce" `
                            -Action {try { HandleDirectoriesEvent $event } catch { WriteLogMessage $_.Exception.Message $app_context.log_file_path } }
}
