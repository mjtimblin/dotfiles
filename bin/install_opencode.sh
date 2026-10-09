#!/bin/bash
#
# Set up opencode and its configuration for the current user:
#   - ~/.config/opencode   (opencode config, rules, model sync scripts)
#   - ~/.config/cortexkit  (cortexkit aft config)
#   - ~/.agents            (agent skills)
# Then sync the LiteLLM provider model list.
#
# Usage:
#   ./bin/install_opencode.sh
#
# Environment:
#   LITELLM_API_KEY  (required for the model sync step)

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR=$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )

mkdir -p ~/.config/opencode
mkdir -p ~/.config/cortexkit
mkdir -p ~/.agents

# Copy files to home directory
cp -r "$REPO_DIR"/config/opencode/* ~/.config/opencode/
cp -r "$REPO_DIR"/config/cortexkit/* ~/.config/cortexkit/
cp -r "$REPO_DIR"/agents/* ~/.agents

# Sync the LiteLLM models (requires LITELLM_API_KEY)
~/.config/opencode/update_litellm_models.sh ~/.config/opencode/opencode.jsonc
