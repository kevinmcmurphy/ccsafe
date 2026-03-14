# ccsafe

Launch Claude Code with `--dangerously-skip-permissions` inside a Docker sandbox, so the blast radius is limited to the directory you activate it from.

## What it does

- Runs Claude Code **inside** a container (true isolation)
- Mounts only `$(pwd)` as read/write — nothing else on your filesystem is accessible
- Mounts `~/.claude` read-write so your config, settings, and skills come through
- Drops all Linux capabilities, no privilege escalation
- 2GB RAM default — safe for Mac Mini M4 with Cowork + Ollama running alongside
- Tunable per-session with `--memory` and `--cpus` flags, or globally via env vars
- Outbound network permitted (Claude Code needs `api.anthropic.com`)

## Auth

ccsafe automatically extracts your Claude Max/Pro OAuth token from the macOS Keychain at launch time. No plaintext secrets in config files — just make sure you've logged in once on your host:

```bash
claude auth login
```

That's it. ccsafe reads the token from Keychain each time it launches.

## Install

```bash
# Put the 4 files in a folder, then:
chmod +x install.sh
./install.sh
source ~/.zshrc   # or ~/.bashrc
```

The installer:
1. Copies files to `~/.ccsafe/`
2. Adds a `source` line to your shell RC
3. Builds the Docker image once (~2-3 min)

## Usage

```bash
# Sandbox current directory (default: 2g RAM, 4 CPUs)
ccsafe

# Sandbox a specific directory
ccsafe ~/projects/myapp

# Override memory for a heavier session (e.g. large monorepo)
ccsafe --memory 4g

# Override both memory and CPUs
ccsafe --memory 4g --cpus 6 ~/projects/bigapp

# Rebuild the image (after Dockerfile changes or to upgrade Claude Code)
ccsafe --build

# Show help
ccsafe --help
```

## Resource defaults

| Machine | Recommended default |
|---------|-------------------|
| MacBook Pro M3 Max (48GB) | `CCSAFE_MEMORY=4g` |
| Mac Mini M4 (16GB) | `CCSAFE_MEMORY=2g` (default) |

To set a persistent default per machine, add to your `~/.zshrc`:

```bash
export CCSAFE_MEMORY=4g   # MBP M3 Max
export CCSAFE_CPUS=6
```

The `--memory` and `--cpus` flags override these for a single session without touching config.

## What's in the container

| Tool | Source |
|------|--------|
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Node 20 | `node:20-slim` base |
| Python 3 | apt |
| Git | apt |
| Pandoc | apt |
| ripgrep | apt |
| jq | apt |

## Mounts

| Host | Container | Mode |
|------|-----------|------|
| `$(pwd)` or specified path | `/workspace` | read/write |
| `~/.claude` | `/home/claude/.claude` | read-write |

## Upgrading Claude Code

Claude Code updates frequently. To pull the latest version into the image:

```bash
ccsafe --build
```

No other changes needed — limits and config are applied at `docker run` time, not baked into the image.

## Security notes

- The OAuth token is passed as an env var into the container. A compromised process inside the container could read it from `/proc/*/environ`. Use on **trusted repositories** only — this is the same caveat Anthropic puts on their own devcontainer reference.
- The `--dangerously-skip-permissions` flag disables Claude Code's own permission prompts. The Docker isolation is your safety net.
- Network is open outbound (needed for Claude API). To restrict further, replace `--platform` with `--network none` and proxy the API — but that's a more complex setup.
