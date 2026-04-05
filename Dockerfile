FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    git \
    gpg \
    gpg-agent \
    iputils-ping \
    netcat-traditional \
    openssh-client \
    pipx \
    python3-full \
    ripgrep \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG USERNAME=devops
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && mkdir -p /home/$USERNAME/.local/bin \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME

RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

USER devops

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Add local bin and Claude Code to PATH
ENV PATH="~/.local/bin:~/.claude/bin:${PATH}"

WORKDIR /workspace
CMD ["/home/devops/.local/bin/claude"]