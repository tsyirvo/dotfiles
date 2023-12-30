Configuration for my personal needs using macOS, Fish shell, Git, and web/mobile development.

This is highly inspired from other dotfiles.

# Usage and the Install

**Caveats:**
If you are on any version of macOS that uses AFPS, you'll need to disable the System Integrity Protection (SIP) temporarily to perform certain tasks. If not disabled, it will make the automated steps of the setup fail due to some builin protections from MacOS.
First check to see if SIP is enabled or not with: `csrutil status`. The output should read: `System Integrity Protection status: enabled.`.

If your SIP is enabled, follow the next steps to disable it (or [on Apple documentation](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection#3599244)). Assuming that you know what you're doing, here is how to turn off SIP on your Mac.

1. Turn off your Mac
2. Reboot the Mac in [Recovery mode](https://support.apple.com/en-us/HT201314)
3. Wait for OS X to boot, and got to the Options
4. Choose Utilities > Terminal
5. Enter `csrutil disable`
6. Reboot the Mac
7. Entering `csrutil status` should read `System Integrity Protection status: disabled.`

Once that's done you can proceed to the steps below, but do not forget to turn it back on once the setup if finished. It could leave your computer vulnerable to malicious code.

# Installation steps

- Login to your Apple account to restore synchronized data
- Check for sofware updates if any
- Install Xcode from the App Store
- Install Homebrew with: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`. Do not forget to add Homebrew to the `PATH`
- Restore your backed up ssh keys, or [generate new ones](https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/). Once done, add them to your GitHub account or wherever needed.
- Install Node now, since it's required for some automated steps later on. I personnaly use to manage my Node version so:

- It's best to install Node (with [Volta](https://volta.sh/)), Ruby (with [rbenv](https://github.com/rbenv/rbenv)) and Python (with [pyenv](https://github.com/pyenv/pyenv)) now since it can be used in the automated steps later. You'll need the following:

  - For Node:

  ```bash
    curl https://get.volta.sh | bash
    volta install node
    node -v
  ```

  - For Ruby:

  ```
  brew install rbenv
  rbenv install 3.3.0
  rbenv global 3.3.0
  ruby -v
  ```

  - For Python:

  ```
  brew install pyenv
  pyenv install 3.11.6
  pyenv global 3.11.6
  python --version
  ```

- Clone this repository with: `git clone git@github.com:tsyirvo/dotfiles.git`
- Look for `TODO(env)` comments that might need tweaking depending on the target machine
- Run the `bootstrap.sh` script, or alternatively, only run the `setup.sh` scripts in specific subfolder if you don't need everything

# Extra stuff to do manually

- Set the correct DNS settings
- Tweak the few OS settings not automated, as well as some Finder config
- Restore the fish history file
- Add VS Code `code` to the `PATH` from the command panel
- Setup Dashlane
- Tweak iTerm 2 config to use the [Nord Theme](https://www.nordtheme.com/) and set the correct font
- Set permissions for audio, video recording and such for work related apps
- Restore all personnal data
- Checkout all the necessary repositories
