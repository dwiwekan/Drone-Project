#!/usr/bin/env bash
# Stop PX4 SITL and Gazebo. Useful when a previous run left processes behind
# (a stale Gazebo server makes the next PX4 launch attach to the old world).
# Note: this stops every `gz sim` process on the machine, not only this project's.
set -u

pkill -INT -x px4 2>/dev/null && echo "[sim_down] stopped px4"
sleep 1
pkill -f 'gz sim' 2>/dev/null && echo "[sim_down] stopped gz sim"
pkill -x px4 2>/dev/null   # in case SIGINT was not enough
exit 0
