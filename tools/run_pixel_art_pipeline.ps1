[CmdletBinding()]
param(
    [string[]]$Task,
    [switch]$List,
    [switch]$Check,
    [switch]$IncludeExperimental,
    [switch]$AllowMigration,
    [string]$GodotPath = 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $PSScriptRoot 'pixel_art\pipeline_manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

function Resolve-ProjectPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    return Join-Path $projectRoot ($RelativePath -replace '/', '\')
}

function Test-PipelineContract {
    $seen = @{}
    foreach ($entry in $manifest.tasks) {
        if ([string]::IsNullOrWhiteSpace($entry.id)) {
            throw 'Every pixel-art pipeline task requires an id.'
        }
        if ($seen.ContainsKey($entry.id)) {
            throw "Duplicate pixel-art pipeline task id: $($entry.id)"
        }
        $seen[$entry.id] = $true
        if ($entry.runtime -notin @('python', 'node', 'godot')) {
            throw "Unsupported runtime '$($entry.runtime)' for task '$($entry.id)'."
        }
        $scriptPath = Resolve-ProjectPath $entry.script
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            throw "Task '$($entry.id)' references missing script '$($entry.script)'."
        }
        foreach ($output in $entry.outputs) {
            $resolvedOutput = [IO.Path]::GetFullPath((Resolve-ProjectPath $output))
            if (-not $resolvedOutput.StartsWith(
                [IO.Path]::GetFullPath($projectRoot),
                [StringComparison]::OrdinalIgnoreCase
            )) {
                throw "Task '$($entry.id)' has output outside the project: '$output'."
            }
        }
    }
}

Test-PipelineContract

if ($List) {
    $manifest.tasks |
        Select-Object id, status, runtime, description |
        Format-Table -AutoSize
    exit 0
}

if ($Check) {
    Write-Host "Pixel-art pipeline manifest is valid: $manifestPath"
    Write-Host "Registered tasks: $($manifest.tasks.Count)"
    exit 0
}

$selected = @()
if ($Task.Count -gt 0) {
    foreach ($taskId in $Task) {
        $entry = $manifest.tasks | Where-Object id -eq $taskId
        if ($null -eq $entry) {
            throw "Unknown pixel-art pipeline task: $taskId"
        }
        $selected += $entry
    }
} else {
    $selected = @($manifest.tasks | Where-Object status -eq 'active')
    if ($IncludeExperimental) {
        $selected += @($manifest.tasks | Where-Object status -eq 'experimental')
    }
}

foreach ($entry in $selected) {
    if ($entry.status -eq 'archived') {
        throw "Task '$($entry.id)' is archived and is not runnable from the active pipeline."
    }
    if ($entry.status -eq 'migration' -and -not $AllowMigration) {
        throw "Task '$($entry.id)' is a destructive one-time migration. Pass -AllowMigration explicitly."
    }

    $scriptPath = Resolve-ProjectPath $entry.script
    $arguments = @()
    if ($null -ne $entry.arguments) {
        $arguments = @($entry.arguments)
    }
    Write-Host "Running pixel-art task '$($entry.id)'..."
    Push-Location $projectRoot
    try {
        switch ($entry.runtime) {
            'python' {
                & python $scriptPath @arguments
            }
            'node' {
                & node $scriptPath @arguments
            }
            'godot' {
                if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
                    throw "Godot console executable not found: $GodotPath"
                }
                & $GodotPath --headless --path $projectRoot --script "res://$($entry.script)"
            }
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Pixel-art task '$($entry.id)' failed with exit code $LASTEXITCODE."
        }
    } finally {
        Pop-Location
    }
}

Write-Host "Pixel-art pipeline completed: $($selected.Count) task(s)."
