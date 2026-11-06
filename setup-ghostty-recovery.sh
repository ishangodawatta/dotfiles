#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Ghostty recovery setup requires macOS."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/setup-symlinks.sh"

# Prefer a stable Homebrew path over an NVM version directory for launchd.
recovery_node=""
for candidate in /opt/homebrew/bin/node /usr/local/bin/node; do
  if [[ -x "$candidate" ]]; then recovery_node="$candidate"; break; fi
done
if [[ -z "$recovery_node" ]]; then recovery_node="$(command -v node || true)"; fi
if [[ -z "$recovery_node" ]] || ! "$recovery_node" -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)'; then
  echo "Install Node.js 18 or newer, then rerun this script."
  exit 1
fi

ghostty_info="/Applications/Ghostty.app/Contents/Info.plist"
if [[ ! -f "$ghostty_info" ]]; then
  echo "Install Ghostty 1.4 or newer in /Applications first."
  exit 1
fi
ghostty_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ghostty_info")
"$recovery_node" -e 'const [major, minor] = process.argv[1].split(".").map(Number); if (!(major > 1 || major === 1 && minor >= 4)) { console.error("Ghostty 1.4 or newer is required"); process.exit(1); }' "$ghostty_version"

recovery_script="$SCRIPT_DIR/vendor/ghostty-resurrect/bin/ghostty-resurrect"
"$recovery_node" "$recovery_script" --help >/dev/null
link_ghostty_recovery

agent_label="local.ghostty-resurrect"
agent_domain="gui/$(id -u)"
agent_file="$HOME/Library/LaunchAgents/$agent_label.plist"
generated_plist=$(mktemp "${TMPDIR:-/tmp}/ghostty-resurrect-plist.XXXXXX")
trap 'rm -f "$generated_plist"' EXIT
agent_path="$(dirname "$recovery_node"):/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

"$recovery_node" - "$SCRIPT_DIR/launchagents/$agent_label.plist" "$generated_plist" "$recovery_node" "$recovery_script" "$agent_path" <<'NODE'
const fs = require('node:fs');
const [template, output, node, script, searchPath] = process.argv.slice(2);
const escape = (value) => value.replace(/[&<>"']/g, (c) => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&apos;'}[c]));
let text = fs.readFileSync(template, 'utf8');
for (const [key, value] of Object.entries({__NODE__: node, __SCRIPT__: script, __PATH__: searchPath})) text = text.replaceAll(key, escape(value));
fs.writeFileSync(output, text);
NODE

/usr/bin/plutil -lint "$generated_plist"
mkdir -p "$HOME/Library/LaunchAgents"
if [[ ! -f "$agent_file" ]] || ! cmp -s "$generated_plist" "$agent_file"; then
  install -m 644 "$generated_plist" "$agent_file"
fi

# Attempt the first capture interactively so any Automation prompt is visible.
if ! "$recovery_node" "$recovery_script" auto-backup; then
  echo "Initial capture needs attention; the scheduled job will retry. Check ghostty-resurrect status."
fi
/bin/launchctl bootout "$agent_domain/$agent_label" >/dev/null 2>&1 || true
/bin/launchctl enable "$agent_domain/$agent_label"
/bin/launchctl bootstrap "$agent_domain" "$agent_file"
echo "Automatic Ghostty backups scheduled every 15 seconds and at login."
echo "Check: ghostty-resurrect status"
echo "Recover: ghostty-resurrect restore --missing"
