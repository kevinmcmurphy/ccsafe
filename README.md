# ccsafe

> **macOS only** — Linux and Windows support is planned. See [TODO](#todo).

Launch Claude Code with `--dangerously-skip-permissions` inside a Docker sandbox, so the blast radius is limited to the directory you activate it from.

## What it does

- Runs Claude Code **inside** a container (true isolation)
- Mounts only `$(pwd)` as read/write — nothing else on your filesystem is accessible
- Mounts `~/.claude` read-write so your config, settings, and skills come through
- Drops all Linux capabilities, no privilege escalation
- 2GB RAM / 4 CPUs by default — tunable per-session or globally via env vars
- Outbound network permitted (Claude Code needs `api.anthropic.com`)

## Prerequisites

- **macOS** (Apple Silicon or Intel)
- **[Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)** — must be running before you use ccsafe
- **A Claude account** — either Claude Max/Pro (OAuth) or an [Anthropic API key](https://console.anthropic.com/)

## Auth

ccsafe supports two auth methods, tried in this order:

**1. Claude Max/Pro OAuth (recommended)** — automatically reads your token from the macOS Keychain. Just log in once on your host:

```bash
claude auth login
```

**2. Anthropic API key** — set `ANTHROPIC_API_KEY` in your environment and ccsafe will pass it through:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

No plaintext secrets are stored in config files.

## Install

```bash
# Clone or download the repo, then:
chmod +x install.sh
./install.sh
source ~/.zshrc   # or ~/.bashrc
```

The installer:
1. Checks that you're on macOS
2. Copies files to `~/.ccsafe/`
3. Adds a `source` line to your shell RC
4. Builds the Docker image once (~2-3 min)

## Usage

```bash
# Sandbox current directory (default: 2g RAM, 4 CPUs)
ccsafe

# Sandbox a specific directory
ccsafe ~/projects/myapp

# Override memory for a heavier session
ccsafe --memory 4g

# Override both memory and CPUs
ccsafe --memory 4g --cpus 6 ~/projects/bigapp

# Rebuild the image (after Dockerfile changes or to upgrade Claude Code)
ccsafe --build

# Show help
ccsafe --help
```

## Resource defaults

| RAM    | CPUs | Good for |
|--------|------|----------|
| `2g`   | `4`  | Default — most projects |
| `4g`   | `6`  | Large monorepos or heavy tool use |

To set a persistent default, add to your `~/.zshrc`:

```bash
export CCSAFE_MEMORY=4g
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
| `~/.claude.json` | `/home/claude/.claude.json` | read-write (if file exists) |
| `~/.local/bin` | `/home/claude/.local/bin` | read-only (if dir exists) |

## Upgrading Claude Code

Claude Code updates frequently. To pull the latest version into the image:

```bash
ccsafe --build
```

No other changes needed — limits and config are applied at `docker run` time, not baked into the image.

## Security notes

> [!WARNING]
> The OAuth token is passed as an env var into the container. A compromised process inside the container could read it from `/proc/*/environ`. Use on **trusted repositories** only — this is the same caveat Anthropic puts on their own devcontainer reference.

- The `--dangerously-skip-permissions` flag disables Claude Code's own permission prompts. The Docker isolation is your safety net.
- Network is open outbound (needed for Claude API). To restrict further, replace `--platform` with `--network none` and proxy the API — but that's a more complex setup.

## TODO

- [ ] Linux support (auth flow differs — no Keychain)
- [ ] Windows support (Docker Desktop + WSL2 path mapping)
- [ ] Publish image to Docker Hub to skip the local build step
- [ ] Multi-arch `docker buildx` for pre-built image distribution

## License

MIT — see [LICENSE](LICENSE).
