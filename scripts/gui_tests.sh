#!/usr/bin/env bash
# Keep native builds sequential: Flutter debug/release share an engine directory.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
export LIBGL_ALWAYS_SOFTWARE=1
log_dir="${TIXUN_GUI_LOG_DIR:-.}"
mkdir -p "$log_dir"
tests=(
  'chat_flow:integration.log'
  'python_flow:integration-python.log'
  'learning_materials:integration-materials.log'
  'practice_flow:integration-practice.log'
  'backup_flow:integration-backup.log'
  'practice_management:integration-management.log'
  'ai_preferences:integration-ai-preferences.log'
  'chatgpt_flow:integration-chatgpt.log'
  'scratchpad_reasoning:integration-scratchpad.log'
  'exam_flow:integration-exams.log'
  'modules_flow:integration-modules.log'
  'subject_preferences_flow:integration-subjects.log'
  'visual_flow:integration-visual.log'
  'visual_player_flow:integration-visual-player.log'
  'visual_drag_flow:integration-visual-drag.log'
  'visual_quiz_flow:integration-visual-quiz.log'
  'visual_circuit_flow:integration-visual-circuit.log'
  'visual_chem_geo_flow:integration-visual-chem-geo.log'
  'visual_constraints_flow:integration-visual-constraints.log'
  'visual_drag_answer_flow:integration-visual-drag-answer.log'
)
for entry in "${tests[@]}"; do
  test_name="${entry%%:*}"
  log_name="${entry#*:}"
  timeout 240s xvfb-run -a -s '-screen 0 1280x900x24' dbus-run-session -- \
    flutter test "integration_test/${test_name}_test.dart" -d linux \
      --dart-define=TIXUN_DEMO=true 2>&1 | tee "$log_dir/$log_name"
done
