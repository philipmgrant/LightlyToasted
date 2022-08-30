function ConfirmDirs([string[]]$existing) {
    Write-Host "LightlyToasted will monitor directories which currently exist:"
    Write-Host ($existing -join ',')
    Write-Host "Existing files in these directories may be deleted after processing!"
    $resp = ""
    while (@('y', 'n') -notcontains $resp.ToLower()) {
        $resp = Read-Host "Proceed using these directories? (Y/N)"
    }
    return ($resp.ToLower() -eq 'y')
}