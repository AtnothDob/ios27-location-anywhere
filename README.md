# iOS Location Anywhere (GPSSimulator)

> 🚀 原生 macOS 桌面端 iOS / iPadOS 全局 GPS 轨迹与真实路网导航模拟器（完美兼容 iOS 17 / iOS 18 / iOS 27+）。  
> 直接基于 Apple 官方最新的 `CoreDevice` 与 `xcrun devicectl` 架构构建，无需越狱，零外部第三方依赖。

---

## ✨ 核心特性

- 🗺️ **MapKit 交互式可视化地图**：
  - 采用现代 macOS 双栏布局，集成高分辨率 Apple 原生地图（支持标准、卫星、混合图层）。
  - 地图任意位置**点击选点**、**双击瞬移**，全局地名/地址联想搜索（基于 `MKLocalSearch`）。
- 🛣️ **Apple Maps 真实道路导航模拟（A → B → C 多途经点）**：
  - 告别单一画圆；基于 Apple 原生路网规划（`MKDirections`），严格贴合现实道路与立交桥行驶。
  - 支持多途经点（Multi-Stop Waypoints）连续规划。
  - 原生支持 **避开高速公路**、**避开收费站** 偏好设置。
  - 详细的**逐向转弯指引（Turn-by-turn Steps）**与**原生车载语音播报**（如同 CarPlay 导航发声）。
- 🏃 **Apple 官方底层拟真运动学场景**：
  - 官方运动学模型：🚶 步行 / 慢跑 (`City Run`)、🚴 城市骑行 (`City Bicycle Ride`)、🍎 Apple Park 巡航 (`Apple`)、🚗 高速公路 (`Freeway Drive`)。
- 🕹️ **八方向虚拟摇杆 & Mac 键盘方向键**：
  - 8 个方向微调按键（可调步长 5m ~ 100m）。
  - 支持直接敲击 Mac 物理键盘 **↑ ↓ ← →** 进行即时平滑走位。
- 🛡️ **拟真 GPS 自然漂移（Anti-Detection Jitter）**：
  - 模拟卫星硬件物理多径效应与信号延迟（±0.5m ~ 4m 高斯微弱抖动），避免固定坐标被系统或应用识别。
- 🔌 **高可靠设备热插拔自动识别**：
  - 每 3 秒后台无阻塞快速扫描，直观展示 `🔌 USB` 有线直连与 `📶 Wi-Fi` 局域网配对状态及 iOS 版本。
- ⭐ **自定义地点收藏**：一键收藏常用经纬度，持久化存储。

---

## 🛠️ 运行与使用前提

### 1. 手机 / 平板端（iOS / iPadOS）
1. **开启「开发者模式」（核心项）**：
   - 打开手机 **「设置」** → **「隐私与安全性」** → 滑到最底部点击 **「开发者模式」**。
   - 开启开关后根据提示**重启手机**，开机解锁后在弹窗中点击**「开启」**并输入锁屏密码。
2. **信任此电脑**：
   - 数据线首次连接 Mac 时，解锁手机在弹窗中选择**「信任此电脑」**并输入密码。
3. **连接方式**：
   - 推荐使用具备数据传输能力的 USB 数据线（即插即用、延迟最低）；
   - 也支持在同一局域网下的 Wi-Fi 配对调试。
4. **无需越狱**：完全兼容未越狱的原装系统。

### 2. Mac 电脑端
- 系统版本：macOS 14.0 Sonoma 或更高版本（Apple Silicon & Intel 均支持）。
- 开发环境：安装有 **Xcode 15.0+** 或 Command Line Tools（确保终端可用 `xcrun devicectl`）。
- 网络正常：用于加载 Apple Maps 卫星/矢量地图瓦片及道路网规划。

---

## 🏗️ 编译与运行

### 方式 A：通过 Xcode 打开
直接双击打开项目中的工程文件：
```bash
open GPSSimulator.xcodeproj
```
在 Xcode 中选择 Target `GPSSimulator`，点击 `Cmd + R` 运行即可。

### 方式 B：终端命令行一键编译
```bash
# 进入项目目录
cd GPSSimulator

# 编译 macOS App
xcodebuild -project GPSSimulator.xcodeproj -scheme GPSSimulator -destination 'platform=macOS' build

# 运行产物
open ~/Library/Developer/Xcode/DerivedData/GPSSimulator-*/Build/Products/Debug/GPSSimulator.app
```

---

## 🔒 隐私与安全性声明

- **本地离线运行**：所有设备通信指令均通过本地 Unix 域套接字与 `devicectl` 桥接，不收集任何用户隐私或设备 UDID 数据。
- **开源合规**：代码中无任何硬编码个人设备信息或私有令牌。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。
