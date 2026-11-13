#!/usr/bin/env bash
# Launch PX4 SITL + Gazebo Harmonic with this project's parameter overrides.
#
#   ./scripts/sim_up.sh                       # x500 in the default world
#   ./scripts/sim_up.sh -m x500_mono_cam      # x500 with a forward mono camera
#   ./scripts/sim_up.sh -w baylands --headless
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PX4_DIR="$ROOT/PX4-Autopilot"
PARAMS_FILE="$ROOT/config/px4_params.env"

MODEL="x500"
WORLD="default"
HEADLESS_MODE=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [-m MODEL] [-w WORLD] [--headless]

  -m, --model MODEL   Vehicle model (default: x500), e.g. x500_mono_cam, x500_depth
  -w, --world WORLD   Gazebo world (default: default), e.g. baylands, lawn, walls, windy
      --headless      Run without the Gazebo GUI
  -h, --help          Show this help

Models: ls PX4-Autopilot/Tools/simulation/gz/models
Worlds: ls PX4-Autopilot/Tools/simulation/gz/worlds
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model) MODEL="$2"; shift 2 ;;
    -w|--world) WORLD="$2"; shift 2 ;;
    --headless) HEADLESS_MODE=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$PX4_DIR/Makefile" ]]; then
  echo "[sim_up] PX4-Autopilot not found. Run ./scripts/setup.sh first." >&2
  exit 1
fi

# Each KEY=VALUE line becomes PX4_PARAM_KEY=VALUE, applied by PX4 at boot.
while IFS='=' read -r key value || [[ -n "$key" ]]; do
  key="${key//[[:space:]]/}"
  [[ -z "$key" || "$key" == \#* ]] && continue
  value="${value%%#*}"
  value="${value//[[:space:]]/}"
  export "PX4_PARAM_${key}=${value}"
  echo "[sim_up] param override: ${key}=${value}"
done < "$PARAMS_FILE"

export PX4_GZ_WORLD="$WORLD"
export GZ_IP=127.0.0.1   # keep Gazebo transport on localhost (same as PX4's make target)
if [[ $HEADLESS_MODE -eq 1 ]]; then
  export HEADLESS=1
else
  # Point the GUI camera at the drone once it has spawned.
  "$ROOT/scripts/gz_focus.sh" "${MODEL}_0" &
fi

echo "[sim_up] model=gz_${MODEL} world=${WORLD} headless=${HEADLESS_MODE}"
exec make -C "$PX4_DIR" px4_sitl "gz_${MODEL}"
