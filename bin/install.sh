#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR/..

# Download submodules
git submodule update --init --recursive

# If .bashrc is autogenerated, rename it to .bash_default
if [[ "$(cat ~/.bashrc | grep "~/.bashrc: executed by bash(1) for non-login shells." )" ]]; then
  mv ~/.bashrc ~/.bash_default
fi

# Copy files to home directory
cp -r .zsh_custom ~
cp -r .shell_config ~
cp .bashrc ~
cp .zshrc ~
cp .vimrc ~

# Create .shell_paths and .shell_local if they don't exist
touch ~/.shell_config/shell_paths
touch ~/.shell_config/shell_local

