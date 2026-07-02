[CmdletBinding()]
param(
    [string[]]$TestId = @(),
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'test_manifest.json'),
    [string]$GodotPath,
    [ValidateRange(1, 32)][int]$Jobs = 2,
    [string]$OutputRoot,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSelection.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestWorker.psm1') -Force

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
Assert-TestManifest -Manifest $manifest
$testsById = @{}
foreach ($test in @($manifest.tests)) {
    $testsById[[string]$test.id] = $test
}

$selectedTests = if ($TestId.Count -eq 0) {
    @($manifest.tests)
} else {
    @($TestId | ForEach-Object {
        if (-not $testsById.ContainsKey($_)) {
            throw "Test id '$_' is not present in the manifest."
        }
        $testsById[$_]
    })
}

$invokeParameters = @{
    Test = $selectedTests
    RepoRoot = $repoRoot
    GodotPath = $GodotPath
    Jobs = $Jobs
}
if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
    $invokeParameters.OutputRoot = $OutputRoot
}
$summary = Invoke-TestWorkers @invokeParameters

if ($Json) {
    $summary |
        Select-Object -Property * -ExcludeProperty results |
        Add-Member -NotePropertyName results -NotePropertyValue @(
            $summary.results | Select-Object -Property * -ExcludeProperty output
        ) -PassThru |
        ConvertTo-Json -Depth 6
} else {
    Write-Output "Worker run: $($summary.run_root)"
    Write-Output "Godot: $($summary.godot_path)"
    Write-Output "Jobs: $($summary.jobs)"
    foreach ($result in $summary.results) {
        Write-Output (
            '[{0}] {1} ({2:n3}s, exit={3}, mode={4}) - {5}' -f `
                $result.status,
                $result.id,
                $result.duration_seconds,
                $result.exit_code,
                $result.execution_mode,
                $result.detail
        )
        if ($result.status -ne 'PASS') {
            Write-Output '--- captured output ---'
            Write-Output $result.output
            Write-Output '--- reproduction ---'
            Write-Output $result.reproduction_command
        }
        if ($result.shutdown_diagnostics_present) {
            Write-Output (
                'Shutdown diagnostics: {0} (retained in result metadata and logs)' -f `
                    $result.shutdown_diagnostic_count
            )
        }
        Write-Output "Logs: $($result.stdout_path) | $($result.stderr_path)"
    }
    Write-Output (
        'Summary: PASS={0} FAIL={1} ERROR={2} SHUTDOWN_DIAGNOSTICS={3} RUNTIME_ERRORS={4}' -f `
            $summary.passed,
            $summary.failed,
            $summary.errors,
            $summary.shutdown_diagnostic_count,
            $summary.runtime_error_count
    )
}

if ($summary.errors -gt 0) {
    exit 2
}
if ($summary.failed -gt 0) {
    exit 1
}
exit 0
