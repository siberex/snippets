#!/usr/bin/env bash
set -euo pipefail

# https://www.jetbrains.com/help/idea/shared-indexes.html

# USAGE:
# idea.indexes.sh /path/to/project/dir

INDEX_DIR="/tmp/shared-indexes"
mkdir -p "$INDEX_DIR"

IDEA_BIN="/Applications/IntelliJ IDEA.app/Contents/MacOS/idea"

CDN_LAYOUT_TOOL="cdn-layout-tool"

PROJECT_DIR=${1:-""}

# If no directory provided, assume current dir is a project dir
if ! [ -d "$PROJECT_DIR" ]; then
    PROJECT_DIR=$(pwd -P)
fi

PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "Project dir: $PROJECT_DIR"
echo "Project name: $PROJECT_NAME"

export IDEA_PROPERTIES=/tmp/ide.properties

echo "idea.system.path=/tmp/ide-system" > "$IDEA_PROPERTIES"
echo "idea.config.path=/tmp/ide-config" >> "$IDEA_PROPERTIES"
echo "idea.log.path=/tmp/ide-log" >> "$IDEA_PROPERTIES"

LAST_COMMIT=$(git --git-dir="$PROJECT_DIR/.git" rev-parse HEAD 2>/dev/null)

# Generate indexes
"$IDEA_BIN" dump-shared-index project --output="$INDEX_DIR/generate-output" --tmp="$INDEX_DIR/temp" --project-dir="$PROJECT_DIR" --project-id="$PROJECT_NAME" --commit="$LAST_COMMIT"


# Random port (RFC 6056), from 1111 to 9999
PORT=$((1111 + RANDOM % 8888))

# Generate CDN directory structure from indexes
"$CDN_LAYOUT_TOOL" --indexes-dir="$INDEX_DIR/generate-output" --url="http://0.0.0.0:$PORT/"


echo Updating project intellij.yaml
touch "$PROJECT_DIR/intellij.yaml"
yq e -i '.sharedIndex.project[0].url = "http://localhost:'"$PORT"'/"' "$PROJECT_DIR/intellij.yaml"
cat "$PROJECT_DIR/intellij.yaml"

echo Launching local web server with generated CDN layout...
cd "$INDEX_DIR/generate-output/project/$PROJECT_NAME"
python3 -m http.server "$PORT"
