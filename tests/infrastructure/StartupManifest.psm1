Set-StrictMode -Version Latest

function ConvertTo-ResourcePath {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$FilePath
    )

    $relative = [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($RepoRoot),
        [System.IO.Path]::GetFullPath($FilePath)
    ).Replace('\', '/')
    return "res://$relative"
}

function ConvertTo-FileSystemPath {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ResourcePath
    )

    if (-not $ResourcePath.StartsWith('res://', [System.StringComparison]::Ordinal)) {
        throw "Resource path must start with res://: $ResourcePath"
    }
    $relative = $ResourcePath.Substring('res://'.Length).Replace(
        '/',
        [System.IO.Path]::DirectorySeparatorChar
    )
    return Join-Path $RepoRoot $relative
}

function Get-OrdinalSortedStrings {
    param([AllowEmptyCollection()][string[]]$Value = @())

    $result = [string[]]@($Value)
    [Array]::Sort($result, [System.StringComparer]::Ordinal)
    return @($result)
}

function Read-StartupManifest {
    param([Parameter(Mandatory)][string]$ManifestPath)

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Startup manifest does not exist: $ManifestPath"
    }
    try {
        return Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
    } catch {
        throw "Startup manifest is not valid JSON: $ManifestPath. $($_.Exception.Message)"
    }
}

