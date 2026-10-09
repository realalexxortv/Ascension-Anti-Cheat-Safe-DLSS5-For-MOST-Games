#!/usr/bin/env bash
# Ascension — install Lecram's DLSS 5 neural mod for AION 2 on Linux.
# The game directory is never written. The mod DLL stays with the Vulkan helper.
set -euo pipefail

APPID="3393110"
PINNED_TAG="0.3.1-2"
PINNED_URL="https://github.com/bmitch87/DLSS5VKLayer/releases/download/0.3.1-2/dlssnr-0.3.1-2-linux-x86_64.tar.gz"
PINNED_SHA="43fd001720a3e15704c1bb8ea03c768b406e058c8eb2859ab0ebc8b3cd48f955"

DRY=0
MODE="install"
STEAM_ROOTS=()
GAME_ROOTS=()
VDF_FILES=()
LAUNCH_PREFIX=""
LAYER_TAG="$PINNED_TAG"
DLL_PATH=""

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Ascension — Lecram's DLSS 5 mod for AION 2 on Linux.

The game folder is never modified. DLSS5VKLayer presents frames to a helper
that lives under your home directory. NC Guard's file check stays quiet
because nothing is added next to the game. This does not disable, hide from,
or patch anti-cheat. The layer still loads in the game process.

  ascension              install or re-apply
  ascension --dry-run    print the plan, change nothing
  ascension --remove     drop the AION 2 launch option and stop the helper
  ascension --purge      --remove, then uninstall the layer
  ascension --help

Lecram's nvngx_dlssnr.dll is not downloaded. Put that file in
  ~/.local/share/ascension/import/
or in ~/Downloads, then run ascension again.
EOF
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  command -v curl >/dev/null 2>&1 || die "curl is required"
  command -v tar >/dev/null 2>&1 || die "tar is required"
  [ "$(uname -s)" = "Linux" ] || die "Ascension is for Linux"
  case "$(uname -m)" in
    x86_64 | amd64) ;;
    *) die "DLSS5VKLayer ships x86_64 only. This machine is $(uname -m)." ;;
  esac
}

steam_running() {
  local comm
  for comm in /proc/[0-9]*/comm; do
    [ -r "$comm" ] || continue
    if [ "$(cat "$comm" 2>/dev/null || true)" = "steam" ]; then
      return 0
    fi
  done
  return 1
}

assert_outside_game() {
  local target="$1" resolved g
  resolved=$(readlink -f "$target" 2>/dev/null || printf '%s' "$target")
  for g in "${GAME_ROOTS[@]+"${GAME_ROOTS[@]}"}"; do
    [ -n "$g" ] || continue
    case "$resolved" in
      "$g" | "$g"/*)
        die "refusing to write inside the AION 2 folder: $resolved"
        ;;
    esac
  done
}

add_unique_root() {
  local raw="$1" r
  [ -d "$raw" ] || return 0
  r=$(readlink -f "$raw")
  local existing
  for existing in "${STEAM_ROOTS[@]+"${STEAM_ROOTS[@]}"}"; do
    [ "$existing" = "$r" ] && return 0
  done
  STEAM_ROOTS+=("$r")
}

add_game_root() {
  local game="$1" existing
  [ -n "$game" ] || return 0
  for existing in "${GAME_ROOTS[@]+"${GAME_ROOTS[@]}"}"; do
    [ "$existing" = "$game" ] && return 0
  done
  GAME_ROOTS+=("$game")
  say "AION 2 folder (not written): $game"
}

add_vdf() {
  local f="$1" existing
  [ -f "$f" ] || return 0
  f=$(readlink -f "$f")
  for existing in "${VDF_FILES[@]+"${VDF_FILES[@]}"}"; do
    [ "$existing" = "$f" ] && return 0
  done
  VDF_FILES+=("$f")
}

note_library() {
  local lib="$1" manifest installdir game
  [ -d "$lib" ] || return 0
  manifest="$lib/steamapps/appmanifest_${APPID}.acf"
  [ -f "$manifest" ] || return 0
  installdir=$(sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)
  [ -n "$installdir" ] || return 0
  game="$lib/steamapps/common/$installdir"
  if [ -d "$game" ]; then
    game=$(readlink -f "$game")
  fi
  add_game_root "$game"
}

discover_steam() {
  local c root lib vdf line paths
  STEAM_ROOTS=()
  GAME_ROOTS=()
  VDF_FILES=()
  for c in \
    "$HOME/.steam/steam" \
    "$HOME/.steam/root" \
    "$HOME/.local/share/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
    add_unique_root "$c"
  done
  for root in "${STEAM_ROOTS[@]+"${STEAM_ROOTS[@]}"}"; do
    if [ -f "$root/steamapps/libraryfolders.vdf" ]; then
      paths=$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\([^"]*\)".*/\1/p' "$root/steamapps/libraryfolders.vdf")
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        note_library "$line"
      done <<< "$paths"
    fi
    note_library "$root"
    for vdf in "$root"/userdata/[0-9]*/config/localconfig.vdf; do
      add_vdf "$vdf"
    done
  done
  if [ "${#STEAM_ROOTS[@]}" -eq 0 ]; then
    say "Steam was not found for this user."
  fi
  if [ "${#GAME_ROOTS[@]}" -eq 0 ]; then
    say "AION 2 (app $APPID) is not installed yet. The launch option is still set if Steam's config is here."
  fi
}

