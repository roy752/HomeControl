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

## Check for NSSM: use Get-Command and validate the resolved path; fall back to where.exe.
$hasNssm = $false
$cmd = Get-Command nssm -ErrorAction SilentlyContinue
if ($cmd -ne $null) {
    # try to resolve executable path from returned command info
    $exePath = $null
    if ($cmd.Path) { $exePath = $cmd.Path }
    elseif ($cmd.Source) { $exePath = $cmd.Source }
    elseif ($cmd.Definition) { $exePath = $cmd.Definition }

    if ($exePath -and (Test-Path $exePath)) {
        $hasNssm = $true
    } else {
        # sometimes Get-Command returns an object without an accessible path; try where.exe
        try {
            $whereResult = & where.exe nssm 2>$null
            if ($whereResult) { $hasNssm = $true }
        } catch {
            # ignore
        }
    }
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
    # fail the script explicitly so CI marks step as failed
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
