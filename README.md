# claude-docker

Canonical Claude Code dev-environment image. Build once, reuse across projects.

## What's included

| Component | Description |
|-----------|-------------|
| **Claude Code** | Anthropic's AI coding CLI |
| **jcodemunch-mcp** | Code-index MCP server — semantic search, session hooks, token savings |
| **OpenWolf** | Project anatomy scanner, token audit, and session tracking hooks |
| **cavemem** skill | `/cavemem` slash command — maximum-efficiency terse response mode |
| **Node.js 22 LTS** | Required by Claude Code and npx-based MCP servers |
| **Go** | Required by gitea-mcp and other Go tools |
| **uv / uvx** | Fast Python tool runner (used to install jcodemunch-mcp) |
| **Docker CLI + Compose** | Run `docker`/`docker compose` from inside Claude via the mounted socket |
| **GitHub CLI** (`gh`) | Optional — see build flags |
| **GitLab CLI** (`glab`) | Optional — see build flags |

## Quick start (new project)

1. Clone this repo and copy `docker-compose.yaml` into your project as `docker-compose.dev-environment.yaml`.
   No edits required — everything is driven by env vars.

2. Create a `.env` in your project root:
   ```
   # Path to claude-docker (absolute is most reliable; sibling default also works)
   CLAUDE_DOCKER_DIR=/workspace/claude-docker

   # Container name and hostname (defaults to "claude")
   PROJECT_NAME=myproject

   # Anthropic API key if not using OAuth
   ANTHROPIC_API_KEY=sk-ant-...
   ```

3. Start:
   ```
   docker compose -f docker-compose.dev-environment.yaml run --rm claude
   ```

On first run `claude-init.sh` will:
- Write `~/.claude/settings.json` with merged hooks and permissions
- Generate `.mcp.json` for the project from the current env vars
- Initialise the jcodemunch code index in `.code-index/` and index the workspace
- Initialise OpenWolf in `.wolf/` and run `openwolf scan` to generate `anatomy.md`
- Install the bundled `/cavemem` skill into `~/.claude/commands/`

## MCP servers

| Server | Description | Repo | When active |
|--------|-------------|------|-------------|
| `jcodemunch` | Semantic code search, token-efficient reads, PreToolUse/PostToolUse hooks | [jgravelle/jcodemunch-mcp](https://github.com/jgravelle/jcodemunch-mcp) | Always |
| `gitea` | Gitea repository and PR management | [gitea/gitea-mcp](https://gitea.com/gitea/gitea-mcp) | `ENABLE_GITEA_MCP=true` |
| `apple-docs` | Apple Developer documentation search | [kimsungwhee/apple-docs-mcp](https://github.com/kimsungwhee/apple-docs-mcp) | `ENABLE_APPLE_DOCS_MCP=true` |

`.mcp.json` is generated fresh on every container start from `defaults/mcp.json` plus any
enabled optional servers. To enable an optional server, set its env var in your `.env`.

## Skills

| Skill | Command | Description | Source |
|-------|---------|-------------|--------|
| cavemem | `/cavemem` | Activates maximum token-efficiency mode — terse, no filler, fragments fine | [kuba-guzik/caveman-micro](https://github.com/kuba-guzik/caveman-micro) |
| OpenWolf | `openwolf scan`, `openwolf init` | Scans project anatomy, audits token usage, manages session hooks | [cytostack/openwolf](https://github.com/cytostack/openwolf) |

## Environment variables

### Build-time (baked into the image)

Set in `.env` before running `docker compose … build`.

| Variable | What it adds | Default |
|----------|-------------|---------|
| `INSTALL_GITHUB_CLI` | `gh` GitHub CLI | `false` |
| `INSTALL_GITLAB_CLI` | `glab` GitLab CLI | `false` |

### Runtime (read on every container start)

Set in `.env` — no rebuild needed.

| Variable | Purpose | Default |
|----------|---------|---------|
| `ENABLE_GITEA_MCP` | Add gitea MCP server to `.mcp.json` | `false` |
| `ENABLE_APPLE_DOCS_MCP` | Add apple-docs MCP server to `.mcp.json` | `false` |
| `GITEA_ACCESS_TOKEN` | Auth token for the Gitea MCP server | `` |
| `GITEA_HOST` | Gitea instance URL | `` |
| `JCODEMUNCH_INIT_ARGS` | Extra args passed to `jcodemunch-mcp init --yes` on first run | `--claude-md project` |
| `PROJECT_NAME` | Container name and hostname | `claude` |
| `ANTHROPIC_API_KEY` | API key (optional if using OAuth) | `` |

## Extending with project-specific init

Add a `compose-init.sh` to your project root. It runs automatically after `claude-init.sh`.

## Building manually

```
docker build -t claude-dev:latest /path/to/claude-docker
```

## File structure

```
claude-docker/
├── Dockerfile              # Image definition (Node 22, Go, uv, jcodemunch, openwolf)
├── claude-init.sh          # Per-project initialisation script (runs at container start)
├── docker-compose.yaml     # Template compose file (copy to your project)
└── defaults/
    ├── mcp.json            # Base MCP config (jcodemunch always; optionals added at runtime)
    ├── settings.json       # Default Claude Code settings (hooks + permissions)
    ├── wolf-config.json    # Default OpenWolf config
    └── commands/
        └── cavemem.md      # /cavemem skill definition
```
