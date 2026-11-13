# Riset 01 — PX4 SITL di Gazebo (Harmonic)

Tanggal: 2026-11-13
Tujuan: menjalankan quadrotor PX4 di Gazebo sebagai fondasi pipeline Visual Odometry (VO/VIO).

## 1. Kondisi mesin saat ini

| Item | Status |
|---|---|
| OS | Ubuntu 22.04.5 (jammy) |
| ROS 2 | Humble (`/opt/ros/humble`) |
| GPU | RTX 3090, driver 550 (render kamera di Gazebo aman) |
| CPU / RAM | 24 core / 30 GB |
| Disk | **sisa ~58 GB (92% terpakai)**, PX4 + toolchain + build butuh ~10–15 GB, dataset rosbag kamera bisa cepat membesar |
| Gazebo Classic 11 | **terpasang** (paket Ubuntu `gazebo 11.10.2+dfsg-1`, memiliki `/usr/bin/gz`) |
| Gazebo Harmonic | **sebagian**: library `libgz-*8` ada, tetapi `gz-sim8` dan `gz-tools2` **tidak** ada |
| Repo OSRF `gazebo-stable` | sudah ada di apt sources |
| PX4 / Micro XRCE-DDS Agent / QGC | belum ada |
| Docker + nvidia-container-toolkit | ada (opsi alternatif) |

### Konflik utama
Di 22.04, Gazebo Classic (paket `gazebo`) dan Gazebo Harmonic (`gz-tools2`) sama-sama memasang `/usr/bin/gz`,
sehingga **tidak bisa dipasang bersamaan**. Itulah sebabnya Harmonic saat ini tidak lengkap.
Satu-satunya pengguna Classic yang terdeteksi: `~/turtlebot3_ws` (`turtlebot3_gazebo`), dan
`ros-humble-gazebo-ros` sendiri tidak terpasang, jadi kemungkinan Classic tidak sedang dipakai.

## 2. Pilihan stack (rekomendasi)

| Komponen | Pilihan | Alasan |
|---|---|---|
| Simulator | **Gazebo Harmonic** (`gz sim` 8) | Satu-satunya Gazebo yang didukung PX4 di Ubuntu 22.04+. Gazebo Classic sudah deprecated di PX4. |
| PX4 | **v1.17.0** (stable terbaru, Mei 2026), di-*pin* ke tag | Riset butuh versi yang reproducible, jangan pakai `main`. |
| Middleware ROS 2 | **uXRCE-DDS** (Micro XRCE-DDS Agent) + `px4_msgs` branch yang sesuai versi PX4 | Jalur resmi PX4 ↔ ROS 2 (menggantikan MAVROS untuk ROS 2). |
| Bridge sensor | `ros-humble-ros-gzharmonic` (`ros_gz_bridge`) | Humble default-nya Fortress, jadi harus pakai varian *gzharmonic*. Versi yang tidak cocok adalah penyebab umum bridge gagal. |
| GCS | QGroundControl AppImage | Arm/takeoff manual, ubah parameter. |

## 3. Langkah instalasi (native)

```bash
# 0) Lepas Gazebo Classic (konflik /usr/bin/gz). Perlu keputusan user dulu.
sudo apt remove gazebo gazebo-common gazebo-plugin-base libgazebo-dev libgazebo11

# 1) Clone PX4, pin ke rilis stable
cd ~/Drone-Project            # atau lokasi lain; PX4 sebaiknya jadi submodule/dep, bukan dimodifikasi langsung
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
cd PX4-Autopilot
git checkout v1.17.0 && git submodule update --init --recursive

# 2) Toolchain + Gazebo Harmonic (script resmi; --no-nuttx kalau belum butuh build hardware)
bash ./Tools/setup/ubuntu.sh --no-nuttx
# reboot / logout-login setelah selesai

# 3) Uji pertama: quadrotor x500 + GUI Gazebo
make px4_sitl gz_x500
# di konsole pxh>:
#   commander takeoff
#   commander land
```

Validasi sukses M1: Gazebo terbuka, x500 muncul, `commander takeoff` membuat drone hover ~2.5 m, lalu mendarat.

### Variasi run yang berguna
```bash
HEADLESS=1 make px4_sitl gz_x500                 # tanpa GUI (untuk batch eksperimen)
PX4_GZ_WORLD=baylands make px4_sitl gz_x500       # pilih world (default, baylands, lawn, walls, windy, aruco, ...)
make px4_sitl gz_x500_mono_cam                    # x500 + kamera mono depan
make px4_sitl gz_x500_depth                       # x500 + depth camera (OAK-D Lite)
make px4_sitl gz_x500_vision                      # x500 untuk uji input external vision
PX4_SIM_SPEED_FACTOR=2 make px4_sitl gz_x500      # simulasi lebih cepat dari real-time

# Mode standalone: jalankan gz sim sendiri lalu PX4 attach (lebih cepat saat iterasi)
PX4_GZ_STANDALONE=1 make px4_sitl gz_x500
```
Cek daftar target yang benar-benar tersedia di versi yang di-checkout:
`ls ROMFS/px4fmu_common/init.d-posix/airframes | grep gz_`

Catatan troubleshooting dari docs:
- Jangan tambahkan `_default` ke nama model.
- `ninja: error: unknown target 'gz_x500'` → `make distclean` lalu ulangi.

