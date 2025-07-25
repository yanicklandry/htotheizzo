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

## Automated Scheduling with Cron

For automatic updates, you can schedule htotheizzo using cron. The recommended frequency is **weekly** as it provides a good balance between keeping packages updated for security and maintaining system stability.

Here are recommended schedules:

### Weekly Updates (Recommended)
```bash
# Edit crontab
crontab -e

# Add this line for weekly updates on Sundays at 2 AM (replace 'username' with your actual username)
0 2 * * 0 /Users/username/bin/htotheizzo.sh >> /Users/username/logs/htotheizzo.log 2>&1
```

### Other Scheduling Options
```bash
# Daily updates at 3 AM (for development machines)
0 3 * * * /Users/username/bin/htotheizzo.sh >> /Users/username/logs/htotheizzo.log 2>&1

# Bi-weekly updates (1st and 15th of each month at 2 AM)
0 2 1,15 * * /Users/username/bin/htotheizzo.sh >> /Users/username/logs/htotheizzo.log 2>&1

# Weekday updates at 1 AM (Monday-Friday)
0 1 * * 1-5 /Users/username/bin/htotheizzo.sh >> /Users/username/logs/htotheizzo.log 2>&1
```

### Setup Steps for Automated Updates

1. **Create log directory:**
   ```bash
   mkdir -p ~/logs
   ```

2. **Get your username and script path:**
   ```bash
   whoami
   which htotheizzo.sh
   # Use these exact paths in your crontab (replace 'username' in examples above)
   ```

3. **Add to crontab:**
   ```bash
   # If you get editor errors, set the editor first:
   export EDITOR=nano
   crontab -e
   # Add your chosen schedule from above
   
   # Alternative: Create crontab file directly
   echo "0 2 * * 0 /Users/$(whoami)/bin/htotheizzo.sh >> /Users/$(whoami)/logs/htotheizzo.log 2>&1" | crontab -
   ```

4. **Verify cron job:**
   ```bash
   crontab -l
   ```

### Important Cron Considerations

- **MacBook sleep mode**: Cron jobs won't run when your MacBook lid is closed (sleep mode). For reliable automation, keep your MacBook plugged in and awake, or use `caffeinate` command
- **Sudo access**: For automated runs, consider configuring passwordless sudo for specific commands or run as root (not recommended)
- **Environment variables**: Cron has a minimal environment, so use full paths
- **Logging**: Always redirect output to a log file to troubleshoot issues
- **Network connectivity**: Ensure the system has internet access during scheduled runs
- **System load**: Schedule during low-usage periods (typically early morning)

### Keeping MacBook Awake for Cron Jobs

If you want cron jobs to run with the lid closed:

```bash
# Prevent sleep while plugged in (run before closing lid)
sudo pmset -c sleep 0

# Or use caffeinate to keep system awake during updates
0 2 * * 0 /usr/bin/caffeinate -s /Users/username/bin/htotheizzo.sh >> /Users/username/logs/htotheizzo.log 2>&1

# Reset sleep settings (optional)
sudo pmset -c sleep 10
```
