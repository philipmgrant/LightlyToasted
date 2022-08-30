function global:WriteLogMessage ([string] $msg, [string]$log_file_path, [bool]$ToConsole = $true) {
    $ts = Get-Date -UFormat '%Y-%m-%d %H:%M:%S'
    if ($log_file_path) {
        if ($ToConsole) {
            "[$ts] $msg" | Tee-Object -FilePath $log_file_path -Append | Write-Host
        } else {
            "[$ts] $msg" | Out-File -FilePath $log_file_path -Append
        }
    } elseif ($ToConsole) {
        "[$ts] $msg" | Write-Host
    }
}