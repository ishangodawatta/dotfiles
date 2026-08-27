#Requires -RunAsAdministrator
# Windows Setup Script - Equivalent to setup-macos.sh
# Run this script as Administrator in PowerShell

param(
    [switch]$Force = $false
)

# Set strict mode and stop on errors
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "[*] Starting Windows setup..." -ForegroundColor Green

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[X] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "[!] Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Function to prompt for yes/no
function Prompt-YesNo {
    param([string]$Prompt)
    do {
        # Flush any buffered input before prompting
        if ($Host.UI.RawUI.KeyAvailable) {
            $Host.UI.RawUI.FlushInputBuffer()
        }

        # Small delay to ensure console is ready
        Start-Sleep -Milliseconds 100

        $response = Read-Host "$Prompt (y/n)"
        $response = $response.ToLower()
        if ($response -eq 'y' -or $response -eq 'yes') {
            return $true
        } elseif ($response -eq 'n' -or $response -eq 'no') {
            return $false
        } else {
            Write-Host "Please answer y or n." -ForegroundColor Yellow
        }
    } while ($true)
}

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Function to check if a winget package is installed
function Test-WingetPackage {
    param([string]$PackageId)
    try {
        $result = winget list --id $PackageId -e 2>$null
        return $result -match $PackageId
    } catch {
        return $false
    }
}

Write-Host ""
Write-Host "[*] Let's configure what to install..." -ForegroundColor Cyan
Write-Host ""

# Initialize installation flags
$INSTALL_WINGET = $false
$INSTALL_GIT = $false
$INSTALL_UV = $false
$INSTALL_GITFILTER_REPO = $false
$INSTALL_BRAVE = $false
$INSTALL_VSCODE = $false
$INSTALL_NVM = $false
$INSTALL_NODE = $false
$INSTALL_CLAUDE_CODE = $false
$INSTALL_PYENV = $false
$INSTALL_PYTHON = $false
$INSTALL_FLUX = $false
$INSTALL_CLIPCLIP = $false
$INSTALL_GOOGLE_CHROME = $false
$INSTALL_TAILSCALE = $false
$INSTALL_GOOGLE_DRIVE = $false
$INSTALL_QBITTORRENT = $false
$INSTALL_OBSIDIAN = $false
$INSTALL_LOGI_OPTIONS = $false
$INSTALL_CONDA = $false
$PYTHON_VERSION = ""

# Check Winget
if (-not (Test-Command "winget")) {
    Write-Host "[!] Winget not found. It should be available on Windows 10 1809+ and Windows 11" -ForegroundColor Yellow
    if (Prompt-YesNo "[PKG] Try to install/update Winget via Microsoft Store?") {
        $INSTALL_WINGET = $true
    }
} else {
    Write-Host "[OK] Winget already installed" -ForegroundColor Green
}

# Check Git
if (-not (Test-Command "git")) {
    if (Prompt-YesNo "[GIT] Install Git for Windows?") {
        $INSTALL_GIT = $true
    }
} else {
    Write-Host "[OK] Git already installed" -ForegroundColor Green
}

# Check git-filter-repo
if (-not (Test-Command "git-filter-repo")) {
    if (Prompt-YesNo "[CLN] Install git-filter-repo?") {
        $INSTALL_GITFILTER_REPO = $true
    }
} else {
    Write-Host "[OK] git-filter-repo already installed" -ForegroundColor Green
}

# Check conda/Anaconda
if (-not (Test-Command "conda")) {
    if (Prompt-YesNo "[CONDA] Install Anaconda3 (includes conda, Python, and data science tools)?") {
        $INSTALL_CONDA = $true
    }
} else {
    Write-Host "[OK] Conda already installed" -ForegroundColor Green
}

# Check pyenv-win
if (-not (Test-Command "pyenv")) {
    if (Prompt-YesNo "[PY] Install pyenv-win (Python version manager)?") {
        $INSTALL_PYENV = $true
        if (Prompt-YesNo "   Install Python via pyenv?") {
            $INSTALL_PYTHON = $true
            $PYTHON_VERSION = Read-Host "   Enter Python version (e.g., 3.13.0)"
        }
    }
} else {
    Write-Host "[OK] pyenv-win already installed" -ForegroundColor Green
    # Check if Python is configured
    try {
        $currentPython = pyenv global 2>$null
        if (-not $currentPython -or $currentPython -eq "system") {
            if (Prompt-YesNo "[PY] Install Python via pyenv?") {
                $INSTALL_PYTHON = $true
                $PYTHON_VERSION = Read-Host "   Enter Python version (e.g., 3.13.0)"
            }
        } else {
            Write-Host "[OK] Python already configured via pyenv: $currentPython" -ForegroundColor Green
        }
    } catch {
        if (Prompt-YesNo "[PY] Install Python via pyenv?") {
            $INSTALL_PYTHON = $true
            $PYTHON_VERSION = Read-Host "   Enter Python version (e.g., 3.13.0)"
        }
    }
}

