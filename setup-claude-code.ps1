# Claude Code & Codex Configuration Setup (PowerShell)
# Links ~/.claude and ~/.codex to the Obsidian vault

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ObsidianVault
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Validate vault path
if (-not (Test-Path (Join-Path $ObsidianVault "projects"))) {
    Write-Host "Error: $ObsidianVault/projects not found -- is this the right vault path?" -ForegroundColor Red
    exit 1
}

$SrcObsidian = Join-Path $env:USERPROFILE "src\obsidian"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$CodexDir = Join-Path $env:USERPROFILE ".codex"
$VaultAgents = Join-Path $ObsidianVault "projects\agents"

if (-not (Test-Path $VaultAgents -PathType Container)) {
    Write-Host "Error: $VaultAgents not found -- expected agent config in projects\agents" -ForegroundColor Red
    exit 1
}

function Link-Item {
    param([string]$Source, [string]$Dest, [switch]$IsDir)
    if ($IsDir) {
        if (-not (Test-Path $Source -PathType Container)) {
            Write-Host "  skip $(Split-Path $Dest -Leaf) (not found in vault)"
            return
        }
    } else {
        if (-not (Test-Path $Source -PathType Leaf)) {
            Write-Host "  skip $(Split-Path $Dest -Leaf) (not found in vault)"
            return
        }
    }
    if (Test-Path $Dest) {
        $item = Get-Item $Dest -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Remove-Item $Dest -Force
        } else {
            Move-Item $Dest "$Dest.bak" -Force
            Write-Host "  backup $Dest -> $Dest.bak"
        }
    }
    New-Item -ItemType SymbolicLink -Path $Dest -Target $Source | Out-Null
    Write-Host "  link $Dest"
}

Write-Host "Linking Claude Code and Codex configuration..." -ForegroundColor Cyan
Write-Host ""

# Obsidian vault symlink
Link-Item -Source $ObsidianVault -Dest $SrcObsidian -IsDir

# Claude Code config
New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
Link-Item -Source (Join-Path $VaultAgents "AGENTS.md") -Dest (Join-Path $ClaudeDir "CLAUDE.md")
Link-Item -Source (Join-Path $VaultAgents "settings.json") -Dest (Join-Path $ClaudeDir "settings.json")
Link-Item -Source (Join-Path $VaultAgents "skills") -Dest (Join-Path $ClaudeDir "skills") -IsDir

# Claude Code project memory + project-scoped instructions.
foreach ($projectDir in Get-ChildItem -Path $VaultAgents -Directory) {
    $project = $projectDir.Name
    $projectPath = $projectDir.FullName
    if ($project -eq "skills" -or $project -eq "src" -or $project.StartsWith(".")) {
        continue
    }

    $memorySource = Join-Path $projectPath "memory"
    if (-not (Test-Path $memorySource -PathType Container)) {
        continue
    }

    $projectRootFile = Join-Path $projectPath ".project-root"
    if (Test-Path $projectRootFile -PathType Leaf) {
        $actualProjectRoot = (Get-Content $projectRootFile -Raw).Trim()
        $claudeKey = $actualProjectRoot -replace "[^a-zA-Z0-9-]", "-"
    } else {
        $claudeKey = "-Users-$env:USERNAME-src-$project"
    }

    $claudeProjectDir = Join-Path $ClaudeDir "projects\$claudeKey"
    New-Item -ItemType Directory -Path $claudeProjectDir -Force | Out-Null
    Link-Item -Source $memorySource -Dest (Join-Path $claudeProjectDir "memory") -IsDir

    $projectAgents = Join-Path $projectPath "AGENTS.md"
    if (Test-Path $projectAgents -PathType Leaf) {
        Link-Item -Source $projectAgents -Dest (Join-Path $claudeProjectDir "CLAUDE.md")
    }
}

# Codex config
New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null
Link-Item -Source (Join-Path $VaultAgents "codex-config.toml") -Dest (Join-Path $CodexDir "config.toml")
Link-Item -Source (Join-Path $VaultAgents "AGENTS.md") -Dest (Join-Path $CodexDir "AGENTS.md")
Link-Item -Source (Join-Path $VaultAgents "skills") -Dest (Join-Path $CodexDir "skills") -IsDir

# Claude Code plugins (install from manifest if claude CLI is available)
$PluginsFile = Join-Path $VaultAgents "plugins.txt"
if ((Get-Command "claude" -ErrorAction SilentlyContinue) -and (Test-Path $PluginsFile)) {
    Write-Host ""
    Write-Host "Installing Claude Code plugins..." -ForegroundColor Cyan
    Get-Content $PluginsFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -match "^#" -or [string]::IsNullOrEmpty($line)) { return }
        if ($line -match "^marketplace\s+(.+)$") {
            claude plugin marketplace add $Matches[1] 2>$null
        } elseif ($line -match "^plugin\s+(.+)$") {
            claude plugin install $Matches[1] --scope user 2>$null
        }
    }
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
