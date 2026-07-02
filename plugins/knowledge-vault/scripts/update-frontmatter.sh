#!/bin/bash
# knowledge-vault: Update YAML frontmatter fields without reading the full file.
# Replaces Claude re-reading entire raw files (~2K-8K tokens) just to flip a flag.
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
import sys

filepath = sys.argv[1]
updates = {}
for arg in sys.argv[2:]:
    key, _, val = arg.partition('=')
    updates[key] = val


def yaml_value(val):
    """Quote values that would be ambiguous or invalid as bare YAML scalars."""
    if val in ('true', 'false') or val == '':
        return val
    try:
        float(val)
        return val
    except ValueError:
        pass
    needs_quoting = (
        ': ' in val or val.endswith(':')
        or ' #' in val
        or val[0] in "'\"{[#&*!|>%@`"
        or val != val.strip()
    )
    if needs_quoting:
        return '"' + val.replace('\\', '\\\\').replace('"', '\\"') + '"'
    return val


with open(filepath, 'r') as f:
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

with open(filepath, 'w') as f:
    f.write(new_content)

print(f'Updated {filepath}: {list(updates.keys())}')
PYEOF
