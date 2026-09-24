# install_tools.ps1 — fetch the map toolchain into the session scratchpad.
#
# All portable, all free, nothing installed system-wide and nothing needing
# admin rights. See tools/chart/README.md for what each piece is for.
param([string]$Dest = "")
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($Dest -eq "") {
    $Dest = Join-Path $env:TEMP "rh_maptools"
}
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Write-Output "installing into $Dest"

# ---- 1. portable CPython ----------------------------------------------------
$py = Join-Path $Dest "py\python.exe"
if (-not (Test-Path $py)) {
    Write-Output "  CPython 3.12.7 (embeddable)"
    Invoke-WebRequest -UseBasicParsing -OutFile "$Dest\py.zip" `
        -Uri "https://www.python.org/ftp/python/3.12.7/python-3.12.7-embed-amd64.zip"
    Expand-Archive "$Dest\py.zip" -DestinationPath "$Dest\py" -Force
    # embeddable builds ship with site-packages disabled, so pip installs are
    # invisible until this line is uncommented
    $pth = Get-ChildItem "$Dest\py" -Filter "python*._pth" | Select-Object -First 1
    $c = Get-Content $pth.FullName
    $c = $c -replace '^#import site', 'import site'
    if ($c -notcontains 'import site') { $c += 'import site' }
    $c | Set-Content $pth.FullName -Encoding ascii
}
& $py --version

# ---- 2. pip and the geometry stack -----------------------------------------
& $py -c "import shapely" 2>$null
if (-not $?) {
    Write-Output "  pip, shapely, pillow, numpy"
    Invoke-WebRequest -UseBasicParsing -OutFile "$Dest\get-pip.py" `
        -Uri "https://bootstrap.pypa.io/get-pip.py"
    & $py "$Dest\get-pip.py" --no-warn-script-location | Out-Null
    & $py -m pip install --no-warn-script-location shapely pillow numpy | Out-Null
}
& $py -c "import shapely, PIL, numpy; print('  shapely', shapely.__version__, '| pillow', PIL.__version__, '| numpy', numpy.__version__)"

# ---- 3. resvg, a production SVG renderer ------------------------------------
$resvg = Join-Path $Dest "resvg\resvg.exe"
if (-not (Test-Path $resvg)) {
    Write-Output "  resvg 0.47.0"
    # 0.48 ships no Windows binary; 0.47 is the newest that does
    Invoke-WebRequest -UseBasicParsing -OutFile "$Dest\resvg.zip" `
        -Uri "https://github.com/linebender/resvg/releases/download/v0.47.0/resvg-win64.zip"
    Expand-Archive "$Dest\resvg.zip" -DestinationPath "$Dest\resvg" -Force
}
Write-Output ("  resvg " + ((& $resvg --version 2>&1) -join ""))

Write-Output ""
Write-Output "ready. export these for make_sheets.ps1:"
Write-Output "  `$env:RH_PY    = `"$py`""
Write-Output "  `$env:RESVG    = `"$resvg`""
