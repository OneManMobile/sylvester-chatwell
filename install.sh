#!/usr/bin/env bash
# Sylvester Chatwell installer.
#
# Installs everything into this repository folder (.venv and .deps), so it
# survives on a Grok Bot computer where only /workspace is durable. Safe to run
# again at any time: finished steps are skipped. Needs no root. If the user has
# root or passwordless sudo and something is missing, apt is used; otherwise
# everything is downloaded in user space.
#
# Linux (x64, arm64) and macOS. Environment overrides: SYLVESTER_STATE,
# SYLVESTER_HOUSEHOLD, NEMLIG_CLI_REF, UV_VERSION, PYTHON_VERSION,
# PLAYWRIGHT_VERSION, NODE_LINE.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEPS=$REPO/.deps
UV_VERSION=${UV_VERSION:-0.13.3}
PYTHON_VERSION=${PYTHON_VERSION:-3.12}
NODE_LINE=${NODE_LINE:-22}
NODE_MIN=20
PLAYWRIGHT_VERSION=${PLAYWRIGHT_VERSION:-1.64.1}
NEMLIG_CLI_URL=https://github.com/tobiasdosdal/Nemlig.com-CLI.git
NEMLIG_CLI_REF=${NEMLIG_CLI_REF:-eb4790d3fb4fa95bcc54f17aab79652589e6b7c9}
# Runtime libraries Chromium needs on Debian/Ubuntu (Ubuntu 24.04 renames some
# to *t64; resolve_pkgs picks whichever exists).
CHROME_PKGS="libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 libcairo2
libcups2 libdbus-1-3 libdrm2 libgbm1 libglib2.0-0 libnspr4 libnss3
libpango-1.0-0 libx11-6 libxcb1 libxcomposite1 libxdamage1 libxext6 libxfixes3
libxkbcommon0 libxrandr2 fontconfig-config fonts-noto-color-emoji"

say() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
with_timeout() { # with_timeout SECONDS CMD...
  local seconds=$1; shift
  if have timeout; then timeout "$seconds" "$@"; else "$@"; fi
}

OS=$(uname -s)
case "$(uname -m)" in
  x86_64 | amd64) ARCH=x64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *) die "unsupported CPU $(uname -m) (x64 or arm64 only)" ;;
esac
case "$OS" in
  Linux | Darwin) ;;
  *) die "unsupported OS $OS (Linux or macOS only)" ;;
esac

# Durable paths (same rules as bin/nemlig, bin/doctor, bin/nemlig-keepalive).
if [ -n "${SYLVESTER_STATE:-}" ]; then
  STATE=$SYLVESTER_STATE
elif [ -d /workspace ] && [ -w /workspace ]; then
  STATE=/workspace/.sylvester
else
  STATE=${XDG_CONFIG_HOME:-$HOME/.config}/sylvester-chatwell
fi
NEMLIG_DIR=${NEMLIG_CONFIG_DIR:-$STATE/nemlig-cli}
if [ -n "${SYLVESTER_HOUSEHOLD:-}" ]; then
  HOUSEHOLD=$SYLVESTER_HOUSEHOLD
elif [ -d /workspace ] && [ -w /workspace ]; then
  HOUSEHOLD=/workspace/sylvester-household
else
  HOUSEHOLD=$STATE/household
fi

# Privileges: root, passwordless sudo, or none.
if [ "$(id -u)" = 0 ]; then
  PRIV=root
elif have sudo && sudo -n true 2>/dev/null; then
  PRIV=sudo
else
  PRIV=none
fi
can_apt() { [ "$OS" = Linux ] && [ "$PRIV" != none ] && have apt-get; }
as_root() { if [ "$PRIV" = root ]; then "$@"; else sudo -n "$@"; fi; }
APT_UPDATED=0
apt_install() {
  if [ "$APT_UPDATED" = 0 ]; then
    as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    APT_UPDATED=1
  fi
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" >/dev/null
}

fetch() { # fetch URL FILE
  if have curl; then
    curl -fsSL --retry 3 -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}
