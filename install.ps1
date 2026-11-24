#Requires -Version 5.1
<#
.SYNOPSIS
    Install the Graphify skill for OpenCode and its Python CLI.

.DESCRIPTION
    Downloads skills/graphify/skill.md from the official Graphify-Labs/graphify
    repository, adapts it for OpenCode, and writes it to the OpenCode global
    skills directory. If the graphify CLI is missing, installs the graphifyy
    package from PyPI with pip --user. Nothing is vendored or re-hosted by this
    project.

.PARAMETER SkillDir
    OpenCode skills root. Defaults to $env:OPENCODE_SKILLS_DIR, or
    ~/.config/opencode/skills.

.PARAMETER Ref
    Branch, tag, or commit of the upstream repository. Defaults to "main".

.PARAMETER Force
    Replace an existing installation. Without it, the installer leaves the
    current copy untouched.

.PARAMETER SkipCli
    Do not install or check the graphify Python CLI.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -Force -Ref main

.EXAMPLE
    .\install.ps1 -SkipCli -SkillDir C:\temp\opencode-skills
#>
[CmdletBinding()]
param(
    [string]$SkillDir,
    [string]$Ref = "main",
    [switch]$Force,
    [switch]$SkipCli
)

$ErrorActionPreference = "Stop"

if ($env:GRAPHIFY_REF -and -not $PSBoundParameters.ContainsKey("Ref")) {
    $Ref = $env:GRAPHIFY_REF
}
if ($env:GRAPHIFY_FORCE -eq "1") {
    $Force = $true
}
if ($env:GRAPHIFY_SKIP_CLI -eq "1") {
    $SkipCli = $true
}

$Repo = "Graphify-Labs/graphify"
$Name = "graphify"
$CliPackage = "graphifyy"

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "!!  $Message" -ForegroundColor Yellow
}

