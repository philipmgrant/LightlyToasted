. $PSScriptRoot/Listener.ps1
. $PSScriptRoot/Logging.ps1


function InitalizeLogging ([string]$LogsDir) {
    # Minimal initialization of logging (so logs can be available before more complicated initialization steps)
    if ($null -eq $app_context) {
        $global:app_context = @{}
    }
    New-Item -Path $LogsDir -ItemType Directory -ErrorAction SilentlyContinue
    $ts = Get-Date -UFormat '%Y%m%d_%H%M%S'
    $app_context["log_file_path"] = Join-Path -Path $LogsDir -ChildPath "toast_$ts.log"
}


function Initialize ([string[]]$WatchedDirs = @(), [string]$FilePattern = "*.toa", [switch]$TimestampFromFile = $false, [double]$SweepIntervalSec = 600,
                    [double]$SweepMinAgeSec = 5, [string]$LogsDir = "", [double]$PurgeLogsOlderThan = -1, [hashtable]$DefaultDirectives = @{},
                    [switch]$SweepOnStartup = $false, [switch]$Recurse = $false, [switch]$EnableWebImages = $false, [double]$MaxWebImageSizeKb = 256) {
    if (!($WatchedDirs.Count)) {
        throw "Empty array of directories supplied"
    }

    if ($null -eq $app_context) {
        $global:app_context = @{}
    }
    $app_context["timestamp_from_file"] = $TimestampFromFile
    $app_context["default_directives"] = $DefaultDirectives
    $app_context["enable_web_images"] = $EnableWebImages
    $app_context["max_web_image_size_bytes"] = [int]($MaxWebImageSizeKb * 1000)

    $apps = Get-StartApps | Where-Object { $_.Name.ToLower() -match ("^(windows )?powershell") }
    $app_context["app_id"] = $apps[0].AppID

    if ($LogsDir) {
        if (!($app_context.log_file_path)) {
            InitalizeLogging $LogsDir
        }

        if ($PurgeLogsOlderThan -ge 0) {
            $keep_after = (Get-Date).AddDays(-$PurgeLogsOlderThan)
            Get-ChildItem -Path $LogsDir -File | Where-Object { $_.CreationTime -lt $keep_after } | Remove-Item -Force
        }
    } else {
        $app_context["log_file_path"] = $null
    }

    WriteLogMessage "Setting up listeners for $( $WatchedDirs.Length ) directories" $log_file_path

     # Resolve items like ~ in the path: the FileSystemWatcher needs the resolved path
    $dir_full_paths = $WatchedDirs | % { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_) }
    foreach($dir in $dir_full_paths) {
        New-Item -Path $dir -ItemType Directory -ErrorAction SilentlyContinue
    }
    CreateToastListeners $dir_full_paths -file_pattern:$FilePattern -recurse:$Recurse
    CreateToastDirectorySweeper $dir_full_paths -interval_sec:$SweepIntervalSec -file_pattern:$FilePattern -min_age_sec:$SweepMinAgeSec -recurse:$Recurse
    WriteLogMessage "Listener setup complete" $log_file_path

    if ($SweepOnStartup) {
        WriteLogMessage "Sweeping for files present on startup" $log_file_path
        New-Event -SourceIdentifier "LightlyToastedSweepForce" -MessageData @{Directories = $dir_full_paths; Pattern = $FilePattern; Recurse = $Recurse}
    }
}