# brew upgrade failed : should display more details

> [2026-06-22 21:42:27] Warning: brew upgrade failed

When an error occurs, we often only see "brew upgrade failed" at the end and nothing else. There should be a list of package and an error log to a specific file.

# confusing error with permissions and brew cleanup

> [2026-06-22 21:42:24] Updating Homebrew with casks...
> [2026-06-22 21:42:27] Warning: brew upgrade failed
> Removing: /opt/homebrew/Cellar/python@3.13/3.13.13_1... (2,727 files, 50.4MB)
> Warning: Permission denied @ apply2files - /opt/homebrew/Cellar/python@3.13/3.13.13_1/Frameworks/Python.framework/Versions/3.13/lib/python3.13/encodings/__pycache__/utf_8_sig.cpython-313.pyc
> ==> This operation has freed approximately 50.4MB of disk space.
> Error: Could not cleanup old kegs! Fix your permissions on:
>   /opt/homebrew/Cellar/python@3.13/3.13.13_1
> [2026-06-22 21:42:38] Warning: brew cleanup failed

i am not sure if this is an error with brew upgrade or brew cleanup. Also, the permission error should have a solution listed and/or a link to a longer error log

# spark : only update outdated

> PROGRESS:Updating Sparkle apps
> [2026-06-22 21:43:06] Updating Sparkle apps...
> AppCleaner: installed 3.6.8 → latest stable 3.6.8
>   download: https://rawcdn.githack.com/freemacsoft/appcleaner/8c3b52858a454d14fba343cf565ff710eaff4bcd/AppCleaner_3.6.8.zip
> ✓ already up to date (installed 3.6.8 ≥ stable 3.6.8).
> ✗ no stable version found in appcast.

it looks like we try to update all sparkle apps and not only those that are outdated. Also, the line starting with "PROGRESS" is not in the same format. Are we depending on anteres ? I think it would be better to adapt the script and include it in the current software. if not possible, cane we include it as a pre requirements (maybe a sub git) ?

# spark update errors : no messages

> [2026-06-22 21:43:07] Warning: Sparkle update failed for cmux

we should have more info. ideally, it would be summarize in a one-liner. if not possible, let's link to a bigger error log
