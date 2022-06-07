# htotheizzo

[![Join the chat at https://gitter.im/yanicklandry/htotheizzo](https://badges.gitter.im/yanicklandry/htotheizzo.svg)](https://gitter.im/yanicklandry/htotheizzo?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Update script to update Homebrew, NPM and Gem packages all at once.

Originally from https://gist.github.com/jfrazelle/57dbf1fccfa02151ff3f, I only very slightly adapted it.

## Requirements

Optional : https://github.com/kcrawford/dockutil to auto update from Dock

## Setup

```
mkdir -p ~/bin # Make sure directory exists
git clone https://github.com/yanicklandry/htotheizzo.git ~/bin/.htotheizzo # Clone to local
ln -s ~/bin/.htotheizzo/htotheizzo.sh ~/bin/htotheizzo.sh # Link
chmod a+x ~/bin/htotheizzo.sh # Permissions
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc # Make sure directory is executable
source ~/.bashrc
```

### Setup on Linux

On Linux, do this additional step to allow you to run HomeBrew on Linux as root :

```
sudo echo "sudo -u $(whoami) $(which brew) \$@" > /usr/local/bin/brew
sudo chmod a+x /usr/local/bin/brew
```

## Usage

It's better to have sudo authorization while still being logged as your user. For example :

```
sudo ls
# enter your password
htotheizzo.sh
```

### Skip one command

Example :

```
skip_kav=1 skip_mas=1 htotheizzo.sh
```
