# Dotfiles

> My dot files for Alacritty, Sway, Waybar, Vim

## Requirements

### Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y git stow nodejs yarn
```

### Fedora

```bash
sudo dnf install -y git stow nodejs yarn
```

### Arch Linux

```bash
sudo pacman -S git stow nodejs yarn
```

## Installation

```bash
git clone https://github.com/osmancoskun/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow .
```
