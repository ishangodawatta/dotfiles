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
$AgentsDir = Join-Path $env:USERPROFILE ".agents"
$VaultClaude = Join-Path $ObsidianVault "projects\claude"

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
Link-Item -Source (Join-Path $VaultClaude "CLAUDE.md") -Dest (Join-Path $ClaudeDir "CLAUDE.md")
Link-Item -Source (Join-Path $VaultClaude "settings.json") -Dest (Join-Path $ClaudeDir "settings.json")
Link-Item -Source (Join-Path $VaultClaude "skills") -Dest (Join-Path $ClaudeDir "skills") -IsDir

# Claude Code project memory
$projects = @("pyfetto-mono", "chears-shadcn", "pyfetto-graphs", "learn")
foreach ($project in $projects) {
    $claudeProjectDir = Join-Path $ClaudeDir "projects\-Users-$env:USERNAME-src-$project"
    New-Item -ItemType Directory -Path $claudeProjectDir -Force | Out-Null
    $memorySource = Join-Path $VaultClaude "$project\memory"
    if (Test-Path $memorySource) {
        Link-Item -Source $memorySource -Dest (Join-Path $claudeProjectDir "memory") -IsDir
    }
}
# pyfetto-mono project-scoped CLAUDE.md
$pfClaudemd = Join-Path $VaultClaude "pyfetto-mono\CLAUDE.md"
if (Test-Path $pfClaudemd) {
    Link-Item -Source $pfClaudemd -Dest (Join-Path $ClaudeDir "projects\-Users-$env:USERNAME-src-pyfetto-mono\CLAUDE.md")
}

# Codex config
New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null
Link-Item -Source (Join-Path $VaultClaude "codex-config.toml") -Dest (Join-Path $CodexDir "config.toml")
Link-Item -Source (Join-Path $VaultClaude "CLAUDE.md") -Dest (Join-Path $CodexDir "AGENTS.md")

# Shared agent skills
New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null
Link-Item -Source (Join-Path $VaultClaude "skills") -Dest (Join-Path $AgentsDir "skills") -IsDir

# Claude Code plugins (install from manifest if claude CLI is available)
$PluginsFile = Join-Path $VaultClaude "plugins.txt"
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
