# opencode-graphify-skill

[![CI](https://github.com/MaxiGP0/opencode-graphify-skill/actions/workflows/ci.yml/badge.svg)](https://github.com/MaxiGP0/opencode-graphify-skill/actions/workflows/ci.yml)

[English](README.md) | [Español](README.es.md)

Instalador de un solo comando que deja disponible en [OpenCode](https://opencode.ai) el skill **[Graphify](https://github.com/Graphify-Labs/graphify)** y además instala su CLI de Python.

El skill original documenta Claude Code y el comando `/graphify`. OpenCode lee los skills globales desde `~/.config/opencode/skills/<nombre>/`, así que este repositorio descarga `skills/graphify/skill.md` al instalar, reescribe su frontmatter y la forma de invocación para OpenCode, y escribe `<raíz-de-skills>/graphify/SKILL.md`. Si falta el CLI `graphify`, ejecuta `pip install --user graphifyy`. No se reempaqueta ni se aloja una copia del skill.

> Este es un instalador no oficial. No está afiliado a Graphify Labs.

La rama por defecto actual del repo original (`v8`) tiene soporte nativo de OpenCode y una estructura de skill distinta, con varios archivos. Este instalador usa a propósito `main`, que todavía incluye el skill autónomo `skills/graphify/skill.md` que adapta este proyecto.

## Qué hace el skill

Graphify convierte cualquier carpeta de código, documentos, papers o imágenes en un grafo de conocimiento persistente y consultable:

- **`graph.html`** - un grafo interactivo que se abre en cualquier navegador.
- **`graph.json`** - el grafo listo para GraphRAG que sobrevive entre sesiones.
- **`GRAPH_REPORT.md`** - god nodes, estructura de comunidades, conexiones sorprendentes, preguntas sugeridas y una auditoría del costo en tokens.
- **Exportaciones opcionales** - bóveda de Obsidian, wiki, SVG, GraphML, Neo4j y un servidor MCP.

Cada arista está etiquetada como `EXTRACTED`, `INFERRED` o `AMBIGUOUS`, así que se ve qué se encontró en la fuente y qué inventó el modelo. La detección de comunidades muestra conexiones entre archivos distintos que no se te ocurriría preguntar de forma directa.

Sirve para un codebase que recién conocés, una lista de lectura, un corpus de investigación o tu carpeta personal `/raw`.

## Requisitos

- [OpenCode](https://opencode.ai) con soporte de skills.
- **Python 3.10 o superior** con `pip` para el CLI `graphify`. Las versiones recientes de `graphifyy` requieren Python 3.11.5+; las anteriores soportan 3.10. El skill se puede instalar sin Python pasando `-SkipCli` / `--skip-cli`.
- **Windows:** PowerShell 5.1 o superior (viene con Windows 10/11).
- **macOS / Linux:** `bash`, `curl` y `tar`.
- Sin otras dependencias para el instalador.

## Instalación

### Windows (PowerShell)

Descargá, revisá y ejecutá:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

O ejecutalo directamente:

```powershell
irm https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 | iex
```

Para actualizar:

```powershell
# Si guardaste install.ps1:
.\install.ps1 -Force

# O sin guardarlo:
$env:GRAPHIFY_FORCE=1; irm https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh | bash
```

Para actualizar:

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh | bash -s -- --force
```

Si preferís leer el script antes:

```bash
curl -fsSL https://raw.githubusercontent.com/MaxiGP0/opencode-graphify-skill/main/install.sh -o install.sh
bash install.sh
```

### Opciones

| PowerShell | Bash | Descripción |
| --- | --- | --- |
| `-SkillDir PATH` | `--dir PATH` | Raíz de skills de OpenCode. Por defecto: `~/.config/opencode/skills` |
| `-Ref REF` | `--ref REF` | Rama, tag o commit del repo original. Por defecto: `main` |
| `-Force` | `--force` | Reemplaza una instalación existente |
| `-SkipCli` | `--skip-cli` | No instala ni revisa el CLI de graphify |

También funcionan las variables de entorno `OPENCODE_SKILLS_DIR`, `GRAPHIFY_REF`, `GRAPHIFY_FORCE=1` y `GRAPHIFY_SKIP_CLI=1`.

El skill se instala en:

- Windows: `%USERPROFILE%\.config\opencode\skills\graphify\SKILL.md`
- macOS / Linux: `~/.config/opencode/skills/graphify/SKILL.md`

### Sobre el CLI

El paquete de PyPI se llama `graphifyy`, pero el comando de consola es `graphify`. Cuando el comando no existe, el instalador ejecuta:

```powershell
python -m pip install --user graphifyy
```

```bash
python3 -m pip install --user graphifyy
```

Después imprime la carpeta `Scripts` (Windows) o `bin` (macOS/Linux) del usuario de Python para que la agregues al `PATH`. Si pip falla, el instalador avisa y deja el skill instalado.

## Verificar la instalación

```powershell
.\verify.ps1
```

```bash
bash verify.sh
```

Salida esperada:

```text
OK  graphify is installed at /home/you/.config/opencode/skills/graphify (1 files).
OK  graphify CLI: graphify 0.9.119
```

Agregá `-RequireCli` / `--require-cli` para que la falta del CLI sea un error en lugar de una advertencia:

```powershell
.\verify.ps1 -RequireCli
```

```bash
bash verify.sh --require-cli
```

Las versiones recientes de `graphifyy` soportan `graphify --version`. Las versiones viejas no, así que el verificador usa `graphify --help` y los metadatos del paquete instalado como respaldo.

Después de instalar, **abrí una sesión nueva de OpenCode** para que tome el skill.

## Cómo usarlo

Dentro de OpenCode, invocá el skill con `@graphify` o pedile que grafique una carpeta:

- `@graphify .` - grafica la carpeta actual.
- `@graphify ./raw --mode deep` - extracción más profunda, con más aristas `INFERRED`.
- `@graphify ./src --update` - re-extrae solo archivos nuevos o modificados.
- `@graphify query "what connects auth to the database?"`
- *"Graph this folder and explain the god nodes."*

El texto del skill usa `graphify <path> [flags]` como forma canónica del comando. OpenCode lo interpreta mediante el flujo de trabajo del skill; el comando de consola también se llama `graphify` y ofrece subcomandos de soporte, como `graphify hook install`, `graphify benchmark` y `graphify path`. En OpenCode no se usa barra inicial.

## Cómo funciona

1. Descarga el archivo del repositorio original desde `codeload.github.com` (rama, tag o commit).
2. Lo extrae en un directorio temporal y ubica `skills/graphify/skill.md`.
3. Reemplaza el frontmatter orientado a Claude por un `name` y un `description` para OpenCode, agrega la nota de adaptación y convierte las invocaciones `/graphify` a `graphify <path> [flags]`.
4. Escribe el resultado en `<raíz-de-skills>/graphify/SKILL.md`.
5. Revisa si existe el CLI `graphify` y, si falta, instala `graphifyy` con `pip --user`.

La CI instala el skill con `--skip-cli` en Ubuntu, macOS y Windows (Windows PowerShell 5.1), y corre un job aparte en Ubuntu que instala `graphifyy`, ejecuta `graphify --version` y `graphify --help`, y verifica con `--require-cli`.

## Actualizar y desinstalar

Actualizá volviendo a ejecutar el instalador con `-Force` / `--force`. Siempre baja la revisión actual de `main`, así que las actualizaciones de esa rama llegan apenas se publican. Pasá `-Ref` / `--ref` para fijar otra rama, tag o commit.

Desinstalar:

```powershell
Remove-Item -Recurse -Force "$HOME\.config\opencode\skills\graphify"
```

```bash
rm -rf ~/.config/opencode/skills/graphify
```

Para quitar también el CLI:

```powershell
python -m pip uninstall graphifyy
```

```bash
python3 -m pip uninstall graphifyy
```

## Licencias y atribución

- **Este instalador:** MIT. Ver [LICENSE](LICENSE).
- **Skill Graphify:** este instalador descarga la rama `main`, cuyo `pyproject.toml` declara `license = { text = "MIT" }`. Esa rama no incluye un archivo `LICENSE` independiente. La rama por defecto actual del repo original (`v8`) usa Apache-2.0, con MIT para las contribuciones previas al cambio de licencia; ver `LICENSE`, `LICENSE-MIT` y `NOTICE`. Ver el [repositorio original](https://github.com/Graphify-Labs/graphify) y [NOTICE](NOTICE).
- **Paquete `graphifyy` de PyPI:** se instala por separado desde PyPI. La versión 0.9.119 declara `License-Expression: Apache-2.0`; revisá los metadatos actuales del paquete antes de redistribuirlo.
- **Graphify** lo mantiene Graphify Labs. Este proyecto es no oficial y no está afiliado a los autores.

Si el skill te resulta útil, dale una estrella al repositorio original: [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify).

## Solución de problemas

**El skill no aparece en OpenCode.** Confirmá la ruta con `verify.ps1` / `verify.sh` y abrí una sesión nueva. OpenCode lee la carpeta de skills al iniciar la sesión.

**No reconoce `@graphify`.** Asegurate de que tu versión de OpenCode soporte skills y de que exista `~/.config/opencode/skills/graphify/SKILL.md`. Pedir "graph this folder" también activa el skill.

**PowerShell bloquea el script.** Usá `powershell -ExecutionPolicy Bypass -File .\install.ps1`.

**No reconoce `graphify` después de instalar.** Cerrá y abrí la terminal de nuevo, o agregá al `PATH` la carpeta `Scripts` / `bin` que imprimió el instalador:

- Windows: `%APPDATA%\Python\Python3XX\Scripts`
- macOS / Linux: `~/.local/bin` (o la ruta que imprimió el instalador)

**pip falla con "externally-managed-environment" en macOS o Linux.** El skill queda instalado igual. Usá `pipx install graphifyy`, o un entorno virtual, y después `verify.sh --require-cli`.

**Python es anterior a 3.10.** Actualizá Python, o instalá solo el skill con `-SkipCli` / `--skip-cli`.

**`graphify --version` da error.** Las versiones viejas del CLI no lo implementan. Ejecutá `graphify --help`; `verify.ps1` / `verify.sh` ya manejan ese respaldo.

**La descarga falla.** El instalador necesita acceso a `github.com` y `codeload.github.com`. Revisá el proxy o el firewall.

**El instalador dice que el skill ya está instalado.** Volvé a ejecutarlo con `-Force` / `--force` para reemplazar la copia existente.

**Una rama o un tag no existe.** Revisá el nombre, o pasá un commit SHA con `-Ref` / `--ref`.

**Cambió la estructura del repo original.** Abrí un issue. El instalador espera `skills/graphify/skill.md` y falla con un mensaje claro si no lo encuentra.