# Check UV
if (-not (Test-Command "uv")) {
    if (Prompt-YesNo "[PY] Install UV (Python package manager)?") {
        $INSTALL_UV = $true
    }
} else {
    Write-Host "[OK] UV already installed" -ForegroundColor Green
}

# Check NVM for Windows
if (-not (Test-Command "nvm")) {
    if (Prompt-YesNo "[PKG] Install NVM for Windows (Node Version Manager)?") {
        $INSTALL_NVM = $true
        if (Prompt-YesNo "   Install Node.js LTS via NVM?") {
            $INSTALL_NODE = $true
        }
    }
} else {
    Write-Host "[OK] NVM for Windows already installed" -ForegroundColor Green
    if (-not (Test-Command "node")) {
        if (Prompt-YesNo "[PKG] Install Node.js LTS via NVM?") {
            $INSTALL_NODE = $true
        }
    } else {
        Write-Host "[OK] Node.js already installed" -ForegroundColor Green
    }
}

# Check Claude Code CLI
if (-not (Test-Command "claude")) {
    if (Prompt-YesNo "[AI] Install Claude Code CLI (Anthropic)?") {
        $INSTALL_CLAUDE_CODE = $true
    }
} else {
    Write-Host "[OK] Claude Code CLI already installed" -ForegroundColor Green
}

# Check applications
if (-not (Test-WingetPackage "Brave.Brave")) {
    if (Prompt-YesNo "[BRAVE] Install Brave Browser?") {
        $INSTALL_BRAVE = $true
    }
} else {
    Write-Host "[OK] Brave Browser already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "flux.flux")) {
    if (Prompt-YesNo "[FLUX] Install f.lux (multi-monitor brightness/color control)?") {
        $INSTALL_FLUX = $true
    }
} else {
    Write-Host "[OK] f.lux already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Vitzo.ClipClip")) {
    if (Prompt-YesNo "[CLIP] Install ClipClip (clipboard manager)?") {
        $INSTALL_CLIPCLIP = $true
    }
} else {
    Write-Host "[OK] ClipClip already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Google.Chrome")) {
    if (Prompt-YesNo "[CHROME] Install Google Chrome?") {
        $INSTALL_GOOGLE_CHROME = $true
    }
} else {
    Write-Host "[OK] Google Chrome already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "tailscale.tailscale")) {
    if (Prompt-YesNo "[TAIL] Install Tailscale (mesh VPN)?") {
        $INSTALL_TAILSCALE = $true
    }
} else {
    Write-Host "[OK] Tailscale already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Google.GoogleDrive")) {
    if (Prompt-YesNo "[DRIVE] Install Google Drive?") {
        $INSTALL_GOOGLE_DRIVE = $true
    }
} else {
    Write-Host "[OK] Google Drive already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "qBittorrent.qBittorrent")) {
    if (Prompt-YesNo "[QBIT] Install qBittorrent (BitTorrent client)?") {
        $INSTALL_QBITTORRENT = $true
    }
} else {
    Write-Host "[OK] qBittorrent already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Obsidian.Obsidian")) {
    if (Prompt-YesNo "[OBS] Install Obsidian (note-taking app)?") {
        $INSTALL_OBSIDIAN = $true
    }
} else {
    Write-Host "[OK] Obsidian already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Logitech.OptionsPlus")) {
    if (Prompt-YesNo "[LOGI] Install Logi Options+ (Logitech device manager)?") {
        $INSTALL_LOGI_OPTIONS = $true
    }
} else {
    Write-Host "[OK] Logi Options+ already installed" -ForegroundColor Green
}

if (-not (Test-WingetPackage "Microsoft.VisualStudioCode")) {
    if (Prompt-YesNo "[CODE] Install Visual Studio Code?") {
        $INSTALL_VSCODE = $true
    }
} else {
    Write-Host "[OK] Visual Studio Code already installed" -ForegroundColor Green
}


Write-Host ""
Write-Host "[*] Starting installation based on your choices..." -ForegroundColor Cyan
Write-Host ""

