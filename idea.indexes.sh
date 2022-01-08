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


# Fancy colors
blu="\e[1;95m" # Bold Magenta
bri="\e[97m"   # Bright
red="\e[1;91m" # Bold Red
clr="\e[0m"    # Reset
function printok() {
  printf "✅ ${blu}%s${clr}\n" "$*"
}
function printerr() {
  printf "❌ ${red}%s${clr}\n" "$*"
}
function printbright() {
  printf "${bri}%s${clr}\n" "$*"
}


# Check dependencies
if [ -x "$IDEA_BIN" ]; then
    printok "IDEA binary found"
else
    printerr You need to install IDEA
    exit 1
fi

if hash yq 2>/dev/null; then
    printok "yq installed"
else
    printerr "You need to install yq: https://github.com/mikefarah/yq/#install"
    printf " - Homebrew: ${bri}%s${clr}\n" "brew install yq"
    printf " - Go: ${bri}%s${clr}\n" "go install github.com/mikefarah/yq/v4@latest"
    exit 2
fi

if hash "$CDN_LAYOUT_TOOL" 2>/dev/null; then
    printok "cdn-layout-tool found"
else
    echo "Downloading cdn-layout-tool..."
    # https://packages.jetbrains.team/maven/p/ij/intellij-shared-indexes-public/com/jetbrains/intellij/indexing/shared/cdn-layout-tool/
    CLT_VER=0.8.65
    curl -L -o "/tmp/cdn-layout-tool-$CLT_VER.zip" "https://packages.jetbrains.team/maven/p/ij/intellij-shared-indexes-public/com/jetbrains/intellij/indexing/shared/cdn-layout-tool/$CLT_VER/cdn-layout-tool-$CLT_VER.zip"

    unzip -u "/tmp/cdn-layout-tool-$CLT_VER.zip" -d "/tmp"
    rm -f "/tmp/cdn-layout-tool-$CLT_VER.zip"

    CDN_LAYOUT_TOOL="/tmp/cdn-layout-tool-$CLT_VER/bin/cdn-layout-tool"
    printf "Done: ${bri}%s${clr}\n" "$CDN_LAYOUT_TOOL"
fi


printf "Project dir: ${bri}%s${clr}\n" "$PROJECT_DIR"
printf "Project name: ${bri}%s${clr}\n" "$PROJECT_NAME"


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
