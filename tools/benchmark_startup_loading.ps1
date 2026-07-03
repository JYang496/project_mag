[CmdletBinding()]
param(
	[int]$Runs = 5,
	[int]$QuitAfterFrames = 2,
	[string]$ProjectPath = '.',
	[string]$GodotPath,
	[string]$HotScene = 'res://World/Start.tscn',
	[string]$DirectedTestScene = 'res://tests/scenes/startup/startup_baseline_probe.tscn',
	[switch]$SkipColdImport,
	[string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Runs = [Math]::Max($Runs, 1)
$QuitAfterFrames = [Math]::Max($QuitAfterFrames, 1)
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

function Resolve-GodotExecutable {
	param([string]$RequestedPath)

	if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
		if (-not (Test-Path -LiteralPath $RequestedPath -PathType Leaf)) {
			throw "Godot executable does not exist: $RequestedPath"
		}
		return (Resolve-Path -LiteralPath $RequestedPath).Path
	}
	$command = Get-Command godot -ErrorAction SilentlyContinue
	if ($null -ne $command) {
		return $command.Source
	}
	$versionedCommands = @(
		Get-Command 'Godot_v*-stable_win64_console.exe' -ErrorAction SilentlyContinue |
			Sort-Object Name -Descending
	)
	if ($versionedCommands.Count -gt 0) {
		return $versionedCommands[0].Source
	}
	$candidates = @(
		'C:\Program Files (x86)\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64_console.exe',
		'C:\Program Files\Godot\Godot_v4.7-stable_win64_console.exe',
		'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
	)
	foreach ($candidate in $candidates) {
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}
	throw 'Godot executable was not found. Pass -GodotPath explicitly.'
}

function Get-Median {
	param([Parameter(Mandatory)][AllowEmptyCollection()][double[]]$Value)

	if ($Value.Count -eq 0) {
		return 0
	}
	$sorted = @($Value | Sort-Object)
	$middle = [int][Math]::Floor($sorted.Count / 2)
	if ($sorted.Count % 2 -eq 1) {
		return [double]$sorted[$middle]
	}
	return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Get-MeasurementMetricsFromFiles {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[string[]]$Paths
	)

	$resourcePaths = @{}
	$errorLines = @()
	$runtimeErrorLines = @()
	$shutdownLeakLines = @()
	$warningLines = @()
	$reportedStages = @()
	$passMarkers = @()
	$failMarkers = @()
	$outputTail = [System.Collections.Queue]::new()
	$stageNames = @(
		'first_scan_filesystem',
		'update_scripts_classes',
		'scan_sources',
		'reimport',
		'loading_editor_layout'
	)
	$observedStageMap = @{}
	$inShutdownLeakDump = $false

	foreach ($path in $Paths) {
		if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
			continue
		}
		foreach ($line in [IO.File]::ReadLines($path)) {
			if ([string]::IsNullOrEmpty($line)) {
				continue
			}
			$outputTail.Enqueue($line)
			while ($outputTail.Count -gt 20) {
				$null = $outputTail.Dequeue()
			}
			if ($line -match '^Loading resource:\s*(.+)$') {
				$resourcePaths[$Matches[1].Trim()] = $true
			}
			if ($line -match '(?i)^(Leaked instance:|Orphan StringName:|StringName: \d+ unclaimed)') {
				$inShutdownLeakDump = $true
			}
			if ($line -match '(?i)(SCRIPT ERROR:|ERROR:|Failed loading resource|Failed to load)') {
				$errorLines += $line
				$isDirectShutdownLeak = $line -match '(?i)(allocations?.*leaked at exit|resources? still in use at exit|ObjectDB instances were leaked)'
				if ($inShutdownLeakDump -or $isDirectShutdownLeak) {
					$shutdownLeakLines += $line
				} else {
					$runtimeErrorLines += $line
				}
			}
			if ($line -match '(?i)(WARNING:|WARN:)') {
				$warningLines += $line
			}
			foreach ($stage in $stageNames) {
				if ($line -match [regex]::Escape($stage)) {
					$observedStageMap[$stage] = $true
				}
			}
			if ($line -match '^StartupBaselineStage:') {
				$reportedStages += $line.Trim()
			}
			if ($line -match '(?i)\bPASS\b') {
				$passMarkers += $line
			}
			if ($line -match '(?i)\b(FAIL|ERROR)\b') {
				$failMarkers += $line
			}
		}
	}
	$resourceList = @($resourcePaths.Keys)
	return [pscustomobject]@{
		unique_resources = $resourceList.Count
		data_resources = @($resourceList | Where-Object { $_ -like 'res://data/*' }).Count
		weapon_resources = @($resourceList | Where-Object { $_ -like 'res://Player/Weapons/*' }).Count
		enemy_resources = @($resourceList | Where-Object { $_ -like 'res://Npc/enemy/*' }).Count
		ui_resources = @($resourceList | Where-Object { $_ -like 'res://UI/*' }).Count
		asset_resources = @($resourceList | Where-Object { $_ -like 'res://asset/*' }).Count
		error_count = $errorLines.Count
		runtime_error_count = $runtimeErrorLines.Count
		shutdown_leak_error_count = $shutdownLeakLines.Count
		warning_count = $warningLines.Count
		observed_editor_stages = @($stageNames | Where-Object { $observedStageMap.ContainsKey($_) })
		reported_runtime_stages = $reportedStages
		pass_markers = $passMarkers
		fail_markers = $failMarkers
		output_tail = @($outputTail.ToArray())
	}
}

