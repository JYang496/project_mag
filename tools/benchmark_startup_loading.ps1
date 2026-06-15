param(
	[int]$QuitAfterSeconds = 1,
	[int]$Runs = 3
)

$ErrorActionPreference = "Stop"
$Runs = [Math]::Max($Runs, 1)
$scenes = @(
	"res://World/Start.tscn",
	"res://World/world.tscn"
)
$rows = @()

foreach ($scene in $scenes) {
	$durations = @()
	$loads = @()
	$loadErrors = 0
	for ($run = 1; $run -le $Runs; $run++) {
		$stopwatch = [Diagnostics.Stopwatch]::StartNew()
		$ErrorActionPreference = "Continue"
		$output = & godot --headless --verbose --path . --scene $scene --quit-after $QuitAfterSeconds 2>&1
		$ErrorActionPreference = "Stop"
		$stopwatch.Stop()
		$durations += $stopwatch.ElapsedMilliseconds
		$loads = @(
			$output |
				Select-String "^Loading resource:" |
				ForEach-Object { $_.Line.Substring(18) } |
				Sort-Object -Unique
		)
		$loadErrors += @($output | Select-String "SCRIPT ERROR:|Failed loading resource|Failed to load").Count
	}
	$durationStats = $durations | Measure-Object -Average -Minimum -Maximum
	$rows += [pscustomobject]@{
		Scene = $scene
		AvgMs = [Math]::Round($durationStats.Average)
		MinMs = $durationStats.Minimum
		MaxMs = $durationStats.Maximum
		UniqueResources = $loads.Count
		Data = @($loads | Where-Object { $_ -like "res://data/*" }).Count
		Weapons = @($loads | Where-Object { $_ -like "res://Player/Weapons/*" }).Count
		Enemies = @($loads | Where-Object { $_ -like "res://Npc/enemy/*" }).Count
		UI = @($loads | Where-Object { $_ -like "res://UI/*" }).Count
		Assets = @($loads | Where-Object { $_ -like "res://asset/*" }).Count
		LoadErrors = $loadErrors
	}
}

$rows | Format-Table -AutoSize
