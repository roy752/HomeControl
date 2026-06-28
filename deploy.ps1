param(
    [string]$ServiceName = "HomeControl",
    [int]$Port = 11010
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repo = (Resolve-Path ".").Path
$venvPath = Join-Path $repo ".venv"
$pythonExe = Join-Path $venvPath "Scripts/python.exe"

if (-not (Test-Path $pythonExe)) {
    Write-Host "Creating virtual environment..."
    python -m venv $venvPath
}

Write-Host "Installing Python dependencies..."
& $pythonExe -m pip install --upgrade pip
& $pythonExe -m pip install -r requirements.txt

Write-Host "Running tests..."
& $pythonExe -m pytest -q

## Check for NSSM: some environments don't return Get-Command though nssm is callable.
$hasNssm = $false
if (Get-Command nssm -ErrorAction SilentlyContinue) {
    $hasNssm = $true
} else {
    try {
        $whereResult = & where.exe nssm 2>$null
        if ($whereResult) { $hasNssm = $true }
    } catch {
        # ignore
    }
}

if (-not $hasNssm) {
    Write-Error "nssm not found. Install NSSM from https://nssm.cc/download/ to register the Windows service."
    exit 1
}

if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Windows service '$ServiceName'..."
    nssm install $ServiceName $pythonExe
    nssm set $ServiceName AppDirectory $repo
    nssm set $ServiceName AppParameters "-m uvicorn main:app --host 0.0.0.0 --port $Port"
    nssm set $ServiceName Start SERVICE_AUTO_START
}

Write-Host "Restarting service '$ServiceName'..."
Restart-Service -Name $ServiceName -Force