import_dir() { printf '%s\n' "$HOME/.local/share/ascension/import"; }
layer_manifest_dir() { printf '%s\n' "$HOME/.local/share/vulkan/implicit_layer.d"; }
helper_bin() { printf '%s\n' "$HOME/.local/bin/dlssnr-helper"; }
version_file() { printf '%s\n' "$HOME/.local/share/ascension/layer.version"; }
backup_dir() { printf '%s\n' "$HOME/.local/share/ascension/backups"; }

set_launch_prefix() {
  local dir
  dir="$(layer_manifest_dir)"
  case "$dir" in
    *" "*)
      LAUNCH_PREFIX="VKLayer_DLSS5=1"
      say "Home path contains a space. Launch option omits VK_ADD_LAYER_PATH."
      ;;
    *)
      LAUNCH_PREFIX="VKLayer_DLSS5=1 VK_ADD_LAYER_PATH=${dir}"
      ;;
  esac
}

find_dll() {
  local import listing best best_named ts path low resolved g
  import="$(import_dir)/nvngx_dlssnr.dll"
  if [ -f "$import" ] && [ -s "$import" ]; then
    resolved=$(readlink -f "$import")
    for g in "${GAME_ROOTS[@]+"${GAME_ROOTS[@]}"}"; do
      case "$resolved" in
        "$g" | "$g"/*) die "the import file resolves inside the game folder" ;;
      esac
    done
    printf '%s\n' "$resolved"
    return 0
  fi

  local -a roots=()
  local dl="$HOME/Downloads" line val d
  if [ -f "$HOME/.config/user-dirs.dirs" ]; then
    line=$(grep -E '^XDG_DOWNLOAD_DIR=' "$HOME/.config/user-dirs.dirs" | head -1 || true)
    if [ -n "$line" ]; then
      val="${line#*=}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val//\$HOME/$HOME}"
      [ -d "$val" ] && dl="$val"
    fi
  fi
  for d in "$dl" "$HOME/Downloads" "$HOME/Desktop" "$(import_dir)"; do
    [ -d "$d" ] || continue
    roots+=("$d")
  done
  [ "${#roots[@]}" -gt 0 ] || return 1

  listing=$(find "${roots[@]}" -maxdepth 3 -type f -iname 'nvngx_dlssnr.dll' \
    -not -path '*/steamapps/common/*' \
    -not -path '*/compatdata/*' \
    -size +0c \
    -printf '%T@\t%p\n' 2>/dev/null | sort -nr || true)
  [ -n "$listing" ] || return 1

  best=""
  best_named=""
  while IFS=$'\t' read -r ts path; do
    [ -n "${path:-}" ] || continue
    resolved=$(readlink -f "$path")
    local skip=0
    for g in "${GAME_ROOTS[@]+"${GAME_ROOTS[@]}"}"; do
      case "$resolved" in
        "$g" | "$g"/*) skip=1 ;;
      esac
    done
    [ "$skip" -eq 1 ] && continue
    low=$(printf '%s' "$resolved" | tr '[:upper:]' '[:lower:]')
    case "$low" in
      *lecram*)
        [ -z "$best_named" ] && best_named="$resolved"
        ;;
    esac
    [ -z "$best" ] && best="$resolved"
  done <<< "$listing"

  if [ -n "$best_named" ]; then
    printf '%s\n' "$best_named"
    return 0
  fi
  if [ -n "$best" ]; then
    printf '%s\n' "$best"
    return 0
  fi
  return 1
}

vdf_patch() {
  local file="$1" mode="$2" result status
  assert_outside_game "$file"
  if [ "$DRY" -eq 1 ]; then
    say "would $mode the AION 2 launch option in $file"
    return 0
  fi
  mkdir -p "$(backup_dir)"
  cp -a "$file" "$(backup_dir)/$(basename "$(dirname "$(dirname "$file")")")-localconfig.vdf"
  set +e
  result=$(python3 - "$file" "$APPID" "$mode" "$LAUNCH_PREFIX" <<'PY'
import pathlib, re, sys

path, appid, mode, prefix = sys.argv[1:5]
file = pathlib.Path(path)
raw = file.read_bytes()
if b"\x00" in raw:
    print("skipped-binary")
    sys.exit(2)
try:
    text = raw.decode("utf-8")
except UnicodeDecodeError:
    print("skipped-binary")
    sys.exit(2)
if text.startswith("\ufeff"):
    text = text[1:]

class ParseError(Exception):
    pass

class P:
    def __init__(self, s):
        self.s = s
        self.i = 0
        self.n = len(s)

    def peek(self):
        return self.s[self.i] if self.i < self.n else ""

    def skip(self):
        while self.i < self.n and self.s[self.i] in " \t\r\n":
            self.i += 1

    def string(self):
        self.skip()
        if self.peek() != '"':
            raise ParseError("expected string at %s" % self.i)
        self.i += 1
        chars = []
        while self.i < self.n:
            c = self.s[self.i]
            if c == "\\":
                self.i += 1
                if self.i >= self.n:
                    break
                chars.append(self.s[self.i])
                self.i += 1
                continue
            if c == '"':
                self.i += 1
                return "".join(chars)
            chars.append(c)
            self.i += 1
        raise ParseError("unterminated string")

    def value(self):
        self.skip()
        if self.peek() == '"':
            start = self.i
            self.string()
            return ("str", start, self.i)
        if self.peek() == "{":
            start, end, items = self.obj()
            return ("obj", start, end, items)
        raise ParseError("expected value at %s" % self.i)

    def obj(self):
        start = self.i
        self.i += 1
        items = []
        while True:
            self.skip()
            if self.peek() == "}":
                self.i += 1
                return start, self.i, items
            if self.i >= self.n:
                raise ParseError("unclosed object")
            key = self.string()
            items.append((key, self.value()))

def find_apps(items, path):
    found = []
    for key, val in items:
        if val[0] != "obj":
            continue
        nxt = path + [key]
        if key == "apps" and any(part.lower() == "steam" for part in path):
            low = [part.lower() for part in nxt]
            score = 2 if "software" in low and "valve" in low else 1
            found.append((score, val))
        found.extend(find_apps(val[3], nxt))
    return found

def unescape(s):
    out, i = [], 0
    while i < len(s):
        if s[i] == "\\" and i + 1 < len(s):
            out.append(s[i + 1])
            i += 2
        else:
            out.append(s[i])
            i += 1
    return "".join(out)

def escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')

def merge_set(existing, prefix):
    if "VKLayer_DLSS5=" in existing or "VKLAYER_DLSS5=" in existing.upper():
        return existing, False
    existing = existing.strip()
    if not existing:
        return prefix + " %command%", True
    if "%command%" in existing:
        return prefix + " " + existing, True
    return prefix + " " + existing + " %command%", True

def merge_clear(existing):
    s = re.sub(r"VK_ADD_LAYER_PATH=\S+", "", existing)
    s = re.sub(r"VKLAYER_DLSS5=\S+", "", s, flags=re.I)
    s = re.sub(r"[ \t]{2,}", " ", s).strip()
    if s in ("", "%command%"):
        return "", True
    return s, s != existing.strip()

parser = P(text)
top = []
try:
    while True:
        parser.skip()
        if parser.i >= parser.n:
            break
        key = parser.string()
        top.append((key, parser.value()))
except ParseError as exc:
    print("skipped-shape %s" % exc)
    sys.exit(3)

found = find_apps(top, [])
if not found:
    print("skipped-shape no apps section")
    sys.exit(3)
found.sort(key=lambda item: item[0], reverse=True)
apps = found[0][1]
app_val = None
for key, val in apps[3]:
    if key == appid and val[0] == "obj":
        app_val = val
        break

def write(new):
    tmp = file.with_name(file.name + ".ascension-tmp")
    tmp.write_text(new, encoding="utf-8")
    tmp.replace(file)
    print("updated")

if app_val is None:
    if mode == "clear":
        print("unchanged")
        sys.exit(0)
    block = (
        '\n\t\t"%s"\n\t\t{\n\t\t\t"LaunchOptions"\t\t"%s"\n\t\t}\n'
        % (appid, escape(prefix + " %command%"))
    )
    insert_at = apps[2] - 1
    write(text[:insert_at] + block + text[insert_at:])
    sys.exit(0)

launch = None
for key, val in app_val[3]:
    if key == "LaunchOptions" and val[0] == "str":
        launch = val
        break

if launch is None:
    if mode == "clear":
        print("unchanged")
        sys.exit(0)
    line = '\n\t\t\t"LaunchOptions"\t\t"%s"\n' % escape(prefix + " %command%")
    insert_at = app_val[2] - 1
    write(text[:insert_at] + line + text[insert_at:])
    sys.exit(0)

existing = unescape(text[launch[1] + 1 : launch[2] - 1])
if mode == "set":
    merged, did = merge_set(existing, prefix)
else:
    merged, did = merge_clear(existing)
if not did:
    print("unchanged")
    sys.exit(0)
if merged == "":
    key_at = text.rfind('"LaunchOptions"', app_val[1], launch[1])
    if key_at < 0:
        print("skipped-shape launch key")
        sys.exit(3)
    line_start = text.rfind("\n", app_val[1], key_at)
    if line_start < 0:
        line_start = key_at
    write(text[:line_start] + text[launch[2] :])
    sys.exit(0)
write(text[: launch[1] + 1] + escape(merged) + text[launch[2] - 1 :])
PY
  )
  status=$?
  set -e
  case "$status" in
    0) say "$result: $file" ;;
    2) say "left untouched (Steam config is not plain text): $file" ;;
    *) say "could not edit Steam config ($result): $file" ;;
  esac
}

apply_launch_options() {
  local f
  if [ "${#VDF_FILES[@]}" -eq 0 ]; then
    say "No Steam user config to edit. Install AION 2 in Steam, quit Steam, run ascension again."
    return 0
  fi
  if steam_running; then
    if [ "$DRY" -eq 1 ]; then
      say "Steam is open. Would apply the launch option after Steam exits."
      return 0
    fi
    queue_waiter
    say "Steam is open, so its config is still in memory."
    say "Quit Steam fully (tray icon too). Ascension writes the launch option as it exits."
    return 0
  fi
  for f in "${VDF_FILES[@]}"; do
    vdf_patch "$f" set
  done
}

queue_waiter() {
  local dir waiter
  dir="$HOME/.local/share/ascension"
  mkdir -p "$dir"
  waiter="$dir/apply-when-steam-exits.sh"
  cat > "$waiter" <<EOF
#!/usr/bin/env bash
set -euo pipefail
while true; do
  found=0
  for comm in /proc/[0-9]*/comm; do
    [ -r "\$comm" ] || continue
    if [ "\$(cat "\$comm" 2>/dev/null || true)" = "steam" ]; then
      found=1
      break
    fi
  done
  [ "\$found" -eq 0 ] && break
  sleep 1
done
sleep 2
exec "$HOME/.local/bin/ascension" --apply-launch-only
EOF
  chmod 755 "$waiter"
  if [ -f "$dir/waiter.pid" ] && kill -0 "$(cat "$dir/waiter.pid")" 2>/dev/null; then
    say "Already waiting for Steam to exit."
    return 0
  fi
  nohup "$waiter" >>"$dir/waiter.log" 2>&1 &
  printf '%s\n' "$!" > "$dir/waiter.pid"
}

