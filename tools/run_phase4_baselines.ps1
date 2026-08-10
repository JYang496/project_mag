param(
    [string]$GodotPath = 'E:\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe',
    [ValidateRange(1, 50)][int]$Runs = 10,
    [string]$OutputRoot = 'test-results/phase4/repeatability'
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found: $GodotPath" }
$target = Join-Path $repoRoot $OutputRoot
New-Item -ItemType Directory -Force -Path $target | Out-Null
$target = (Resolve-Path -LiteralPath $target).Path
if (-not $target.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputRoot must remain inside the repository: $target"
}
$env:PHASE4_REVISION = (git -C $repoRoot rev-parse --short HEAD).Trim()
$records = @()
for ($index = 1; $index -le $Runs; $index++) {
    $runRoot = Join-Path $target ("run-{0:d2}" -f $index)
    New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
    & pwsh -NoProfile -File (Join-Path $repoRoot 'tests/infrastructure/run_test_workers.ps1') `
        -GodotPath $GodotPath -TestId performance.phase4_baseline -OutputRoot $runRoot | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Phase 4 baseline run $index failed with exit code $LASTEXITCODE" }
    $baseline = Get-ChildItem -LiteralPath $runRoot -Recurse -Filter phase4_performance_baseline.json | `
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $baseline) { throw "Phase 4 baseline JSON missing after run $index" }
    $payload = Get-Content -Raw -LiteralPath $baseline.FullName | ConvertFrom-Json
    foreach ($result in $payload.results) {
        $records += [pscustomobject]@{
            run = $index
            scenario_id = [string]$result.scenario_id
            average_frame_ms = [double]$result.average_frame_ms
            p95_frame_ms = [double]$result.p95_frame_ms
            p99_frame_ms = [double]$result.p99_frame_ms
            maximum_frame_ms = [double]$result.maximum_frame_ms
            registry_queries = $result.registry_queries
            scanned_candidates = $result.scanned_candidates
            position_signature = $result.position_signature
        }
    }
}
function Get-Median([double[]]$Values) {
    if ($Values.Count -eq 0) { return 0.0 }
    $sorted = @($Values | Sort-Object)
    $middle = [math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) { return [double]$sorted[$middle] }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}
$scenarioSummaries = @()
foreach ($group in ($records | Group-Object scenario_id | Sort-Object Name)) {
    $p99 = [double[]]@($group.Group | ForEach-Object { $_.p99_frame_ms })
    $maximum = [double[]]@($group.Group | ForEach-Object { $_.maximum_frame_ms })
    $signatures = @($group.Group.position_signature | Where-Object { $null -ne $_ } | Sort-Object -Unique)
    $scenarioSummaries += [ordered]@{
        scenario_id = $group.Name
        samples = $group.Count
        median_p99_frame_ms = Get-Median $p99
        min_p99_frame_ms = ($p99 | Measure-Object -Minimum).Minimum
        max_p99_frame_ms = ($p99 | Measure-Object -Maximum).Maximum
        median_maximum_frame_ms = Get-Median $maximum
        deterministic_position_signatures = $signatures
        deterministic = $signatures.Count -le 1
    }
}
$summary = [ordered]@{
    schema_version = 1
    revision = $env:PHASE4_REVISION
    runs = $Runs
    generated_utc = [DateTime]::UtcNow.ToString('o')
    scenarios = $scenarioSummaries
}
$summaryPath = Join-Path $target 'phase4_repeatability_summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Output "PHASE4_REPEATABILITY_SUMMARY=$summaryPath"
$summary | ConvertTo-Json -Depth 8
