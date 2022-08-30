param (
    # Default values here are arbitrary, since we pull out $MyInvocation.BoundParameters specifically
    # and any values not explicitly supplied here are not splatted to Initialize.  So look at
    # Init.ps1 for the "real" default parameter values.
    [string]$Config = '',
    [string[]]$WatchedDirs = @(),
    [string]$LogsDir = '',
    [double]$SweepIntervalSec = -1,
    [string]$FilePattern = '',
    [double]$PurgeLogsOlderThan = -1,
    [switch]$TimestampFromFile = $false,
    [switch]$Recurse = $false,
    [switch]$EnableWebImages = $false,
    [int]$MaxWebImageSizeKb = -1
)

. $PSScriptRoot/DllLoad.ps1
. $PSScriptRoot/Init.ps1

$global:app_context = @{}

# Get args from JSON config, if supply
$init_args = @{}
if ($Config) {
    $j = (Get-Content -Path $Config) | ConvertFrom-Json
    $j.PSObject.Properties | % {
        if ($_.Value.GetType().Name -eq "PSCustomObject") {
            # We might have one layer of object nesting (for DefaultDirectives)
            $val = @{}
            $_.Value.PSObject.Properties | % { $val[$_.Name] = $_.Value }
        } else {
            $val = $_.Value
        }
        $init_args[$_.Name] = $val
    }
}

# Override with the parameters we got directly
$MyInvocation.BoundParameters.keys | % { $init_args[$_] = (Get-Variable $_).Value }

# Set up the system
try {
    InitalizeLogging $init_args.LogsDir  # Set up logging first so we can log any init problems
    $init_args["SweepOnStartup"] = $true
    Initialize @init_args
    if ($init_args.ContainsKey("DefaultDirectives")) {
        # Splatting doesn't pass the hashtable properly, so we need to write directly into the app_context
        $app_context["default_directives"] = $init_args["DefaultDirectives"]
    }
} catch {
    WriteLogMessage "Error initializing:" $app_context.log_file_path
    WriteLogMessage $_ $app_context.log_file_path
    exit 100
}

# Event loop
try {
    while ($true) {
        $ev = Wait-Event
        if ($ev.MessageData.TerminateLoop) {
            break
        }
    }
} catch {
    WriteLogMessage  "Uncaught exception while processing:" $app_context.log_file_path
    WriteLogMessage  $_ $app_context.log_file_path
    exit 101
}
