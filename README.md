# Dotfiles

> Alacritty, Sway, Waybar, Vim — managed with **GNU Stow**.

## Layout

Dotfiles that belong in `$HOME` live under the **`home/`** stow package:

```
home/
  .config/sway/...
  .config/waybar/...
  .config/alacritty/...
  .vimrc
  Wallpapers/   # optional
```

Install by stowing that package into your home directory (see below).

## Requirements

### Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y git stow
```

### Fedora

```bash
sudo dnf install -y git stow
```

### Arch Linux

```bash
sudo pacman -S git stow
```

(Node.js / Yarn are optional; only needed if you use `setup.sh` for dev tooling.)

## Installation (stow)

```bash
git clone https://github.com/osmancoskun/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
stow --restow --target="$HOME" home
```

- **`--restow`** refreshes symlinks after you `git pull`.
- If a file already exists and stow refuses: see **`man stow`** (`--adopt` is destructive; back up first).

## Optional: full bootstrap

```bash
cd ~/.dotfiles
./setup.sh
```

This installs extra packages (browsers, Node, Oh My Zsh, etc.) and then runs **`stow home`** for you.
