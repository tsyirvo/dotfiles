Configuration for my personal needs using macOS, Fish shell, Git, and web development.

This is highly inspired from other dotfiles.

# Usage and the Install

**Caveats:**
If you are on any version of macOS that uses AFPS, you'll need to disable the SIP.
First check to see if SIP is enabled or not.

```shell
csrutil status
```

output should read:

```shell
System Integrity Protection status: enabled.
```

If your SIP is enabled, then follow the next steps to disable it – Assuming that you know what you're doing, here is how to turn off System Integrity Protection on your Mac.

1. Turn off your Mac (Apple > Shut Down).
2. Hold down Command-R and press the Power button. Keep holding Command-R until the Apple logo appears.
3. Wait for OS X to boot into the OS X Utilities window.
4. Choose Utilities > Terminal.
5. Enter csrutil disable.
6. Enter reboot.
7. `csrutil status` -> should read `System Integrity Protection status: disabled.`

Once that's done you can follow this:

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

5. A final touch that I didn't automate yet is to set all my dev environment theme to use [Nord Theme](https://www.nordtheme.com/). This also implies to use the correct Nerd Fonts already insalled.
