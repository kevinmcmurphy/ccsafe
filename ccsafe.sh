#!/usr/bin/env bash
# ccsafe — Launch Claude Code in a sandboxed Docker container
#
# USAGE:
#   ccsafe                        # sandbox current directory
#   ccsafe /path/to/dir           # sandbox a specific directory
#   ccsafe --memory 4g            # override memory limit for this session
#   ccsafe --cpus 6               # override CPU limit for this session
#   ccsafe --memory 4g --cpus 6 /path  # combine flags with directory
#   ccsafe --build                # rebuild the Docker image
#   ccsafe --help                 # show this help
#
# DEFAULTS (override by setting env vars in your shell RC):
#   CCSAFE_MEMORY=2g              # safe default for Mac Mini M4 (16GB)
#   CCSAFE_CPUS=4                 # leave headroom for Cowork + Ollama
#
# AUTH:
#   Automatically extracts your Claude Max/Pro OAuth token from the macOS
#   Keychain at launch time. No plaintext secrets in config files.
#   Just run `claude auth login` on your host once — ccsafe handles the rest.
#
# MOUNTS:
#   $(pwd) or specified path  →  /workspace             (read/write)
#   ~/.claude                 →  /home/claude/.claude   (read-write)
#
# Everything else on your filesystem is inaccessible to the container.

CCSAFE_IMAGE="ccsafe:latest"
CCSAFE_DIR="$HOME/.ccsafe"

# ── Defaults (override in your shell RC via env vars) ─────────────────────────
CCSAFE_MEMORY="${CCSAFE_MEMORY:-2g}"
CCSAFE_CPUS="${CCSAFE_CPUS:-4}"

# ── Build ─────────────────────────────────────────────────────────────────────
_ccsafe_build() {
    echo "🔨 Building ccsafe image..."
    if [ ! -f "$CCSAFE_DIR/Dockerfile" ]; then
        echo "❌ Dockerfile not found at $CCSAFE_DIR/Dockerfile"
        return 1
    fi
    docker build \
        --platform linux/arm64 \
        -t "$CCSAFE_IMAGE" \
        "$CCSAFE_DIR"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "✅ ccsafe image built successfully."
    else
        echo "❌ Build failed (exit $exit_code)."
        return $exit_code
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
ccsafe() {
    local memory="$CCSAFE_MEMORY"
    local cpus="$CCSAFE_CPUS"
    local target_dir=""

    # ── Parse flags ───────────────────────────────────────────────────────────
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --build)
                _ccsafe_build
                return $?
                ;;
            --help|-h)
                echo "ccsafe — Claude Code sandboxed launcher"
                echo ""
                echo "Usage:"
                echo "  ccsafe                        Sandbox current directory"
                echo "  ccsafe /path/to/dir           Sandbox a specific directory"
                echo "  ccsafe --memory 4g            Override memory limit"
                echo "  ccsafe --cpus 6               Override CPU limit"
                echo "  ccsafe --build                Rebuild the Docker image"
                echo "  ccsafe --help                 Show this help"
                echo ""
                echo "Defaults:"
                echo "  Memory : $CCSAFE_MEMORY (set CCSAFE_MEMORY in shell RC to change)"
                echo "  CPUs   : $CCSAFE_CPUS   (set CCSAFE_CPUS in shell RC to change)"
                return 0
                ;;
            --memory)
                shift
                memory="$1"
                shift
                ;;
            --cpus)
                shift
                cpus="$1"
                shift
                ;;
            -*)
                echo "❌ Unknown flag: $1"
                echo "   Run 'ccsafe --help' for usage."
                return 1
                ;;
            *)
                target_dir="$1"
                shift
                ;;
        esac
    done

    # ── Resolve target directory ──────────────────────────────────────────────
    if [ -n "$target_dir" ]; then
        if [ ! -d "$target_dir" ]; then
            echo "❌ '$target_dir' is not a valid directory."
            return 1
        fi
        target_dir="$(cd "$target_dir" && pwd)"
    else
        target_dir="$(pwd)"
    fi

    # ── Validate memory format (basic guard) ──────────────────────────────────
    if ! [[ "$memory" =~ ^[0-9]+(\.[0-9]+)?[kmgKMG]$ ]]; then
        echo "❌ Invalid memory value: '$memory' (examples: 2g, 512m, 4g)"
        return 1
    fi

    # ── Check image exists; auto-build if not ────────────────────────────────
    if ! docker image inspect "$CCSAFE_IMAGE" &>/dev/null; then
        echo "⚠️  ccsafe image not found. Building now (one-time, ~2-3 min)..."
        _ccsafe_build || return 1
        echo ""
    fi

    # ── Warn if ~/.claude is missing ──────────────────────────────────────────
    if [ ! -d "$HOME/.claude" ]; then
        echo "⚠️  ~/.claude not found — launching without config or skills."
    fi

    # ── Optional mounts (only added if paths exist on host) ───────────────────
    local extra_mounts=()
    if [ -d "$HOME/.local/bin" ]; then
        extra_mounts+=(--volume "$HOME/.local/bin:/home/claude/.local/bin:ro")
    fi

    # ── Extract auth from macOS Keychain ────────────────────────────────────
    local auth_env=()
    local oauth_token=""

    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        # Explicit env var takes priority
        oauth_token="$CLAUDE_CODE_OAUTH_TOKEN"
    else
        # Extract OAuth access token from macOS Keychain (where Claude Code stores it)
        local creds_json=""
        creds_json="$(security find-generic-password -s "Claude Code-credentials" -a "$(whoami)" -w 2>/dev/null)" || true

        if [ -n "$creds_json" ]; then
            oauth_token="$(echo "$creds_json" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("claudeAiOauth",{}).get("accessToken",""))' 2>/dev/null)" || true
        fi
    fi

    if [ -n "$oauth_token" ]; then
        auth_env+=(--env "CLAUDE_CODE_OAUTH_TOKEN=$oauth_token")
    elif [ -n "$ANTHROPIC_API_KEY" ]; then
        auth_env+=(--env "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    else
        echo "⚠️  No auth found. Could not read from macOS Keychain."
        echo "   Run 'claude auth login' on your host first."
        echo ""
    fi

    echo "🚀 ccsafe"
    echo "   Workspace : $target_dir"
    echo "   Config    : $HOME/.claude (writable overlay)"
    echo "   Memory    : $memory"
    echo "   CPUs      : $cpus"
    echo ""

    docker run \
        --rm \
        --interactive \
        --tty \
        --platform linux/arm64 \
        --volume "$target_dir:/workspace:rw" \
        --volume "$HOME/.claude:/home/claude/.claude:rw" \
        --volume "$HOME/.claude.json:/home/claude/.claude.json:rw" \
        "${extra_mounts[@]}" \
        --workdir /workspace \
        "${auth_env[@]}" \
        --env "PATH=/home/claude/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        --memory="$memory" \
        --cpus="$cpus" \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        "$CCSAFE_IMAGE"
}