sha256() {
  if have sha256sum; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

mkdir -p "$DEPS/cache"
TMP=$(mktemp -d "$DEPS/cache/tmp.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# --- 1. Basic tools -------------------------------------------------------
missing=""
have git || missing="$missing git"
have curl || have wget || missing="$missing curl"
have tar || missing="$missing tar"
have gzip || missing="$missing gzip"
if [ -n "$missing" ]; then
  if can_apt; then
    say "Installing basic tools with apt:$missing"
    # shellcheck disable=SC2086 # word splitting intended
    apt_install ca-certificates $missing
  else
    die "missing:$missing. Install them (or ask the administrator) and run ./install.sh again."
  fi
fi

# --- 2. uv + Python venv --------------------------------------------------
UV=$DEPS/uv/uv
if ! { [ -x "$UV" ] && "$UV" --version 2>/dev/null | grep -q " $UV_VERSION"; }; then
  say "Downloading uv $UV_VERSION"
  case "$OS-$ARCH" in
    Linux-x64) target=x86_64-unknown-linux-musl ;;
    Linux-arm64) target=aarch64-unknown-linux-musl ;;
    Darwin-x64) target=x86_64-apple-darwin ;;
    Darwin-arm64) target=aarch64-apple-darwin ;;
  esac
  fetch "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/uv-$target.tar.gz" "$TMP/uv.tar.gz"
  mkdir -p "$TMP/uv" "$DEPS/uv"
  tar -xzf "$TMP/uv.tar.gz" -C "$TMP/uv" --strip-components=1
  mv -f "$TMP/uv/uv" "$UV"
fi
export UV_PYTHON_INSTALL_DIR=$DEPS/python UV_CACHE_DIR=$DEPS/cache/uv UV_NO_CONFIG=1
PY=$REPO/.venv/bin/python
if ! "$PY" -c 'import sys' 2>/dev/null; then
  say "Creating Python $PYTHON_VERSION environment (.venv)"
  "$UV" venv --quiet --clear --python "$PYTHON_VERSION" --python-preference only-managed "$REPO/.venv"
fi
if ! "$PY" -c 'import PIL, pyphen, requests' 2>/dev/null; then
  say "Installing Python packages (Pillow, pyphen, requests)"
  "$UV" pip install --quiet --python "$PY" Pillow pyphen requests
fi

# --- 3. Node.js -----------------------------------------------------------
node_major() { "$1" -e 'process.stdout.write(process.versions.node.split(".")[0])' 2>/dev/null || echo 0; }
LOCAL_NODE=$DEPS/node/bin/node
install_local_node() {
  [ -x "$LOCAL_NODE" ] && [ "$(node_major "$LOCAL_NODE")" -ge "$NODE_MIN" ] && return 0
  local plat file base="https://nodejs.org/dist/latest-v$NODE_LINE.x"
  case "$OS-$ARCH" in
    Linux-x64) plat=linux-x64 ;;
    Linux-arm64) plat=linux-arm64 ;;
    Darwin-x64) plat=darwin-x64 ;;
    Darwin-arm64) plat=darwin-arm64 ;;
  esac
  say "Downloading Node.js $NODE_LINE LTS ($plat)"
  fetch "$base/SHASUMS256.txt" "$TMP/SHASUMS256.txt"
  file=$(grep -oE "node-v[0-9.]+-$plat\.tar\.gz" "$TMP/SHASUMS256.txt" | head -n 1)
  [ -n "$file" ] || die "no Node.js download for $plat"
  fetch "$base/$file" "$TMP/$file"
  grep -q "^$(sha256 "$TMP/$file")  $file\$" "$TMP/SHASUMS256.txt" || die "Node.js checksum mismatch"
  mkdir -p "$TMP/node"
  tar -xzf "$TMP/$file" -C "$TMP/node" --strip-components=1
  rm -rf "$DEPS/node"
  mv "$TMP/node" "$DEPS/node"
}
if have node && [ "$(node_major node)" -ge "$NODE_MIN" ]; then
  NODE=$(command -v node)
else
  install_local_node
  NODE=$LOCAL_NODE
fi

