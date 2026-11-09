#!/usr/bin/env bash
# Native regression prerequisites only; not Safari, WebGL or device acceptance.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_CACHE_HOME="$work/cache"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
python3 -m unittest discover -s tests -p test_native_web_export.py
python3 -m unittest discover -s tests -p test_godot_web_compatibility.py
python3 -m unittest discover -s tests -p test_native_resource_profile.py
for suite in test_story_resource_lifecycle test_score_web_playback test_web_runtime_foundation test_web_focus_integration; do
  export XDG_DATA_HOME="$work/$suite-data"
  mkdir -p "$XDG_DATA_HOME"
  engine=("$GODOT")
  if command -v timeout >/dev/null 2>&1; then engine=(timeout 180s "$GODOT"); fi
  echo "RUN $suite"
  if ! "${engine[@]}" --headless --path godot --script "res://tests/$suite.gd" > "$work/run.log" 2>&1; then
    cat "$work/run.log"; exit 1
  fi
  cat "$work/run.log"
  if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked|^FAIL:' "$work/run.log"; then exit 1; fi
done
echo 'Web foundation passed. Exported-browser and physical-device acceptance remain separate.'
