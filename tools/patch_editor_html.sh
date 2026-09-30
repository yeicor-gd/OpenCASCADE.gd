#!/usr/bin/env bash
# Patch the Godot web editor HTML to auto-open a project from a preloaded zip.
#
# Usage:
#   tools/patch_editor_html.sh EDITOR_HTML PRELOAD_HTML
#
# EDITOR_HTML   Path to godot.editor.html (will be modified in-place)
# PRELOAD_HTML  Path to web_editor_preload.html (injected before </body>)
#
# The patches:
#   1. startEditor(zip) → startEditor(zip, projectPath)
#   2. When projectPath is given, use --editor --path instead of --project-manager
#   3. persistentDrops disabled in editor mode
#   4. After editor.init(), copy window.__preloadFiles into the virtual FS
#   5. Inject the preload script before </body>
#
# Examples:
#   # Local (from repo root):
#   tools/patch_editor_html.sh demo/exports/editor/godot.editor.html tools/web_editor_preload.html
#
#   # CI:
#   tools/patch_editor_html.sh web/editor/godot.editor.html tools/web_editor_preload.html

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 EDITOR_HTML PRELOAD_HTML" >&2
    exit 1
fi

HTML="$1"
PRELOAD="$2"

if [ ! -f "$HTML" ]; then
    echo "Error: editor HTML not found: $HTML" >&2
    exit 1
fi
if [ ! -f "$PRELOAD" ]; then
    echo "Error: preload HTML not found: $PRELOAD" >&2
    exit 1
fi

echo "Patching $HTML ..."

# 1. Accept optional projectPath parameter
if grep -q 'function startEditor(zip) {' "$HTML"; then
    sed -i 's/function startEditor(zip) {/function startEditor(zip, projectPath) {/' "$HTML"
    echo "  Patched startEditor signature"
else
    echo "Error: startEditor(zip) pattern not found in $HTML — Godot editor format may have changed" >&2
    exit 1
fi

# 2. Use --editor --path when projectPath is given
if grep -q "const args = \['--project-manager', '--single-window'\];" "$HTML"; then
    sed -i "s|const args = \['--project-manager', '--single-window'\];|const args = projectPath ? ['--editor', '--path', projectPath, '--single-window'] : ['--project-manager', '--single-window'];|" "$HTML"
    echo "  Patched args override"
else
    echo "Error: args pattern not found — Godot editor format may have changed" >&2
    exit 1
fi

# 3. Only use persistentDrops in project-manager mode
if grep -q "'persistentDrops': true" "$HTML"; then
    sed -i "s|'persistentDrops': true|'persistentDrops': !projectPath|" "$HTML"
    echo "  Patched persistentDrops"
else
    echo "Error: persistentDrops pattern not found — Godot editor format may have changed" >&2
    exit 1
fi

# 4. After editor.init(), copy preloaded files into the virtual FS
python3 - "$HTML" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
if "__preloadFiles" in content:
    print("  __preloadFiles copy already present, skipping")
else:
    marker = "editor.copyToFS('/tmp/preload.zip', zip);"
    idx = content.find(marker)
    if idx == -1:
        print("Warning: marker not found, skipping __preloadFiles injection", file=sys.stderr)
    else:
        end = content.find("}", idx + len(marker))
        if end == -1:
            print("Warning: closing brace not found after copyToFS marker, skipping __preloadFiles injection", file=sys.stderr)
        else:
            insert = (
                "\n\t\t\tif (projectPath && window.__preloadFiles) {"
                "\n\t\t\t\twindow.__preloadFiles.forEach(function(f) { editor.copyToFS(f[0], f[1]); });"
                "\n\t\t\t}"
            )
            content = content[:end+1] + insert + content[end+1:]
            with open(path, 'w') as f:
                f.write(content)
            print("  Injected __preloadFiles copy")
PYEOF

# 5. Inject preload script before </body>
sed -i '/<\/body>/,$d' "$HTML"
sed -i '/<\/html>/d' "$HTML"
cat "$PRELOAD" >> "$HTML"
printf '</body>\n</html>\n' >> "$HTML"

# 6. Inject coi-serviceworker for SharedArrayBuffer (threads on GitHub Pages)
if grep -q 'coi-serviceworker.js' "$HTML"; then
    echo "  coi-serviceworker already injected, skipping"
else
    sed -i 's|</head>|<script src="coi-serviceworker.js"></script>\n\t</head>|' "$HTML"
    echo "  Injected coi-serviceworker script tag"
fi

echo "Patched: $HTML"