# --- 4. nemlig CLI (pinned upstream commit + our patches) -----------------
CLI=$DEPS/nemlig-cli
STAMP=$DEPS/nemlig-cli.stamp
patch_id=$( { echo "$NEMLIG_CLI_REF"; cat "$REPO"/nemlig-cli-patches/*.patch; } | git hash-object --stdin)
if ! { [ -f "$CLI/src/cli.js" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$patch_id" ]; }; then
  say "Installing nemlig CLI (Nemlig.com-CLI + patches)"
  [ -d "$CLI/.git" ] || git clone --quiet "$NEMLIG_CLI_URL" "$CLI"
  git -C "$CLI" am --abort >/dev/null 2>&1 || true
  git -C "$CLI" cat-file -e "$NEMLIG_CLI_REF^{commit}" 2>/dev/null || git -C "$CLI" fetch --quiet origin
  git -C "$CLI" checkout --quiet --force -B sylvester-patches "$NEMLIG_CLI_REF"
  if ! git -C "$CLI" -c user.name=sylvester -c user.email=sylvester@localhost \
    am --quiet "$REPO"/nemlig-cli-patches/*.patch; then
    git -C "$CLI" am --abort >/dev/null 2>&1 || true
    die "the nemlig CLI patches don't apply to $NEMLIG_CLI_REF"
  fi
  echo "$patch_id" >"$STAMP"
fi
"$REPO/bin/nemlig" --version >/dev/null || die "bin/nemlig does not run (node: $NODE)"

# --- 5. Durable state: nemlig login + household files --------------------
mkdir -p "$NEMLIG_DIR"
chmod 700 "$STATE" "$NEMLIG_DIR" 2>/dev/null || true
link=$HOME/.config/nemlig-cli
if [ "$NEMLIG_DIR" != "$link" ]; then
  if [ -L "$link" ]; then
    [ "$(readlink "$link")" = "$NEMLIG_DIR" ] || warn "$link points elsewhere; bin/nemlig uses $NEMLIG_DIR"
  elif [ -e "$link" ]; then
    warn "$link exists; bin/nemlig uses $NEMLIG_DIR (log in again with bin/nemlig)"
  else
    mkdir -p "$HOME/.config"
    ln -s "$NEMLIG_DIR" "$link"
  fi
fi
mkdir -p "$HOUSEHOLD/cards"
for template in "$REPO"/templates/*.md; do
  [ -e "$HOUSEHOLD/$(basename "$template")" ] || cp "$template" "$HOUSEHOLD/"
done

# --- 6. Headless Chrome ---------------------------------------------------
LAUNCHER=$DEPS/chrome/chrome
LIBROOT=$DEPS/chrome/libroot
chrome_works() {
  local extra=""
  [ "$(id -u)" = 0 ] && extra=--no-sandbox
  # shellcheck disable=SC2086 # $extra is one optional flag
  with_timeout 120 "$1" --headless=new --disable-gpu $extra --dump-dom \
    'data:text/html,<p>sylvester-ok</p>' 2>/dev/null | grep -q sylvester-ok
}
find_chrome() {
  local candidate
  for candidate in "${RECIPE_CARD_CHROME:-}" "$LAUNCHER" google-chrome google-chrome-stable chromium chromium-browser \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    [ -n "$candidate" ] || continue
    if [ -x "$candidate" ] || { [ "${candidate#/}" = "$candidate" ] && have "$candidate"; }; then
      chrome_works "$candidate" && { echo "$candidate"; return 0; }
    fi
  done
  return 1
}
real_chrome() {
  [ -d "$DEPS/ms-playwright" ] || return 0
  find "$DEPS/ms-playwright" -type f -name chrome -path '*/chrome-linux*/chrome' | head -n 1
}
write_launcher() {
  local real=$1 libdirs="" dir rel
  if [ -d "$LIBROOT" ]; then
    while IFS= read -r dir; do
      rel=${dir#"$DEPS/chrome/"}
      libdirs="$libdirs\$D/$rel:"
    done < <(find "$LIBROOT" -name '*.so*' -exec dirname {} \; | sort -u)
  fi
  mkdir -p "$DEPS/chrome" "$DEPS/cache/fontconfig"
  # Chromium misloads web fonts when fontconfig sees no fonts at all, so the
  # repo's fonts (and any unpacked ones) are always visible.
  cat >"$DEPS/chrome/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>/usr/share/fonts</dir>
  <dir>$LIBROOT/usr/share/fonts</dir>
  <dir>$REPO/fonts</dir>
  <cachedir>$DEPS/cache/fontconfig</cachedir>
</fontconfig>
EOF
  cat >"$LAUNCHER" <<EOF
#!/bin/sh
# Generated by install.sh: headless Chromium for bin/recipe-card.
D=\$(cd "\$(dirname "\$0")" && pwd)
LD_LIBRARY_PATH="$libdirs\${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH
[ -f "\$D/fonts.conf" ] && export FONTCONFIG_FILE="\$D/fonts.conf"
exec "\$D/../${real#"$DEPS/"}" --no-sandbox "\$@"
EOF
  chmod 755 "$LAUNCHER"
}
missing_libs() { ldd "$1" 2>/dev/null | awk '/not found/ {print $1}' | sort -u; }
APTOPTS=()
resolve_pkgs() { # prints installable package names for CHROME_PKGS
  local p
  for p in $CHROME_PKGS; do
    if apt-cache "${APTOPTS[@]}" show "${p}t64" >/dev/null 2>&1; then
      echo "${p}t64"
    elif apt-cache "${APTOPTS[@]}" show "$p" >/dev/null 2>&1; then
      echo "$p"
    fi
  done
}
userspace_libs() { # unpack Chromium's libraries without root
  local aptd=$DEPS/apt pkgs p deb
  mkdir -p "$aptd/lists/partial" "$aptd/cache/archives/partial" "$aptd/debs"
  APTOPTS=(-o "Dir::State::Lists=$aptd/lists" -o "Dir::Cache=$aptd/cache"
    -o Debug::NoLocking=1 -o "APT::Sandbox::User=$(id -un)")
  say "Fetching Chromium libraries in user space (apt-get download, no root)"
  apt-get "${APTOPTS[@]}" -qq update 2>/dev/null || die "apt-get update (user space) failed"
  # shellcheck disable=SC2046 # word splitting intended
  pkgs=$(apt-cache "${APTOPTS[@]}" depends --recurse --no-recommends --no-suggests --no-conflicts \
    --no-breaks --no-replaces --no-enhances $(resolve_pkgs) | grep -E '^[a-z0-9]' | sort -u || true)
  rm -f "$aptd/debs"/*.deb
  local wanted=""
  for p in $pkgs; do
    [ "$(dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null)" = installed ] || wanted="$wanted $p"
  done
  # One batch download; if a package fails, fall back to one at a time.
  # shellcheck disable=SC2086 # word splitting intended
  if ! (cd "$aptd/debs" && apt-get "${APTOPTS[@]}" -qq download $wanted >/dev/null 2>&1); then
    for p in $wanted; do
      (cd "$aptd/debs" && apt-get "${APTOPTS[@]}" -qq download "$p" >/dev/null 2>&1) || warn "could not download $p"
    done
  fi
  rm -rf "$LIBROOT"
  mkdir -p "$LIBROOT"
  for deb in "$aptd/debs"/*.deb; do
    [ -e "$deb" ] && dpkg-deb -x "$deb" "$LIBROOT"
  done
  rm -f "$aptd/debs"/*.deb
}

# Refresh an existing launcher (repo moved, newer install.sh).
real=$(real_chrome)
if [ -n "$real" ] && [ -x "$LAUNCHER" ]; then
  write_launcher "$real"
fi
CHROME=$(find_chrome || true)
if [ -z "$CHROME" ] && [ "$OS" = Darwin ]; then
  warn "Google Chrome not found: install it from https://www.google.com/chrome/ (or set RECIPE_CARD_CHROME)"
elif [ -z "$CHROME" ]; then
  real=$(real_chrome)
  if [ -z "$real" ]; then
    say "Downloading headless Chromium (Playwright $PLAYWRIGHT_VERSION)"
    NPX=$(dirname "$NODE")/npx
    if [ ! -x "$NPX" ]; then
      install_local_node
      NPX=$DEPS/node/bin/npx
    fi
    if ! PATH="$(dirname "$NPX"):$PATH" PLAYWRIGHT_BROWSERS_PATH=$DEPS/ms-playwright npm_config_cache=$DEPS/cache/npm \
      npm_config_update_notifier=false "$NPX" --yes "playwright@$PLAYWRIGHT_VERSION" install --no-shell chromium \
      >"$TMP/playwright.log" 2>&1; then
      cat "$TMP/playwright.log" >&2
      die "Chromium download failed"
    fi
    real=$(real_chrome)
    [ -n "$real" ] || die "Chromium download failed"
  fi
  write_launcher "$real"
  if [ -n "$(missing_libs "$real")" ] || ! chrome_works "$LAUNCHER"; then
    if can_apt; then
      say "Installing Chromium libraries with apt"
      as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
      APT_UPDATED=1
      # shellcheck disable=SC2046 # word splitting intended
      apt_install $(resolve_pkgs)
    elif have apt-get && have dpkg-deb; then
      userspace_libs
      write_launcher "$real"
    fi
  fi
  # The first start can be slow (font cache); try twice before giving up.
  if chrome_works "$LAUNCHER" || chrome_works "$LAUNCHER"; then
    CHROME=$LAUNCHER
  else
    warn "Chromium does not start:"
    with_timeout 120 "$LAUNCHER" --headless=new --disable-gpu --dump-dom about:blank 2>&1 >/dev/null | tail -n 5 >&2 || true
  fi
fi

# --- Summary --------------------------------------------------------------
echo
echo "Sylvester Chatwell is installed in $REPO"
echo "  python:    $("$PY" --version 2>&1) (.venv)"
echo "  node:      $("$NODE" --version) ($NODE)"
echo "  nemlig:    bin/nemlig (Nemlig.com-CLI $(git -C "$CLI" rev-parse --short "$NEMLIG_CLI_REF") + patches)"
echo "  chrome:    ${CHROME:-NOT WORKING}"
echo "  login dir: $NEMLIG_DIR"
echo "  household: $HOUSEHOLD"
echo
if [ -z "$CHROME" ]; then
  echo "Cards can't be rendered until Chrome works (see the warning above)."
  exit 1
fi
echo "Next: bin/doctor — then connect nemlig.com: run bin/nemlig-login --email <your e-mail>,"
echo "  open the URL it prints and type your password on that page."