drop_global_pin() {
  local pin="$HOME/.config/environment.d/dlssnr.conf"
  if [ ! -f "$pin" ]; then
    return 0
  fi
  if [ "$DRY" -eq 1 ]; then
    say "would remove the session-wide Vulkan pin at $pin"
    say "The layer then turns on only for AION 2."
    return 0
  fi
  rm -f "$pin"
  say "Removed the session-wide Vulkan pin. Only AION 2 turns the layer on."
}

resolve_bundled_tarball() {
  local candidate self dir
  if [ -n "${ASCENSION_TARBALL:-}" ] && [ -f "$ASCENSION_TARBALL" ]; then
    return 0
  fi
  for candidate in \
    "${APPDIR:-}/usr/share/ascension/dlssnr-${PINNED_TAG}-linux-x86_64.tar.gz"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      ASCENSION_TARBALL="$candidate"
      return 0
    fi
  done
  if [ -n "${0:-}" ] && [ -f "$0" ]; then
    self=$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")
    dir=$(dirname "$self")
    for candidate in \
      "$dir/dlssnr-${PINNED_TAG}-linux-x86_64.tar.gz" \
      "$dir/../share/ascension/dlssnr-${PINNED_TAG}-linux-x86_64.tar.gz" \
      "$dir/../../payload/dlssnr-${PINNED_TAG}-linux-x86_64.tar.gz"; do
      if [ -f "$candidate" ]; then
        ASCENSION_TARBALL=$(readlink -f "$candidate")
        return 0
      fi
    done
  fi
  return 1
}

