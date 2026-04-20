# Dotfiles

This repository contains my personal dotfiles and configurations for various applications and tools I use.

### Setup

```sh
brew install stow
./setup
```

---

### Installing apps

```sh
brew install --cask ghostty
brew install --cask nikitabobko/tap/aerospace
brew install starship
brew install eza
brew install btop

brew install neovim
brew install ripgrep
brew install fd

brew install nodenv
```

### Auto wallpaper (light/dark mode)

Switches the wallpaper automatically when the system toggles between Light and Dark mode. Uses a LaunchAgent with `WatchPaths` on `.GlobalPreferences.plist` — event-driven, no polling, zero dependencies.

The source is `.wallpapers/change-wallpaper.swift` (Swift). `./setup` compiles it to a native binary at `~/.local/bin/change-wallpaper` for instant execution.

**Recompile after editing the source:**

```sh
swiftc ~/.wallpapers/change-wallpaper.swift -o ~/.local/bin/change-wallpaper
```

**Test manually:**

```sh
~/.local/bin/change-wallpaper

# Force light mode temporarily
defaults delete -g AppleInterfaceStyle && ~/.local/bin/change-wallpaper

# Restore dark mode
defaults write -g AppleInterfaceStyle Dark && ~/.local/bin/change-wallpaper
```

**Reload the agent after editing the plist:**

```sh
launchctl bootout gui/$(id -u)/sh.celo.change-wallpaper
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/sh.celo.change-wallpaper.plist
```

**Remove:**

```sh
launchctl bootout gui/$(id -u)/sh.celo.change-wallpaper
rm ~/Library/LaunchAgents/sh.celo.change-wallpaper.plist
rm ~/.local/bin/change-wallpaper
```

### Links to Applications

Some applications require additional setup or configuration. Below are links to their respective documentation or websites:

- [Ghostty](https://github.com/ghostty-org/ghostty)
- [Aerospace](https://github.com/nikitabobko/AeroSpace)
- [Starship](https://github.com/starship/starship)

- [Neovim](https://github.com/neovim/neovim/blob/master/INSTALL.md)

- [Nodenv](https://github.com/nodenv/nodenv?tab=readme-ov-file#installation)
