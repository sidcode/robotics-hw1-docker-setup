#!/bin/bash
set -e

# Stop Gazebo from contacting the online model database (it hangs the gzclient GUI
# on "Preparing your world"). All HW1 worlds use local models.
export GAZEBO_MODEL_DATABASE_URI="${GAZEBO_MODEL_DATABASE_URI-}"

# Source ROS 2 and the HW1 workspace for every command run in the container.
source /opt/ros/humble/setup.bash
if [ -f "/root/mrs_ws/install/local_setup.bash" ]; then
    source /root/mrs_ws/install/local_setup.bash
fi

exec "$@"