install_layer() {
  local tag url tarball dest work inst current
  tag="$PINNED_TAG"
  url="$PINNED_URL"
  current=""
  if [ -f "$(version_file)" ]; then
    current=$(cat "$(version_file)")
  fi
  if [ "$DRY" -eq 0 ] && [ -x "$(helper_bin)" ] && [ -f "$HOME/.local/lib/dlssnr/helper/dlssnr_helper.exe" ] && [ "$current" = "$tag" ]; then
    say "DLSS5VKLayer $tag is already installed under ~/.local"
    drop_global_pin
    return 0
  fi
  resolve_bundled_tarball || true
  if [ "$DRY" -eq 1 ]; then
    if [ -n "${ASCENSION_TARBALL:-}" ]; then
      say "would install DLSS5VKLayer $tag from the bundled package (no download)"
    else
      say "would install DLSS5VKLayer $tag from GitHub into ~/.local (user install, no root)"
    fi
    say "would remove the session-wide Vulkan pin so other games stay untouched"
    return 0
  fi
  if [ -z "${ASCENSION_TARBALL:-}" ]; then
    local api parsed
    api=$(curl -fsSL --max-time 20 https://api.github.com/repos/bmitch87/DLSS5VKLayer/releases/latest || true)
    if [ -n "$api" ]; then
      parsed=$(printf '%s' "$api" | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(0)
tag=data.get("tag_name") or ""
url=""
for asset in data.get("assets") or []:
    name=asset.get("name") or ""
    if name.endswith("linux-x86_64.tar.gz"):
        url=asset.get("browser_download_url") or ""
        break
if tag and url:
    print(tag)
    print(url)
')
      if [ -n "$parsed" ]; then
        tag=$(printf '%s\n' "$parsed" | sed -n '1p')
        url=$(printf '%s\n' "$parsed" | sed -n '2p')
      fi
    fi
  fi
  LAYER_TAG="$tag"
  dest="$HOME/.local/share/ascension/cache"
  assert_outside_game "$dest"
  assert_outside_game "$HOME/.local/lib/dlssnr"
  assert_outside_game "$HOME/.local/share/vulkan"
  mkdir -p "$dest"
  if [ -n "${ASCENSION_TARBALL:-}" ]; then
    tarball="$ASCENSION_TARBALL"
    say "using bundled layer $tarball"
    echo "$PINNED_SHA  $tarball" | sha256sum -c -
  else
    tarball="$dest/$(basename "$url")"
    if [ ! -f "$tarball" ]; then
      say "downloading $url"
      curl -fL --retry 3 --max-time 180 -o "$tarball.partial" "$url"
      mv "$tarball.partial" "$tarball"
    else
      say "using cached $tarball"
    fi
    if [ "$url" = "$PINNED_URL" ]; then
      echo "$PINNED_SHA  $tarball" | sha256sum -c -
    fi
  fi
  work=$(mktemp -d)
  tar --no-same-owner -xzf "$tarball" -C "$work"
  inst=$(find "$work" -name install.sh -print -quit)
  [ -n "$inst" ] || die "tarball has no install.sh"
  bash "$inst" --user
  printf '%s\n' "$tag" > "$(version_file)"
  rm -rf "$work"
  drop_global_pin
  say "Installed DLSS5VKLayer $tag"
}

import_dll() {
  local dll="$1" stage sibling base
  [ -n "$dll" ] || return 0
  assert_outside_game "$dll"
  say "Lecram DLL: $dll"
  say "sha256 $(sha256sum "$dll" | awk '{print $1}')"
  if [ "$DRY" -eq 1 ]; then
    say "would copy it into the helper store (~/.local/share/dlssnr/binaries), not the game"
    return 0
  fi
  stage=$(mktemp -d)
  cp -f "$dll" "$stage/nvngx_dlssnr.dll"
  for sibling in nvngx.dll nvapi64.dll; do
    if [ -f "$(dirname "$dll")/$sibling" ]; then
      cp -f "$(dirname "$dll")/$sibling" "$stage/$sibling"
    fi
  done
  assert_outside_game "$HOME/.local/share/dlssnr"
  "$(helper_bin)" import-binaries "$stage"
  rm -rf "$stage"
  base="${XDG_DATA_HOME:-$HOME/.local/share}/dlssnr/binaries/nvngx_dlssnr.dll"
  if [ -f "$base" ]; then
    assert_outside_game "$base"
    say "Imported into $base"
  fi
}

runner_ready() {
  [ -x "$(helper_bin)" ] || return 1
  "$(helper_bin)" runners >/dev/null 2>&1 && return 0
  command -v wine >/dev/null 2>&1
}

install_autostart() {
  local unit="$HOME/.config/systemd/user/ascension-dlssnr.service"
  if [ "$DRY" -eq 1 ]; then
    say "would start the helper when you log in, outside the game"
    return 0
  fi
  if [ "${ASCENSION_SKIP_SYSTEMD:-0}" = 1 ]; then
    return 0
  fi
  if ! runner_ready; then
    say "No Proton-GE, Proton-CachyOS, Wine-GE, or system Wine yet."
    say "The layer is installed. Add one of those, then run ascension again so the helper can start."
    return 0
  fi
  if systemctl --user show-environment >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$unit" <<'EOF'
[Unit]
Description=Ascension DLSS 5 helper
After=default.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=%h/.local/bin/dlssnr-helper start
ExecStop=%h/.local/bin/dlssnr-helper stop

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload || true
    systemctl --user enable --now ascension-dlssnr.service || say "helper service did not start; check: dlssnr-helper doctor"
  else
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/ascension-dlssnr.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ascension DLSS 5 helper
Exec=$HOME/.local/bin/dlssnr-helper start
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
    if [ "${ASCENSION_SKIP_HELPER_START:-0}" != 1 ]; then
      "$(helper_bin)" start || say "helper did not start; run: dlssnr-helper doctor"
    fi
  fi
}

install_desktop_entry() {
  local apps="$HOME/.local/share/applications"
  if [ "$DRY" -eq 1 ]; then
    say "would add an Ascension menu entry that re-runs this installer"
    return 0
  fi
  mkdir -p "$apps"
  cat > "$apps/ascension.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ascension
GenericName=AION 2 DLSS 5
Comment=Re-apply Lecram DLSS 5 for AION 2 without touching the game folder
Exec=bash -c '$HOME/.local/bin/ascension; printf "\\nPress Enter to close.\\n"; read -r _'
Terminal=true
Categories=Game;
StartupNotify=false
EOF
}

copy_self() {
  if [ "$DRY" -eq 1 ]; then
    say "would install the ascension command to ~/.local/bin/ascension"
    return 0
  fi
  if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "-bash" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -f "$0" "$HOME/.local/bin/ascension"
    chmod 755 "$HOME/.local/bin/ascension"
  fi
}

stop_helper() {
  if [ "$DRY" -eq 1 ]; then
    say "would stop the helper"
    return 0
  fi
  if [ -x "$(helper_bin)" ]; then
    "$(helper_bin)" stop || true
  fi
  if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user disable --now ascension-dlssnr.service >/dev/null 2>&1 || true
  fi
  rm -f "$HOME/.config/systemd/user/ascension-dlssnr.service"
  rm -f "$HOME/.config/autostart/ascension-dlssnr.desktop"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

remove_launch_options() {
  local f
  if [ "${#VDF_FILES[@]}" -eq 0 ]; then
    say "No Steam user config found."
    return 0
  fi
  if steam_running && [ "$DRY" -eq 0 ]; then
    say "Quit Steam fully, then run: ascension --remove"
    say "Steam would overwrite the config on exit if it is edited now."
    return 0
  fi
  for f in "${VDF_FILES[@]}"; do
    vdf_patch "$f" clear
  done
}

purge_layer() {
  local tarball work uninst dll dest
  stop_helper
  remove_launch_options
  dll="${XDG_DATA_HOME:-$HOME/.local/share}/dlssnr/binaries/nvngx_dlssnr.dll"
  dest="$(import_dir)/nvngx_dlssnr.dll"
  if [ -f "$dll" ] && [ ! -f "$dest" ]; then
    if [ "$DRY" -eq 1 ]; then
      say "would keep your DLL at $dest"
    else
      mkdir -p "$(import_dir)"
      cp -f "$dll" "$dest"
      say "Kept your DLL at $dest"
    fi
  fi
  if [ "$DRY" -eq 1 ]; then
    say "would uninstall DLSS5VKLayer from ~/.local"
    return 0
  fi
  if [ -n "${ASCENSION_TARBALL:-}" ]; then
    tarball="$ASCENSION_TARBALL"
  else
    tarball=$(find "$HOME/.local/share/ascension/cache" -name 'dlssnr-*-linux-x86_64.tar.gz' -print -quit 2>/dev/null || true)
  fi
  if [ -n "$tarball" ] && [ -f "$tarball" ]; then
    work=$(mktemp -d)
    tar --no-same-owner -xzf "$tarball" -C "$work"
    uninst=$(find "$work" -name uninstall.sh -print -quit)
    if [ -n "$uninst" ]; then
      bash "$uninst" --user --purge || true
    fi
    rm -rf "$work"
  else
    rm -rf "$HOME/.local/lib/dlssnr"
    rm -f "$HOME/.local/bin/dlssnr-helper" "$HOME/.local/bin/dlssnr-gui" \
      "$HOME/.local/bin/dlssnr-runner-probe" "$HOME/.local/bin/dlssnr-shmctl"
    rm -f "$HOME/.local/share/vulkan/implicit_layer.d"/VK_LAYER_NV_dlssnr.json \
      "$HOME/.local/share/vulkan/implicit_layer.d"/VK_LAYER_NV_dlssnr.*.json
    rm -f "$HOME/.config/environment.d/dlssnr.conf"
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/dlssnr" \
      "${XDG_DATA_HOME:-$HOME/.local/share}/dlssnr" \
      "${XDG_STATE_HOME:-$HOME/.local/state}/dlssnr" \
      "/tmp/dlssnr-$UID"
  fi
  rm -f "$(version_file)" "$HOME/.local/share/applications/ascension.desktop" \
    "$HOME/.local/bin/ascension"
  say "Layer removed. The game folder was not touched. Your import folder was kept."
}

prepare_import_dir() {
  if [ "$DRY" -eq 1 ]; then
    say "would create $(import_dir) for Lecram's nvngx_dlssnr.dll"
    return 0
  fi
  assert_outside_game "$(import_dir)"
  mkdir -p "$(import_dir)"
}

cmd_install() {
  local missing=0
  say "Ascension — Lecram DLSS 5 for AION 2"
  say "Nothing is written into the game folder."
  if [ "$DRY" -eq 1 ]; then
    say "Dry-run. Nothing will be changed."
  fi
  set_launch_prefix
  discover_steam
  prepare_import_dir
  if DLL_PATH=$(find_dll); then
    say "Found nvngx_dlssnr.dll outside the game."
  else
    DLL_PATH=""
    missing=1
    say "Lecram's nvngx_dlssnr.dll is not on this machine yet."
    say "Drop that one file into $(import_dir) and run ascension again."
  fi
  install_layer
  copy_self
  if [ -x "$(helper_bin)" ] || [ "$DRY" -eq 1 ]; then
    if [ "$DRY" -eq 1 ]; then
      say "would run: dlssnr-helper init"
    elif [ -x "$(helper_bin)" ]; then
      "$(helper_bin)" init || true
    fi
  fi
  if [ -n "$DLL_PATH" ]; then
    import_dll "$DLL_PATH"
  fi
  install_autostart
  install_desktop_entry
  apply_launch_options
  say "Launch option for AION 2 only:"
  say "  ${LAUNCH_PREFIX} %command%"
  if [ "$DRY" -eq 0 ] && [ -x "$(helper_bin)" ]; then
    say "---- dlssnr-helper doctor ----"
    "$(helper_bin)" doctor || say "doctor reported something missing (see above)"
  fi
  if [ "$missing" -eq 1 ]; then
    say "Layer is ready. Ascension will not fetch Lecram's DLL for you."
    exit 2
  fi
  if [ "$DRY" -eq 0 ]; then
    say "Done. Launch AION 2 from Steam after Steam has been restarted once."
    say "Undo with: ascension --remove"
  fi
}

self_test() {
  local tmp home steam game user before after count
  command -v python3 >/dev/null 2>&1 || die "python3 is required"
  [ -n "${ASCENSION_TARBALL:-}" ] || die "self-test needs ASCENSION_TARBALL"
  tmp=$(mktemp -d)
  home="$tmp/home"
  steam="$home/.local/share/Steam"
  game="$steam/steamapps/common/AION2"
  user="$steam/userdata/1000/config"
  mkdir -p "$game" "$user" "$home/Downloads" "$steam/userdata/1001/config" "$steam/steamapps"
  printf 'sentinel\n' > "$game/DO_NOT_TOUCH"
  printf 'MZ-fake-lecram-dll' > "$home/Downloads/nvngx_dlssnr.dll"
  printf 'not-a-vdf\0binary\n' > "$steam/userdata/1001/config/localconfig.vdf"
  cat > "$steam/steamapps/appmanifest_${APPID}.acf" <<EOF
"AppState"
{
	"appid"		"$APPID"
	"installdir"		"AION2"
}
EOF
  cat > "$steam/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
	"0"
	{
		"path"		"$steam"
		"apps"
		{
			"$APPID"		"1"
		}
	}
}
EOF
  cat > "$user/localconfig.vdf" <<'EOF'
"UserLocalConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"apps"
				{
					"730"
					{
						"LaunchOptions"		"gamemoderun %command%"
					}
				}
			}
		}
	}
}
EOF
  before=$(sha256sum "$game/DO_NOT_TOUCH" | awk '{print $1}')
  local bin_before
  bin_before=$(sha256sum "$steam/userdata/1001/config/localconfig.vdf" | awk '{print $1}')

  HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    ASCENSION_TARBALL="$ASCENSION_TARBALL" \
    ASCENSION_SKIP_HELPER_START=1 \
    ASCENSION_SKIP_SYSTEMD=1 \
    DLSSNR_UID=97531 \
    bash "$0"
  [ "$?" -eq 0 ]

  after=$(sha256sum "$game/DO_NOT_TOUCH" | awk '{print $1}')
  [ "$before" = "$after" ] || die "self-test: game file changed"
  [ ! -e "$game/nvngx_dlssnr.dll" ] || die "self-test: dll landed in the game"
  [ -f "$home/.local/share/dlssnr/binaries/nvngx_dlssnr.dll" ] || die "self-test: dll was not imported"
  grep -q 'VKLayer_DLSS5=1' "$user/localconfig.vdf" || die "self-test: launch option missing"
  grep -q 'gamemoderun %command%' "$user/localconfig.vdf" || die "self-test: other game launch option changed"
  [ ! -f "$home/.config/environment.d/dlssnr.conf" ] || die "self-test: global Vulkan pin left behind"
  local bin_after
  bin_after=$(sha256sum "$steam/userdata/1001/config/localconfig.vdf" | awk '{print $1}')
  [ "$bin_before" = "$bin_after" ] || die "self-test: binary steam config was rewritten"
  count=$(grep -c 'VKLayer_DLSS5=1' "$user/localconfig.vdf")
  [ "$count" -eq 1 ] || die "self-test: launch option duplicated on first run"

  HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    ASCENSION_TARBALL="$ASCENSION_TARBALL" \
    ASCENSION_SKIP_HELPER_START=1 \
    ASCENSION_SKIP_SYSTEMD=1 \
    DLSSNR_UID=97531 \
    bash "$0"
  count=$(grep -c 'VKLayer_DLSS5=1' "$user/localconfig.vdf")
  [ "$count" -eq 1 ] || die "self-test: launch option duplicated on second run"

  local stamp stamp2
  stamp=$(sha256sum "$user/localconfig.vdf" "$game/DO_NOT_TOUCH" | sha256sum)
  HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    ASCENSION_TARBALL="$ASCENSION_TARBALL" \
    bash "$0" --dry-run >/dev/null
  stamp2=$(sha256sum "$user/localconfig.vdf" "$game/DO_NOT_TOUCH" | sha256sum)
  [ "$stamp" = "$stamp2" ] || die "self-test: dry-run wrote files"

  HOME="$home" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    XDG_STATE_HOME="$home/.local/state" \
    ASCENSION_TARBALL="$ASCENSION_TARBALL" \
    ASCENSION_SKIP_SYSTEMD=1 \
    bash "$0" --remove >/dev/null
  if grep -q 'VKLayer_DLSS5' "$user/localconfig.vdf"; then
    die "self-test: remove left the launch option"
  fi
  grep -q 'gamemoderun %command%' "$user/localconfig.vdf" || die "self-test: remove ate the other game"
  after=$(sha256sum "$game/DO_NOT_TOUCH" | awk '{print $1}')
  [ "$before" = "$after" ] || die "self-test: remove touched the game"
  rm -rf "$tmp" "/tmp/dlssnr-97531"
  say "self-test ok"
}

main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY=1 ;;
      --remove) MODE="remove" ;;
      --purge) MODE="purge" ;;
      --apply-launch-only) MODE="launch" ;;
      --self-test) MODE="self-test" ;;
      -h | --help) usage; exit 0 ;;
      *) die "unknown option: $arg (try --help)" ;;
    esac
  done
  if [ "$MODE" = "self-test" ]; then
    self_test
    exit 0
  fi
  require_tools
  set_launch_prefix
  case "$MODE" in
    install) cmd_install ;;
    remove)
      say "Removing Ascension from AION 2. The game folder is not touched."
      discover_steam
      stop_helper
      remove_launch_options
      say "Launch option cleared. The layer is still installed. ascension --purge removes it."
      ;;
    purge)
      say "Purging the layer. The game folder is not touched."
      discover_steam
      purge_layer
      ;;
    launch)
      discover_steam
      apply_launch_options
      ;;
  esac
}

main "$@"
