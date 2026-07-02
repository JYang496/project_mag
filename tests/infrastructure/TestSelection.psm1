Set-StrictMode -Version Latest

function ConvertTo-NormalizedRepoPath {
    param([Parameter(Mandatory)][string]$Path)

    $normalized = $Path.Trim().Replace('\', '/')
    while ($normalized.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }
    return $normalized
}

function Test-PathPrefix {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Prefix
    )

    return $Path.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Read-TestInfrastructureJson {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required test infrastructure file does not exist: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Assert-TestManifest {
    param([Parameter(Mandatory)]$Manifest)

    if ([int]$Manifest.schema_version -ne 1) {
        throw "Unsupported test manifest schema_version '$($Manifest.schema_version)'."
    }
    if ($null -eq $Manifest.tests) {
        throw 'Test manifest is missing tests.'
    }

    $requiredFields = @(
        'id',
        'entry_type',
        'path',
        'domain',
        'dependency_domains',
        'parallel_safe',
        'writes_user_data',
        'timeout_seconds'
    )
    $seenIds = @{}
    foreach ($test in @($Manifest.tests)) {
        foreach ($field in $requiredFields) {
            if ($test.PSObject.Properties.Name -notcontains $field) {
                throw "Test manifest entry is missing '$field': $($test | ConvertTo-Json -Compress)"
            }
        }
        if ([string]::IsNullOrWhiteSpace([string]$test.id)) {
            throw 'Test manifest entry has an empty id.'
        }
        if ($seenIds.ContainsKey([string]$test.id)) {
            throw "Duplicate test id '$($test.id)'."
        }
        $seenIds[[string]$test.id] = $true
        if (@('scene', 'script') -notcontains [string]$test.entry_type) {
            throw "Test '$($test.id)' has unsupported entry_type '$($test.entry_type)'."
        }
        if (-not ([string]$test.path).StartsWith('res://', [System.StringComparison]::Ordinal)) {
            throw "Test '$($test.id)' path must start with res://."
        }
        if ([int]$test.timeout_seconds -le 0) {
            throw "Test '$($test.id)' timeout_seconds must be positive."
        }
    }
}

function Assert-SourceDomainMap {
    param([Parameter(Mandatory)]$SourceMap)

    if ([int]$SourceMap.schema_version -ne 1) {
        throw "Unsupported source map schema_version '$($SourceMap.schema_version)'."
    }
    if ($null -eq $SourceMap.full_fallback -or $null -eq $SourceMap.domain_rules) {
        throw 'Source domain map must define full_fallback and domain_rules.'
    }
    foreach ($rule in @($SourceMap.domain_rules)) {
        if ([string]::IsNullOrWhiteSpace([string]$rule.prefix) -or
            [string]::IsNullOrWhiteSpace([string]$rule.domain) -or
            @('known', 'uncertain') -notcontains [string]$rule.certainty) {
            throw "Invalid source domain rule: $($rule | ConvertTo-Json -Compress)"
        }
    }
}

function Test-IsFullFallbackPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$SourceMap
    )

    foreach ($exactPath in @($SourceMap.full_fallback.exact_paths)) {
        if ($Path.Equals([string]$exactPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    foreach ($prefix in @($SourceMap.full_fallback.prefixes)) {
        if (Test-PathPrefix -Path $Path -Prefix ([string]$prefix)) {
            return $true
        }
    }
    return $false
}

function Test-IsIgnoredPath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$SourceMap
    )

    foreach ($exactPath in @($SourceMap.ignored_exact_paths)) {
        if ($Path.Equals([string]$exactPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    foreach ($prefix in @($SourceMap.ignored_prefixes)) {
        if (Test-PathPrefix -Path $Path -Prefix ([string]$prefix)) {
            return $true
        }
    }
    return $false
}

function Find-DomainRule {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$SourceMap
    )

    foreach ($rule in @($SourceMap.domain_rules)) {
        if (Test-PathPrefix -Path $Path -Prefix ([string]$rule.prefix)) {
            return $rule
        }
    }
    return $null
}

function Select-AffectedTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$ChangedPath,
        [string[]]$IncludeTest = @(),
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$SourceMapPath
    )

    $manifest = Read-TestInfrastructureJson -Path $ManifestPath
    $sourceMap = Read-TestInfrastructureJson -Path $SourceMapPath
    Assert-TestManifest -Manifest $manifest
    Assert-SourceDomainMap -SourceMap $sourceMap

    $normalizedPaths = @(
        $ChangedPath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { ConvertTo-NormalizedRepoPath -Path $_ } |
            Sort-Object -Unique
    )
    $requestedIds = @(
        $IncludeTest |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $testsById = @{}
    foreach ($test in @($manifest.tests)) {
        $testsById[[string]$test.id] = $test
    }
    foreach ($id in $requestedIds) {
        if (-not $testsById.ContainsKey($id)) {
            throw "Explicit test id '$id' is not present in the manifest."
        }
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $domains = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $unknownPaths = [System.Collections.Generic.List[string]]::new()
    $fullFallback = $false

    foreach ($path in $normalizedPaths) {
        if (Test-IsFullFallbackPath -Path $path -SourceMap $sourceMap) {
            $fullFallback = $true
            $reasons.Add("full fallback: core or infrastructure contract changed: $path")
            continue
        }
        $rule = Find-DomainRule -Path $path -SourceMap $sourceMap
        if ($null -ne $rule) {
            if ([string]$rule.certainty -eq 'uncertain') {
                $fullFallback = $true
                $reasons.Add("full fallback: dependency mapping is uncertain for $path")
            } else {
                [void]$domains.Add([string]$rule.domain)
                $reasons.Add("mapped $path -> $($rule.domain)")
            }
            continue
        }
        if (Test-IsIgnoredPath -Path $path -SourceMap $sourceMap) {
            $reasons.Add("ignored non-production change: $path")
            continue
        }
        $fullFallback = $true
        $unknownPaths.Add($path)
        $reasons.Add("full fallback: unmapped production or test path: $path")
    }

    foreach ($test in @($manifest.tests)) {
        if (@($test.dependency_domains) -contains '*') {
            $fullFallback = $true
            $reasons.Add("full fallback: test '$($test.id)' has an uncertain wildcard dependency")
        }
    }

    $selectedById = @{}
    if ($fullFallback) {
        foreach ($test in @($manifest.tests)) {
            $selectedById[[string]$test.id] = $test
        }
    } else {
        foreach ($test in @($manifest.tests)) {
            $isAffected = $domains.Contains([string]$test.domain)
            if (-not $isAffected) {
                foreach ($dependency in @($test.dependency_domains)) {
                    if ($domains.Contains([string]$dependency)) {
                        $isAffected = $true
                        break
                    }
                }
            }
            if ($isAffected) {
                $selectedById[[string]$test.id] = $test
                $reasons.Add("selected '$($test.id)' for domain/dependency impact")
            }
        }
        if ($domains.Count -gt 0 -and $selectedById.Count -eq 0) {
            $fullFallback = $true
            $reasons.Add('full fallback: mapped domains have no registered test coverage')
            foreach ($test in @($manifest.tests)) {
                $selectedById[[string]$test.id] = $test
            }
        }
    }

    foreach ($id in $requestedIds) {
        $selectedById[$id] = $testsById[$id]
        $reasons.Add("explicitly included '$id'")
    }

    $mode = if ($fullFallback) {
        'full'
    } elseif ($selectedById.Count -gt 0) {
        'affected'
    } else {
        'none'
    }
    if ($normalizedPaths.Count -eq 0 -and $requestedIds.Count -eq 0) {
        $reasons.Add('no changed paths or explicit tests; selection is empty')
    }

    return [pscustomobject]@{
        mode = $mode
        catalog_status = [string]$manifest.catalog_status
        changed_paths = @($normalizedPaths)
        domains = @($domains | Sort-Object)
        explicit_test_ids = @($requestedIds)
        unknown_paths = @($unknownPaths)
        reasons = @($reasons)
        tests = @($selectedById.Values | Sort-Object -Property id)
    }
}

Export-ModuleMember -Function Assert-TestManifest, Select-AffectedTests