function Join-ProcessArguments {
	param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments)

	$escaped = foreach ($argument in $Arguments) {
		if ($argument -notmatch '[\s"]') {
			$argument
			continue
		}
		'"' + ($argument -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
	}
	return ($escaped -join ' ')
}

function Invoke-GodotMeasurement {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][string]$MeasurementProjectPath,
		[Parameter(Mandatory)][string[]]$Arguments,
		[Parameter(Mandatory)][string]$UserHome
	)

	New-Item -ItemType Directory -Path $UserHome -Force | Out-Null
	$previousUserHome = $env:GODOT_USER_HOME
	$env:GODOT_USER_HOME = $UserHome
	$process = $null
	$stdoutPath = Join-Path $UserHome "$Name.stdout.log"
	$stderrPath = Join-Path $UserHome "$Name.stderr.log"
	try {
		$stopwatch = [Diagnostics.Stopwatch]::StartNew()
		$process = Start-Process `
			-FilePath $script:GodotExecutable `
			-ArgumentList (Join-ProcessArguments -Arguments $Arguments) `
			-RedirectStandardOutput $stdoutPath `
			-RedirectStandardError $stderrPath `
			-NoNewWindow `
			-Wait `
			-PassThru
		$stopwatch.Stop()
		$exitCode = $process.ExitCode
		$metrics = Get-MeasurementMetricsFromFiles -Paths @($stdoutPath, $stderrPath)
	} finally {
		$env:GODOT_USER_HOME = $previousUserHome
		if ($process -ne $null) {
			$process.Dispose()
		}
	}
	return [pscustomobject]@{
		name = $Name
		duration_ms = $stopwatch.ElapsedMilliseconds
		exit_code = $exitCode
		unique_resources = $metrics.unique_resources
		data_resources = $metrics.data_resources
		weapon_resources = $metrics.weapon_resources
		enemy_resources = $metrics.enemy_resources
		ui_resources = $metrics.ui_resources
		asset_resources = $metrics.asset_resources
		error_count = $metrics.error_count
		runtime_error_count = $metrics.runtime_error_count
		shutdown_leak_error_count = $metrics.shutdown_leak_error_count
		warning_count = $metrics.warning_count
		observed_editor_stages = $metrics.observed_editor_stages
		reported_runtime_stages = $metrics.reported_runtime_stages
		pass_markers = $metrics.pass_markers
		fail_markers = $metrics.fail_markers
		output_tail = $metrics.output_tail
	}
}

function Copy-ProjectForColdImport {
	param(
		[Parameter(Mandatory)][string]$Source,
		[Parameter(Mandatory)][string]$Destination
	)

	New-Item -ItemType Directory -Path $Destination -Force | Out-Null
	$null = & robocopy $Source $Destination /E /XD .git .godot /XF .git /NFL /NDL /NJH /NJS /NP
	if ($LASTEXITCODE -gt 7) {
		throw "robocopy failed with exit code $LASTEXITCODE."
	}
}

function Summarize-Series {
	param(
		[Parameter(Mandatory)][string]$Name,
		[Parameter(Mandatory)][object[]]$Measurements
	)

	return [pscustomobject]@{
		name = $Name
		runs = $Measurements.Count
		median_ms = [Math]::Round((Get-Median -Value @($Measurements.duration_ms)), 1)
		min_ms = ($Measurements.duration_ms | Measure-Object -Minimum).Minimum
		max_ms = ($Measurements.duration_ms | Measure-Object -Maximum).Maximum
		median_unique_resources = [Math]::Round((Get-Median -Value @($Measurements.unique_resources)), 1)
		total_errors = ($Measurements.error_count | Measure-Object -Sum).Sum
		total_runtime_errors = ($Measurements.runtime_error_count | Measure-Object -Sum).Sum
		total_shutdown_leak_errors = ($Measurements.shutdown_leak_error_count | Measure-Object -Sum).Sum
		total_warnings = ($Measurements.warning_count | Measure-Object -Sum).Sum
		exit_codes = @($Measurements.exit_code)
		raw_runs = $Measurements
	}
}

$script:GodotExecutable = Resolve-GodotExecutable -RequestedPath $GodotPath
$godotVersion = (& $script:GodotExecutable --version | Select-Object -First 1).ToString().Trim()
$commit = (& git -C $ProjectPath rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
	throw 'Unable to resolve the project commit.'
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) (
	'project_mag_startup_benchmark_' + [Guid]::NewGuid().ToString('N')
)
$resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
if (-not $resolvedTemporaryRoot.StartsWith($resolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase)) {
	throw "Refusing to use temporary path outside the system temp directory: $resolvedTemporaryRoot"
}

New-Item -ItemType Directory -Path $resolvedTemporaryRoot -Force | Out-Null
try {
	$coldImport = $null
	if (-not $SkipColdImport) {
		$coldProject = Join-Path $resolvedTemporaryRoot 'cold_project'
		Copy-ProjectForColdImport -Source $ProjectPath -Destination $coldProject
		$coldImport = Invoke-GodotMeasurement `
			-Name 'cold_import' `
			-MeasurementProjectPath $coldProject `
			-Arguments @('--headless', '--verbose', '--editor', '--path', $coldProject, '--import', '--quit') `
			-UserHome (Join-Path $resolvedTemporaryRoot 'cold_user_home')
		$coldImport | Add-Member -NotePropertyName imported_cache_files -NotePropertyValue @(
			Get-ChildItem -LiteralPath (Join-Path $coldProject '.godot\imported') -File -ErrorAction SilentlyContinue
		).Count
	}

	$hotRuns = @()
	for ($run = 1; $run -le $Runs; $run++) {
		$hotRuns += Invoke-GodotMeasurement `
			-Name "hot_start_$run" `
			-MeasurementProjectPath $ProjectPath `
			-Arguments @(
				'--headless',
				'--verbose',
				'--path', $ProjectPath,
				'--scene', $HotScene,
				'--quit-after', [string]$QuitAfterFrames
			) `
			-UserHome (Join-Path $resolvedTemporaryRoot "hot_user_home_$run")
	}

	$testRuns = @()
	for ($run = 1; $run -le $Runs; $run++) {
		$testRuns += Invoke-GodotMeasurement `
			-Name "directed_test_$run" `
			-MeasurementProjectPath $ProjectPath `
			-Arguments @(
				'--headless',
				'--verbose',
				'--path', $ProjectPath,
				'--scene', $DirectedTestScene
			) `
			-UserHome (Join-Path $resolvedTemporaryRoot "test_user_home_$run")
	}

	$report = [pscustomobject]@{
		schema_version = 1
		captured_at = (Get-Date).ToString('o')
		project_path = $ProjectPath
		commit = $commit
		godot_path = $script:GodotExecutable
		godot_version = $godotVersion
		settings = [pscustomobject]@{
			runs = $Runs
			quit_after_frames = $QuitAfterFrames
			hot_scene = $HotScene
			directed_test_scene = $DirectedTestScene
			user_data_isolation = 'GODOT_USER_HOME per process'
			cold_cache_isolation = 'temporary project copy without .git or .godot'
			stage_timing_note = 'External duration is process start-to-exit; editor stage names and probe-reported runtime elapsed times are retained separately.'
		}
		cold_import = $coldImport
		hot_start = Summarize-Series -Name 'hot_start' -Measurements $hotRuns
		directed_test = Summarize-Series -Name 'directed_test' -Measurements $testRuns
	}
	$json = $report | ConvertTo-Json -Depth 12
	if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
		$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
			[IO.Path]::GetFullPath($OutputPath)
		} else {
			[IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
		}
		$outputDirectory = Split-Path -Parent $resolvedOutput
		New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
		[IO.File]::WriteAllText($resolvedOutput, $json, [Text.UTF8Encoding]::new($false))
	}
	Write-Output $json

	$failedRuns = @(
		$hotRuns + $testRuns |
			Where-Object { $_.exit_code -ne 0 -or $_.runtime_error_count -gt 0 }
	)
	$missingPassRuns = @($testRuns | Where-Object { $_.pass_markers.Count -eq 0 })
	if (($null -ne $coldImport -and ($coldImport.exit_code -ne 0 -or $coldImport.runtime_error_count -gt 0)) -or
		$failedRuns.Count -gt 0 -or
		$missingPassRuns.Count -gt 0) {
		exit 1
	}
} finally {
	if (Test-Path -LiteralPath $resolvedTemporaryRoot) {
		$confirmedTemporaryRoot = [IO.Path]::GetFullPath($resolvedTemporaryRoot)
		if (-not $confirmedTemporaryRoot.StartsWith($resolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase)) {
			throw "Refusing to remove temporary path outside the system temp directory: $confirmedTemporaryRoot"
		}
		Remove-Item -LiteralPath $confirmedTemporaryRoot -Recurse -Force
	}
}
