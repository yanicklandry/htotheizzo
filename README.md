# htotheizzo

[![Join the chat at https://gitter.im/yanicklandry/htotheizzo](https://badges.gitter.im/yanicklandry/htotheizzo.svg)](https://gitter.im/yanicklandry/htotheizzo?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Update script to update Homebrew, NPM and Gem packages all at once.

Originally from https://gist.github.com/jfrazelle/57dbf1fccfa02151ff3f, I only very slightly adapted it.

## Requirements

Optional : https://github.com/kcrawford/dockutil to auto update from Dock

## Setup

- Make sure directory exists : `mkdir -p ~/bin`
- Clone to local : `git clone git@github.com:yanicklandry/htotheizzo.git ~/bin/.htotheizzo`
- Link : `ln -s ~/bin/.htotheizzo/htotheizzo.sh ~/bin/htotheizzo.sh`
- Permissions : `chmod a+x ~/bin/htotheizzo.sh`
- Make sure directory is executable : `edit ~/.bashrc` and add `export PATH="$PATH:$HOME/bin"`
