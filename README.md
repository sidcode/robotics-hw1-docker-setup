# HW1: Wall Following (Docker setup)

A ready-to-use, reproducible environment for HW1 of *51.515 Fundamentals of
Robotics and Multi-Robot Systems*. The assignment is to write a PID controller
that makes a Husky follow the wall on its left in Gazebo.

Everything (ROS 2 Humble, Gazebo, RViz, rqt, and the `~/mrs_ws` workspace) lives
inside one Docker image, so you do not need to install ROS on your machine. The
full assignment description is in [`HW1.pdf`](HW1.pdf).

## Demo

The recording below shows the environment running: the controller publishing the
cross-track error on `/husky/cte`, the laser scanning at 50 Hz, and the Husky
driving along the course.

![HW1 wall-following demo](docs/demo.gif)

## 1. What's in here

```
HW1-Docker-Setup/
├── README.md
├── HW1.pdf                      <- the assignment handout (read this)
├── HW1/                         <- the ROS 2 workspace (goes to ~/mrs_ws/src/HW1)
│   ├── wall_following_assigment/
│   │   ├── scripts/wall_follower.py   <- you write your code here (Parts A, B, C)
│   │   ├── launch/                     <- gazebo + controller launch files
│   │   ├── worlds/                     <- walls_one_sided.world, walls_two_sided.world
│   │   └── resources/wall_following.rviz
│   ├── husky/ , LMS1xx/                 <- robot description + laser driver
└── docker/
    ├── Dockerfile              <- self-contained image (Ubuntu 22.04 + ROS 2 Humble + Gazebo)
    ├── docker-compose.yml      <- NVIDIA GPU setup
    ├── docker-compose.cpu.yml  <- no-GPU setup (Mesa software rendering)
    ├── entrypoint.sh
    ├── run.sh                  <- convenience wrapper (build / shell / solution / ...)
    └── output/                 <- recordings (bags / CSVs) land here on your host
```

## 2. Prerequisites

A Linux host with:

1. Docker and Docker Compose v2
   ```bash
   docker --version
   docker compose version
   ```
