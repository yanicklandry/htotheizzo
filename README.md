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
