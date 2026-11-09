#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
engine=("$GODOT")
if command -v timeout >/dev/null 2>&1; then engine=(timeout 120s "$GODOT"); fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# Isolated editor/cache/save state. Tests never touch personal game saves.
export HOME="$work/home" XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
run_engine() {
  local log="$work/engine.log"
  # A GUI fixture may deliberately save a CPU/P2 party. A later solo test must
  # never inherit it. Tests that exercise restart do so inside their own suite.
  local data
  data="$(mktemp -d "$work/suite-data.XXXXXX")"
  local runner=("${engine[@]}")
  # Complete six-character later-world routes are longer than unit fixtures.
  if command -v timeout >/dev/null 2>&1; then
    if [[ "$*" == *test_world_six_full_runs.gd* ]]; then runner=(timeout 900s "$GODOT");
    elif [[ "$*" == *test_full_moving_day_runs.gd* || "$*" == *test_full_holiday_runs.gd* ]]; then runner=(timeout 900s "$GODOT"); fi
  fi
  XDG_DATA_HOME="$data" "${runner[@]}" "$@" > "$log" 2>&1 || { cat "$log"; return 1; }
  cat "$log"
  if grep -Eq 'SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB instances leaked' "$log"; then
    echo 'Godot reported a runtime error or leaked object.' >&2
    return 1
  fi
}
python3 scripts/import-godot-content.py
node scripts/extract-story.mjs
python3 -m unittest discover -s tests -v
run_engine --headless --path godot --script res://tools/build_audio.gd
"$GODOT" --headless --path godot --editor --import > "$work/import.log" 2>&1
if grep -E 'SCRIPT ERROR|Parse Error|^ERROR:' "$work/import.log"; then
  echo 'Godot reported an import or script error.' >&2
  exit 1
fi
run_engine --headless --path godot --script res://tests/smoke.gd
run_engine --headless --path godot --script res://tests/test_pickup_inventory.gd
run_engine --headless --path godot --script res://tests/test_receipt_replay.gd
run_engine --headless --path godot --script res://tests/test_mobile_controls.gd
run_engine --headless --path godot --script res://tests/test_mobile_menu_integration.gd
for suite in test_legal_notices test_mobile_frontend_targets test_map_mobile_targets test_title_mobile_layout test_jar_thief test_abilities test_story test_audio test_combat_integration test_full_street_run test_movement_skills test_passive_movement_order test_skill_integration test_world_one test_world_one_integration test_rooftop_renderer test_full_rooftop_run test_bus_ride test_bus_integration test_bus_renderer test_full_bus_run test_street_renderer test_remaining_street_runs test_binman test_binman_renderer test_street_expansion test_ability_ghost_order test_full_binman_run test_world_two test_supermarket_combat test_supermarket_renderer test_supermarket_integration test_full_parking_run test_supermarket_hazards test_aisle_renderer test_shopping_street_renderer test_aisle_integration test_full_aisle_run test_full_shopping_bonus_run test_stockroom_renderer test_stockroom_integration test_full_stockroom_run test_supermarket_course test_bakery_renderer test_trolley_dash_renderer test_course_integration test_full_bakery_run test_full_trolley_dash_run test_checkout_boss test_checkout_renderer test_checkout_integration test_full_checkout_run test_campaign_progression test_save_presentation test_campaign_map test_campaign_map_integration test_campaign_integration test_world_three test_festival_combat test_festival_boss test_festival_renderer test_festival_integration test_full_festival_field_run test_festival_queue_rush test_festival_queue_renderer test_festival_queue_integration test_full_festival_queue_run test_festival_night test_festival_night_renderer test_festival_night_integration test_full_festival_night_run test_festival_big_top test_festival_big_top_renderer test_big_top_integration test_full_big_top_run test_festival_hayride test_festival_hayride_renderer test_festival_hayride_integration test_full_festival_hayride_run test_festival_finale test_festival_tout_renderer test_ticket_tout_integration test_full_ticket_tout_run test_festival_bonus test_festival_bonus_renderer test_festival_bonus_integration test_full_festival_bonus_run test_native_audit test_player_hud test_touch_controls test_shared_effects_renderer test_shared_loot_renderer test_visual_feedback test_visual_feedback_integration test_texture_mirroring test_sprite_mirroring test_hud_notifications test_later_world_loading test_holiday_runtime test_holiday_renderer test_holiday_lifecycle test_holiday_captain test_holiday_captain_renderer test_full_holiday_runs test_full_captain_run test_world_five test_world_five_renderer test_world_five_integration test_world_five_collectibles test_full_moving_day_runs test_world_six test_billing_combat test_billing_renderer test_sir_charge test_world_six_integration test_world_six_receipts test_world_six_collectibles test_world_six_presentation test_world_six_full_runs test_credits_roll test_campaign_completion test_original_score test_original_score_integration; do
  if [[ "$suite" == test_audio ]]; then
    run_engine --headless --path godot --script "res://tests/$suite.gd" -- --require-prebuilt
  elif [[ "$suite" == test_full_moving_day_runs || "$suite" == test_world_six_full_runs ]]; then
    run_engine --headless --path godot --script "res://tests/$suite.gd" -- --all-characters
  else
    run_engine --headless --path godot --script "res://tests/$suite.gd"
  fi
done
echo 'Native data and headless runtime checks passed. This does not validate device rendering or exports.'
