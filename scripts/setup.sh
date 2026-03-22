#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Setting up Deckard development environment"

# Check for Xcode
if ! command -v xcodebuild &>/dev/null; then
    echo "Error: Xcode is not installed."
    exit 1
fi

# Install git hooks
echo "==> Installing git hooks"
ln -sf ../../scripts/pre-commit "$PROJECT_DIR/.git/hooks/pre-commit"

echo "==> Setup complete!"
echo "You can now open Deckard.xcodeproj in Xcode or build with xcodebuild."
