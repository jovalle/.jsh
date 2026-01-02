#!/bin/bash
# jsh test container entrypoint
# Selects shell based on JSH_TEST_SHELL env var (default: zsh)

set -e

SHELL_CMD="${JSH_TEST_SHELL:-zsh}"

# Validate shell
case "$SHELL_CMD" in
    bash|zsh)
        ;;
    *)
        echo "Error: Invalid shell '$SHELL_CMD'. Use 'bash' or 'zsh'."
        exit 1
        ;;
esac

echo "================================================"
echo "  jsh test container"
echo "  Shell: $SHELL_CMD"
echo "  jsh mounted at: ~/.jsh"
echo "================================================"
echo ""
echo "To initialize jsh, run:"
echo "  source ~/.jsh/dotfiles/.jshrc   # or .bashrc for bash"
echo ""

exec "$SHELL_CMD" -l
