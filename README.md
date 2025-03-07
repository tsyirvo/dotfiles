Configuration for my personal needs using macOS, Fish shell, Git, and web/mobile development.

This is highly inspired from other dotfiles.

# My setup on a new machine

- Check for sofware updates if any
- Install Xcode from the App Store
- Install Xcode command line tools
- Install Homebrew with: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`. Do not forget to add Homebrew to `PATH`
- Restore backed up ssh keys, or [generate new ones](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/).
- Install [stow](https://www.gnu.org/software/stow) to manage symlinks
- Setup a language runtimes manager. I use [mise](https://mise.jdx.dev/) that work with what I frequently use (Node, Ruby and Python).
- Clone this repository with: `git clone git@github.com:tsyirvo/dotfiles.git`
- Install all apps and binaries with: `./packages/setup.sh`
- Configure macOS settings whit: `./macos/setup.sh`
