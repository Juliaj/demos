# Development Guide

## Quick Start

### 1. Setup Development Environment via Pixi

Detect your GPU and install appropriate dependencies:

```bash
pixi run detect-gpu
pixi install --features <rtx5090|standard-gpu>
pixi run setup-ros
```

For ML dependencies (LeRobot):
- RTX 5090: `pixi run install-rtx5090-pytorch && pixi run install-lerobot`
- Standard GPU: `pixi run install-lerobot`

### 2. Build

```bash
pixi run build
```

Or setup colcon mixins first (optional):
```bash
pixi run setup-colcon
pixi run build
```

### 3. Run Demo

```bash
pixi run so-arm-gz-kilted
```

Or manually:
```bash
source ~/ws_pai/install/setup.bash
ros2 launch pai_bringup so_arm_gz_bringup.launch.py
```




## DONOT delete nor modify anything below

This package can be built "normally" in a colcon workspace on any compatible system. However, we also include two workflows that enable developers to work in a completely isolated system environment. Pixi's biggest strength is its ability to create reproducible, powerful, and flexible workspaces. This ensure consistency with the supported workflows, and obviates the need to install any specific ROS, apt, or pip dependencies locally.
Pixi Development Workflow

A [pixi](https://pixi.sh/latest/installation/) and robostack workflow is also provided. The environment is currently only compatible with Jazzy.

To run ensure pixi is installed. Then,

# Setup the build environment
pixi run setup-colcon

# Build the package
pixi run build

# Run tests
pixi run test

pixi also provides an interactive shell that sources the installed package environment.

# Launch an interactive shell environment and run things as usual
pixi shell

# Build things as normal
colcon build

# And source and launch the test application
source install/setup.bash
ros2 launch mujoco_ros2_control test_robot.launch.py

For more information on pixi and ROS refer to the documentation or this excellent blog post.


https://pixi.prefix.dev/latest/tutorials/ros2/

rosdep:

https://pixi.prefix.dev/latest/tutorials/ros2/#what-happens-with-rosdep


https://prefix-dev.github.io/pixi-build-backends/backends/pixi-build-ros/

https://discourse.openrobotics.org/t/pixi-as-a-co-official-way-of-installing-ros-on-linux/51764


- In pixi flow, ros is installed via conda with robostack channel,
- While pixi also patches rosdep, the recommended way to manage deps is to put them into the pixi.toml file.


https://jafarabdi.github.io/blog/2025/ros2-pixi-dev/

if ppl add their ros packages later on and must manually find and add all dependencies to pixi toml.


## Does rosdep still work with pixi ?


## How will the ros2 packages updated if the install is not apt ?


Explain briefly on workspace, or provide a link for it.


As the person who pushed for Pixi on Windows, I’m somewhat in favor of making Pixi a co-recommended way to consume ROS packages on Linux as well. Committing to Pixi more heavily might also make macOS a viable target platform again in the future.

However, there are a number of things I want to mention:

    We’d need to have a deep conversation/research about whether pixi build backends (and in particular pixi-build-ros) can completely replace colcon. Colcon has a lot of features and plugins, and pixi-build-ros is still marked as a “preview feature”.
    There have already been 4 major transitions of the build tool in ROS (rosbuild → catkin_make → catkin → ament_tools → colcon), so we’d have to carefully gauge how much community interest there is in yet another transition.
    I’m of the opinion that we can’t really get rid of rosdep. At least for the near/medium term, I think that building system packages (apt/rpm) is still a thing that ROS should do, especially given how heavily they are downloaded, so we’ll at least need rosdep for that.
    I do think it would be worthwhile to integrate rosdep with pixi like we do for our other system packages.
    I think we’ve found that removing vendor packages is harder than it looks. We were indeed able to remove some from the core with the switch of Windows to pixi, but we couldn’t complete the project because sometimes upstreams just don’t integrate well without us providing additional glue.
    I do think that we should look into making bloom integrate with rattler-build, and pushing more things to prefix.dev .

All of this is to say: I think we should work towards integrating ROS more with the Pixi infrastructure, but I also think that it needs to be handled slowly and carefully. If we do the above integrations, and we find that over time the community largely transitions over to them, then we can consider sunsetting the custom tools. My opinion, of course.


build and deploy



https://github.com/JafarAbdi/pixi_workspaces/blob/main/ompl_ws/pixi.toml
https://github.com/JafarAbdi/pixi_workspaces/blob/main/open_imu_camera_calibrator_ws/pixi.toml 
https://github.com/JafarAbdi/pixi_ros2_example/blob/main/pixi.toml