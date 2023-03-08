# LightlyToasted internals

When LightlyToasted runs, it starts up an event loop, consisting essentially of:

1. Wait for a notification file to appear in a watched directory.

2. From the [text content and directives](file_format.md) in the file, generate notification content per the Windows [Toast XML schema](https://docs.microsoft.com/en-us/uwp/schemas/tiles/toastschema/schema-root).

3. Show the notification.

4. Delete the notification file.

While a notification may include elements which let the user interact with it further (clickable file and URL links, snooze and dismiss buttons etc), from LightlyToasted's point of view, the process is "fire and forget".  All user interaction with a notification is handled natively in Windows.

## Detecting notification files<!--anchorinuse-->

LightlyToasted uses a [FileSystemWatcher](https://docs.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher?view=net-6.0) to detect incoming files in near-real-time.  On startup, and at regular intervals (configurable by setting `SweepIntervalSec` in the config; every 10 minutes by default) it also checks the directory's contents and identifies any relevant files.  This handles anything that was waiting before LightlyToasted started, and serves as a fallback in case the FileSystemWatcher fails to detect something.  (For example, FileSystemWatcher does in principle work on LAN Samba shares, but shouldn't be expected to be 100% reliable.)

By default, LightlyToasted only looks at files with the extension `.toa`, but this is configurable by setting `Pattern` in the configuration.

