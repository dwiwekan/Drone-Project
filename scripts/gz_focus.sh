#!/usr/bin/env bash
# Move the Gazebo GUI camera to a model once both the GUI and the model exist.
#
#   ./scripts/gz_focus.sh            # focus x500_0
#   ./scripts/gz_focus.sh x500_0 120 # custom model name and timeout (seconds)
set -u   # no pipefail: `grep -q` closing the pipe early is expected here

NAME="${1:-x500_0}"
TIMEOUT="${2:-90}"
export GZ_IP="${GZ_IP:-127.0.0.1}"

deadline=$((SECONDS + TIMEOUT))
until timeout 5 gz service -l 2>/dev/null | grep -qx '/gui/move_to' &&
      timeout 5 gz model --list 2>/dev/null | grep -q -- "- ${NAME}\$"; do
  if (( SECONDS >= deadline )); then
    echo "[gz_focus] timed out waiting for GUI and model '${NAME}'" >&2
    exit 1
  fi
  sleep 1
done

sleep 3   # let the GUI finish loading the model meshes
if timeout 5 gz service -s /gui/move_to --reqtype gz.msgs.StringMsg \
     --reptype gz.msgs.Boolean --timeout 3000 --req "data: \"${NAME}\"" >/dev/null 2>&1; then
  echo "[gz_focus] camera moved to ${NAME}"
else
  echo "[gz_focus] failed to move camera to ${NAME}" >&2
  exit 1
fi
