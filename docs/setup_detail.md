# Detailed setup options

The command-line options to `Setup.ps1` are as follows.  `~` here is the current user's home directory.

Several options allow values to be passed into the configuration JSON file that is created: for the meaning of these, refer to the [documentation on config parameters](config_detail.md).

| Argument name | Type | Default | Meaning |
|---------------|------|---------|---------|
| `-ConfigPath` | valid file path | `~/LightlyToasted/Configs/default.json` | Location of the JSON config file. |
| `-OverwriteConfig` | switch | | Set this switch to overwrite any config that already exists at `-ConfigPath`. |
| `-WatchedDirs` | comma-separated list of directory paths | *[see documentation on configuration](config_detail.md)* |
| `-LogsDir` | valid directory path | *[see documentation on configuration](config_detail.md)* | |
| `-SweepIntervalSec` | numeric | *[see documentation on configuration](config_detail.md)* | |
| `-FilePattern` | file filter string | *[see documentation on configuration](config_detail.md)* | |
| `-PurgeLogsOlderThan` | numeric | *[see documentation on configuration](config_detail.md)* | |
| `-TimestampFromFile` | switch | *[see documentation on configuration](config_detail.md)* | |
| `-Recurse` | switch | *[see documentation on configuration](config_detail.md)* | |
| `-EnableWebImages` | switch | *[see documentation on configuration](config_detail.md)* | |
| `-MaxWebImageSizeKb` | numeric | *[see documentation on configuration](config_detail.md)* | |
| `-NoTask` | switch | | If supplied, no scheduled task is created (only the config file). |
| `-TaskPath` | string | `LightlyToasted` | The Task Scheduler folder in which the scheduled task will be created. |
| `-TaskName` | string | `LightlyToasted` | The name of the scheduled task. |
| `-OverwriteTask` | switch | | Set this switch to overwrite any task that already exists at `-TaskPath\-TaskName`. |
| `-DisableTask` | switch | | Set this switch to create the task in Disabled state. |
| `-DontStartImmediately` | switch | | Set this switch to prevent the created task from being immediately started by the script. |