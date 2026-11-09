#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
engine=("$GODOT")
if command -v timeout >/dev/null 2>&1; then engine=(timeout 120s "$GODOT"); fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$work/harness/src"
# Run verify-native.sh first. This reimports current scripts/resources before packing.
pack="${1:-$work/native-preview.pck}"
pack="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$pack")"
run_engine() {
  "${engine[@]}" "$@" > "$work/run.log" 2>&1 || { cat "$work/run.log"; return 1; }
  if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked' "$work/run.log"; then cat "$work/run.log"; return 1; fi
}
run_engine --headless --path godot --editor --import
run_engine --headless --path godot --export-pack 'Android Native Preview' "$pack"
# No source assets are available in this harness. Raw WAVs once passed editor
# tests but vanished from the export; mandatory prebuilt checks prevent relapse.
printf 'config_version=5\n' > "$work/harness/project.godot"
cp godot/tests/test_packed_runtime.gd "$work/harness/runtime.gd"
cp godot/tests/test_audio.gd "$work/harness/audio.gd"
cp godot/src/game_audio.gd "$work/harness/src/game_audio.gd"
run_engine --headless --path "$work/harness" --script res://runtime.gd -- "--pack=$pack"
cat "$work/run.log"
run_engine --headless --path "$work/harness" --script res://audio.gd -- "--pack=$pack" --require-prebuilt
cat "$work/run.log"
# Independently prove each new music resource contains its encoded stream,
# with no compositor intermediates or project scripts available to help it.
run_engine --headless --path godot --script res://tests/test_original_score_pack.gd -- "--build-pack=$work/score.pck"
cat "$work/run.log"
mkdir -p "$work/score-empty"
run_engine --headless --path "$work/score-empty" --main-pack "$work/score.pck" --script res://tests/test_original_score_pack.gd -- --isolated
cat "$work/run.log"
echo 'Resource pack verified in an asset-free harness. This is not an APK, IPA or device test.'
if [[ $# -gt 0 ]]; then echo "Pack: $pack"; fi
