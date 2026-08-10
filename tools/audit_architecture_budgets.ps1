param(
    [string]$BudgetPath = "tools/architecture_budgets.json",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedBudget = Join-Path $repoRoot $BudgetPath
if (-not (Test-Path -LiteralPath $resolvedBudget)) {
    throw "Architecture budget file not found: $resolvedBudget"
}
$budget = Get-Content -Raw -LiteralPath $resolvedBudget | ConvertFrom-Json -AsHashtable
$largeThreshold = [int]$budget.large_file_threshold
$functionThreshold = [int]$budget.function_review_threshold
$runtimeRoots = @("autoload", "World", "Player", "Combat", "Board", "Objects", "UI")
$files = foreach ($root in $runtimeRoots) {
    Get-ChildItem -LiteralPath (Join-Path $repoRoot $root) -Recurse -Filter *.gd -File
}
$results = @()
$functionWarnings = @()
foreach ($file in $files) {
    $relative = $file.FullName.Substring($repoRoot.Length + 1).Replace("\", "/")
    $lines = Get-Content -LiteralPath $file.FullName
    $nonblank = @($lines | Where-Object { $_.Trim().Length -gt 0 }).Count
    if ($nonblank -ge $largeThreshold) {
        $ceiling = if ($budget.owners.ContainsKey($relative)) { [int]$budget.owners[$relative] } else { $null }
        $results += [ordered]@{
            path = $relative
            nonblank_lines = $nonblank
            ceiling = $ceiling
            status = if ($null -eq $ceiling) { "UNBUDGETED" } elseif ($nonblank -le $ceiling) { "PASS" } else { "OVER_BUDGET" }
        }
    }
    $activeName = $null
    $activeStart = 0
    $activeCount = 0
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^func\s+([^\(]+)') {
            if ($null -ne $activeName -and $activeCount -gt $functionThreshold) {
                $functionWarnings += [ordered]@{ path = $relative; function = $activeName; start_line = $activeStart; nonblank_lines = $activeCount }
            }
            $activeName = $Matches[1]
            $activeStart = $index + 1
            $activeCount = 1
        } elseif ($null -ne $activeName -and $lines[$index].Trim().Length -gt 0) {
            $activeCount++
        }
    }
    if ($null -ne $activeName -and $activeCount -gt $functionThreshold) {
        $functionWarnings += [ordered]@{ path = $relative; function = $activeName; start_line = $activeStart; nonblank_lines = $activeCount }
    }
}
$violations = @($results | Where-Object { $_.status -ne "PASS" })
$output = [ordered]@{
    schema_version = 1
    large_file_threshold = $largeThreshold
    function_review_threshold = $functionThreshold
    controlled_owners = $results
    long_function_warnings = $functionWarnings
    violation_count = $violations.Count
}
if ($Json) {
    $output | ConvertTo-Json -Depth 8
} else {
    Write-Output "Architecture budget audit"
    foreach ($entry in $results | Sort-Object path) {
        Write-Output ("[{0}] {1} lines={2} ceiling={3}" -f $entry.status, $entry.path, $entry.nonblank_lines, $entry.ceiling)
    }
    foreach ($entry in $functionWarnings | Sort-Object path, start_line) {
        Write-Output ("[REVIEW] {0}:{1} function={2} lines={3}" -f $entry.path, $entry.start_line, $entry.function, $entry.nonblank_lines)
    }
    Write-Output "ARCHITECTURE_BUDGET_VIOLATIONS=$($violations.Count)"
}
if ($violations.Count -gt 0) { exit 1 }
