# How to run LightlyToasted

## Quickstart

The recommended way to run LightlyToasted is to first [do a quick install](quick_install.md) using `Setup.ps1`, and then to modify the configuration and scheduled task as needed.

## Running from the command line <!--anchorinuse-->

While a scheduled task is the recommended way of running LightlyToasted, it can also be run from a PowerShell prompt.

The simplest way is to reference a JSON configuration file ([as documented here](config_detail.md)):
    
    ./Runner.ps1 -Config ~/LightlyToasted/Configs/default.json

The config parameters that can be specified in the JSON can also (with the exception of `DefaultDirectives`) be specified as command line arguments.  If a parameter on the command line also exists in the JSON config, the commmand line takes precedence. (For boolean arguments, the command line parameter is a switch: you don't supply a `true` or `false` value, rather the presence of the option implies `true` and the absence of the option implies `false`.  Note that this prevents a parameter that is `true` in the JSON from being overridden on the command line).

It is also possible to specify all the parameters from the command line and have no JSON config at all – although this way, you can't specify `DefaultDirectives`.

Examples:

1. Use a JSON config file, but force `EnableWebImages` to `true` and override `LogsDir`.

        ./Runner.ps1 -Config ~/LightlyToasted/Configs/default.json -EnableWebImages -LogsDir C:\Logs\LightlyToasted

2. Specify a configuration using only command line parameters with no JSON file.

        ./Runner.ps1 -WatchedDirs C:/foo/bar,D:/baz -LogsDir C:\Logs\LightlyToasted -FilePattern "*.tst" -PurgeLogsOlderThan 7

## Running from a scheduled task

In the default scheduled task created by `Setup.ps1`, the Action taken is:

  * **Action**: Start a program

  * **Program**: `powershell.exe` *or* `pwsh.exe` (depending on whether you ran the setup script in Powershell 5, or 6/7)

  * **Arguments**: `-WindowStyle Hidden -Command . C:\LightlyToastedSource\Runner.ps1 -Config ~/LightlyToasted/Configs/default.json; exit $LASTEXITCODE`

  * **Start in**: `C:\LightlyToastedSource`


(where the directory containing LightlyToasted is assumed to be `C:\LightlyToastedSource`.)

Note the use of `exit $LASTEXITCODE` so that error codes from LightlyToasted are reflected back in the task's status.

Some aspects of the task are configurable through [command-line options](setup_detail.md) to `Setup.ps1`.  Also, once the task is created, you can freely edit it in Task Scheduler.

The scheduled task created by `Setup.ps1` will run when you log on, and very briefly flash up a PowerShell window.  If that window annoys you, you can get rid of it by opening Task Scheduler, and setting "Run whether user is logged on or not" on the Task's "General" tab.  (`Setup.ps1` doesn't try to do this automatically since it's very difficult to reliably do programmatically without making assumptions about [security policy templates etc.](https://stackoverflow.com/a/70793765))

(Note: doing this doesn't change the trigger for the task, which in the default task created by `Setup.ps1` is set to "At log on of user" for the user who ran the script.  You can change that in Task Scheduler too if you want to.)

## Logging

A log file per execution of `Runner.ps1` will be written in the directory specified by `LogsDir` in the configuration, named (for example) `toast_20220830_091011.log`, where the start time of the task is included in YYYYMMDD_HHMMSS format.

LightlyToasted can automatically purge old log files on startup: the parameter `PurgeLogsOlderThan` (in the [JSON config file](config_detail.md) or as a command-line argument) specifies the maximum age in days of log files that will be retained.

## Error codes

LightlyToasted generally aims to catch exceptions and keep running: the goal is that a malformed notification file should result in an error being logged, but not crash the task.

If the script does exit unexpectedly, the currently possible error codes are:

| Denary | Hex | Meaning |
|--------|-----|---------|
| 100    | 64  | Error on initialization (usually, invalid parameters in the config JSON or on the command line). |
| 101    | 65  | Unrecoverable error processing a notification file.


