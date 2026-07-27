param(
    [string]$PythonPath = ""
)

$ErrorActionPreference = "Stop"
$ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvRoot = Join-Path $ToolRoot ".venv"

if ([string]::IsNullOrWhiteSpace($PythonPath)) {
    $PythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
}
if ([string]::IsNullOrWhiteSpace($PythonPath) -or -not (Test-Path -LiteralPath $PythonPath)) {
    throw "未找到 Python。请使用 -PythonPath 指定 Python 3.10+ 的 python.exe。"
}

if (-not (Test-Path -LiteralPath $VenvRoot)) {
    & $PythonPath -m venv $VenvRoot
}

$VenvPython = Join-Path $VenvRoot "Scripts\python.exe"
& $VenvPython -m pip install --disable-pip-version-check -r (Join-Path $ToolRoot "requirements.txt")
& $VenvPython -m unittest discover -s (Join-Path $ToolRoot "tests") -v

Push-Location $ToolRoot
try {
    & $VenvPython -m PyInstaller `
        --noconfirm `
        --clean `
        --windowed `
        --onedir `
        --name "PerfectPixelNormalizer" `
        --collect-all "perfect_pixel" `
        --collect-all "cv2" `
        "app.py"

    & $VenvPython -m PyInstaller `
        --noconfirm `
        --clean `
        --console `
        --onefile `
        --name "PerfectPixelCLI" `
        --collect-all "perfect_pixel" `
        --collect-all "cv2" `
        "cli.py"
}
finally {
    Pop-Location
}

$ExePath = Join-Path $ToolRoot "dist\PerfectPixelNormalizer\PerfectPixelNormalizer.exe"
if (-not (Test-Path -LiteralPath $ExePath)) {
    throw "构建结束，但没有找到预期的可执行文件：$ExePath"
}

$DistRoot = Split-Path -Parent $ExePath
$CliBuildPath = Join-Path $ToolRoot "dist\PerfectPixelCLI.exe"
$CliPath = Join-Path $DistRoot "PerfectPixelCLI.exe"
if (-not (Test-Path -LiteralPath $CliBuildPath)) {
    throw "构建结束，但没有找到 CLI 可执行文件：$CliBuildPath"
}
Copy-Item -LiteralPath $CliBuildPath -Destination $CliPath -Force
Copy-Item -LiteralPath (Join-Path $ToolRoot "README.md") -Destination $DistRoot -Force
Copy-Item -LiteralPath (Join-Path $ToolRoot "THIRD_PARTY_NOTICES.md") -Destination $DistRoot -Force

& $ExePath --self-test
if ($LASTEXITCODE -ne 0) {
    throw "可执行文件自检失败，退出码：$LASTEXITCODE"
}
& $CliPath --version
if ($LASTEXITCODE -ne 0) {
    throw "CLI 可执行文件自检失败，退出码：$LASTEXITCODE"
}

$ArchivePath = Join-Path $ToolRoot "dist\PerfectPixelNormalizer-windows-x64.zip"
Compress-Archive -Path (Join-Path $DistRoot "*") -DestinationPath $ArchivePath -Force
Write-Output "BUILD_OK=$ExePath"
Write-Output "PACKAGE_OK=$ArchivePath"