function Get-StartupCatalogActualPaths {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)]$Catalog
    )

    $directory = [string]$Catalog.directory
    $extension = [string]$Catalog.extension
    $directoryPath = ConvertTo-FileSystemPath -RepoRoot $RepoRoot -ResourcePath $directory
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        return @()
    }
    $paths = @(
        Get-ChildItem -LiteralPath $directoryPath -File |
            Where-Object { $_.Extension.Equals($extension, [System.StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { ConvertTo-ResourcePath -RepoRoot $RepoRoot -FilePath $_.FullName }
    )
    return @(Get-OrdinalSortedStrings -Value $paths)
}

function Test-StartupManifestStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [string[]]$Domain = @()
    )

    $manifest = Read-StartupManifest -ManifestPath $ManifestPath
    $errors = [System.Collections.Generic.List[string]]::new()
    $catalogResults = [System.Collections.Generic.List[object]]::new()
    $allowedPreparePhases = @('world', 'world_deferred')

    $rootFields = @('schema_version', 'runtime_consumed', 'runtime_consumed_domains', 'ordering', 'catalogs')
    $missingRootFields = @(
        $rootFields | Where-Object { $manifest.PSObject.Properties.Name -notcontains $_ }
    )
    foreach ($field in $missingRootFields) {
        $errors.Add("startup manifest is missing '$field'")
    }
    if ($missingRootFields.Count -gt 0) {
        return [pscustomobject]@{ ok = $false; errors = @($errors); catalogs = @() }
    }

    if ([int]$manifest.schema_version -ne 1) {
        $errors.Add("unsupported schema_version '$($manifest.schema_version)'")
    }
    if (-not [bool]$manifest.runtime_consumed) {
        $errors.Add('runtime_consumed must be true')
    }
    if ([string]$manifest.ordering -ne 'manifest_paths_sorted') {
        $errors.Add("ordering must be 'manifest_paths_sorted'")
    }
    if ($null -eq $manifest.catalogs) {
        $errors.Add('catalogs must be an array')
        return [pscustomobject]@{ ok = $false; errors = @($errors); catalogs = @() }
    }

    $seenDomains = @{}
    $catalogDomains = [System.Collections.Generic.List[string]]::new()
    foreach ($catalog in @($manifest.catalogs)) {
        $requiredCatalogFields = @(
            'domain',
            'prepare_phase',
            'directory',
            'extension',
            'expected_type',
            'id_property',
            'paths'
        )
        $missingCatalogFields = @(
            $requiredCatalogFields |
                Where-Object { $catalog.PSObject.Properties.Name -notcontains $_ }
        )
        foreach ($field in $missingCatalogFields) {
            $errors.Add("catalog is missing '$field': $($catalog | ConvertTo-Json -Compress)")
        }
        if ($missingCatalogFields.Count -gt 0) {
            continue
        }
        $catalogDomain = ([string]$catalog.domain).Trim()
        if ([string]::IsNullOrWhiteSpace($catalogDomain)) {
            $errors.Add('catalog contains an empty domain')
            continue
        }
        if ($seenDomains.ContainsKey($catalogDomain)) {
            $errors.Add("duplicate catalog domain '$catalogDomain'")
            continue
        }
        $seenDomains[$catalogDomain] = $true
        $catalogDomains.Add($catalogDomain)

        if ($allowedPreparePhases -notcontains [string]$catalog.prepare_phase) {
            $errors.Add("catalog '$catalogDomain' has unsupported prepare_phase '$($catalog.prepare_phase)'")
        }
        if (-not ([string]$catalog.directory).StartsWith('res://', [System.StringComparison]::Ordinal) -or
            -not ([string]$catalog.directory).EndsWith('/', [System.StringComparison]::Ordinal)) {
            $errors.Add("catalog '$catalogDomain' directory must be a res:// path ending in '/'")
        }
        if (-not ([string]$catalog.extension).StartsWith('.', [System.StringComparison]::Ordinal)) {
            $errors.Add("catalog '$catalogDomain' extension must start with '.'")
        }
        if ([string]::IsNullOrWhiteSpace([string]$catalog.expected_type)) {
            $errors.Add("catalog '$catalogDomain' expected_type is empty")
        }

        if ($Domain.Count -gt 0 -and $Domain -notcontains $catalogDomain) {
            continue
        }
        $declared = @($catalog.paths | ForEach-Object { [string]$_ })
        $actual = @(Get-StartupCatalogActualPaths -RepoRoot $RepoRoot -Catalog $catalog)
        $duplicates = @($declared | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
        foreach ($path in $duplicates) {
            $errors.Add("catalog '$catalogDomain' contains duplicate path '$path'")
        }
        $sortedDeclared = @(Get-OrdinalSortedStrings -Value $declared)
        if (($declared -join "`n") -cne ($sortedDeclared -join "`n")) {
            $errors.Add("catalog '$catalogDomain' paths are not ordinally sorted")
        }
        $unlisted = @($actual | Where-Object { $declared -cnotcontains $_ })
        $missing = @($declared | Where-Object { $actual -cnotcontains $_ })
        foreach ($path in $unlisted) {
            $errors.Add("catalog '$catalogDomain' has unlisted resource '$path'")
        }
        foreach ($path in $missing) {
            $errors.Add("catalog '$catalogDomain' declares missing or out-of-scope resource '$path'")
        }
        $catalogResults.Add([pscustomobject]@{
            domain = $catalogDomain
            declared_count = $declared.Count
            actual_count = $actual.Count
            unlisted = $unlisted
            missing = $missing
        })
    }

    $declaredRuntimeDomains = @($manifest.runtime_consumed_domains | ForEach-Object { [string]$_ })
    $duplicateRuntimeDomains = @(
        $declaredRuntimeDomains | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name
    )
    foreach ($domainName in $duplicateRuntimeDomains) {
        $errors.Add("runtime_consumed_domains contains duplicate '$domainName'")
    }
    $sortedCatalogDomains = @(Get-OrdinalSortedStrings -Value @($catalogDomains))
    $sortedRuntimeDomains = @(Get-OrdinalSortedStrings -Value $declaredRuntimeDomains)
    if (($sortedCatalogDomains -join "`n") -cne ($sortedRuntimeDomains -join "`n")) {
        $errors.Add(
            "runtime_consumed_domains must exactly match catalog domains; catalogs=[$($sortedCatalogDomains -join ', ')] runtime=[$($sortedRuntimeDomains -join ', ')]"
        )
    }
    foreach ($requestedDomain in $Domain) {
        if (-not $seenDomains.ContainsKey($requestedDomain)) {
            $errors.Add("requested domain '$requestedDomain' is not present in the manifest")
        }
    }

    return [pscustomobject]@{
        ok = $errors.Count -eq 0
        errors = @($errors)
        catalogs = @($catalogResults)
    }
}

function Update-StartupManifestPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [string[]]$Domain = @()
    )

    $manifest = Read-StartupManifest -ManifestPath $ManifestPath
    $changes = [System.Collections.Generic.List[object]]::new()
    $seenDomains = @{}
    foreach ($catalog in @($manifest.catalogs)) {
        $catalogDomain = ([string]$catalog.domain).Trim()
        $seenDomains[$catalogDomain] = $true
        if ($Domain.Count -gt 0 -and $Domain -notcontains $catalogDomain) {
            continue
        }
        $before = @($catalog.paths | ForEach-Object { [string]$_ })
        $after = @(Get-StartupCatalogActualPaths -RepoRoot $RepoRoot -Catalog $catalog)
        $catalog.paths = @($after)
        $changes.Add([pscustomobject]@{
            domain = $catalogDomain
            added = @($after | Where-Object { $before -cnotcontains $_ })
            removed = @($before | Where-Object { $after -cnotcontains $_ })
            count = $after.Count
        })
    }
    foreach ($requestedDomain in $Domain) {
        if (-not $seenDomains.ContainsKey($requestedDomain)) {
            throw "Requested domain '$requestedDomain' is not present in the manifest."
        }
    }

    $json = $manifest | ConvertTo-Json -Depth 16
    [System.IO.File]::WriteAllText(
        [System.IO.Path]::GetFullPath($ManifestPath),
        $json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    return @($changes)
}

Export-ModuleMember -Function `
    Get-StartupCatalogActualPaths, `
    Read-StartupManifest, `
    Test-StartupManifestStructure, `
    Update-StartupManifestPaths
