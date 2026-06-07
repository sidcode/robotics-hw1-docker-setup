# =============================================================================
# robots101 HW1 -- self-contained wall-following assignment image
#
# Fully self-contained and reproducible on ANY machine with Docker + the NVIDIA
# Container Toolkit. Ubuntu 22.04 + ROS 2 Humble (desktop-full) + Gazebo Classic
# 11 + ros2_control, plus the HW1 workspace, built exactly the way the handout
# describes:
#   ~/mrs_ws/src  <- starter code (here: /root/mrs_ws/src/HW1)
#   ./package_install.bash
#   rosdep update --include-eol-distros
#   rosdep install --from-paths src -y --ignore-src
#   colcon build --symlink-install
# =============================================================================
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV ROS_DOMAIN_ID=0
ENV ROS_LOCALHOST_ONLY=1

# --- Locale -----------------------------------------------------------------
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# --- Base tooling + ROS 2 apt repo ------------------------------------------
RUN apt-get update && apt-get install -y \
    software-properties-common curl gnupg lsb-release git wget vim nano sudo tmux \
    python3-pip python3-dev && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" \
        > /etc/apt/sources.list.d/ros2.list && \
    rm -rf /var/lib/apt/lists/*

# --- ROS 2 Humble + Gazebo + control stack ----------------------------------
RUN apt-get update && apt-get install -y \
    ros-humble-desktop-full \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-gazebo-ros2-control \
    ros-humble-ros2-control \
    ros-humble-ros2-controllers \
    ros-humble-robot-localization \
    ros-humble-xacro \
    ros-humble-tf-transformations \
    ros-humble-tf2-tools \
    ros-humble-joint-state-publisher-gui \
    ros-humble-rqt-reconfigure \
    python3-colcon-common-extensions \
    python3-rosdep python3-argcomplete python3-vcstool && \
    rm -rf /var/lib/apt/lists/*

RUN rosdep init && rosdep update

# --- Workspace (HW1 step: create ~/mrs_ws/src and add the starter code) -------
ENV MRS_WS=/root/mrs_ws
RUN mkdir -p ${MRS_WS}/src

# HW1 step: ./package_install.bash  (installs the assignment's apt dependencies).
# Copied + run on its own so this slow layer stays cached across code edits.
COPY HW1/wall_following_assigment/package_install.bash /tmp/package_install.bash
RUN chmod +x /tmp/package_install.bash && /tmp/package_install.bash && \
    rm -rf /var/lib/apt/lists/*

# Now the full starter code.
COPY HW1 ${MRS_WS}/src/HW1

# HW1 step: make the assignment scripts executable.
RUN chmod +x ${MRS_WS}/src/HW1/wall_following_assigment/scripts/*.py

# HW1 step: resolve workspace dependencies with rosdep.
# husky_bringup run-depends on real-robot-only drivers that the simulation does
# not need; we skip those keys so rosdep finishes cleanly.
WORKDIR ${MRS_WS}
RUN apt-get update && \
    (rosdep update --include-eol-distros 2>/dev/null || true) && \
    bash -c "source /opt/ros/humble/setup.bash && \
        rosdep install --from-paths src -y --ignore-src --rosdistro humble \
            --skip-keys 'microstrain_inertial_driver robot_upstart urg_node \
                         velodyne_driver velodyne_pointcloud nmea_navsat_driver' \
        || true" && \
    rm -rf /var/lib/apt/lists/*

# HW1 step: colcon build --symlink-install (the whole workspace).
RUN bash -c "source /opt/ros/humble/setup.bash && colcon build --symlink-install"

# --- Shell convenience (HW1 step: the lines to add to ~/.bashrc) -------------
RUN echo "export ROS_DOMAIN_ID=0"                    >> /root/.bashrc && \
    echo "export ROS_LOCALHOST_ONLY=1"               >> /root/.bashrc && \
    echo "source /opt/ros/humble/setup.bash"         >> /root/.bashrc && \
    echo "source ${MRS_WS}/install/local_setup.bash" >> /root/.bashrc

# Also source for login shells (`docker compose exec ... bash -lc ...` bypasses the
# entrypoint and is non-interactive, so it never reads ~/.bashrc).
RUN printf '%s\n' \
    'export ROS_DOMAIN_ID=0' \
    'export ROS_LOCALHOST_ONLY=1' \
    'source /opt/ros/humble/setup.bash' \
    "source ${MRS_WS}/install/local_setup.bash" \
    > /etc/profile.d/10-ros-hw1.sh

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
