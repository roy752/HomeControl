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

## Assume NSSM is installed and callable on the system.
# Some runner environments may register nssm in nonstandard ways; to avoid
# false negatives, we don't pre-check here — let any nssm invocation fail
# naturally so CI will surface the error and logs will show the failing command.

if (-not (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Windows service '$ServiceName'..."

    # Resolve nssm executable: allow overriding with NSSM_EXE env var
    $nssmExe = $env:NSSM_EXE
    if (-not $nssmExe) {
        $cmd = Get-Command nssm -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Path) { $nssmExe = $cmd.Path }
        elseif ($cmd -and $cmd.Source) { $nssmExe = $cmd.Source }
    }

    # Common fallback locations where nssm.exe is often installed
    $commonPaths = @("C:\nssm\nssm.exe","C:\Program Files\nssm\nssm.exe","C:\Program Files (x86)\nssm\nssm.exe")
    foreach ($p in $commonPaths) {
        if (-not $nssmExe -and (Test-Path $p)) { $nssmExe = $p }
    }

    if (-not $nssmExe) {
        Write-Error "nssm not found. Set NSSM_EXE environment variable to full path, or ensure nssm is on the service PATH."
        exit 1
    }

    Write-Host "Using nssm: $nssmExe"
    & $nssmExe install $ServiceName $pythonExe
    & $nssmExe set $ServiceName AppDirectory $repo
    & $nssmExe set $ServiceName AppParameters "-m uvicorn main:app --host 0.0.0.0 --port $Port"
    & $nssmExe set $ServiceName Start SERVICE_AUTO_START
}

Write-Host "Restarting service '$ServiceName'..."
Restart-Service -Name $ServiceName -Force
