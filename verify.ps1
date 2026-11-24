#Requires -Version 5.1
<#
.SYNOPSIS
    Check that the Graphify skill and its CLI are installed for OpenCode.

.DESCRIPTION
    Validates SKILL.md (name, description, OpenCode adaptation) and probes the
    graphify CLI. Recent graphifyy releases support `graphify --version`; older
    ones do not, so the verifier falls back to `graphify --help` and the
    installed package metadata.

.PARAMETER SkillDir
    OpenCode skills root. Defaults to $env:OPENCODE_SKILLS_DIR, or
    ~/.config/opencode/skills.

.PARAMETER RequireCli
    Fail when the graphify CLI is missing. Without it, a missing CLI only warns.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\verify.ps1

.EXAMPLE
    .\verify.ps1 -SkillDir C:\temp\opencode-skills -RequireCli
#>
[CmdletBinding()]
param(
    [string]$SkillDir,
    [switch]$RequireCli
)

$ErrorActionPreference = "Stop"

$Name = "graphify"

function Write-Fail([string]$Message) {
    Write-Host "FAIL  $Message" -ForegroundColor Red
}

function Get-PythonCommand {
    foreach ($Candidate in @("python", "py")) {
        $Command = Get-Command $Candidate -ErrorAction SilentlyContinue
        if ($Command) {
            return $Candidate
        }
    }
    return $null
}

function Get-PackageVersion([string]$Python) {
    if (-not $Python) {
        return $null
    }
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Version = & $Python -c "import importlib.metadata as m; print(m.version('graphifyy'))" 2>$null
        if ($LASTEXITCODE -eq 0 -and $Version) {
            return $Version.Trim()
        }
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }
    return $null
}

function Invoke-GraphifyProbe([string]$Python, [string]$PackageVersion) {
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $OldNative = $null
    try {
        $OldNative = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }
    catch {
        # Windows PowerShell 5.1 does not have this preference.
    }

    try {
        if (Get-Command graphify -ErrorAction SilentlyContinue) {
            $Version = & graphify --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $Version) {
                return ($Version | Select-Object -First 1).Trim()
            }
            & graphify --help 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                if ($PackageVersion) {
                    return "graphify (graphifyy $PackageVersion; no --version output)"
                }
                return "graphify (version output not supported)"
            }
        }

        if ($Python) {
            $Version = & $Python -m graphify --version 2>$null
            if ($LASTEXITCODE -eq 0 -and $Version) {
                return (($Version | Select-Object -First 1).Trim() + " (python -m graphify)")
            }
            & $Python -m graphify --help 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                if ($PackageVersion) {
                    return "graphifyy $PackageVersion (python -m graphify)"
                }
                return "python -m graphify (version output not supported)"
            }
        }
    }
    finally {
        try {
            $PSNativeCommandUseErrorActionPreference = $OldNative
        }
        catch {
            # Ignore: the preference does not exist on Windows PowerShell 5.1.
        }
        $ErrorActionPreference = $OldPreference
    }

    return $null
}

if (-not $SkillDir) {
    if ($env:OPENCODE_SKILLS_DIR) {
        $SkillDir = $env:OPENCODE_SKILLS_DIR
    }
    else {
        $HomeDir = if ($HOME) { $HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $null }
        if (-not $HomeDir) {
            Write-Fail "Could not find your home directory. Pass -SkillDir explicitly."
            exit 1
        }
        $SkillDir = Join-Path $HomeDir ".config\opencode\skills"
    }
}

$Target = Join-Path $SkillDir $Name
$SkillFile = Join-Path $Target "SKILL.md"

if (-not (Test-Path -LiteralPath $SkillFile)) {
    Write-Fail "$Name is not installed at $Target"
    Write-Host "      Run install.ps1 first." -ForegroundColor Yellow
    exit 1
}

$SkillText = [System.IO.File]::ReadAllText($SkillFile, [System.Text.Encoding]::UTF8)

if ($SkillText -notmatch "(?m)^name:[ \t]*$([regex]::Escape($Name))[ \t]*$") {
    Write-Fail "SKILL.md has an unexpected 'name' field."
    exit 1
}

if ($SkillText -notmatch "(?m)^description:[ \t]*\S") {
    Write-Fail "SKILL.md has no description, so OpenCode will not list the skill."
    exit 1
}

if ($SkillText -notmatch "OpenCode adaptation") {
    Write-Fail "SKILL.md is missing the OpenCode adaptation note."
    exit 1
}

if ($SkillText -notmatch "@graphify") {
    Write-Fail "SKILL.md does not document the @graphify invocation."
    exit 1
}

if ($SkillText -match "(?m)^[ \t]*/graphify([ \t]|$)") {
    Write-Fail "SKILL.md still contains a slash invocation (/graphify)."
    exit 1
}

$FileCount = (Get-ChildItem -LiteralPath $Target -Recurse -File).Count
Write-Host "OK  $Name is installed at $Target ($FileCount files)." -ForegroundColor Green

$Python = Get-PythonCommand
$PackageVersion = Get-PackageVersion $Python
$Cli = Invoke-GraphifyProbe $Python $PackageVersion

if ($Cli) {
    Write-Host "OK  graphify CLI: $Cli" -ForegroundColor Green
    exit 0
}
elseif ($RequireCli) {
    Write-Fail "The graphify CLI was not found."
    Write-Host "      Install it with: python -m pip install --user graphifyy" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "WARN The graphify CLI was not found. The skill is installed and will prompt you if needed." -ForegroundColor Yellow
    Write-Host "      Install it with: python -m pip install --user graphifyy" -ForegroundColor Yellow
    exit 0
}
