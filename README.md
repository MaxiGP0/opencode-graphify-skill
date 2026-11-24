# opencode-graphify-skill

[![CI](https://github.com/MaxiGP0/opencode-graphify-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/MaxiGP0/opencode-graphify-skill/actions/workflows/ci.yml)

[English](README.md) | [Español](README.es.md)

One-command installer that makes the **[Graphify](https://github.com/Graphify-Labs/graphify)** skill available in [OpenCode](https://opencode.ai) and installs its Python CLI.

The upstream skill documents Claude Code and the `/graphify` slash command. OpenCode reads global skills from `~/.config/opencode/skills/<name>/`, so this repository downloads `skills/graphify/skill.md` at install time, rewrites its frontmatter and command form for OpenCode, and writes `<skills-root>/graphify/SKILL.md`. If the `graphify` CLI is missing, it runs `pip install --user graphifyy`. Nothing is vendored or re-hosted.

> This is an unofficial installer. It is not affiliated with Graphify Labs.

Upstream's current default branch (`v8`) has native OpenCode support and a different, multi-file skill layout. This installer intentionally follows `main`, which still ships the standalone `skills/graphify/skill.md` that this project adapts.

## What the skill does

Graphify turns any folder of code, docs, papers, or images into a persistent, queryable knowledge graph:

- **`graph.html`** - an interactive graph you can open in any browser.
- **`graph.json`** - the GraphRAG-ready graph that survives across sessions.
- **`GRAPH_REPORT.md`** - god nodes, community structure, surprising connections, suggested questions, and a token-cost audit.
- **Optional exports** - Obsidian vault, wiki, SVG, GraphML, Neo4j, and an MCP server.

Every edge is tagged `EXTRACTED`, `INFERRED`, or `AMBIGUOUS`, so you can see what was found in the source and what the model guessed. Community detection surfaces connections between different files that you would not think to ask about directly.

Use it for a codebase you are new to, a reading list, a research corpus, or a personal `/raw` folder.

## Requirements

- [OpenCode](https://opencode.ai) with skills support.
- **Python 3.10 or newer** with `pip` for the `graphify` CLI. Recent `graphifyy` releases require Python 3.11.5+; older releases support 3.10. The skill itself can be installed without Python by passing `-SkipCli` / `--skip-cli`.
- **Windows:** PowerShell 5.1 or newer (built into Windows 10/11).
- **macOS / Linux:** `bash`, `curl`, and `tar`.
- No other installer dependencies.

## Install

### Windows (PowerShell)

Download, inspect, and run:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Or run it directly:

```powershell
irm https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 | iex
```

To update:

```powershell
# If you saved install.ps1:
.\install.ps1 -Force

# Or without saving it:
$env:GRAPHIFY_FORCE=1; irm https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh | bash
```

To update:

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh | bash -s -- --force
```

Read the script first if you prefer:

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh -o install.sh
bash install.sh
```

### Options

| PowerShell | Bash | Description |
| --- | --- | --- |
| `-SkillDir PATH` | `--dir PATH` | OpenCode skills root. Default: `~/.config/opencode/skills` |
| `-Ref REF` | `--ref REF` | Branch, tag, or commit of the upstream repo. Default: `main` |
| `-Force` | `--force` | Replace an existing installation |
| `-SkipCli` | `--skip-cli` | Do not install or check the graphify CLI |

Environment variables `OPENCODE_SKILLS_DIR`, `GRAPHIFY_REF`, `GRAPHIFY_FORCE=1`, and `GRAPHIFY_SKIP_CLI=1` work too.

The skill is installed to:

- Windows: `%USERPROFILE%\.config\opencode\skills\graphify\SKILL.md`
- macOS / Linux: `~/.config/opencode/skills/graphify/SKILL.md`

### About the CLI

The PyPI package is named `graphifyy`, but the console command is `graphify`. When the command is not found, the installer runs:

```powershell
python -m pip install --user graphifyy
```

```bash
python3 -m pip install --user graphifyy
```

It then prints the Python user `Scripts` (Windows) or `bin` (macOS/Linux) directory so you can add it to `PATH`. If pip fails, the installer warns and leaves the skill installed.

## Verify the installation

```powershell
.\verify.ps1
```

```bash
bash verify.sh
```

Expected output:

```text
OK  graphify is installed at /home/you/.config/opencode/skills/graphify (1 files).
OK  graphify CLI: graphify 0.9.119
```

Add `-RequireCli` / `--require-cli` to make a missing CLI a failure instead of a warning:

```powershell
.\verify.ps1 -RequireCli
```

```bash
bash verify.sh --require-cli
```

Recent `graphifyy` releases support `graphify --version`. Older releases do not, so the verifier falls back to `graphify --help` and the installed package metadata.

After installing, **start a new OpenCode session** so it picks up the skill.

## Use it

Inside OpenCode, invoke the skill with `@graphify` or by asking to graph a folder:

- `@graphify .` - graph the current folder.
- `@graphify ./raw --mode deep` - deeper extraction with more `INFERRED` edges.
- `@graphify ./src --update` - re-extract only new or changed files.
- `@graphify query "what connects auth to the database?"`
- *"Graph this folder and explain the god nodes."*

The skill text uses `graphify <path> [flags]` as its canonical command form. OpenCode interprets that through the skill workflow; the console command is also named `graphify` and provides supporting subcommands such as `graphify hook install`, `graphify benchmark`, and `graphify path`. There is no leading slash in OpenCode.

## How it works

1. Download the upstream repository archive from `codeload.github.com` (default branch, tag, or commit).
2. Extract it to a temporary directory and locate `skills/graphify/skill.md`.
3. Replace the Claude-oriented frontmatter with an OpenCode `name` and `description`, add the OpenCode adaptation note, and convert `/graphify` invocations to `graphify <path> [flags]`.
4. Write the result to `<skills-root>/graphify/SKILL.md`.
5. Check for the `graphify` CLI and install `graphifyy` with `pip --user` when needed.

CI installs the skill with `--skip-cli` on Ubuntu, macOS, and Windows (Windows PowerShell 5.1), and runs a separate Ubuntu job that installs `graphifyy`, executes `graphify --version` and `graphify --help`, and verifies with `--require-cli`.

## Update and uninstall

Update by re-running the installer with `-Force` / `--force`. It always fetches the current `main` revision, so updates to that branch arrive as soon as they are published. Pass `-Ref` / `--ref` to pin another branch, tag, or commit.

Uninstall:

```powershell
Remove-Item -Recurse -Force "$HOME\.config\opencode\skills\graphify"
```

```bash
rm -rf ~/.config/opencode/skills/graphify
```

To remove the CLI as well:

```powershell
python -m pip uninstall graphifyy
```

```bash
python3 -m pip uninstall graphifyy
```

## Licenses and attribution

- **This installer:** MIT. See [LICENSE](LICENSE).
- **Graphify skill:** this installer downloads the `main` branch, whose `pyproject.toml` declares `license = { text = "MIT" }`. That branch has no standalone `LICENSE` file. Upstream's current default branch (`v8`) uses Apache-2.0 with MIT for pre-relicensing contributions; see its `LICENSE`, `LICENSE-MIT`, and `NOTICE`. See the [upstream repository](https://github.com/Graphify-Labs/graphify) and [NOTICE](NOTICE).
- **PyPI package `graphifyy`:** installed separately from PyPI. The 0.9.119 release reports `License-Expression: Apache-2.0`; check the current package metadata before redistribution.
- **Graphify** is maintained upstream by Graphify Labs. This project is unofficial and not affiliated with the authors.

If you find the skill useful, star the original repository: [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify).

## Troubleshooting

**The skill does not appear in OpenCode.** Confirm the path with `verify.ps1` / `verify.sh`, then start a new session. OpenCode reads the skills folder when a session starts.

**`@graphify` is not recognized.** Make sure your OpenCode build supports skills, and confirm that `~/.config/opencode/skills/graphify/SKILL.md` exists. Asking "graph this folder" also triggers the skill.

**PowerShell blocks the script.** Use `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

**`graphify` is not recognized after installation.** Close and reopen the terminal, or add the printed `Scripts` / `bin` directory to `PATH`:

- Windows: `%APPDATA%\Python\Python3XX\Scripts`
- macOS / Linux: `~/.local/bin` (or the path printed by the installer)

**pip fails with "externally-managed-environment" on macOS or Linux.** The skill is still installed. Use `pipx install graphifyy`, or a virtual environment, then run `verify.sh --require-cli`.

**Python is older than 3.10.** Upgrade Python, or install the skill alone with `-SkipCli` / `--skip-cli`.

**`graphify --version` prints an error.** Older CLI releases do not implement it. Run `graphify --help`; `verify.ps1` / `verify.sh` already handles this fallback.

**The download fails.** The installer needs access to `github.com` and `codeload.github.com`. Check your proxy or firewall.

**The installer says the skill is already installed.** Re-run it with `-Force` / `--force` to replace the existing copy.

**A branch or tag does not exist.** Check the name, or pass a commit SHA with `-Ref` / `--ref`.

**The upstream layout changed.** Open an issue. The installer expects `skills/graphify/skill.md` and fails clearly if it is missing.