### Troubleshooting yang sudah dialami (M1, 2026-11-13)

**Drone tidak terlihat di Gazebo, padahal log PX4 normal** (`gz_bridge ... model: x500_0`, `home set`).
- Penyebab: kamera GUI tergeser sekitar 255 m dari drone (dugaan: scroll/drag sebelum mesh drone selesai dimuat).
  Model sebenarnya ada: `GZ_IP=127.0.0.1 gz model --list`.
- Solusi: Entity Tree → klik kanan `x500_0` → *Move to*, atau
  `GZ_IP=127.0.0.1 gz service -s /gui/move_to --reqtype gz.msgs.StringMsg --reptype gz.msgs.Boolean --timeout 3000 --req 'data: "x500_0"'`

**`commander takeoff` tidak menggerakkan drone, muncul `Arming denied: Resolve system health failures first`.**
- Penyebab: `NAV_DLL_ACT=2` (default PX4 v1.17) mewajibkan GCS terhubung sebelum arming
  (`Preflight Fail: No connection to the GCS`). Koneksi ROS 2/uXRCE-DDS **tidak** dihitung sebagai GCS.
- Solusi: jalankan QGroundControl, atau khusus simulasi `param set NAV_DLL_ACT 0` (tersimpan di instance SITL).
- Cara diagnosis dari terminal lain (memakai client PX4 di `build/px4_sitl_default/bin/`):
  `./px4-listener vehicle_status` (lihat `arming_state`, `gcs_connection_lost`), `./px4-listener health_report`,
  serta `ulog_messages <file.ulg>` untuk membaca pesan lengkap di log.

## 4. ROS 2 (untuk milestone berikutnya)

```bash
# Micro XRCE-DDS Agent
mkdir -p ~/Drone-Project/ros2_ws/src && cd ~/Drone-Project/ros2_ws/src
git clone -b v2.4.3 https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
git clone -b release/1.17 https://github.com/PX4/px4_msgs.git   # HARUS sesuai versi PX4 (cek nama branch)
git clone https://github.com/PX4/px4_ros_com.git
cd .. && source /opt/ros/humble/setup.bash && colcon build

# Jalankan
MicroXRCEAgent udp4 -p 8888        # PX4 SITL otomatis connect ke UDP 8888
ros2 topic list | grep fmu         # /fmu/out/vehicle_odometry, /fmu/in/vehicle_visual_odometry, ...

# Bridge kamera Gazebo -> ROS 2 (nama topic cek dulu dengan `gz topic -l`)
sudo apt install ros-humble-ros-gzharmonic
ros2 run ros_gz_bridge parameter_bridge \
  /clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock \
  <gz_camera_topic>@sensor_msgs/msg/Image[gz.msgs.Image
```

## 5. Hubungan ke Visual Odometry (gambaran)

```
Gazebo Harmonic ──(gz transport)──► ros_gz_bridge ──► /camera/image, /imu, /clock
      │                                                     │
      │ (sensor sim)                                        ▼
      ▼                                              VO/VIO node (mis. OpenVINS / VINS-Fusion / ORB-SLAM3)
PX4 SITL (EKF2) ◄── uXRCE-DDS ◄── /fmu/in/vehicle_visual_odometry (px4_msgs/VehicleOdometry, NED/FRD)
      │
      └──► /fmu/out/vehicle_odometry (+ ground truth dari Gazebo) ──► evaluasi ATE/RPE (evo)
```

Hal teknis yang perlu diperhatikan nanti:
- **Frame**: PX4 memakai NED/FRD, ROS memakai ENU/FLU, sehingga konversi harus eksplisit di node bridge VO→PX4.
- **EKF2**: `EKF2_EV_CTRL` (pilih fusi posisi/kecepatan/yaw dari vision), `EKF2_HGT_REF` (Vision),
  `EKF2_EV_DELAY`, `EKF2_EV_POS_X/Y/Z`; untuk skenario GPS-denied: `EKF2_GPS_CTRL=0`.
- **Rate**: input vision ≥ 30 Hz agar di-fuse EKF2.
- **Waktu**: semua node pakai `use_sim_time` + bridge `/clock`.
- **Ground truth**: ambil pose model dari Gazebo (bukan dari EKF PX4) untuk evaluasi VO yang jujur.

## 6. Alternatif: Docker
Jika Gazebo Classic harus tetap ada (mis. untuk turtlebot3), jalankan PX4 + Harmonic di container
(base `ubuntu:22.04` + `ubuntu.sh`, `--gpus all`, mount X11). Kekurangannya: setup GUI/GPU/DDS networking
lebih ribet dan iterasi lebih lambat. Untuk proyek ini disarankan native.

## Sumber
- PX4 Gazebo Simulation: https://docs.px4.io/main/en/sim_gazebo_gz/
- PX4 Ubuntu dev env: https://docs.px4.io/main/en/dev_setup/dev_env_linux_ubuntu.html
- PX4 ROS 2 User Guide: https://docs.px4.io/main/en/ros2/user_guide.html
- PX4 External Position Estimation (VIO): https://docs.px4.io/main/en/ros/external_position_estimation.html
- PX4 Releases: https://github.com/PX4/PX4-Autopilot/releases
- Forum (versi ros_gz harus cocok): https://discuss.px4.io/t/how-to-get-depth-data-from-the-px4-gazebo-simulation-and-visualize-it-in-rviz2/37916