function Expand-TarGz([string]$Archive, [string]$Destination) {
    # Minimal tar extractor for the upstream archive. It keeps the Windows
    # installer dependency-free on PowerShell 5.1 (no tar.exe required).
    Add-Type -AssemblyName System.IO.Compression

    $TarPath = Join-Path $Destination "archive.tar"
    $Input = [System.IO.File]::OpenRead($Archive)
    try {
        $Gzip = New-Object System.IO.Compression.GZipStream($Input, [System.IO.Compression.CompressionMode]::Decompress)
        try {
            $Output = [System.IO.File]::Create($TarPath)
            try {
                $Gzip.CopyTo($Output)
            }
            finally {
                $Output.Dispose()
            }
        }
        finally {
            $Gzip.Dispose()
        }
    }
    finally {
        $Input.Dispose()
    }

    $Bytes = [System.IO.File]::ReadAllBytes($TarPath)
    $Position = 0
    $LongName = $null
    $PaxPath = $null

    while ($Position + 512 -le $Bytes.Length) {
        $Header = New-Object byte[] 512
        [Array]::Copy($Bytes, $Position, $Header, 0, 512)
        $Position += 512

        $AllZero = $true
        foreach ($Byte in $Header) {
            if ($Byte -ne 0) {
                $AllZero = $false
                break
            }
        }
        if ($AllZero) {
            break
        }

        $RawName = [System.Text.Encoding]::UTF8.GetString($Header, 0, 100).TrimEnd([char]0)
        $Prefix = [System.Text.Encoding]::UTF8.GetString($Header, 345, 155).TrimEnd([char]0)
        $SizeText = [System.Text.Encoding]::ASCII.GetString($Header, 124, 12).Trim([char]0).Trim()
        $Size = if ($SizeText) { [Convert]::ToInt64($SizeText, 8) } else { 0 }
        $Type = [char]$Header[156]
        $DataStart = $Position
        $Padded = [int]([Math]::Ceiling($Size / 512.0) * 512)

        if ($Type -eq "x" -or $Type -eq "g") {
            if ($Type -eq "x" -and $Size -gt 0) {
                $PaxText = [System.Text.Encoding]::UTF8.GetString($Bytes, $DataStart, [int]$Size)
                foreach ($Line in ($PaxText -split "`n")) {
                    if ($Line -match "^\d+ path=(.*)$") {
                        $PaxPath = $Matches[1]
                    }
                }
            }
            $Position = $DataStart + $Padded
            continue
        }

        if ($Type -eq "L") {
            $LongName = [System.Text.Encoding]::UTF8.GetString($Bytes, $DataStart, [int]$Size).TrimEnd([char]0)
            $Position = $DataStart + $Padded
            continue
        }

        $EntryName = if ($PaxPath) {
            $PaxPath
        }
        elseif ($LongName) {
            $LongName
        }
        elseif ($Prefix) {
            "$Prefix/$RawName"
        }
        else {
            $RawName
        }
        $PaxPath = $null
        $LongName = $null
        $Position = $DataStart + $Padded

        $Relative = $EntryName.Replace("\", "/").TrimStart("/")
        if (-not $Relative) {
            continue
        }
        if ($Relative -match "(^|/)\.\.(/|$)" -or $Relative -match "^[A-Za-z]:") {
            continue
        }

        $OutPath = Join-Path $Destination $Relative.Replace("/", [System.IO.Path]::DirectorySeparatorChar)

        if ($Type -eq "5" -or $EntryName.EndsWith("/")) {
            New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
            continue
        }

        if ($Type -eq "0" -or $Type -eq "7" -or $Type -eq [char]0) {
            $Parent = Split-Path -Parent $OutPath
            if ($Parent) {
                New-Item -ItemType Directory -Path $Parent -Force | Out-Null
            }
            $FileBytes = New-Object byte[] ([int]$Size)
            if ($Size -gt 0) {
                [Array]::Copy($Bytes, $DataStart, $FileBytes, 0, [int]$Size)
            }
            [System.IO.File]::WriteAllBytes($OutPath, $FileBytes)
        }
    }

    Remove-Item -LiteralPath $TarPath -Force -ErrorAction SilentlyContinue
}

function ConvertTo-OpenCodeSkill([string]$Text) {
    $Text = $Text.TrimStart([char]0xFEFF)
    $Text = $Text -replace "`r`n", "`n"

    $Body = $Text
    if ($Text.StartsWith("---`n")) {
        $Lines = $Text -split "`n"
        $End = -1
        for ($Index = 1; $Index -lt $Lines.Count; $Index++) {
            if ($Lines[$Index].Trim() -eq "---") {
                $End = $Index
                break
            }
        }
        if ($End -lt 0) {
            throw "The upstream skill.md has no closing frontmatter delimiter."
        }
        $Body = ($Lines[($End + 1)..($Lines.Count - 1)] -join "`n")
    }

    # Claude Code writes /graphify. OpenCode has no slash commands for skills,
    # so the canonical command form becomes `graphify <path> [flags]`.
    $Body = $Body -replace '(?m)^#\s+/graphify\s*$', '# graphify'
    $Body = $Body.Replace('/graphify', 'graphify')
    $Body = $Body -replace 'Claude vision', 'model vision'
    $Body = $Body -replace 'Claude alone', 'an LLM alone'
    $Body = $Body -replace '\(Claude, costs tokens\)', '(the model, costs tokens)'
    $Body = $Body -replace 'via Claude', 'via the model'
    $Body = $Body -replace 'here in Claude', 'here in OpenCode'
    $Body = $Body -replace 'Agent tool', 'task tool'
    $Body = $Body -replace '(?m)^#\s+graphify\s*\n', ''
    $Body = $Body.TrimStart("`n")

    $Header = @'
---
name: graphify
description: Turn any folder of code, docs, papers, or images into a knowledge graph with graph.html, graph.json, and GRAPH_REPORT.md. Use when the user asks to graph a folder, understand a codebase, or explore a research corpus.
---

# graphify

OpenCode adaptation. In OpenCode invoke this skill with @graphify or by asking to graph a folder; the CLI command is `graphify` (no leading slash).

Notes for OpenCode: the pipeline below runs inside your OpenCode session. Use the task tool where the upstream text says Agent tool, and on Windows use `python` where it says `python3`. Claude-specific integration sections are kept for reference only.

'@

    $Footer = @'

---

Upstream skill: https://github.com/Graphify-Labs/graphify/blob/main/skills/graphify/skill.md
MIT-declared upstream (main branch). This OpenCode adaptation is unofficial.
'@

    return ($Header + "`n" + $Body.TrimEnd() + "`n" + $Footer + "`n")
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

function Test-GraphifyModule([string]$Python) {
    if (-not $Python) {
        return $false
    }
    $OldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Python -c "import graphify" 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    finally {
        $ErrorActionPreference = $OldPreference
    }
}

function Get-UserScriptsDir([string]$Python) {
    if ($Python) {
        $OldPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $Dir = & $Python -c "import sysconfig; print(sysconfig.get_path('scripts', 'nt_user'))" 2>$null
            if ($LASTEXITCODE -eq 0 -and $Dir) {
                return $Dir.Trim()
            }
        }
        finally {
            $ErrorActionPreference = $OldPreference
        }
    }
    if ($env:APPDATA) {
        return (Join-Path $env:APPDATA "Python\Python3XX\Scripts")
    }
    return $null
}

function Show-PathHint([string]$Python) {
    $Scripts = Get-UserScriptsDir $Python
    if ($Scripts) {
        Write-Host "    Add the Python user Scripts folder to PATH if 'graphify' is not recognized:"
        Write-Host "      $Scripts"
    }
}

if (-not $SkillDir) {
    if ($env:OPENCODE_SKILLS_DIR) {
        $SkillDir = $env:OPENCODE_SKILLS_DIR
    }
    else {
        $HomeDir = if ($HOME) { $HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $null }
        if (-not $HomeDir) {
            throw "Could not find your home directory. Pass -SkillDir explicitly."
        }
        $SkillDir = Join-Path $HomeDir ".config\opencode\skills"
    }
}

$Target = Join-Path $SkillDir $Name

if ((Split-Path -Leaf $Target) -ne $Name) {
    throw "Refusing to install to an unexpected path: $Target"
}

$AlreadyInstalled = $false

if (Test-Path -LiteralPath $Target) {
    if (-not $Force) {
        Write-Warn "$Name is already installed at:"
        Write-Host "    $Target"
        Write-Host "    Re-run with -Force to update it."
        $AlreadyInstalled = $true
    }
    else {
        Write-Step "Removing the existing installation"
        Remove-Item -LiteralPath $Target -Recurse -Force
    }
}

$TempDir = $null
if (-not $AlreadyInstalled) {
    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("graphify-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

try {
    if ($AlreadyInstalled) {
        return
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    catch {
        # PowerShell 7 / .NET Core does not need (and may reject) this setting.
    }

    $Url = "https://codeload.github.com/$Repo/tar.gz/$Ref"
    $Archive = Join-Path $TempDir "skill.tar.gz"

    Write-Step "Downloading $Url"
    $OldProgress = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Archive -UseBasicParsing
    }
    finally {
        $ProgressPreference = $OldProgress
    }

    Write-Step "Extracting"
    Expand-TarGz -Archive $Archive -Destination $TempDir

    $SkillMd = Get-ChildItem -LiteralPath $TempDir -Recurse -File -Filter "skill.md" |
        Where-Object {
            $_.FullName -match "[\\/]skills[\\/]graphify[\\/]skill\.md$" -and
            ([System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)) -match "(?m)^name:[ \t]*$([regex]::Escape($Name))[ \t]*$"
        } |
        Select-Object -First 1

    if (-not $SkillMd) {
        throw "Could not find skills/graphify/skill.md in the downloaded archive. The upstream layout may have changed."
    }

    $SourceText = [System.IO.File]::ReadAllText($SkillMd.FullName, [System.Text.Encoding]::UTF8)
    if ($SourceText -notmatch "(?m)^description:[ \t]*\S") {
        throw "The upstream skill.md has no description, so OpenCode will not list the skill."
    }

    $Adapted = ConvertTo-OpenCodeSkill $SourceText

    if ($Adapted -notmatch "(?m)^name:[ \t]*$([regex]::Escape($Name))[ \t]*$") {
        throw "The adapted SKILL.md has an unexpected 'name' field."
    }
    if ($Adapted -notmatch "(?m)^description:[ \t]*\S") {
        throw "The adapted SKILL.md has no description."
    }
    if ($Adapted -notmatch "OpenCode adaptation") {
        throw "The adapted SKILL.md is missing the OpenCode adaptation note."
    }
    if ($Adapted -match "(?m)^[ \t]*/graphify([ \t]|$)") {
        throw "The adapted SKILL.md still contains a slash invocation."
    }

    Write-Step "Installing to $Target"
    New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    $TargetFile = Join-Path $Target "SKILL.md"
    [System.IO.File]::WriteAllText($TargetFile, $Adapted, (New-Object System.Text.UTF8Encoding($false)))

    if (-not (Test-Path -LiteralPath $TargetFile)) {
        throw "Installation is incomplete: SKILL.md was not written."
    }

    Write-Ok "Installed $TargetFile"
}
finally {
    if ($TempDir) {
        Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not $SkipCli) {
    $Python = Get-PythonCommand
    $Graphify = Get-Command graphify -ErrorAction SilentlyContinue

    if ($Graphify) {
        Write-Ok "graphify CLI found: $($Graphify.Source)"
    }
    elseif (Test-GraphifyModule $Python) {
        Write-Ok "graphify is installed as a Python module, but the console script is not on PATH."
        Show-PathHint $Python
    }
    elseif (-not $Python) {
        Write-Warn "Python was not found. The skill is installed, but the graphify CLI is missing."
        Write-Host "    Install Python 3.10+ and run: python -m pip install --user $CliPackage"
    }
    else {
        Write-Step "Installing the graphify CLI ($CliPackage)"
        & $Python -m pip install --user $CliPackage
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "pip could not install $CliPackage. The skill is still installed."
            Write-Host "    Install the CLI manually: $Python -m pip install --user $CliPackage"
        }
        else {
            Write-Ok "Installed the graphify CLI with pip."
        }
        Show-PathHint $Python
    }
}

Write-Host ""
Write-Host "Start a new OpenCode session and invoke the skill:" -ForegroundColor Green
Write-Host "  @graphify .                          # graph the current folder"
Write-Host "  @graphify ./src --mode deep          # deeper INFERRED edges"
Write-Host "  @graphify query `"what connects auth to the database?`""
Write-Host ""
Write-Host "The CLI command is 'graphify' when installed (no leading slash)."
Write-Host "Source and license: https://github.com/$Repo"
