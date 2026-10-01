# GPSSimulator / iOS Location Anywhere

## 项目概览
本项目是一个原生 macOS 桌面端应用（Swift + SwiftUI + MapKit + CoreDevice），专门为 iOS / iPadOS（完美兼容 iOS 17 / 18 / 27+）提供全局 GPS 模拟、真实道路导航（Apple Maps）、逐向转弯指引（TTS 中文语音）、以及经纬度坐标注入。

## 项目结构
- `GPSSimulator.xcodeproj`: Xcode 工程文件
- `GPSSimulator/`: Swift 源码目录
  - `GPSSimulatorApp.swift`: App 入口与生命周期管理
  - `ContentView.swift`: 主控制面板与 UI 布局（双栏模式、摇杆控制、参数设置、经纬度输入）
  - `MapViewModel.swift`: 地图状态管理、MapKit 交互、航线规划与多源全球搜索（OpenStreetMap / Nominatim + Photon）
  - `GPSController.swift`: `xcrun devicectl` 通信逻辑、坐标注入、自然漂移（Anti-detection Jitter）
  - `DeviceScanner.swift`: 官方 JSON 结构化设备扫描器
  - `GPSSimulator.entitlements`: 权限配置文件（禁用沙盒以执行底层系统 devicectl 命令行）
  - `Assets.xcassets`: 图标与资产
- `GPSSimulator.app`: 编译产物（原生 macOS 应用）
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
