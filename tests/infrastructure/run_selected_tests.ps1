[CmdletBinding()]
param(
    [string]$BaseRef,
    [string[]]$ChangedPath,
    [string[]]$IncludeTest = @(),
    [string]$ManifestPath,
    [string]$SourceMapPath,
    [string]$GodotPath,
    [ValidateRange(1, 32)][int]$Jobs = 2,
    [string]$OutputRoot,
    [switch]$SkipCheckOnly,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'TestSelection.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'TestWorker.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'StartupManifest.psm1') -Force

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot 'test_manifest.json'
}
if ([string]::IsNullOrWhiteSpace($SourceMapPath)) {
    $SourceMapPath = Join-Path $PSScriptRoot 'source_domain_map.json'
}

function Get-GitChangedPath {
    param([string]$ComparisonBase)

    $paths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $commands = @(
        @('diff', '--name-only', '--diff-filter=ACMRTUXB'),
        @('diff', '--cached', '--name-only', '--diff-filter=ACMRTUXB'),
        @('ls-files', '--others', '--exclude-standard')
    )
    if (-not [string]::IsNullOrWhiteSpace($ComparisonBase)) {
        $commands += ,@('diff', '--name-only', '--diff-filter=ACMRTUXB', "$ComparisonBase...HEAD")
    }
    foreach ($arguments in $commands) {
        $output = & git @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "git $($arguments -join ' ') failed with exit code $LASTEXITCODE."
        }
        foreach ($path in @($output)) {
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                [void]$paths.Add($path)
            }
        }
    }
    return @($paths | Sort-Object)
}

function Invoke-GodotCheckOnly {
    param(
        [Parameter(Mandatory)][string]$ResolvedGodotPath,
        [Parameter(Mandatory)][string]$ResolvedRepoRoot
    )

    $output = & $ResolvedGodotPath --headless --path $ResolvedRepoRoot --check-only --quit 2>&1
    $lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
    $exitCode = if ($lastExitCodeVariable -eq $null) {
        0
    } else {
        [int]$lastExitCodeVariable.Value
    }
    $outputText = (@($output) | ForEach-Object { $_.ToString() }) -join "`n"
    $diagnostics = Get-TestOutputDiagnostics -Output $outputText
    return [pscustomobject]@{
        exit_code = $exitCode
        ok = $exitCode -eq 0 -and [int]$diagnostics.runtime_error_count -eq 0
        runtime_error_count = [int]$diagnostics.runtime_error_count
        runtime_errors = @($diagnostics.runtime_errors)
        shutdown_diagnostic_count = [int]$diagnostics.shutdown_diagnostic_count
        output = $outputText
    }
}

function Invoke-StartupManifestAudit {
    param(
        [Parameter(Mandatory)][string]$ResolvedGodotPath,
        [Parameter(Mandatory)][string]$ResolvedRepoRoot
    )

    $startupManifestPath = Join-Path $ResolvedRepoRoot 'data/startup/startup_resource_manifest.json'
    $structure = Test-StartupManifestStructure `
        -RepoRoot $ResolvedRepoRoot `
        -ManifestPath $startupManifestPath
    if (-not [bool]$structure.ok) {
        return [pscustomobject]@{
            ok = $false
            exit_code = 2
            structure_errors = @($structure.errors)
            output = ''
        }
    }
    $auditScript = 'res://tests/headless/startup/run_startup_resource_manifest_audit_headless.gd'
    $output = & $ResolvedGodotPath `
        --headless `
        --path $ResolvedRepoRoot `
        --script $auditScript `
        --quit-after 5 `
        2>&1
    $exitCode = [int]$LASTEXITCODE
    $outputText = (@($output) | ForEach-Object { $_.ToString() }) -join "`n"
    return [pscustomobject]@{
        ok = $exitCode -eq 0 -and $outputText -match 'STARTUP_MANIFEST_AUDIT: PASS'
        exit_code = $exitCode
        structure_errors = @()
        output = $outputText
    }
}

$resolvedGodotPath = Resolve-GodotExecutable -GodotPath $GodotPath
$effectiveChangedPath = if ($PSBoundParameters.ContainsKey('ChangedPath')) {
    @($ChangedPath)
} else {
    @(Get-GitChangedPath -ComparisonBase $BaseRef)
}

$selection = Select-AffectedTests `
    -ChangedPath $effectiveChangedPath `
    -IncludeTest $IncludeTest `
    -ManifestPath $ManifestPath `
    -SourceMapPath $SourceMapPath

