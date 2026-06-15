param(
	[string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
$moduleDir = Join-Path $ProjectRoot "Player\Weapons\Modules"
$iconDir = Join-Path $ProjectRoot "Textures\modules"
New-Item -ItemType Directory -Force -Path $iconDir | Out-Null

function Get-IconSpec([string]$name) {
	$color = "#e3e8f2"
	$kind = "burst"
	$badge = ""

	if ($name -match "freeze|cryo|chill|ice|subzero|permafrost|shatter|brittle|trail") {
		$color = "#55c7ff"; $kind = "snow"
	}
	elseif ($name -match "fire|ember|molten") {
		$color = "#ff7738"; $kind = "flame"
	}
	elseif ($name -match "heat|overheat") {
		$color = "#ffae35"; $kind = "heat"
	}
	elseif ($name -match "reload") {
		$color = "#7ee04f"; $kind = "reload"
	}
	elseif ($name -match "crit|battle_focus") {
		$color = "#d788ff"; $kind = "target"
	}
	elseif ($name -match "lifesteal|vampiric") {
		$color = "#ff5475"; $kind = "heart"
	}
	elseif ($name -match "lightning|stun") {
		$color = "#ffe04d"; $kind = "bolt"
	}
	elseif ($name -match "bleed|damage|impact|pierce") {
		$color = "#ef5350"; $kind = "blade"
	}
	elseif ($name -match "dot|plague|corrosive") {
		$color = "#9bd447"; $kind = "toxin"
	}
	elseif ($name -match "dash|momentum|quick|speed") {
		$color = "#58e1d8"; $kind = "speed"
	}
	elseif ($name -match "magazine|multi|bullet|projectile") {
		$color = "#f2d36b"; $kind = "projectile"
	}
	elseif ($name -match "area|diffusion") {
		$color = "#72a7ff"; $kind = "area"
	}
	elseif ($name -match "magnet") {
		$color = "#d788ff"; $kind = "magnet"
	}

	switch -Regex ($name) {
		"battle_focus" { $badge = "multi"; break }
		"brittle_trigger" { $badge = "warning"; break }
		"bullet_size" { $badge = "ring"; break }
		"corrosive_touch" { $badge = "break"; break }
		"dot_on_hit" { $badge = "multi"; break }
		"plague_seed" { $badge = "warning"; break }
		"dash_cooler" { $badge = "move"; break }
		"momentum_haste" { $badge = "multi"; break }
		"projectile_speed" { $badge = "push"; break }
		"reload_offhand_boost" { $badge = "multi"; break }
		"reload_speed_link" { $badge = "link"; break }
		"heat_throttle" { $badge = "down"; break }
		"heat_vent" { $badge = "fan"; break }
		"amplifier|damage_boost|damage_up|concentration" { $badge = "up"; break }
		"calibrator|battle_focus" { $badge = "focus"; break }
		"dash_cooler|quick_cycle|fast_reload|heat_throttle|heat_vent|speed_link|projectile_speed" { $badge = "fast"; break }
		"capacity|expanded_magazine|bullet_size" { $badge = "plus"; break }
		"multi_launcher|chain" { $badge = "multi"; break }
		"area_expander|field|splash|blast_damage" { $badge = "ring"; break }
		"impact|blast_knockback" { $badge = "push"; break }
		"diffusion|trail" { $badge = "fan"; break }
		"shield|vampiric" { $badge = "shield"; break }
		"move_boost|momentum" { $badge = "move"; break }
		"offhand" { $badge = "link"; break }
		"lifesteal" { $badge = "plus"; break }
		"brittle|shatter" { $badge = "break"; break }
		"extension" { $badge = "long"; break }
		"prison|stun" { $badge = "lock"; break }
		"infuser|ember|plague|bleed|dot_on_hit|corrosive" { $badge = "drop"; break }
		"pierce" { $badge = "pierce"; break }
		"overheat" { $badge = "warning"; break }
	}
	return @{ Color = $color; Kind = $kind; Badge = $badge }
}

function Get-MainGlyph([string]$kind, [string]$c) {
	switch ($kind) {
		"target" { return "<circle cx='16' cy='16' r='8'/><circle cx='16' cy='16' r='3'/><path d='M16 4v5M16 23v5M4 16h5M23 16h5'/>" }
		"snow" { return "<path d='M16 5v22M7 10l18 12M25 10L7 22M12 7l4 3 4-3M12 25l4-3 4 3M6 15l4 1-1 4M26 15l-4 1 1 4'/>" }
		"flame" { return "<path d='M17 4c2 6-3 7 1 11 2-3 5-3 5 2 0 6-4 10-9 10s-8-4-7-9c1-5 6-7 7-12 3 3 1 6 3 8'/>" }
		"heat" { return "<path d='M10 25c-3-4 2-6 0-10s2-6 0-9M16 25c-3-4 2-6 0-10s2-6 0-9M22 25c-3-4 2-6 0-10s2-6 0-9'/>" }
		"reload" { return "<path d='M9 10a9 9 0 1 1-1 11'/><path d='M5 10h7V3'/><rect x='13' y='11' width='7' height='11' rx='1'/>" }
		"heart" { return "<path d='M16 27S5 21 5 12c0-6 8-7 11-2 3-5 11-4 11 2 0 9-11 15-11 15z'/>" }
		"bolt" { return "<path d='M18 3L8 18h7l-1 11 10-16h-7z'/>" }
		"blade" { return "<path d='M6 25L23 8l4-3-2 6L9 27z'/><path d='M6 21l5 5M19 8l5 5'/>" }
		"toxin" { return "<path d='M16 5c5 7 8 10 8 15a8 8 0 0 1-16 0c0-5 3-8 8-15z'/><circle cx='13' cy='19' r='1'/><circle cx='19' cy='22' r='1'/>" }
		"speed" { return "<path d='M5 11h11M3 16h13M5 21h11M17 9l10 7-10 7z'/>" }
		"projectile" { return "<path d='M7 22L21 8l4-1-1 4-14 14z'/><path d='M5 10h7M3 15h7M5 20h3'/>" }
		"area" { return "<circle cx='16' cy='16' r='10'/><circle cx='16' cy='16' r='4'/><path d='M16 3v4M16 25v4M3 16h4M25 16h4'/>" }
		"magnet" { return "<path d='M8 6v12a8 8 0 0 0 16 0V6h-6v12a2 2 0 0 1-4 0V6z'/><path d='M8 11h6M18 11h6'/>" }
		default { return "<path d='M16 4l3 8 9 4-9 4-3 8-3-8-9-4 9-4z'/>" }
	}
}

function Get-Badge([string]$badge, [string]$c) {
	switch ($badge) {
		"up" { return "<path class='badge' d='M22 27v-7M19 23l3-3 3 3'/>" }
		"focus" { return "<circle class='badge' cx='23' cy='23' r='3'/><circle class='fill' cx='23' cy='23' r='1'/>" }
		"fast" { return "<path class='badge' d='M21 20l-2 4h3l-1 5 5-7h-3l2-2z'/>" }
		"plus" { return "<path class='badge' d='M23 19v8M19 23h8'/>" }
		"multi" { return "<circle class='fill' cx='20' cy='24' r='1.5'/><circle class='fill' cx='24' cy='21' r='1.5'/><circle class='fill' cx='26' cy='25' r='1.5'/>" }
		"ring" { return "<circle class='badge' cx='23' cy='23' r='4'/>" }
		"push" { return "<path class='badge' d='M19 23h8M24 20l3 3-3 3'/>" }
		"fan" { return "<path class='badge' d='M19 27l8-8M19 27l4-9M19 27l9-4'/>" }
		"shield" { return "<path class='badge' d='M23 18l5 2v4c0 3-2 5-5 6-3-1-5-3-5-6v-4z'/>" }
		"move" { return "<path class='badge' d='M19 24h8M24 21l3 3-3 3'/>" }
		"link" { return "<path class='badge' d='M18 24h4M22 21h3a3 3 0 0 1 0 6h-3M20 21h-2a3 3 0 0 0 0 6h2'/>" }
		"break" { return "<path class='badge' d='M20 18l3 4-2 2 3 4'/>" }
		"long" { return "<path class='badge' d='M19 24h9M19 21v6M28 21v6'/>" }
		"lock" { return "<rect class='badge' x='19' y='22' width='8' height='6' rx='1'/><path class='badge' d='M21 22v-2a2 2 0 0 1 4 0v2'/>" }
		"drop" { return "<path class='badge' d='M23 18c3 4 4 5 4 7a4 4 0 0 1-8 0c0-2 1-3 4-7z'/>" }
		"pierce" { return "<path class='badge' d='M18 26l10-7M24 19h4v4'/>" }
		"warning" { return "<path class='badge' d='M23 18l6 10H17zM23 21v3M23 26v1'/>" }
		"down" { return "<path class='badge' d='M22 19v8M19 24l3 3 3-3'/>" }
		default { return "" }
	}
}

$scenes = Get-ChildItem $moduleDir -Filter "wmod_*.tscn" | Where-Object { $_.Name -ne "wmod_base.tscn" }
foreach ($scene in $scenes) {
	$name = $scene.BaseName
	$spec = Get-IconSpec $name
	$color = $spec.Color
	$main = Get-MainGlyph $spec.Kind $color
	$badge = Get-Badge $spec.Badge $color
	$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
  <style>
    .main { fill: none; stroke: $color; stroke-width: 2; stroke-linecap: square; stroke-linejoin: round; }
    .badge { fill: #10141f; stroke: #ffffff; stroke-width: 1.5; stroke-linecap: square; stroke-linejoin: round; }
    .fill { fill: #ffffff; stroke: none; }
  </style>
  <g class="main">$main</g>
  $badge
</svg>
"@
	$iconPath = Join-Path $iconDir "$name.svg"
	[System.IO.File]::WriteAllText($iconPath, $svg, [System.Text.UTF8Encoding]::new($false))

	$content = [System.IO.File]::ReadAllText($scene.FullName)
	$resourcePath = "res://asset/images/modules/$name.svg"
	$content = [regex]::Replace(
		$content,
		'(?m)^\[ext_resource type="Texture2D"(?: uid="[^"]+")? path="[^"]+" id="([^"]+)"\]$',
		"[ext_resource type=`"Texture2D`" path=`"$resourcePath`" id=`"`$1`"]",
		1
	)
	[System.IO.File]::WriteAllText($scene.FullName, $content, [System.Text.UTF8Encoding]::new($false))
}

$cards = foreach ($scene in $scenes | Sort-Object BaseName) {
	$name = $scene.BaseName
	"<article><img src='../asset/images/modules/$name.svg' alt='$name'><span>$($name -replace '^wmod_', '' -replace '_', ' ')</span></article>"
}
$preview = @"
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Module Icon Preview</title>
<style>
body{margin:0;padding:28px;background:#10141f;color:#e3e8f2;font:14px system-ui,sans-serif}
h1{margin:0 0 24px;font-size:22px}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:12px}
article{display:flex;align-items:center;gap:12px;padding:12px;background:#181f2d;border:1px solid #2b3548;border-radius:8px}
img{width:48px;height:48px;image-rendering:pixelated;background:#0b0e16;border-radius:6px}
span{text-transform:capitalize;line-height:1.25}
</style>
</head>
<body><h1>Weapon Module Icons ($($scenes.Count))</h1><main>$($cards -join "`n")</main></body>
</html>
"@
[System.IO.File]::WriteAllText((Join-Path $ProjectRoot "docs\module_icon_preview.html"), $preview, [System.Text.UTF8Encoding]::new($false))

Write-Host "Generated and assigned $($scenes.Count) module icons."
