#!/bin/sh
# claude-init.sh — baked into every claude-docker image.
# Runs at container start before the interactive shell.
# All steps are idempotent.

set -e

WORKSPACE="${WORKSPACE:-/workspace}"
CLAUDE_DIR="/home/devops/.claude"
DEFAULTS_DIR="/home/devops/.config/claude-docker"

echo "[claude-init] Starting — workspace: $WORKSPACE"

# ── .claude/settings.json ────────────────────────────────────────────────────
# Copy the merged default settings if the project doesn't have one yet.
if [ ! -f "$CLAUDE_DIR/settings.json" ] || [ "$(cat "$CLAUDE_DIR/settings.json")" = "{}" ]; then
    echo "[claude-init] Installing default Claude settings..."
    mkdir -p "$CLAUDE_DIR"
    cp "$DEFAULTS_DIR/settings.json" "$CLAUDE_DIR/settings.json"
fi

# ── ~/.claude.json ────────────────────────────────────────────────────────────
# Kept inside the .claude volume (a directory mount) rather than as a separate
# file bind mount, because Docker creates a directory at the source path when
# the file doesn't exist on the host. A symlink bridges the expected location.
mkdir -p "$CLAUDE_DIR"
CLAUDE_JSON="$CLAUDE_DIR/claude.json"
CLAUDE_JSON_LINK="/home/devops/.claude.json"
if [ ! -f "$CLAUDE_JSON" ]; then
    # Migrate data from the old top-level bind-mount location if present.
    if [ -f "$WORKSPACE/.claude.json" ]; then
        cp "$WORKSPACE/.claude.json" "$CLAUDE_JSON"
    else
        echo '{}' > "$CLAUDE_JSON"
    fi
fi
# Replace a stale directory (created by Docker on missing file mount) with symlink.
if [ -d "$CLAUDE_JSON_LINK" ]; then
    rmdir "$CLAUDE_JSON_LINK" 2>/dev/null || true
fi
if [ ! -e "$CLAUDE_JSON_LINK" ]; then
    ln -s "$CLAUDE_JSON" "$CLAUDE_JSON_LINK"
fi

# ── .mcp.json ────────────────────────────────────────────────────────────────
# Always regenerate from the base template plus optional servers controlled by
# runtime env vars. This ensures the file stays in sync if env vars change
# between runs and prevents stale baked-in config from persisting on the volume.
echo "[claude-init] Generating .mcp.json..."
mcp=$(cat "$DEFAULTS_DIR/mcp.json")
if [ "${ENABLE_GITEA_MCP:-false}" = "true" ]; then
    mcp=$(printf '%s' "$mcp" | jq '.mcpServers["gitea"] = {
        "type": "stdio",
        "command": "go",
        "args": ["run", "gitea.com/gitea/gitea-mcp@latest", "-t", "stdio"],
        "env": {"GITEA_ACCESS_TOKEN": "${GITEA_ACCESS_TOKEN}", "GITEA_HOST": "${GITEA_HOST}"}
    }')
fi
if [ "${ENABLE_APPLE_DOCS_MCP:-false}" = "true" ]; then
    mcp=$(printf '%s' "$mcp" | jq '.mcpServers["apple-docs"] = {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@kimsungwhee/apple-docs-mcp@latest"],
        "env": {}
    }')
fi
printf '%s\n' "$mcp" > "$WORKSPACE/.mcp.json"

# ── jcodemunch-mcp initialisation ────────────────────────────────────────────
# The code-index lives in $WORKSPACE/.code-index and must be initialised
# before the jcodemunch hooks can do anything useful.
if [ ! -d "$WORKSPACE/.code-index" ] || [ -z "$(ls -A "$WORKSPACE/.code-index" 2>/dev/null)" ]; then
    echo "[claude-init] Initialising jcodemunch code index..."
    JCODEMUNCH_INIT_ARGS="${JCODEMUNCH_INIT_ARGS:---claude-md project}"
    # --client none: skip `claude mcp add` — .mcp.json handles project-scope registration
    # --index: explicitly trigger workspace indexing (not on by default)
    # shellcheck disable=SC2086
    if ! (cd "$WORKSPACE" && jcodemunch-mcp init --yes --client none --index $JCODEMUNCH_INIT_ARGS); then
        echo "[claude-init] WARNING: jcodemunch init failed — run 'jcodemunch-mcp init --yes --index' manually"
    fi
else
    echo "[claude-init] jcodemunch already initialised (.code-index exists)"
fi

# ── OpenWolf initialisation ───────────────────────────────────────────────────
# openwolf init creates .wolf/config.json and the JS hook files.
# Falls back to copying bundled defaults if init fails.
if [ ! -f "$WORKSPACE/.wolf/config.json" ]; then
    echo "[claude-init] Initialising OpenWolf..."
    mkdir -p "$WORKSPACE/.wolf"
    if ! (cd "$WORKSPACE" && openwolf init); then
        echo "[claude-init] WARNING: openwolf init failed"
    fi
    # If openwolf init didn't create config, copy our defaults
    if [ ! -f "$WORKSPACE/.wolf/config.json" ]; then
        cp "$DEFAULTS_DIR/wolf-config.json" "$WORKSPACE/.wolf/config.json"
        echo "[claude-init] Copied default wolf config"
    fi
    echo "[claude-init] Running openwolf scan to generate anatomy.md..."
    if ! (cd "$WORKSPACE" && openwolf scan); then
        echo "[claude-init] WARNING: openwolf scan failed — run 'openwolf scan' manually"
    fi
else
    echo "[claude-init] OpenWolf already initialised (.wolf/config.json exists)"
fi

# ── Claude commands (user-level skills) ──────────────────────────────────────
# The .claude dir is a volume mount, so baked-in files are hidden at runtime.
# Copy default commands into the mounted dir on first use; skip any that exist.
if [ -d "$DEFAULTS_DIR/commands" ]; then
    mkdir -p "$CLAUDE_DIR/commands"
    for f in "$DEFAULTS_DIR/commands/"*; do
        [ -f "$f" ] || continue
        dest="$CLAUDE_DIR/commands/$(basename "$f")"
        if [ ! -f "$dest" ]; then
            cp "$f" "$dest"
            echo "[claude-init] Installed command: $(basename "$f")"
        fi
    done
fi

echo "[claude-init] Done."
