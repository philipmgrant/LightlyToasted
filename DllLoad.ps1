$legacy = $PSVersionTable.PSVersion.Major -eq 5

[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\dll\CommunityToolkit.WinUI.Notifications.dll")
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\dll\Microsoft.Windows.SDK.NET.dll")
[System.Reflection.Assembly]::LoadFrom("$PSScriptRoot\dll\WinRT.Runtime.dll")

if ($legacy) {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
}