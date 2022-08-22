Configuration for my personal needs using macOS, Fish shell, Git, and web development.

This is highly inspired from other dotfiles.

---

# Usage and the Install

1. Restore your safely backed up ssh keys to `~/.ssh/`

   1. Alternatively, [generate new ssh keys](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/), and add these to your GitHub account.

2. Install Homebrew, Git and Node

```bash
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
```

```bash
  brew install git
```

I use [Volta](https://volta.sh/) to manage my Node version so:

```bash
  curl https://get.volta.sh | bash

  volta install node
```

3. Clone this repository

```
git clone git@github.com:tsyirvo/dotfiles.git
```

4. Run the `bootstrap.sh` script

   1. Alternatively, only run the `setup.sh` scripts in specific subfolder if you don't need everything

5. Install [Fisher](https://github.com/jorgebucaran/fisher) and Plugins -- _Optional_

```bash
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
fisher
```
