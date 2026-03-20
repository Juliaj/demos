#!/usr/bin/env bash

# set -uo pipefail

# Strip ANSI escapes (e.g. from `HF_USER=$(hf auth whoami)` when the CLI uses colors). LeRobot parses
# repo_id as YAML; a leading ESC triggers: ReaderError unacceptable character #x001b.
_hf_user_plain() {
  printf '%s' "${HF_USER:-}" | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\r'
}

# Match lerobot.utils.constants (HF_HOME, HF_LEROBOT_HOME).
_lerobot_resolved_hf_home() {
  local h="${HF_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/huggingface}"
  printf '%s' "${h/#\~/$HOME}"
}

_lerobot_resolved_base() {
  local hf_home
  hf_home="$(_lerobot_resolved_hf_home)"
  if [[ -n "${HF_LEROBOT_HOME:-}" ]]; then
    printf '%s' "${HF_LEROBOT_HOME/#\~/$HOME}"
  else
    printf '%s/lerobot' "${hf_home}"
  fi
}

_hf_hub_dir() {
  local hf_home hub
  hf_home="$(_lerobot_resolved_hf_home)"
  hub="${HF_HUB_CACHE:-${hf_home}/hub}"
  printf '%s' "${hub/#\~/$HOME}"
}

record() {
  # Streaming encode (0.4.4+): faster episode save; vcodec=auto picks best HW encoder when available.
  # Tune I/O: --dataset.num_image_writer_threads_per_camera=4 --dataset.num_image_writer_processes=0

  : "${HF_USER:?set HF_USER to your Hugging Face username (avoid colored hf output; use NO_COLOR=1 hf auth whoami)}"
  local dataset_name="record-test"
  local hf_user_plain
  hf_user_plain="$(_hf_user_plain)"
  local repo_id="${hf_user_plain}/${dataset_name}"

  # Same paths bash and Python use (env can differ inside pixi/subshells if not passed through).
  local hf_home lr_base lerobot_ds_root hf_hub
  hf_home="$(_lerobot_resolved_hf_home)"
  lr_base="$(_lerobot_resolved_base)"
  lerobot_ds_root="${lr_base}/${repo_id}"
  hf_hub="$(_hf_hub_dir)"

  echo "Removing local LeRobot dataset dir: ${lerobot_ds_root}"
  if [[ -e "${lerobot_ds_root}" ]]; then
    chmod -R u+w "${lerobot_ds_root}" 2>/dev/null || true
    rm -rf "${lerobot_ds_root}"
  fi
  if [[ -e "${lerobot_ds_root}" ]]; then
    echo "error: could not remove dataset dir (permissions or in use?): ${lerobot_ds_root}" >&2
    return 1
  fi

  shopt -s nullglob
  local hub_dir
  for hub_dir in "${hf_hub}/datasets--${hf_user_plain}--${dataset_name}"*; do
    echo "Removing Hub snapshot cache: ${hub_dir}"
    rm -rf "${hub_dir}"
  done
  shopt -u nullglob

  # Optional: DELETE_HF_DATASET_ON_HUB=1 also removes the dataset on the Hub (needs hf CLI + auth).
  if [[ "${DELETE_HF_DATASET_ON_HUB:-0}" == 1 ]] && command -v hf >/dev/null 2>&1; then
    echo "Deleting Hub dataset ${repo_id} (DELETE_HF_DATASET_ON_HUB=1)"
    hf repo delete "${repo_id}" --repo-type dataset || true
  fi

  # push_to_hub=false avoids LeRobot 0.4.x bug: finally calls dataset.push_to_hub when create() failed (dataset is None).
  local push_hub="false"
  [[ "${PUSH_LEROBOT_DATASET:-0}" == 1 ]] && push_hub="true"

  env HF_HOME="${hf_home}" HF_LEROBOT_HOME="${lr_base}" \
      lerobot-record \
      --robot.type=so101_follower \
      --robot.port=/dev/ttyACM0 \
      --robot.id=my_follower_arm \
      --robot.cameras='{ front: {type: opencv, index_or_path: "/dev/video0", width: 640, height: 480, fps: 30,fourcc: "MJPG"}, wrist: {type: opencv, index_or_path: "/dev/video2", width: 640, height: 480, fps: 30,fourcc: "MJPG"}}' \
      --teleop.type=so101_leader \
      --teleop.port=/dev/ttyACM1 \
      --teleop.id=my_leader_arm \
      --display_data=false \
      --dataset.repo_id="${repo_id}" \
      --dataset.num_episodes=5 \
      --dataset.single_task="Grab the blue cube" \
      --dataset.streaming_encoding=true \
      --dataset.encoder_threads=2 \
      --dataset.vcodec=auto \
      --dataset.push_to_hub="${push_hub}"
}

teleop() {
  echo "Teleoperating SO-101 follower arm"
  echo

  lerobot-teleoperate \
      --robot.type=so101_follower \
      --robot.port=/dev/ttyACM0 \
      --robot.id=my_follower_arm \
      --robot.cameras='{ front: {type: opencv, index_or_path: "/dev/video0", width: 640, height: 480, fps: 30,fourcc: "MJPG"}, wrist: {type: opencv, index_or_path: "/dev/video2", width: 640, height: 480, fps: 30,fourcc: "MJPG"}}' \
      --teleop.type=so101_leader \
      --teleop.port=/dev/ttyACM1 \
      --teleop.id=my_leader_arm \
      --display_data=true
}

recalibrate_leader() {
  echo "Recalibrating SO-101 leader arm"
  echo
  rm -rf ~/.cache/huggingface/lerobot/calibration/teleoperators

  lerobot-calibrate \
    --teleop.type=so101_leader \
    --teleop.port=/dev/ttyACM1 \
    --teleop.id=my_leader_arm
}

recalibrate_follower() {
  echo "Recalibrating SO-101 follower arm"
  echo

  rm -rf ~/.cache/huggingface/lerobot/calibration/robots/

  lerobot-calibrate \
    --robot.type=so101_follower \
    --robot.port=/dev/ttyACM0 \
    --robot.id=my_follower_arm
}

record
# teleop
# recalibrate_leader
# recalibrate_follower