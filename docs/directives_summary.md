## Summary of valid directives

All the below directives can be either specified per notification using [special lines in the text file](file_format.md), or [configured as defaults](config.md).

| Name              | Type      | Valid values                      | Meaning                                                           |
|-------------------|-----------|-----------------------------------|-------------------------------------------------------------------|
| `Header`            | String    | Any string | Header text which appears above the notification. Also useful as a grouping key: notifications with the same app ID and header will appear together as a ["conversation"](https://docs.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-headers). |
| `AttributionText`   | String    | Any string | An additional line of small text which appears at the bottom of the notification. |
| `Scenario`          | String    | `reminder`, `alarm`, `urgent`, `incomingCall` | The "scenario" which should govern the notification's behaviour (but the effect is limited TODO link here). |
| `Duration`          | String    | `short`, `long` | The duration for the notification to remain on screen before minimising.  `short` (the default) and `long` correspond to about 5 and 25 seconds respectively.|
| `ImageSource`       | String    | Valid local path or URL | The path or URL of a local or (if TODO link web image downloads are enabled) internet image file. |
| `ImageAltText`      | String    | Any string | Alternate text for the image. |
| `ImagePlacement`    | String    | `hero`, `below` | Instead of placing the image at the left of the notification, puts it above (`hero`) or below (`below`) the text. |
| `ImageCrop`         | String    | `circle` | Crops the image into a circle.  Has no effect when `ImagePlacement` is specified. |
| `ButtonLabel1`, `ButtonLabel2`, ... | String | Any string | Text labels to appear on the buttons of the notification. |
| `ButtonTarget1`, `ButtonTarget2`, ... | String | Valid local path or URL | The path of a file, or the URL, which will be opened on clicking the button. |
| `DismissButton`   | Boolean || Adds a "Dismiss" button allowing the user to dismiss the notification. |
| `SnoozeButton`    | Boolean || Adds a "Snooze" button allowing the user to snooze the notification for the system default time. |
| `ButtonsInContextMenu` | Boolean || Removes the buttons from the notification body and makes them accessible through a context menu. |
| `SourceAppId`       | String    | [AppUserModelID](https://docs.microsoft.com/en-us/windows/win32/shell/appids) of an installed app | Sets the application which will appear as the source of the notification. |