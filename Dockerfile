# ccsafe — Claude Code sandbox image
# Architecture: arm64 (Apple Silicon) + amd64
# Base: node:20-slim (Debian-based — avoids musl/Alpine compatibility issues with Claude Code)

FROM node:20-slim

# ── System packages ──────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Build tools (needed for some npm native modules)
    build-essential \
    # Pandoc
    pandoc \
    # Common utilities Claude Code tends to reach for
    ripgrep \
    jq \
    less \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js: install latest LTS alongside the base node:20 ───────────────────
# node:20-slim already ships Node 20 — we just update npm to latest
RUN npm install -g npm@latest

# ── Claude Code CLI ───────────────────────────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code

# ── Non-root user ─────────────────────────────────────────────────────────────
# Matches a typical macOS UID to avoid file permission friction on mounts
RUN useradd -m -u 1001 -s /bin/bash claude

# ── Directory structure ───────────────────────────────────────────────────────
RUN mkdir -p /workspace && chown claude:claude /workspace

# ── Switch to non-root user ───────────────────────────────────────────────────
USER claude
WORKDIR /workspace

# ── Entrypoint: launch Claude Code with dangerous flag ────────────────────────
ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