# Install Winget (if needed)
if ($INSTALL_WINGET) {
    Write-Host "[PKG] Winget installation required..." -ForegroundColor Yellow
    Write-Host "[!] Please install 'App Installer' from Microsoft Store to get Winget" -ForegroundColor Yellow
    Write-Host "[!] Visit: https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ForegroundColor Cyan
    Write-Host "[!] After installation, run this script again" -ForegroundColor Yellow
    exit 0
}

# Install Git
if ($INSTALL_GIT) {
    Write-Host "[GIT] Installing Git..." -ForegroundColor Yellow
    winget install -e --id Git.Git --source winget
    Write-Host "[OK] Git installed" -ForegroundColor Green
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# Install UV
if ($INSTALL_UV) {
    Write-Host "[PY] Installing UV..." -ForegroundColor Yellow
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    Write-Host "[OK] UV installed" -ForegroundColor Green
}

# Install Anaconda3
if ($INSTALL_CONDA) {
    Write-Host "[CONDA] Installing Anaconda3..." -ForegroundColor Yellow
    winget install -e --id Anaconda.Anaconda3 --source winget

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Initialize conda for all shells
    Write-Host "[CONDA] Initializing conda..." -ForegroundColor Yellow
    $condaPath = "$env:USERPROFILE\anaconda3\Scripts\conda.exe"
    if (Test-Path $condaPath) {
        & $condaPath init
        Write-Host "[OK] Anaconda3 installed and initialized" -ForegroundColor Green
        Write-Host "[!] Please restart your terminal to use conda" -ForegroundColor Yellow
    } else {
        Write-Host "[!] Anaconda3 installed but conda.exe not found at expected location" -ForegroundColor Yellow
        Write-Host "[!] You may need to manually run: conda init" -ForegroundColor Yellow
    }
}

# Install git-filter-repo via pip
if ($INSTALL_GITFILTER_REPO) {
    Write-Host "[CLN] Installing git-filter-repo..." -ForegroundColor Yellow
    if (Test-Command "pip") {
        pip install git-filter-repo
        Write-Host "[OK] git-filter-repo installed" -ForegroundColor Green
    } else {
        Write-Host "[!] pip not found. Install Python first, then run: pip install git-filter-repo" -ForegroundColor Yellow
    }
}

# Install pyenv-win
if ($INSTALL_PYENV) {
    Write-Host "[PY] Installing pyenv-win..." -ForegroundColor Yellow
    if (Test-Command "choco") {
        choco install pyenv-win -y

        # Refresh PATH for current session
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        Write-Host "[OK] pyenv-win installed" -ForegroundColor Green
    } else {
        Write-Host "[X] Chocolatey is required to install pyenv-win" -ForegroundColor Red
        Write-Host "[!] Install Chocolatey from https://chocolatey.org/install" -ForegroundColor Yellow
    }
}

# Install Python via pyenv
if ($INSTALL_PYTHON -and $PYTHON_VERSION) {
    Write-Host "[PY] Installing Python $PYTHON_VERSION via pyenv..." -ForegroundColor Yellow
    # Ensure pyenv is in PATH
    $env:Path = "$env:USERPROFILE\.pyenv\pyenv-win\bin;$env:USERPROFILE\.pyenv\pyenv-win\shims;" + $env:Path

    pyenv install $PYTHON_VERSION
    pyenv global $PYTHON_VERSION

    Write-Host "[OK] Python installed: $(python --version)" -ForegroundColor Green
}

# Install NVM for Windows
if ($INSTALL_NVM) {
    Write-Host "[PKG] Installing NVM for Windows..." -ForegroundColor Yellow
    winget install -e --id CoreyButler.NVMforWindows --source winget
    Write-Host "[OK] NVM for Windows installed" -ForegroundColor Green
    Write-Host "[!] Please restart your terminal to use NVM" -ForegroundColor Yellow
}

# Install Node.js via NVM (Note: This requires a restart)
if ($INSTALL_NODE) {
    Write-Host "[PKG] Node.js installation via NVM requires terminal restart..." -ForegroundColor Yellow
    Write-Host "After restart, run: nvm install lts && nvm use lts" -ForegroundColor Cyan
}

# Install Claude Code CLI
if ($INSTALL_CLAUDE_CODE) {
    Write-Host "[AI] Installing Claude Code CLI..." -ForegroundColor Yellow
    try {
        irm https://claude.ai/install.ps1 | iex
        Write-Host "[OK] Claude Code CLI installed" -ForegroundColor Green
    } catch {
        Write-Host "[X] Claude Code CLI installation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}


# Install applications via Winget
$apps = @(
    @{Flag = $INSTALL_BRAVE; Name = "Brave Browser"; Id = "Brave.Brave"; Emoji = "[BRAVE]"},
    @{Flag = $INSTALL_FLUX; Name = "f.lux"; Id = "flux.flux"; Emoji = "[FLUX]"},
    @{Flag = $INSTALL_CLIPCLIP; Name = "ClipClip"; Id = "Vitzo.ClipClip"; Emoji = "[CLIP]"},
    @{Flag = $INSTALL_GOOGLE_CHROME; Name = "Google Chrome"; Id = "Google.Chrome"; Emoji = "[CHROME]"},
    @{Flag = $INSTALL_TAILSCALE; Name = "Tailscale"; Id = "tailscale.tailscale"; Emoji = "[TAIL]"},
    @{Flag = $INSTALL_GOOGLE_DRIVE; Name = "Google Drive"; Id = "Google.GoogleDrive"; Emoji = "[DRIVE]"},
    @{Flag = $INSTALL_QBITTORRENT; Name = "qBittorrent"; Id = "qBittorrent.qBittorrent"; Emoji = "[QBIT]"},
    @{Flag = $INSTALL_OBSIDIAN; Name = "Obsidian"; Id = "Obsidian.Obsidian"; Emoji = "[OBS]"},
    @{Flag = $INSTALL_LOGI_OPTIONS; Name = "Logi Options+"; Id = "Logitech.OptionsPlus"; Emoji = "[LOGI]"},
    @{Flag = $INSTALL_VSCODE; Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode"; Emoji = "[CODE]"}
)

foreach ($app in $apps) {
    if ($app.Flag) {
        Write-Host "$($app.Emoji) Installing $($app.Name)..." -ForegroundColor Yellow
        $result = winget install -e --id $($app.Id) 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $($app.Name) installed" -ForegroundColor Green
        } else {
            Write-Host "[!] $($app.Name) installation had issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
            if ($result -match "administrator context") {
                Write-Host "    Note: $($app.Name) cannot be installed in administrator mode" -ForegroundColor Yellow
            }
        }
    }
}

# Verify installations
Write-Host ""
Write-Host "[?] Current installation status:" -ForegroundColor Cyan

if (Test-Command "winget") { Write-Host "[OK] Winget: $((winget --version).Trim())" -ForegroundColor Green }
if (Test-Command "git") { Write-Host "[OK] Git: $((git --version).Trim())" -ForegroundColor Green }
if (Test-Command "uv") { Write-Host "[OK] UV: $((uv --version).Trim())" -ForegroundColor Green }
if (Test-Command "git-filter-repo") { Write-Host "[OK] git-filter-repo: Available" -ForegroundColor Green }

# Check conda
if (Test-Command "conda") {
    try {
        $condaVersion = conda --version 2>$null
        if ($condaVersion) { Write-Host "[OK] Conda: $condaVersion" -ForegroundColor Green }
    } catch {}
}

# Check pyenv/Python
if (Test-Command "pyenv") {
    Write-Host "[OK] pyenv-win: Available" -ForegroundColor Green
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion) { Write-Host "[OK] Python: $pythonVersion" -ForegroundColor Green }
    } catch {}
}

# Check NVM/Node/npm
if (Test-Command "nvm") { Write-Host "[OK] NVM: Available" -ForegroundColor Green }
if (Test-Command "node") { Write-Host "[OK] Node.js: $((node --version).Trim())" -ForegroundColor Green }
if (Test-Command "npm") { Write-Host "[OK] npm: $((npm --version).Trim())" -ForegroundColor Green }
if (Test-Command "claude") {
    try {
        $claudeVersion = claude --version 2>$null
        if ($claudeVersion) { Write-Host "[OK] Claude Code CLI: $claudeVersion" -ForegroundColor Green }
    } catch {}
}

# Check installed applications
foreach ($app in $apps) {
    if (Test-WingetPackage $app.Id) {
        Write-Host "[OK] $($app.Name): Installed" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[DONE] Windows setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "[OBS] Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart your terminal to ensure all PATH changes take effect" -ForegroundColor White
Write-Host "2. Configure git if not already done:" -ForegroundColor White
Write-Host "3. If you installed conda, restart terminal and verify with: conda --version" -ForegroundColor White
Write-Host "4. If you installed NVM, run: nvm install lts && nvm use lts" -ForegroundColor White
Write-Host "5. Open VS Code and install your preferred extensions" -ForegroundColor White
Write-Host "6. Configure f.lux for your monitor brightness preferences" -ForegroundColor White
