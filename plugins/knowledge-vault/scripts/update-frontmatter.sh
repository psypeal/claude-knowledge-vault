#!/bin/bash
# knowledge-vault: Update YAML frontmatter fields without reading the full file.
# Avoids a model-side full-file read when only frontmatter changes.
# Usage: bash update-frontmatter.sh <file> <key=value> [key=value...]
# Example: bash update-frontmatter.sh .vault/raw/paper.md compiled=true

set -euo pipefail

FILE="${1:?Usage: update-frontmatter.sh <file> <key=value> [key=value...]}"
shift

if [ ! -f "$FILE" ]; then
    echo "Error: $FILE not found"
    exit 1
fi

python3 - "$FILE" "$@" << 'PYEOF'
import re
import sys

filepath = sys.argv[1]
updates = {}
for arg in sys.argv[2:]:
    if '=' not in arg:
        print(f"Error: invalid update '{arg}' (expected key=value)")
        sys.exit(1)
    key, _, val = arg.partition('=')
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]*', key):
        print(f"Error: invalid frontmatter key '{key}'")
        sys.exit(1)
    if '\n' in val or '\r' in val:
        print(f"Error: multiline values are not supported for '{key}'")
        sys.exit(1)
    # Handle booleans
    if val.lower() == 'true':
        val = 'true'
    elif val.lower() == 'false':
        val = 'false'
    updates[key] = val


def yaml_value(value):
    """Return a safe YAML scalar while preserving booleans and numbers."""
    if value in ('true', 'false', 'null'):
        return value
    if value == '':
        return '""'
    try:
        float(value)
        return value
    except ValueError:
        pass
    needs_quoting = (
        ': ' in value
        or value.endswith(':')
        or ' #' in value
        or value[0] in "'\"{[#&*!|>%@`"
        or value != value.strip()
    )
    if needs_quoting:
        escaped = value.replace('\\', '\\\\').replace('"', '\\"')
        return f'"{escaped}"'
    return value

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

if not content.startswith('---'):
    print('Error: no frontmatter found')
    sys.exit(1)

parts = content.split('---', 2)
if len(parts) < 3:
    print('Error: malformed frontmatter')
    sys.exit(1)

fm_lines = parts[1].strip().split('\n')
new_fm_lines = []
updated_keys = set()

for line in fm_lines:
    if ':' in line:
        key = line.split(':')[0].strip()
        if key in updates:
            new_fm_lines.append(f'{key}: {yaml_value(updates[key])}')
            updated_keys.add(key)
            continue
    new_fm_lines.append(line)

# Add any new keys not already in frontmatter
for key, val in updates.items():
    if key not in updated_keys:
        new_fm_lines.append(f'{key}: {yaml_value(val)}')

new_content = '---\n' + '\n'.join(new_fm_lines) + '\n---' + parts[2]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f'Updated {filepath}: {list(updates.keys())}')
PYEOF
