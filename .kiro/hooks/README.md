# .kiro/hooks

This directory holds hook definition files that drive `tukuy watch`.
Each `.json` file corresponds to one hook.

## Hook JSON fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Stable identifier for the hook (filename stem for user hooks). |
| `event` | `"add"` | `"change"` | `"unlink"` | Filesystem event type that triggers the hook. |
| `glob` | string | picomatch glob pattern (cwd-relative) to match against changed paths. |
| `action` | string | Agent instruction / prompt passed to the AI agent via `-p`. |
| `enabled` | boolean | Whether the hook is active. Set to `false` to disable. Defaults to `true` when absent. |
| `maxTokens` | number | Per-hook token ceiling for the agent response. Falls back to the configured default when absent. |
| `debounceMs` | number | Debounce window in milliseconds. Rapid events within this window are collapsed into one dispatch. |
| `source` | `"built-in"` | `"user"` | Set automatically. `"built-in"` hooks ship with tukuy; `"user"` hooks are created by you. |

## How to disable a built-in hook

Set `enabled` to `false` in the corresponding JSON file. For example, to disable the
`spec-drift` hook open `.kiro/hooks/spec-drift.json` and change:

```json
{
  "enabled": false
}
```

The change takes effect the next time `tukuy watch` starts.

## Adding your own hooks

Create a new `.json` file in this directory with the fields above.
The filename stem becomes the hook id. For example, `.kiro/hooks/my-hook.json` has id `my-hook`.
