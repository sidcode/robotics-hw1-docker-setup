#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# robots101 HW1 helper. Run from the docker/ directory:
#
#   ./run.sh build          # build the image
#   ./run.sh shell          # open a shell in the container (starts it if needed)
#   ./run.sh solution       # one command: Gazebo + Husky + PID controller + rqt
#   ./run.sh solution two   # same, but the two-sided world
#   ./run.sh viz [one|two]   # headless Gazebo + RViz + controller (no gzclient hang)
#   ./run.sh sim [one|two]   # just Gazebo + Husky (drive it yourself / teleop)
#   ./run.sh rviz           # open rviz2 with the provided config
#   ./run.sh teleop         # keyboard teleop (sanity check from the handout)
#   ./run.sh record [one|two]# run the world headless and save cte CSV + bag to output/
#   ./run.sh stop           # stop and remove the container
# -----------------------------------------------------------------------------
set -e
cd "$(dirname "$0")"
SVC=hw1
# Default = NVIDIA GPU (docker-compose.yml). Set HW1_GPU=0 to use the software-GL
# CPU variant (no NVIDIA GPU required).
if [ "${HW1_GPU:-1}" = "0" ]; then
    DC="docker compose -f docker-compose.cpu.yml"
else
    DC="docker compose"
fi

world_file() { [ "$1" = "two" ] && echo "walls_two_sided.world" || echo "walls_one_sided.world"; }

allow_x() {
    # Let the container talk to the host X server (GUI: Gazebo / rviz / rqt).
    xhost +local:root >/dev/null 2>&1 || true
}

ensure_up() {
    if [ -z "$($DC ps -q $SVC 2>/dev/null)" ]; then
        allow_x
        $DC up -d
    fi
}

# Source ROS + workspace explicitly: `docker compose exec` bypasses the entrypoint,
# and a non-interactive bash does not read ~/.bashrc.
SRC='source /opt/ros/humble/setup.bash && source /root/mrs_ws/install/local_setup.bash'
dexec() { $DC exec $SVC bash -lc "$SRC && $1"; }

case "${1:-shell}" in
    build)    $DC build ;;
    shell)    ensure_up; allow_x; $DC exec $SVC bash ;;
    sim)      ensure_up; dexec "ros2 launch wall_following_assigment gazebo_wall_world.launch.py world:=$(world_file ${2:-one})" ;;
    solution) ensure_up; dexec "ros2 launch wall_following_assigment bringup.launch.py world:=$(world_file ${2:-one})" ;;
    viz)      ensure_up; dexec "ros2 launch wall_following_assigment bringup.launch.py world:=$(world_file ${2:-one}) gui:=false rviz:=true" ;;
    rviz)     ensure_up; dexec "rviz2 -d /root/mrs_ws/src/HW1/wall_following_assigment/resources/wall_following.rviz" ;;
    teleop)   ensure_up; dexec "ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -r cmd_vel:=/husky_velocity_controller/cmd_vel_unstamped" ;;
    record)   ensure_up; $DC exec -T $SVC bash -s -- "$(world_file ${2:-one})" "${3:-60}" < record_run.sh ;;
    stop)     $DC down ;;
    *) echo "unknown command: $1"; sed -n '2,20p' "$0"; exit 1 ;;
esac
