# .dotfiles

A personal dotfiles repository for managing MacOS development environment configuration.

## Overview

This repository contains configuration files and setup scripts to quickly set up a consistent development environment on MacOS. It includes:

- Shell configuration (ZSH)
- Package management via Homebrew
- Terminal customization with Starship prompt
- Development tools and utilities
- Project scaffolding script

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/.dotfiles.git ~/.dotfiles

# Run the install script
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

## Features

### Shell Configuration

- Custom ZSH configuration with performance optimizations
- Lazy-loading of NVM for faster shell startup
- Useful shell functions and aliases
- Integration with modern command-line tools
- Syntax highlighting and autosuggestions
- Command history improvements

### Development Tools

The Brewfile installs a curated set of development tools:

- **Shell Utilities**: zsh, starship, fzf, bat, eza, ripgrep, fd
- **Development Tools**: git, node, yarn, go, neovim
- **System Tools**: btop, htop, coreutils
- **CLI Tools**: jq, yq, gh (GitHub CLI)

### Terminal Customization

- Starship prompt configuration for a clean and informative terminal
- Nerd Font installation for proper terminal icons
- Ghostty terminal emulator

### Project Scaffolding

The `scaffold.sh` script provides a convenient way to clone and initialize projects from template repositories:

```bash
# Usage
scaffold <scaffold-name> <project-name>

# Example
scaffold frontend my-project
```

## File Structure

- `install.sh` - Main installation script
- `zshrc.sh` - ZSH configuration
- `Brewfile` - Homebrew packages and applications
- `starship.toml` - Starship prompt configuration
- `scaffold.sh` - Project scaffolding script
- `aliases.local.sh` - Custom aliases

## Customization

You can customize your environment by:

1. Modifying the `Brewfile` to add/remove packages
2. Editing `zshrc.sh` to adjust shell configuration
3. Updating `starship.toml` for prompt customization
4. Creating/editing `.env.secrets.sh` (not tracked by git) for environment variables
5. Creating/editing `aliases.local.sh` for custom aliases

## License

MIT