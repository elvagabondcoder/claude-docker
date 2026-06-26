FROM debian:bookworm-slim

# ── System packages (always installed) ───────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    file \
    git \
    gpg \
    gpg-agent \
    iputils-ping \
    jq \
    netcat-traditional \
    openssh-client \
    pipx \
    python3-full \
    ripgrep \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS ───────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Go (for gitea-mcp and other go-based tools) ──────────────────────────────
ARG GO_VERSION=1.23.8
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ── Docker CLI + Compose plugin ──────────────────────────────────────────────
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ── GitHub CLI (optional) ─────────────────────────────────────────────────────
# Enable: --build-arg INSTALL_GITHUB_CLI=true
ARG INSTALL_GITHUB_CLI=false
RUN if [ "$INSTALL_GITHUB_CLI" = "true" ]; then \
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
      && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
      && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*; \
    fi

# ── GitLab CLI (optional) ─────────────────────────────────────────────────────
# Enable: --build-arg INSTALL_GITLAB_CLI=true
ARG INSTALL_GITLAB_CLI=false
RUN if [ "$INSTALL_GITLAB_CLI" = "true" ]; then \
      curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-cli/script.deb.sh | bash \
      && apt-get install -y glab \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# ── Non-root devops user ──────────────────────────────────────────────────────
ARG USERNAME=devops
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /home/$USERNAME/.local/bin \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ── Global npm packages (must run as root — Node.js is system-wide) ──────────
RUN npm install -g openwolf

USER devops
WORKDIR /home/devops

# ── Claude Code ──────────────────────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash

# ── uv (fast Python package/tool runner) ─────────────────────────────────────
RUN curl -fsSL https://astral.sh/uv/install.sh | bash

ENV PATH="/home/devops/.local/bin:/home/devops/.claude/bin:${PATH}"

# ── jcodemunch-mcp — code-index MCP, required for hooks ──────────────────────
RUN uv tool install jcodemunch-mcp

# ── Default configs ──────────────────────────────────────────────────────────
RUN mkdir -p /home/devops/.config/claude-docker
COPY --chown=devops:devops defaults/ /home/devops/.config/claude-docker/


# ── claude-init.sh — runs at container start for every project ────────────────
USER root
COPY claude-init.sh /usr/local/bin/claude-init.sh
RUN chmod +x /usr/local/bin/claude-init.sh
USER devops

WORKDIR /workspace
CMD ["bash"]
