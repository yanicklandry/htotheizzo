# htotheizzo

Update script to update Homebrew, NPM and Gem packages all at once.

Originally from https://gist.github.com/jfrazelle/57dbf1fccfa02151ff3f, I only very slightly adapted it.

## Setup

- Make sure directory exists : `mkdir -p ~/bin`
- Clone to local : `git clone git@github.com:yanicklandry/htotheizzo.git ~/bin/.htotheizzo`
- Link : `ln -s ~/bin/.htotheizzo/htotheizzo.sh ~/bin/htotheizzo.sh`
- Permissions : `chmod a+x ~/bin/htotheizzo.sh`
- Make sure directory is executable : `edit ~/.bashrc` and add `export PATH="$PATH:$HOME/bin"`
