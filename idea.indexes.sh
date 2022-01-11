#!/usr/bin/env bash
set -euo pipefail

# https://www.jetbrains.com/help/idea/shared-indexes.html

# USAGE:
# idea.indexes.sh /path/to/project/dir

CDN_ROOT="$HOME/_idea_cdn"
mkdir -p "$CDN_ROOT"

TMP_OUTPUT_DIR="$(mktemp -d)"
function cleanup() {
  rm -rf "$TMP_OUTPUT_DIR"
}
trap cleanup SIGINT
#trap cleanup ERR

#IDEA_BIN="open -na 'Intellij IDEA' --args"
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
echo Creating shared indexes at:
printbright "$TMP_OUTPUT_DIR"
printbright "You could later copy produced *.ijx files to the idea.system.path/shared-index"
"$IDEA_BIN" dump-shared-index project --output="$TMP_OUTPUT_DIR" --tmp="/tmp" --project-dir="$PROJECT_DIR" --project-id="$PROJECT_NAME" --commit="$LAST_COMMIT" --add-hash-to-output-names=false

PORT=9876
URL="http://0.0.0.0:$PORT/"

# Generate CDN directory structure from indexes
echo Creating CDN layout from index chunks...
"$CDN_LAYOUT_TOOL" --indexes-dir="$TMP_OUTPUT_DIR" --url="$URL"

rm "$TMP_OUTPUT_DIR/project/list.json.xz"
cp -Rp "$TMP_OUTPUT_DIR/project"/* "$CDN_ROOT"
rm -rf "$TMP_OUTPUT_DIR/project"
cp -p "$TMP_OUTPUT_DIR"/*.ijx.xz "$CDN_ROOT"

echo Updating project intellij.yaml
touch "$PROJECT_DIR/intellij.yaml"
yq e -i '.sharedIndex.project[0].url = "'$URL$PROJECT_NAME'"' "$PROJECT_DIR/intellij.yaml"
cat "$PROJECT_DIR/intellij.yaml"

echo Launching local web server with generated CDN layout at:
printbright "$CDN_ROOT"

if hash php 2>/dev/null; then
    cd "$CDN_ROOT"
    php -S "0.0.0.0:$PORT"
elif hash python3 2>/dev/null; then
    cd "$CDN_ROOT"
    python3 -m http.server "$PORT"
elif hash npx 2>/dev/null; then
    npx http-server "$CDN_ROOT" --port="$PORT"
else
    printerr "Could not find python3, php or npx, please launch local web server manually:"
    printbright "cd $CDN_ROOT"
    printbright "python3 -m http.server $PORT"
    exit 3
fi
