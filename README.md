# Drone-Project: PX4 + Gazebo + Visual Odometry

A simulation testbed for **vision-based state estimation on multirotor UAVs**.
A PX4-controlled quadrotor flies in Gazebo Harmonic, its onboard camera and IMU are
streamed to ROS 2, a visual(-inertial) odometry pipeline estimates the vehicle's
motion, and the estimate is evaluated against simulator ground truth and finally
fed back into PX4's EKF2 for GPS-denied flight.

**Design principle:** PX4 is used unmodified, pinned as a git submodule. Everything
project-specific (parameters, launch scripts, ROS 2 nodes, evaluation) lives in this
repository.

## Status

| Milestone | Goal | Status |
|---|---|---|
| M1 | PX4 SITL + Gazebo: take off and land a quadrotor | ✅ done |
| M2 | ROS 2 link via uXRCE-DDS + an offboard node that flies a repeatable trajectory | ⏳ next |
| M3 | Stream camera + IMU + ground truth to ROS 2, record datasets | planned |
| M4 | Run VO/VIO offline, evaluate against ground truth (ATE/RPE with `evo`) | planned |
| M5 | Close the loop: VIO into PX4 EKF2, GPS-denied flight | planned |
| M6 | Experiments and write-up (method comparison, worlds, wind, lighting) | planned |

## Stack

| Component | Version |
|---|---|
| OS | Ubuntu 22.04 |
| Autopilot | [PX4-Autopilot](https://github.com/PX4/PX4-Autopilot) v1.17.0 (submodule) |
| Simulator | Gazebo Harmonic (gz-sim 8) |
| Middleware | ROS 2 Humble, Micro XRCE-DDS (from M2) |

## Quick start

```bash
git clone --recursive <this-repo-url> Drone-Project
cd Drone-Project
./scripts/setup.sh        # one-time: PX4 deps + Gazebo Harmonic + SITL build (needs sudo)
./scripts/sim_up.sh       # launch PX4 SITL + Gazebo with the x500 quadrotor
```

In the PX4 console (`pxh>`):

```
commander takeoff
commander land
```

More launch options:

```bash
./scripts/sim_up.sh -m x500_mono_cam        # x500 with a forward-facing mono camera
./scripts/sim_up.sh -m x500_depth -w walls  # depth camera, different world
./scripts/sim_up.sh --headless              # no GUI (batch experiments)
./scripts/sim_down.sh                       # stop leftover PX4 / Gazebo processes
```

> **Ubuntu 22.04 note:** Gazebo Classic and Gazebo Harmonic cannot be installed side by
> side (both provide `/usr/bin/gz`). Remove Gazebo Classic before running `setup.sh`.

## Repository layout

```
.
├── PX4-Autopilot/        # PX4 firmware, unmodified (git submodule, pinned to v1.17.0)
├── config/
│   └── px4_params.env    # PX4 parameter overrides applied at every SITL boot
├── scripts/
│   ├── setup.sh          # one-time install + build
│   ├── sim_up.sh         # launch simulation (model / world / headless options)
│   ├── sim_down.sh       # stop simulation processes
│   └── gz_focus.sh       # point the Gazebo GUI camera at the drone
└── docs/
    └── research/         # setup research notes and troubleshooting
```

### How PX4 is customized without modifying it

PX4's SITL startup script applies any environment variable named `PX4_PARAM_<NAME>`
as a parameter. `scripts/sim_up.sh` reads `config/px4_params.env` and exports each
entry that way, so parameter changes are versioned here and reviewed like code.

## Documentation

- [docs/research/01-px4-gazebo-sitl.md](docs/research/01-px4-gazebo-sitl.md): stack
  choice, setup steps, and troubleshooting (camera lost in Gazebo, arming denied without a GCS).

## Acknowledgements

Built on [PX4](https://px4.io), [Gazebo](https://gazebosim.org), and [ROS 2](https://docs.ros.org).