$checkOnly = [pscustomobject]@{
    skipped = [bool]$SkipCheckOnly
    ok = $true
    exit_code = $null
    runtime_error_count = 0
    runtime_errors = @()
}
if (-not $SkipCheckOnly) {
    $checkOnly = Invoke-GodotCheckOnly `
        -ResolvedGodotPath $resolvedGodotPath `
        -ResolvedRepoRoot $repoRoot
    $checkOnly | Add-Member -NotePropertyName skipped -NotePropertyValue $false
    if (-not [bool]$checkOnly.ok) {
        if ($Json) {
            [pscustomobject]@{
                selection = $selection
                check_only = $checkOnly | Select-Object -Property * -ExcludeProperty output
                worker = $null
            } | ConvertTo-Json -Depth 8
        } else {
            Write-Output "Selection mode: $($selection.mode)"
            Write-Output "Check-only: FAIL exit=$($checkOnly.exit_code) runtime_errors=$($checkOnly.runtime_error_count)"
            if ($checkOnly.runtime_errors.Count -gt 0) {
                Write-Output 'Runtime errors:'
                foreach ($errorLine in $checkOnly.runtime_errors) {
                    Write-Output "  - $errorLine"
                }
            }
        }
        exit 2
    }
}

$startupManifest = Invoke-StartupManifestAudit `
    -ResolvedGodotPath $resolvedGodotPath `
    -ResolvedRepoRoot $repoRoot
if (-not [bool]$startupManifest.ok) {
    if ($Json) {
        [pscustomobject]@{
            selection = $selection
            check_only = $checkOnly | Select-Object -Property * -ExcludeProperty output
            startup_manifest = $startupManifest | Select-Object -Property * -ExcludeProperty output
            worker = $null
        } | ConvertTo-Json -Depth 8
    } else {
        Write-Output "Selection mode: $($selection.mode)"
        Write-Output "Startup manifest: FAIL exit=$($startupManifest.exit_code)"
        foreach ($errorMessage in $startupManifest.structure_errors) {
            Write-Output "  - $errorMessage"
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$startupManifest.output)) {
            Write-Output $startupManifest.output
        }
    }
    exit 2
}

$workerSummary = $null
if (@($selection.tests).Count -gt 0) {
    $invokeParameters = @{
        Test = @($selection.tests)
        RepoRoot = $repoRoot
        GodotPath = $resolvedGodotPath
        Jobs = $Jobs
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) {
        $invokeParameters.OutputRoot = $OutputRoot
    }
    $workerSummary = Invoke-TestWorkers @invokeParameters
}

if ($Json) {
    [pscustomobject]@{
        selection = $selection
        check_only = $checkOnly | Select-Object -Property * -ExcludeProperty output
        startup_manifest = $startupManifest | Select-Object -Property * -ExcludeProperty output
        worker = if ($workerSummary -eq $null) {
            $null
        } else {
            $workerSummary |
                Select-Object -Property * -ExcludeProperty results |
                Add-Member -NotePropertyName results -NotePropertyValue @(
                    $workerSummary.results | Select-Object -Property * -ExcludeProperty output
                ) -PassThru
        }
    } | ConvertTo-Json -Depth 8
} else {
    Write-Output "Selection mode: $($selection.mode)"
    Write-Output "Catalog status: $($selection.catalog_status)"
    Write-Output "Changed paths: $($selection.changed_paths.Count)"
    Write-Output "Domains: $(if ($selection.domains.Count -gt 0) { $selection.domains -join ', ' } else { '(none)' })"
    Write-Output "Selected tests: $(@($selection.tests).Count)"
    Write-Output "Check-only: $(if ($SkipCheckOnly) { 'SKIPPED' } else { 'PASS' })"
    Write-Output 'Startup manifest: PASS'
    if ($workerSummary -eq $null) {
        Write-Output 'Worker: SKIPPED (no selected tests)'
    } else {
        Write-Output "Worker run: $($workerSummary.run_root)"
        Write-Output (
            'Summary: PASS={0} FAIL={1} ERROR={2} SHUTDOWN_DIAGNOSTICS={3} RUNTIME_ERRORS={4}' -f `
                $workerSummary.passed,
                $workerSummary.failed,
                $workerSummary.errors,
                $workerSummary.shutdown_diagnostic_count,
                $workerSummary.runtime_error_count
        )
    }
}

if ($workerSummary -ne $null) {
    if ($workerSummary.errors -gt 0) {
        exit 2
    }
    if ($workerSummary.failed -gt 0) {
        exit 1
    }
}
exit 0