2. A GPU path. Pick the one that matches your machine:
   - NVIDIA GPU (recommended): install the NVIDIA Container Toolkit
     ```bash
     curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
       | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
     curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
       | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
       | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
     sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
     sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
     docker run --rm --gpus all nvidia/cuda:12.2.2-base-ubuntu22.04 nvidia-smi   # verify
     ```
   - No NVIDIA GPU: use the CPU variant in [section 8](#8-running-without-an-nvidia-gpu).
     The same image works both ways.
3. An X server (a normal Linux desktop session). Check that `echo $DISPLAY` is non-empty.

> Windows, macOS, and WSL2: these instructions target native Linux (the lab
> machines). They may also work with an X server such as WSLg or XQuartz. That
> path is not tested here.

## 3. Build the image

```bash
cd docker
./run.sh build
```

The first build downloads ROS 2 Humble and Gazebo and compiles the workspace,
which takes around 15 to 25 minutes. Later builds use the cache and are fast. The
build runs the same steps the handout lists, inside the image:
`package_install.bash`, then `rosdep install`, then `colcon build --symlink-install`.

## 4. Run it

### Option A: one command (recommended)

```bash
cd docker
./run.sh solution           # Gazebo GUI + Husky + your controller + rqt (one-sided world)
./run.sh solution two       # the two-sided world
```

> Gazebo's first load is slow and can sit on "Preparing your world" for a minute.
> Wait for it to finish. If it stays stuck, use Option C (headless + RViz), or see
> [section 7](#7-troubleshooting).
>
> Until you implement `wall_follower.py` the robot does not move. That is expected.

### Option B: the handout's 3-terminal workflow

```bash
./run.sh shell      # terminal 1
ros2 launch wall_following_assigment gazebo_wall_world.launch.py
#   switch worlds:  ... gazebo_wall_world.launch.py world:=walls_two_sided.world

./run.sh shell      # terminal 2
rviz2 -d ~/mrs_ws/src/HW1/wall_following_assigment/resources/wall_following.rviz

./run.sh shell      # terminal 3
ros2 launch wall_following_assigment wall_follower_python.launch.py
```

These are the grading commands and work verbatim:
```bash
ros2 launch wall_following_assigment gazebo_wall_world.launch.py
ros2 launch wall_following_assigment wall_follower_python.launch.py
```

### Option C: headless Gazebo + RViz (reliable GUI option)

If `gzclient` hangs on your machine, run Gazebo headless and watch the robot and
laser scan in RViz:

```bash
./run.sh viz            # one-sided world, no gzclient
./run.sh viz two        # two-sided world
```

### Other helpers

```bash
./run.sh shell          # open a bash shell in the container
./run.sh sim [one|two]   # just Gazebo + Husky (no controller; drive it yourself)
./run.sh rviz           # open RViz with the provided config
./run.sh teleop         # keyboard teleop sanity check (from the handout)
./run.sh stop           # stop and remove the container
```

`teleop` runs:
```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard \
  --ros-args -r cmd_vel:=/husky_velocity_controller/cmd_vel_unstamped
```

## 5. Your task

You write your code in
[`HW1/wall_following_assigment/scripts/wall_follower.py`](HW1/wall_following_assigment/scripts/wall_follower.py).
See `HW1.pdf` for full details and the point breakdown. In short:

- Part A: compute the cross-track error from each `LaserScan` and publish it on
  `/husky/cte` (`std_msgs/Float32`).
- Part B: fill in the `PID` class and command an angular velocity on
  `/husky/cmd_vel` so the robot follows the left wall.
- Part C: make the PID gains live-tunable from `rqt_reconfigure`. The launch file
  exposes `Kp`, `Kd`, `Ki`, `forward_speed`, and `desired_distance_from_wall`. Set
  their initial values in `launch/wall_follower_python.launch.py`.
- Part D: run both worlds, record a video and the cross-track-error CSV.

After editing `wall_follower.py`, re-run `./run.sh solution`. The workspace is
built with `--symlink-install`, so Python changes take effect immediately and you
do not need to rebuild.

Note from the starter code: the laser is published with BEST_EFFORT QoS, so your
scan subscriber must request BEST_EFFORT to receive messages:
```python
from rclpy.qos import QoSProfile, QoSReliabilityPolicy
qos = QoSProfile(depth=10, reliability=QoSReliabilityPolicy.BEST_EFFORT)
```

## 6. Part D: videos and CSVs

Cross-track-error data (ROS 2 bag and CSV) for both worlds:

```bash
cd docker
./run.sh record one          # -> output/walls_one_sided.csv  + output/bag_walls_one_sided/
./run.sh record two          # -> output/walls_two_sided.csv  + output/bag_walls_two_sided/
./run.sh record one 90       # optional: record for 90 s instead of 60
```

This matches the handout's:
```bash
ros2 bag record /husky/cte
ros2 topic echo /husky/cte > cross_track_error.csv
```

Video: launch `./run.sh solution [one|two]` (or `./run.sh viz ...`) and
screen-record the Gazebo window with your host recorder (GNOME: `Ctrl+Alt+Shift+R`).
Rename the deliverables as the handout asks, for example
`FirstName_LastName_StudentNumber_walls_one_sided.mp4` and `.csv`. Keep each video
under 10 MB.

## 7. Troubleshooting

Gazebo stuck on "Preparing your world" or `gzclient` hangs.
The simulation backend usually runs even when the GUI hangs.
- Wait through the first load.
- Use `./run.sh viz` instead (headless Gazebo + RViz), which is enough for grading.
- Or reset Gazebo inside the container and relaunch (from the handout):
  ```bash
  killall -9 gzserver gzclient 2>/dev/null
  ros2 launch wall_following_assigment gazebo_wall_world.launch.py
  ```

"Husky robot doesn't appear" or `spawn_entity ... timed out`.
On a slow first load the spawn confirmation can exceed Gazebo's timeout and print
an error while the robot still spawns. Check:
```bash
ros2 service call /get_model_list gazebo_msgs/srv/GetModelList
```
If it really did not spawn, run `killall -9 gzserver gzclient` and relaunch.

Black window or "cannot connect to display".
On the host run `xhost +local:root` (the `run.sh` helper does this for you), and
make sure `echo $DISPLAY` is non-empty.

No `/scan` messages in your node. Subscribe with BEST_EFFORT QoS (see section 5).

## 8. Running without an NVIDIA GPU

The same image runs with no NVIDIA GPU. Gazebo, RViz, and rqt render with Mesa
software OpenGL. Use the provided `docker/docker-compose.cpu.yml`. Nothing on the
host needs changing.

Prefix any helper command with `HW1_GPU=0`:
```bash
cd docker
HW1_GPU=0 ./run.sh build
HW1_GPU=0 ./run.sh solution     # software-rendered Gazebo GUI
HW1_GPU=0 ./run.sh viz          # headless Gazebo + RViz (lighter on CPU)
HW1_GPU=0 ./run.sh record one
HW1_GPU=0 ./run.sh stop
```
You can `export HW1_GPU=0` once, then use `./run.sh ...` normally.

Or drive compose directly:
```bash
cd docker
docker compose -f docker-compose.cpu.yml build
docker compose -f docker-compose.cpu.yml up -d
docker compose -f docker-compose.cpu.yml exec hw1 \
  bash -lc 'ros2 launch wall_following_assigment bringup.launch.py'
```

Software rendering uses the CPU, so first loads take longer. If the full Gazebo
GUI is slow, use `HW1_GPU=0 ./run.sh viz`. The controller, `/husky/cte`,
recording, and rqt tuning work the same way.
