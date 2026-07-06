[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$infrastructureRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $infrastructureRoot)
Import-Module (Join-Path $infrastructureRoot 'TestSelection.psm1') -Force
$manifestPath = Join-Path $infrastructureRoot 'test_manifest.json'
$sourceMapPath = Join-Path $infrastructureRoot 'source_domain_map.json'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Equal {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual,
        [Parameter(Mandatory)][string]$Message
    )
    if ($Expected -ne $Actual) {
        $failures.Add("$Message Expected='$Expected' Actual='$Actual'")
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        $failures.Add($Message)
    }
}

function Select-ForTest {
    param(
        [AllowEmptyCollection()][string[]]$Path = @(),
        [string[]]$Include = @()
    )
    return Select-AffectedTests `
        -ChangedPath $Path `
        -IncludeTest $Include `
        -ManifestPath $manifestPath `
        -SourceMapPath $sourceMapPath
}

Assert-TestManifest -Manifest $manifest
Assert-Equal 'active' $manifest.catalog_status 'Current manifest should declare the active catalog state.'
Assert-Equal 1 @($manifest.tests).Count 'Active manifest should register the reward fuse branch regression.'
foreach ($test in @($manifest.tests)) {
    $relativeEntryPath = ([string]$test.path).Substring('res://'.Length).Replace(
        '/',
        [System.IO.Path]::DirectorySeparatorChar
    )
    Assert-True `
        (Test-Path -LiteralPath (Join-Path $repoRoot $relativeEntryPath) -PathType Leaf) `
        "Manifest entry '$($test.id)' points to a missing path '$($test.path)'."
}

$empty = Select-ForTest
Assert-Equal 'none' $empty.mode 'Empty change set should select no tests.'
Assert-Equal 0 $empty.tests.Count 'Empty change set should have an empty test list.'
Assert-True ([bool]($empty.reasons -match 'no changed paths')) 'Empty selection must explain why it is empty.'

$singleDomain = Select-ForTest -Path 'UI/scripts/controllers/example_controller.gd'
Assert-Equal 'affected' $singleDomain.mode 'Known UI source should select affected registered tests.'
Assert-True ($singleDomain.domains -contains 'ui') 'Known UI source should map to ui.'
Assert-Equal 1 $singleDomain.tests.Count 'Known UI source should select the reward fuse branch regression through dependency coverage.'
Assert-Equal 'reward.fuse_branch_selection' $singleDomain.tests[0].id 'UI source should select reward fuse branch regression.'

$multiDomain = Select-ForTest -Path @(
    'UI/scripts/controllers/example_controller.gd',
    'Player/Weapons/scripts/example_weapon.gd'
)
Assert-Equal 'affected' $multiDomain.mode 'Known multi-domain changes should select affected registered tests.'
Assert-True ($multiDomain.domains -contains 'ui') 'Multi-domain selection should include ui.'
Assert-True ($multiDomain.domains -contains 'weapon') 'Multi-domain selection should include weapon.'
Assert-Equal 1 $multiDomain.tests.Count 'Known multi-domain changes should select the reward fuse branch regression once.'

$projectCore = Select-ForTest -Path 'project.godot'
Assert-Equal 'full' $projectCore.mode 'project.godot must force a full fallback.'
Assert-Equal $manifest.tests.Count $projectCore.tests.Count 'Full fallback must return every manifest entry.'

$autoloadCore = Select-ForTest -Path 'autoload/GlobalVariables.gd'
Assert-Equal 'full' $autoloadCore.mode 'Autoload changes must force a full fallback.'

$manifestCore = Select-ForTest -Path 'tests/infrastructure/test_manifest.json'
Assert-Equal 'full' $manifestCore.mode 'Manifest changes must force a full fallback.'

$uncertainDependency = Select-ForTest -Path 'data/weapons/example.tres'
Assert-Equal 'full' $uncertainDependency.mode 'Uncertain dependency mapping must force a full fallback.'

$unknownProduction = Select-ForTest -Path 'Utility/new_contract.gd'
Assert-Equal 'full' $unknownProduction.mode 'Unmapped production files must force a full fallback.'
Assert-True ($unknownProduction.unknown_paths -contains 'Utility/new_contract.gd') 'Unknown production path must be reported.'

$docsOnly = Select-ForTest -Path 'docs/notes/example.md'
Assert-Equal 'none' $docsOnly.mode 'Documentation-only changes should not run tests.'
Assert-True ([bool]($docsOnly.reasons -match 'ignored non-production')) 'Ignored documentation must have an explicit reason.'

$invalidExplicitThrew = $false
try {
    $null = Select-ForTest -Include 'missing.test'
} catch {
    $invalidExplicitThrew = $true
}
Assert-True $invalidExplicitThrew 'Unknown explicit test ids must fail closed.'

if ($failures.Count -gt 0) {
    Write-Error "TestSelection self-test: FAIL ($($failures.Count))"
    foreach ($failure in $failures) {
        Write-Error " - $failure"
    }
    exit 1
}

Write-Output 'TestSelection self-test: PASS'
Write-Output 'Covered: active schema, empty, single-domain, multi-domain, core, manifest, uncertain, unknown, docs-only, invalid explicit id.'
exit 0
