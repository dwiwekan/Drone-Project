#!/usr/bin/env bash
# One-time setup on Ubuntu 22.04:
#   1. fetch PX4-Autopilot at the version pinned by this repo (git submodule)
#   2. install PX4's toolchain + Gazebo Harmonic (PX4's own ubuntu.sh, needs sudo)
#   3. build PX4 SITL
#
#   ./scripts/setup.sh              # full setup
#   ./scripts/setup.sh --skip-deps  # only fetch + build (dependencies already installed)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_DEPS=0
[[ "${1:-}" == "--skip-deps" ]] && SKIP_DEPS=1

cd "$ROOT"

echo "[setup] 1/3 Fetching PX4-Autopilot (pinned submodule)..."
git submodule update --init --recursive PX4-Autopilot

if [[ $SKIP_DEPS -eq 0 ]]; then
  echo "[setup] 2/3 Installing PX4 dependencies + Gazebo Harmonic (sudo required)..."
  echo "        Note: Gazebo Classic must be removed first on Ubuntu 22.04 (both ship /usr/bin/gz)."
  bash PX4-Autopilot/Tools/setup/ubuntu.sh --no-nuttx
else
  echo "[setup] 2/3 Skipping dependency installation"
fi

echo "[setup] 3/3 Building PX4 SITL..."
make -C PX4-Autopilot px4_sitl

echo "[setup] Done. Start the simulation with: ./scripts/sim_up.sh"
