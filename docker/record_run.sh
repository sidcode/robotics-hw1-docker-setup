#!/usr/bin/env bash
# Part D data capture: run a world headless and save the cross-track error as a
# ROS 2 bag + a CSV in /root/output (-> docker/output on the host).
# Usage (inside the container): record_run.sh <world.world> [seconds]
set -e
source /opt/ros/humble/setup.bash
source /root/mrs_ws/install/local_setup.bash
export ROS_DOMAIN_ID=0 ROS_LOCALHOST_ONLY=1
# Headless run: keep Qt apps (rqt) from erroring on a missing display.
export QT_QPA_PLATFORM=offscreen

WORLD="${1:-walls_one_sided.world}"
DUR="${2:-60}"
NAME="${WORLD%.world}"
OUT=/root/output
mkdir -p "$OUT"
rm -rf "$OUT/bag_${NAME}"

echo "### [record] launching $WORLD headless ..."
ros2 launch wall_following_assigment bringup.launch.py world:="$WORLD" gui:=false rviz:=false \
    > "$OUT/run_${NAME}.log" 2>&1 &
LP=$!

for i in $(seq 1 60); do
    ros2 topic list 2>/dev/null | grep -q "/husky/cte" && break; sleep 1
done
sleep 3

echo "### [record] recording /husky/cte for ${DUR}s ..."
ros2 bag record -o "$OUT/bag_${NAME}" /husky/cte > /dev/null 2>&1 &
BP=$!
timeout "${DUR}" ros2 topic echo /husky/cte > "$OUT/${NAME}.csv" 2>/dev/null || true

kill "$BP" 2>/dev/null || true
kill "$LP" 2>/dev/null || true
pkill -f gzserver 2>/dev/null || true
pkill -f gzclient 2>/dev/null || true
sleep 2
echo "### [record] done. Wrote:"
echo "    docker/output/${NAME}.csv"
echo "    docker/output/bag_${NAME}/"
