[CmdletBinding()]
param([string]$GodotPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infrastructureRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $infrastructureRoot)
Import-Module (Join-Path $infrastructureRoot 'TestSelection.psm1') -Force
Import-Module (Join-Path $infrastructureRoot 'TestWorker.psm1') -Force
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        $failures.Add("$Message Expected='$Expected' Actual='$Actual'")
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $failures.Add($Message)
    }
}

Assert-Equal 'PASS' (Get-TestOutcome -ExitCode 0 -Output 'Fixture: PASS' -TimedOut $false).status `
    'Parser should recognize PASS.'
Assert-Equal 'FAIL' (Get-TestOutcome -ExitCode 1 -Output 'Fixture: FAIL' -TimedOut $false).status `
    'Parser should recognize FAIL.'
Assert-Equal 'ERROR' (Get-TestOutcome -ExitCode 0 -Output 'SCRIPT ERROR: parse failed' -TimedOut $false).status `
    'Parser should recognize an error marker.'
Assert-Equal 'ERROR' (Get-TestOutcome -ExitCode -1 -Output 'Fixture: READY' -TimedOut $true).status `
    'Parser should classify timeout as ERROR.'
Assert-Equal 'ERROR' (Get-TestOutcome -ExitCode 0 -Output 'Fixture completed' -TimedOut $false).status `
    'Parser should fail closed without a completion marker.'

$shutdownLeakOutput = @'
Fixture: PASS
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: 4 resources still in use at exit (run with --verbose for details).
'@
$shutdownLeakOutcome = Get-TestOutcome -ExitCode 0 -Output $shutdownLeakOutput -TimedOut $false
Assert-Equal 'PASS' $shutdownLeakOutcome.status `
    'Explicit PASS with only shutdown leak diagnostics should pass.'
Assert-True $shutdownLeakOutcome.shutdown_diagnostics_present `
    'Shutdown leak PASS must report diagnostics.'
Assert-Equal 2 $shutdownLeakOutcome.shutdown_diagnostic_count `
    'Shutdown leak diagnostic count mismatch.'
Assert-Equal 0 $shutdownLeakOutcome.runtime_error_count `
    'Shutdown leak diagnostics must not be counted as runtime errors.'

$mixedRuntimeErrorOutput = @'
Fixture: PASS
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: gameplay state corrupted
ERROR: 4 resources still in use at exit (run with --verbose for details).
'@
$mixedRuntimeErrorOutcome = Get-TestOutcome `
    -ExitCode 0 `
    -Output $mixedRuntimeErrorOutput `
    -TimedOut $false
Assert-Equal 'ERROR' $mixedRuntimeErrorOutcome.status `
    'A real runtime error mixed with shutdown diagnostics must remain ERROR.'
Assert-Equal 2 $mixedRuntimeErrorOutcome.shutdown_diagnostic_count `
    'Mixed output shutdown diagnostic count mismatch.'
Assert-Equal 1 $mixedRuntimeErrorOutcome.runtime_error_count `
    'Mixed output runtime error count mismatch.'

$fixtureDefinitions = @(
    [pscustomobject]@{
        id = 'infrastructure.worker_success'
        entry_type = 'script'
        path = 'res://tests/infrastructure/fixtures/worker_success.gd'
        domain = 'infrastructure'
        dependency_domains = @()
        parallel_safe = $true
        writes_user_data = $false
        timeout_seconds = 15
    },
    [pscustomobject]@{
        id = 'infrastructure.worker_failure'
        entry_type = 'script'
        path = 'res://tests/infrastructure/fixtures/worker_failure.gd'
        domain = 'infrastructure'
        dependency_domains = @()
        parallel_safe = $true
        writes_user_data = $false
        timeout_seconds = 15
    },
    [pscustomobject]@{
        id = 'infrastructure.worker_timeout'
        entry_type = 'script'
        path = 'res://tests/infrastructure/fixtures/worker_timeout.gd'
        domain = 'infrastructure'
        dependency_domains = @()
        parallel_safe = $true
        writes_user_data = $false
        timeout_seconds = 2
    },
    [pscustomobject]@{
        id = 'infrastructure.worker_isolation_a'
        entry_type = 'script'
        path = 'res://tests/infrastructure/fixtures/worker_isolation.gd'
        domain = 'infrastructure'
        dependency_domains = @()
        parallel_safe = $true
        writes_user_data = $true
        timeout_seconds = 15
    },
    [pscustomobject]@{
        id = 'infrastructure.worker_isolation_b'
        entry_type = 'script'
        path = 'res://tests/infrastructure/fixtures/worker_isolation.gd'
        domain = 'infrastructure'
        dependency_domains = @()
        parallel_safe = $false
        writes_user_data = $false
        timeout_seconds = 15
    }
)
$fixtureManifest = [pscustomobject]@{
    schema_version = 1
    catalog_status = 'self-test'
    tests = $fixtureDefinitions
}
Assert-TestManifest -Manifest $fixtureManifest

$runRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'project_mag-test-worker-selftest-{0}' -f [guid]::NewGuid().ToString('N')
)
$summary = Invoke-TestWorkers `
    -Test $fixtureDefinitions `
    -RepoRoot $repoRoot `
    -GodotPath $GodotPath `
    -Jobs 2 `
    -OutputRoot $runRoot

