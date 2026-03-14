#!/usr/bin/env bash
# install.sh — Install ccsafe to ~/.ccsafe and wire up your shell
set -e

INSTALL_DIR="$HOME/.ccsafe"
SHELL_RC=""

echo "📦 Installing ccsafe..."

# ── Detect shell ──────────────────────────────────────────────────────────────
if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    echo "⚠️  Could not detect shell. Please add the source line manually."
    SHELL_RC="$HOME/.profile"
fi

# ── Copy files ────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/Dockerfile" "$INSTALL_DIR/Dockerfile"
cp "$SCRIPT_DIR/ccsafe.sh" "$INSTALL_DIR/ccsafe.sh"
chmod +x "$INSTALL_DIR/ccsafe.sh"

echo "✅ Files installed to $INSTALL_DIR"

# ── Wire up shell ─────────────────────────────────────────────────────────────
SOURCE_LINE="# ccsafe — Claude Code sandbox"$'\n'"source \"$INSTALL_DIR/ccsafe.sh\""

if grep -q "ccsafe" "$SHELL_RC" 2>/dev/null; then
    echo "✅ Shell already configured in $SHELL_RC (skipping)"
else
    echo "" >> "$SHELL_RC"
    echo "$SOURCE_LINE" >> "$SHELL_RC"
    echo "✅ Added source line to $SHELL_RC"
fi

# ── Build image ───────────────────────────────────────────────────────────────
echo ""
echo "🔨 Building Docker image (this takes ~2-3 min, once only)..."
docker build \
    --platform linux/arm64 \
    -t ccsafe:latest \
    "$INSTALL_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ccsafe installed!"
echo ""
echo "Reload your shell:"
echo "   source $SHELL_RC"
echo ""
echo "Then use it:"
echo "   ccsafe              # sandbox current directory"
echo "   ccsafe ~/projects/myapp  # sandbox a specific directory"
echo "   ccsafe --build      # rebuild after Dockerfile changes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
