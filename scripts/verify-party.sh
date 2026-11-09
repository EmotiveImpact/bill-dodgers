#!/usr/bin/env bash
# Pair/CPU regression launcher. Automated routes use explicit invulnerability;
# passing them is not physical-input, difficulty, networking or mobile QA.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
full=false
quick=true
world=all
for arg in "$@"; do
  case "$arg" in
    --full) full=true ;;
    --routes-only) full=true; quick=false ;;
    --world=[1-6]) world="${arg#--world=}" ;;
    *) echo "Usage: $0 [--full|--routes-only] [--world=1..6]" >&2; exit 2 ;;
  esac
done
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
logs="${BD_PARTY_LOG_DIR:-$(mktemp -d /tmp/bill-dodgers-party-results.XXXXXX)}"
mkdir -p "$logs"
logs="$(cd "$logs" && pwd)"
export HOME="$work/home" XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
git rev-parse HEAD > "$logs/git-head.txt"
git status --short > "$logs/git-status.txt"
find godot/src godot/tests -type f -name '*.gd' -print0 | sort -z | xargs -0 sha256sum > "$logs/source-sha256.txt"
printf 'Logs: %s\n' "$logs"
sequence=0
run() {
  local suite="$1"; shift
  sequence=$((sequence + 1))
  local key log data
  printf -v key '%03d-%s' "$sequence" "$suite"
  log="$logs/$key.log"
  data="$work/$key-data"
  # Only these explicit restart probes share the selection fixture's state.
  if [[ "$suite" == test_party_selection ]]; then data="$work/selection-data"; fi
  mkdir -p "$data"
  local runner=("$GODOT")
  if command -v timeout >/dev/null 2>&1; then runner=(timeout 1200s "$GODOT"); fi
  printf '\nRUN %s %s\n' "$suite" "$*"
  if ! XDG_DATA_HOME="$data" "${runner[@]}" --headless --path godot --script "res://tests/$suite.gd" -- "$@" > "$log" 2>&1; then
    cat "$log"; echo "FAILED: $key" >&2; return 1
  fi
  cat "$log"
  if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked|^FAIL:' "$log"; then
    echo "Engine/assertion failure: $key" >&2; return 1
  fi
}
if $quick; then
  for suite in test_party_runtime test_companion_ai test_party_input test_companion_context test_party_combat test_party_combat_integration test_party_cpu_order test_party_cpu_skills test_party_revive_order test_party_host test_party_family_loading test_party_hud test_mobile_controls test_mobile_menu_integration test_legal_notices test_mobile_frontend_targets test_map_mobile_targets test_title_mobile_layout test_local_two_player_engine test_local_two_player_transitions test_party_selection test_save_presentation test_party_world_one test_party_world_two test_party_world_two_host test_festival_party_combat test_festival_party_world test_holiday_party test_holiday_party_host test_moving_day_party test_moving_day_party_host test_billing_party test_billing_party_host; do
    run "$suite"
    if [[ "$suite" == test_party_selection ]]; then
      for role in p2 cpu solo; do run test_party_selection --restart-check "$role"; done
    fi
  done
fi
if $full; then
  if [[ "$world" == all || "$world" == 1 ]]; then
    run test_local_two_player_routes --level=1-1 "--output=$logs/local-p2-1-1.json"
  fi
  if [[ "$world" == all || "$world" == 2 ]]; then
    for stage in 1 2; do run test_local_two_player_routes "--level=2-$stage" "--output=$logs/local-p2-2-$stage.json"; done
  fi
  if [[ "$world" == all || "$world" == 1 ]]; then
    for suite in test_full_party_street_run test_full_party_rooftop_run test_full_party_bus_run test_remaining_party_street_runs test_full_party_binman_run; do
      run "$suite" --cycle-mates
    done
  fi
  for mate in jp maya ama leo theo mei; do
    if [[ "$world" == all || "$world" == 2 ]]; then
      run test_party_world_two_full_runs "--cpu=$mate" "--output=$logs/world-two-$mate.json"
    fi
    if [[ "$world" == all || "$world" == 3 ]]; then
      # Separate short-lived instances bound memory in the long Queue/Bonus runs.
      for stage in 1 2 3 4 5 6 S; do
        run test_full_festival_party_run "--character=$mate" "--level=3-$stage"
      done
    fi
    if [[ "$world" == all || "$world" == 4 ]]; then
      run test_full_holiday_party_runs "--cpu=$mate" "--output=$logs/world-four-$mate.json"
    fi
    if [[ "$world" == all || "$world" == 5 ]]; then
      run test_full_moving_day_party_runs --mode=cpu "--mate=$mate" "--output=$logs/world-five-$mate.json"
    fi
    if [[ "$world" == all || "$world" == 6 ]]; then
      run test_full_billing_party_runs "--character=$mate" "--report=$logs/world-six-$mate.json"
    fi
  done
fi
echo "Passed $sequence pair regression processes. Logs: $logs"
echo 'Assisted source-progression evidence only. Device and human-input acceptance remain separate.'
