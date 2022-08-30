param (
    [string]$ConfigPath = "~/LightlyToasted/Configs/default.json",
    [switch]$OverwriteConfig = $false,
    [string[]]$WatchedDirs = @("~/LightlyToasted/Inbox"),
    [string]$LogsDir = "~/LightlyToasted/Logs",
    [double]$SweepIntervalSec = 600,
    [string]$FilePattern = "*.toa",
    [double]$PurgeLogsOlderThan = -1,
    [switch]$TimestampFromFile = $false,
    [switch]$Recurse = $false,
    [switch]$EnableWebImages = $false,
    [double]$MaxWebImageSizeKb = 256,
    [switch]$NoTask = $false,
    [string]$TaskPath = "LightlyToasted",
    [string]$TaskName = "LightlyToasted listener",
    [switch]$OverwriteTask = $false,
    [switch]$DisableTask = $false,
    [switch]$DontStartImmediately = $false
)

. $PSScriptRoot/SetupUtil.ps1


### Config creation
if (!($OverwriteConfig) -and (Test-Path $ConfigPath)) {
    Write-Host "Retaining existing config $ConfigPath"
} else {
    $existing_dirs = $WatchedDirs | Where-Object { Test-Path -Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_) }
    if ($existing_dirs) {
        if (!(ConfirmDirs $existing_dirs)) {
            Write-Host "Aborting setup."
            exit
        }
    }

    $config = @{WatchedDirs = $WatchedDirs; LogsDir = $LogsDir; SweepIntervalSec = $SweepIntervalSec; FilePattern = $FilePattern;
                PurgeLogsOlderThan = $PurgeLogsOlderThan; TimestampFromFile = [bool]$TimestampFromFile; Recurse = [bool]$Recurse;
                EnableWebImages = [bool]$EnableWebImages; MaxWebImageSizeKb = $MaxWebImageSizeKb}
    $config_json = ConvertTo-Json $config

    $parent_dir = Split-Path $ConfigPath -Parent
    New-Item $parent_dir -ItemType Directory -ErrorAction SilentlyContinue
    Set-Content -Path $ConfigPath -Value $config_json
    Write-Host "Created new config at $ConfigPath"
}

### Task creation
# Normalize task path
if (!($TaskPath.StartsWith("\"))) {
    $TaskPath = "\" + $TaskPath
}
if (!($TaskPath.EndsWith("\"))) {
    $TaskPath = $TaskPath + "\"
}

if (!($NoTask)) {
    $existing = Get-ScheduledTask | Where-Object {($_.TaskPath -eq $TaskPath) -and ($_.TaskName -eq $TaskName)}
    if (!$OverwriteTask -and $existing) {
        Write-Host "Retaining existing task $TaskPath$TaskName"
    } else {
        $ps_exe_path = (Get-Process -Id $PID).Path
        $exec_args = "-WindowStyle Hidden -Command . $PSScriptRoot\Runner.ps1 -Config $ConfigPath; " + 'exit $LASTEXITCODE'

        $action = New-ScheduledTaskAction -WorkingDirectory $PSScriptRoot -Execute $ps_exe_path -Argument $exec_args
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -Disable:$DisableTask
        $task_description = "Listen for new text files and fire toast notifications"

        if ($existing) {
            Write-Host "Deleting existing task..."
            $existing | Unregister-ScheduledTask -Confirm:$false -ErrorAction Stop
        }
        Write-Host "Creating task..."
        Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -TaskName $TaskName -TaskPath $TaskPath -Description $task_description

        if (!($DontStartImmediately) -and !($DisableTask)) {
            Write-Host "Starting task..."
            Start-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
        }
    }
}
