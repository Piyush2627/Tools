Write-Host "=== Universal VS Code + MSYS2 + Code Runner Setup ===" -ForegroundColor Cyan

function Exists($cmd) {
    Get-Command $cmd -ErrorAction SilentlyContinue | Out-Null
    return $?
}

# Helper to refresh environment variables in the current session
function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "   >> Environment variables refreshed." -ForegroundColor DarkGray
}

# -------------------------
# 0. Check Winget
# -------------------------
if (Exists winget) {
    Write-Host "`nWinget detected! Using Winget for installation..." -ForegroundColor Green

    # 1. Install VS Code
    Write-Host "[1/4] Installing VS Code via Winget..." -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements

    # 2. Install MSYS2
    Write-Host "[2/4] Installing MSYS2 via Winget..." -ForegroundColor Yellow
    winget install --id MSYS2.MSYS2 -e --silent --accept-package-agreements --accept-source-agreements

    # Wait for MSYS2 to settle
    Start-Sleep -Seconds 10
    
    # --- FIX: Install GCC Toolchain using Pacman (Was missing!) ---
    Write-Host "[2.5/4] Downloading GCC/G++ Toolchain..." -ForegroundColor Yellow
    $bash = "C:\msys64\usr\bin\bash.exe"
    if (Test-Path $bash) {
        & $bash -lc "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc"
    } else {
        Write-Host "Error: MSYS2 bash not found at $bash" -ForegroundColor Red
    }

    # 3. Add MSYS2 mingw64/bin to user PATH
    $mingwBin="C:\msys64\mingw64\bin"
    $userPath=[Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$mingwBin*") {
        [Environment]::SetEnvironmentVariable("Path","$userPath;$mingwBin","User")
        Write-Host "✔ MSYS2 compiler added to PATH." -ForegroundColor Green
    } else {
        Write-Host "✔ PATH already configured." -ForegroundColor Green
    }

    # Refresh Env so we can find 'code' command
    Refresh-Env

    # 4. Install Code Runner extension
    if (Exists code) {
        Write-Host "[4/4] Installing Extensions..." -ForegroundColor Yellow
        $extensions = code --list-extensions
        if ($extensions -contains "formulahendry.code-runner") {
            Write-Host "✔ Code Runner already installed." -ForegroundColor Green
        } else {
            code --install-extension formulahendry.code-runner
            Write-Host "✔ Code Runner installed." -ForegroundColor Green
        }
    } else {
        Write-Host "⚠ Could not find 'code' command in current session. Restart terminal to finish setup." -ForegroundColor Magenta
    }

    Write-Host "`n✅ Winget installation complete. Restart PowerShell to use GCC/G++." -ForegroundColor Cyan

} else {
    Write-Host "`n⚠ Winget not found! Falling back to manual MSYS2 installation..." -ForegroundColor Red

    # -------------------------
    # Manual installation script
    # -------------------------

    # 1. VS Code
    Write-Host "[1/4] Checking VS Code..." -ForegroundColor Yellow
    $vsCodeExe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vsCodeExe) {
        Write-Host "✔ VS Code already installed." -ForegroundColor Green
    } else {
        Write-Host "Installing VS Code..." -ForegroundColor Cyan
        $vscode = "$env:TEMP\vscode.exe"
        Invoke-WebRequest "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -OutFile $vscode
        Start-Process $vscode -ArgumentList "/silent","/mergetasks=!runcode" -Wait
        Write-Host "✔ VS Code installed." -ForegroundColor Green
    }
    # Update current session path manually so we can use 'code' later
    $env:Path += ";$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"

    # 2. MSYS2
    Write-Host "[2/4] Checking MSYS2..." -ForegroundColor Yellow
    $msysPath = "C:\msys64"
    if (Test-Path "$msysPath\mingw64\bin\gcc.exe") {
        Write-Host "✔ MSYS2 already installed." -ForegroundColor Green
    } else {
        Write-Host "Installing MSYS2..." -ForegroundColor Cyan
        $msysInstaller = "$env:TEMP\msys2.exe"
        # FIX: Updated URL to a generic "latest" link to prevent 404s in the future
        Invoke-WebRequest "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe" -OutFile $msysInstaller
        Start-Process $msysInstaller -ArgumentList "--confirm-command","--accept-messages","--root","C:\msys64" -Wait
        Write-Host "✔ MSYS2 installed." -ForegroundColor Green
    }

    # 3. Install GCC/G++
    Write-Host "[3/4] Installing GCC & G++..." -ForegroundColor Yellow
    $bash = "C:\msys64\usr\bin\bash.exe"
    if (Test-Path $bash) {
         & $bash -lc "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc"
    }

    # 4. PATH + Code Runner
    Write-Host "[4/4] Updating PATH and Code Runner extension..." -ForegroundColor Yellow
    $mingwBin = "C:\msys64\mingw64\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$mingwBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$mingwBin", "User")
        Write-Host "✔ Compiler added to PATH." -ForegroundColor Green
    } else {
        Write-Host "✔ PATH already configured." -ForegroundColor Green
    }

    if (Exists code) {
        $extensions = code --list-extensions
        if ($extensions -contains "formulahendry.code-runner") {
            Write-Host "✔ Code Runner already installed." -ForegroundColor Green
        } else {
            code --install-extension formulahendry.code-runner
            Write-Host "✔ Code Runner installed." -ForegroundColor Green
        }
    }

    Write-Host "`n✅ Manual installation complete. Restart PowerShell before compiling C/C++." -ForegroundColor Cyan
}

Write-Host "`n=== Setup Finished ===" -ForegroundColor Cyan