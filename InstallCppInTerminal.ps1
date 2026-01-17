Write-Host "=== Universal VS Code + MSYS2 + Code Runner Setup ===" -ForegroundColor Cyan

# ---------------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------------

function Exists($cmd) {
    Get-Command $cmd -ErrorAction SilentlyContinue | Out-Null
    return $?
}

# Reloads environment variables from the registry into the current session
# This allows us to use 'code' and 'gcc' immediately after installing them.
function Refresh-Env {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Edits VS Code settings.json to enable "Run in Terminal"
function Enable-RunInTerminal {
    Write-Host "Configuring Code Runner to run in Terminal..." -ForegroundColor Yellow
    
    $settingsPath = "$env:APPDATA\Code\User\settings.json"
    $settingsDir = Split-Path $settingsPath

    # Create file if it doesn't exist
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null }
    if (-not (Test-Path $settingsPath)) { Set-Content -Path $settingsPath -Value "{}" }

    # Read and parse JSON
    try {
        $jsonContent = Get-Content $settingsPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($jsonContent)) { $jsonContent = "{}" }
        $jsonObj = $jsonContent | ConvertFrom-Json
    } catch {
        $jsonObj = @{}
    }

    # Add/Update settings
    # 1. Run in Terminal (Required for input)
    $jsonObj | Add-Member -Name "code-runner.runInTerminal" -Value $true -MemberType NoteProperty -Force
    # 2. Save before run (Prevents running old code)
    $jsonObj | Add-Member -Name "code-runner.saveFileBeforeRun" -Value $true -MemberType NoteProperty -Force
    # 3. Clear previous output (Cleaner interface)
    $jsonObj | Add-Member -Name "code-runner.clearPreviousOutput" -Value $true -MemberType NoteProperty -Force

    # Save back to file
    $jsonObj | ConvertTo-Json -Depth 100 | Set-Content $settingsPath
    Write-Host "✔ VS Code settings updated." -ForegroundColor Green
}

# ---------------------------------------------------------
# MAIN LOGIC
# ---------------------------------------------------------

if (Exists winget) {
    # ============================
    # OPTION A: WINGET INSTALL
    # ============================
    Write-Host "`nWinget detected! Using Winget for installation..." -ForegroundColor Green

    # 1. Install VS Code
    Write-Host "[1/5] Installing VS Code via Winget..." -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements

    # 2. Install MSYS2
    Write-Host "[2/5] Installing MSYS2 via Winget..." -ForegroundColor Yellow
    winget install --id MSYS2.MSYS2 -e --silent --accept-package-agreements --accept-source-agreements

    # Wait for MSYS2 filesystem to initialize
    Start-Sleep -Seconds 10
    
    # 3. Install GCC/G++ Toolchain (Critical Step)
    Write-Host "[3/5] Downloading GCC/G++ Toolchain..." -ForegroundColor Yellow
    $bash = "C:\msys64\usr\bin\bash.exe"
    if (Test-Path $bash) {
        & $bash -lc "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc"
    } else {
        Write-Host "Error: MSYS2 bash not found at $bash" -ForegroundColor Red
    }

    # 4. Add MSYS2 mingw64/bin to user PATH
    $mingwBin="C:\msys64\mingw64\bin"
    $userPath=[Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$mingwBin*") {
        [Environment]::SetEnvironmentVariable("Path","$userPath;$mingwBin","User")
        Write-Host "✔ MSYS2 compiler added to PATH." -ForegroundColor Green
    }

    # Refresh Env so we can find 'code' command
    Refresh-Env

    # 5. Install Extensions & Config
    if (Exists code) {
        Write-Host "[4/5] Installing Extensions..." -ForegroundColor Yellow
        $extensions = code --list-extensions
        if ($extensions -contains "formulahendry.code-runner") {
            Write-Host "✔ Code Runner already installed." -ForegroundColor Green
        } else {
            code --install-extension formulahendry.code-runner
            Write-Host "✔ Code Runner installed." -ForegroundColor Green
        }
        
        # Apply the setting change
        Enable-RunInTerminal
    } else {
        Write-Host "⚠ Could not find 'code' command. Restart terminal and run 'code --install-extension formulahendry.code-runner' manually." -ForegroundColor Magenta
    }

    Write-Host "`n✅ Winget installation complete. Restart PowerShell to use GCC/G++." -ForegroundColor Cyan

} else {
    # ============================
    # OPTION B: MANUAL FALLBACK
    # ============================
    Write-Host "`n⚠ Winget not found! Falling back to manual installation..." -ForegroundColor Red

    # 1. VS Code
    Write-Host "[1/5] Checking VS Code..." -ForegroundColor Yellow
    $vsCodeExe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
    if (Test-Path $vsCodeExe) {
        Write-Host "✔ VS Code already installed." -ForegroundColor Green
    } else {
        Write-Host "Downloading VS Code..." -ForegroundColor Cyan
        $vscode = "$env:TEMP\vscode.exe"
        Invoke-WebRequest "https://update.code.visualstudio.com/latest/win32-x64-user/stable" -OutFile $vscode
        Start-Process $vscode -ArgumentList "/silent","/mergetasks=!runcode" -Wait
        Write-Host "✔ VS Code installed." -ForegroundColor Green
    }
    
    # Temporarily add VS Code to current session PATH
    $env:Path += ";$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin"

    # 2. MSYS2
    Write-Host "[2/5] Checking MSYS2..." -ForegroundColor Yellow
    $msysPath = "C:\msys64"
    if (Test-Path "$msysPath\mingw64\bin\gcc.exe") {
        Write-Host "✔ MSYS2 already installed." -ForegroundColor Green
    } else {
        Write-Host "Downloading MSYS2..." -ForegroundColor Cyan
        $msysInstaller = "$env:TEMP\msys2.exe"
        Invoke-WebRequest "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe" -OutFile $msysInstaller
        Start-Process $msysInstaller -ArgumentList "--confirm-command","--accept-messages","--root","C:\msys64" -Wait
        Write-Host "✔ MSYS2 installed." -ForegroundColor Green
    }

    # 3. Install GCC/G++
    Write-Host "[3/5] Installing GCC & G++..." -ForegroundColor Yellow
    $bash = "C:\msys64\usr\bin\bash.exe"
    if (Test-Path $bash) {
         & $bash -lc "pacman -S --needed --noconfirm mingw-w64-x86_64-gcc"
    }

    # 4. PATH Setup
    Write-Host "[4/5] Updating PATH..." -ForegroundColor Yellow
    $mingwBin = "C:\msys64\mingw64\bin"
    $userPath = [Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$mingwBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$mingwBin", "User")
        Write-Host "✔ Compiler added to PATH." -ForegroundColor Green
    }

    # 5. Extensions & Config
    Write-Host "[5/5] Configuring VS Code..." -ForegroundColor Yellow
    if (Exists code) {
        $extensions = code --list-extensions
        if ($extensions -contains "formulahendry.code-runner") {
            Write-Host "✔ Code Runner already installed." -ForegroundColor Green
        } else {
            code --install-extension formulahendry.code-runner
            Write-Host "✔ Code Runner installed." -ForegroundColor Green
        }
        
        # Apply the setting change
        Enable-RunInTerminal
    } else {
         Write-Host "⚠ VS Code command not found in current session. Restart and install extensions manually." -ForegroundColor Yellow
    }

    Write-Host "`n✅ Manual installation complete. Restart PowerShell before compiling C/C++." -ForegroundColor Cyan
}

Write-Host "`n=== Setup Finished ===" -ForegroundColor Cyan