$results = @{}
foreach ($result in $summary.results) {
    $results[$result.id] = $result
}
Assert-Equal 'PASS' $results['infrastructure.worker_success'].status 'Success fixture status mismatch.'
Assert-Equal 'FAIL' $results['infrastructure.worker_failure'].status 'Failure fixture status mismatch.'
Assert-Equal 'ERROR' $results['infrastructure.worker_timeout'].status 'Timeout fixture status mismatch.'
Assert-True $results['infrastructure.worker_timeout'].timed_out 'Timeout fixture must record timed_out.'
Assert-Equal 'PASS' $results['infrastructure.worker_isolation_a'].status 'Isolation fixture A status mismatch.'
Assert-Equal 'PASS' $results['infrastructure.worker_isolation_b'].status 'Isolation fixture B status mismatch.'
Assert-Equal 'parallel' $results['infrastructure.worker_success'].execution_mode `
    'Parallel-safe non-writer should use parallel mode.'
Assert-Equal 'exclusive' $results['infrastructure.worker_isolation_a'].execution_mode `
    'user:// writer should use exclusive mode.'
Assert-Equal 'exclusive' $results['infrastructure.worker_isolation_b'].execution_mode `
    'Non-parallel-safe test should use exclusive mode.'

$isolationPathA = [regex]::Match(
    $results['infrastructure.worker_isolation_a'].output,
    'ISOLATION_USER_DATA=(.+)'
).Groups[1].Value.Trim()
$isolationPathB = [regex]::Match(
    $results['infrastructure.worker_isolation_b'].output,
    'ISOLATION_USER_DATA=(.+)'
).Groups[1].Value.Trim()
Assert-True (-not [string]::IsNullOrWhiteSpace($isolationPathA)) 'Isolation fixture A must report user://.'
Assert-True (-not [string]::IsNullOrWhiteSpace($isolationPathB)) 'Isolation fixture B must report user://.'
Assert-True ($isolationPathA -ne $isolationPathB) 'Workers must not share user:// paths.'
Assert-True (Test-Path -LiteralPath (Join-Path $isolationPathA 'worker_isolation_marker.txt')) `
    'Isolation fixture A marker is missing.'
Assert-True (Test-Path -LiteralPath (Join-Path $isolationPathB 'worker_isolation_marker.txt')) `
    'Isolation fixture B marker is missing.'

foreach ($result in $summary.results) {
    Assert-True (Test-Path -LiteralPath $result.stdout_path -PathType Leaf) `
        "stdout log missing for '$($result.id)'."
    Assert-True (Test-Path -LiteralPath $result.stderr_path -PathType Leaf) `
        "stderr log missing for '$($result.id)'."
    Assert-True (Test-Path -LiteralPath $result.metadata_path -PathType Leaf) `
        "result metadata missing for '$($result.id)'."
    Assert-True (-not [string]::IsNullOrWhiteSpace($result.reproduction_command)) `
        "reproduction command missing for '$($result.id)'."
}
Assert-True (Test-Path -LiteralPath (Join-Path $summary.run_root 'summary.json') -PathType Leaf) `
    'Run summary is missing.'
Assert-Equal 0 $summary.shutdown_diagnostic_count `
    'Infrastructure fixtures should not emit shutdown diagnostics.'
Assert-Equal 0 $summary.runtime_error_count `
    'Expected fixture outcomes should not emit Godot runtime errors.'

if ($failures.Count -gt 0) {
    Write-Output "TestWorker self-test: FAIL ($($failures.Count))"
    foreach ($failure in $failures) {
        Write-Output " - $failure"
    }
    Write-Output "Retained run artifacts: $($summary.run_root)"
    exit 1
}

Write-Output 'TestWorker parser self-test: PASS'
Write-Output 'TestWorker process self-test: PASS'
Write-Output 'Covered: success, failure, runtime errors, shutdown diagnostics, mixed diagnostics, missing marker, timeout, user:// isolation, scheduling, logs, reproduction.'
Write-Output "Retained run artifacts: $($summary.run_root)"
exit 0
