# GPSSimulator / iOS Location Anywhere

## 项目概览
本项目是一个原生 macOS 桌面端应用（Swift + SwiftUI + MapKit + CoreDevice），专门为 iOS / iPadOS（完美兼容 iOS 17 / 18 / 27+）提供全局 GPS 模拟、真实道路导航（Apple Maps）、逐向转弯指引（TTS 中文语音）、以及经纬度坐标注入。

## 项目结构
- `GPSSimulator.xcodeproj`: Xcode 工程文件
- `GPSSimulator/`: Swift 源码目录
  - `GPSSimulatorApp.swift`: App 入口与生命周期管理
  - `ContentView.swift`: 主控制面板与 UI 布局（双栏模式、摇杆控制、参数设置、经纬度输入）
  - `MapViewModel.swift`: 地图状态管理、MapKit 交互、航线规划与多源全球搜索（OpenStreetMap / Nominatim + Photon）
  - `GPSController.swift`: 坐标注入、导航 / 场景循环、自然漂移（Anti-detection Jitter）
  - `RoamingEngine.swift`: 全天智能漫游（周边 POI 检索 + 多站点行程）
  - `ChinaCoordinateCorrector.swift`: 中国大陆边界判定与 WGS-84 / GCJ-02 / BD-09 坐标互转
  - `DeviceScanner.swift`: 官方 JSON 结构化设备扫描器，以及 `devicectl()` / `injectLocation()` 命令封装（所有 devicectl 调用都应走这里）
  - `GPSSimulator.entitlements`: 权限配置文件（禁用沙盒以执行底层系统 devicectl 命令行）
  - `Assets.xcassets`: 图标与资产
- `GPSSimulator.app`: 本地编译产物（已被 `.gitignore` 忽略，不入库；发布包见 GitHub Releases）
- `打开GPS轨迹模拟器.command`: 快速启动脚本
- `GPS_Simulator.py`: 早期 Python 原型参考脚本

## 常用命令
- **编译项目**:
  ```bash
  xcodebuild -project GPSSimulator.xcodeproj -scheme GPSSimulator -destination 'platform=macOS' build
  ```
- **复制构建产物**:
  ```bash
  rsync -av ~/Library/Developer/Xcode/DerivedData/GPSSimulator-*/Build/Products/Debug/GPSSimulator.app/ "./GPSSimulator.app/"
  ```
- **运行 App**:
  ```bash
  open ./GPSSimulator.app
  ```
- **代码仓库**:
  [https://github.com/AtnothDob/ios27-location-anywhere](https://github.com/AtnothDob/ios27-location-anywhere)
