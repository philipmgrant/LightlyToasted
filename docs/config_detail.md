# Configuring LightlyToasted

The preferred way of defining a configuration is to use a JSON file, which is then passed to `Runner.ps1` using the `-Config` argument.  The [quick install process](quick_install.md) generates an initial JSON file, and you can edit this to avoid creating a config from scratch.

A valid configuration file consists of a single JSON object, which can contain the following keys:

| Key | Value type | Meaning | Default if unspecified
|---------------|------|---------|---------|
| `WatchedDirs` | list of directory paths | Directories to be monitored for notification files. | N/A - **mandatory**. If absent from the JSON, it must be supplied on the command line. |
| `LogsDir` | valid directory path | Directory for log files. | No logs are written. |
| `SweepIntervalSec` | numeric | Interval (in seconds) between reads of the watched directories.  (NB This does not stop LightlyToasted processing files in real-time: it's an [additional fallback](internals.md#detecting-notification-files).)| Interval is 600 seconds (10 minutes) |
| `FilePattern` | file filter string | Pattern of filenames which will be processed as notifications.  Allowed wildcards are `*` and `?`, with their usual Windows meanings. | Filter is `*.toa`. (To include all files, `*.*` must be *explicitly* configured). |
| `PurgeLogsOlderThan` | numeric | If positive, on startup the task will purge log files older than *n* days. | All files are retained. |
| `TimestampFromFile` | boolean | If `true`, each notification will show the timestamp of the file that triggered them | Timestamp shown is the time the notification was fired. |
| `Recurse` | boolean | If `true`, subdirectories of the `WatchedDirs` will be recursively monitored. | Only files which belong directly to `WatchedDirs` are monitored. |
| `EnableWebImages` | boolean | If `true`, internet URLs are valid values of `ImageSource`: images will be downloaded to a temp directory. | Internet URLs are ignored if passed as `ImageSource` |
| `MaxWebImageSizeKb` | numeric | Maximum size in KB of internet images which will be downloaded. | 256 KB. | 
| `DefaultDirectives` | object | The object's key-value pairs supply default values for any of the [supported directives](directives_summary.md). | No default values are applied to the directives. |

As an example, the JSON below specifies (recursively) watched directories and a logs directory, specifies one week of log retention, and applies default directives to control image placement and give every notification a dismiss button.

    {
        "WatchedDirs": ["D:\\LightlyToasted\\Toast1", "D:\\LightlyToasted\\Toast2"],
        "LogsDir": "D:\\Logs\\ToastLogs",
        "PurgeLogsOlderThan": 7,
        "Recurse": true,
        "DefaultDirectives": {
            "ImagePlacement": "below",
            "DismissButton": true
        }
    }

Alternatively, these parameters (apart from `DefaultDirectives`) can be passed as [command-line arguments to `Runner.ps1`](how_to_run.md#running-from-the-command-line).
