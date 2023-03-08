# Using directives

## Header and AttributionText <!--anchorinuse-->

The `Header` and `AttributionText` directives allow text to be rendered above and below the main body of the notification (so in total, you can get up to 5 lines of text: header, 3 lines of body text, and attribution).

| | |
|-|-|
| `\|Header: Header_text`<br>`\|AttributionText: Brought to you by LightlyToasted`<br>`Body text`<br>`Some more body text`<br>`A final line of body text` | <img src="images/header_and_attr.png" alt="Example notification with header and attribution text"> |

The header is also useful as a grouping key: notifications with the same app ID and header will appear together as a ["conversation"](https://docs.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-headers).  This is particularly useful when there isn't a particular `SourceAppId` applicable to your script or app: you can let LightlyToasted default to using PowerShell's own app ID, and use headers to keep related notifications together.

## Scenario and Duration <!--anchorinuse-->

The `Duration` directive is quite straightforward: a value of `long` causes the notification to stay on screen for about 25 seconds before sliding back into the taskbar.  A value of `short` gives the same as the default behaviour (about 5 seconds).

`Scenario` in principle should give some finer-grained behaviour about whether the notification plays a sound, how it interacts with "Focus Assist" mode and so on.  As far as I can tell, the actual effects are quite limited: the only value that makes a difference is `incomingCall` will keep the notification indefinitely on screen until the user dismisses it and (on Windows 11) play a specific "phone call" sound.

I'm definitely interested in hearing if you get different behaviour on your Windows setup!

## Images

The `ImageSource` directive can be a full local path or a URL.  (For local files, you can use a `file://` URL if you like, but a normal Windows path works just as well.)

Note that to [use images from internet URLs](internet_images.md), it's necessary to **set `EnableWebImages` to `true` for the LightlyToasted background task**: either through a config JSON file or a command line option.

The `ImageAltText` directive specifies alt text for accessibility.

By default, the image appears as a small square to the left of the notification text.

| | |
|-|-|
| `\|ImageSource: D:\Images\img1.png`<br>`\|ImageAltText: Example notification with square image to left of text`<br>`Notification`<br>`with square`<br>`image to left` | <img src="images/image_square_left.png" alt="Example notification with square image to left of text"> |

To crop it to a circle, include `|ImageCrop: circle`.

| | |
|-|-|
| `\|ImageSource: D:\Images\img1.png`<br>`\|ImageCrop: circle`<br>`\|ImageAltText: Example notification with circular image to left of text`<br>`Notification`<br>`with circular`<br>`image to left` | <img src="images/image_circle_left.png" alt="Example notification with circular image to left of text"> |

Alternatively, `ImagePlacement` allows the image to be placed below the text, or above it (a `hero` image in Microsoft's terminology).

| | |
|-|-|
| `\|ImageSource: D:\Images\imgrect.png`<br>`\|ImagePlacement: hero`<br>`\|ImageAltText: Example notification with image above text`<br>`Notification`<br>`with image`<br>`above the text` | <img src="images/image_hero.png" alt="Example notification with image above text" height=220> |
| `\|ImageSource: D:\Images\imgrect.png`<br>`\|ImagePlacement: below`<br>`\|ImageAltText: Example notification with image below text`<br>`Notification`<br>`with image`<br>`below the text` | <img src="images/image_below.png" alt="Example notification with image below text" height=160> |



## Action buttons

Your notification can include any combination of the following:

* A **snooze** button that snoozes the notification for the system default time.
* A **dismiss** button that permanently dismisses the notification.
* Your own custom buttons which open **URLs** or **local files**:
    * URLs are opened with the default browser.
    * Local files are opened with the default app for the file's extension.  (Unfortunately if there is no default, Windows doesn't ask the user to choose an app: the action just fails silently.)

To include snooze and/or dismiss buttons, use the directives `|SnoozeButton` and `|DismissButton` respectively.

To include custom buttons, use pairs of directives: `|ButtonTarget1` and `|ButtonLabel1` for the first button; `|ButtonTarget2` and `|ButtonLabel2` and so on.

| | |
|-|-|
| `Notification`<br>`with clickable buttons`<br>`\|SnoozeButton`<br>`\|DismissButton`<br>`\|ButtonLabel1: Github`<br>`\|ButtonTarget1: https://www.github.com`<br>`\|ButtonLabel2: Logs`<br>`\|ButtonTarget2: C:\Temp\LogsDir\logfile.txt`<br> | <img src="images/buttons.png" alt="Example notification with buttons"> |

## Source application ID

All Windows toast notifications are associated with an app: the app name and mini-icon appear at the top of the notification, and govern the grouping of notifications in the taskbar.  To be a fully capable "owner" of notifications, an app needs to have an [AppUserModelID](https://docs.microsoft.com/en-us/windows/win32/shell/appids).

LightlyToasted aims to be portable and not to touch the Windows Registry or Start Menu, so we don't get an AppUserModelID.  Instead, LightlyToasted by default uses the ID of the app that is guaranteed to exist on any system that can run LightlyToasted, i.e. PowerShell!

Although this means that all LightlyToasted notifications will by default be grouped under PowerShell in the taskbar, you can ensure that related notifications stay together in a common subgroup by giving their notifications the same header, [using the `|Header` directive](#header-and-attributiontext).

You can override the use of PowerShell's AppID by setting the `|SourceAppId` directive: either per notification, or by setting it as a default directive in the LightlyToasted config.  So if you're using LightlyToasted to send notifications from an app that has an AppUserModelID, you can use that and Windows will resolve it to an application name and icon.  (You can see the available AppUserModelIDs on the system using the Powershell cmdlet `Get-StartApps`.)

| | |
|-|-|
| `\|SourceAppId: Microsoft.Office.WINWORD.EXE.15`<br>`\|ImageSource: https://bit.ly/3R1yaBN`<br>`It looks like you're writing a letter`<br>`Would you like help?` | <img src="images/clippy.png" alt="Example notification with an AppUserModelID"> |

It is also possible to supply a free text string (not a valid AppUserModelID) as `|SourceAppId`.  In this case, the string you supply will be shown as the application on the notification.

| | |
|-|-|
| `\|SourceAppId: Some unregistered app`<br>`\|ImageSource: D:\Images\img1.png`<br>`Setting the SourceAppId`<br>`to any string`<br>`does "work", sometimes` | <img src="images/unregistered_app.png" alt="Example notification with a free-text SourceAppId"> |

**CAUTION: this is undocumented behaviour**, and seems to work only partially: some types of notification will silently fail to display.  For example, simple text-only notifications seem to work, but:

* Notifications with a header silently fail.
* Notifications with an image placement of `hero` or `below` silently fail.


