# iOS Location Anywhere (GPSSimulator)

> 🚀 原生 macOS 桌面端 iOS / iPadOS 全局 GPS 轨迹与真实路网导航模拟器（完美兼容 iOS 17 / iOS 18 / iOS 27+）。  
> 直接基于 Apple 官方最新的 `CoreDevice` 与 `xcrun devicectl` 架构构建，无需越狱，零外部第三方依赖。

---

## ⚡ 普通用户极简上手（3 步开箱即用，无需懂编程）

如果你不是开发者，不需要下载源码或安装庞大的 Xcode，只需按以下步骤操作：

### 第一步：下载并安装 App
1. 前往 👉 [**GitHub Releases 页面**](https://github.com/AtnothDob/ios27-location-anywhere/releases/latest) 下载最新构建包 `GPSSimulator-macOS-v1.0.0.zip`。
2. 双击解压得到 `GPSSimulator.app`，直接拖拽到 Mac 的 **「应用程序 (Applications)」** 文件夹中。
3. **首次打开安全提示解决**：
   - 苹果系统对未购买年费证书的开源软件会提示“无法验证开发者”；
   - **正确打开方式**：按住键盘 `Control` 键点击（或右键点击）该 App，选择 **「打开」**，在弹出的系统对话框中再次点击 **「打开」** 即可（只需一次，后续可正常双击启动）。
   - 或者在「终端」中执行：`xattr -cr /Applications/GPSSimulator.app`。

### 第二步：手机/平板端准备（仅需一次）
1. **开启「开发者模式」**：
   - 打开 iPhone / iPad 的 **「设置」** → **「隐私与安全性」** → 滑到最底部点击 **「开发者模式」**。
   - 打开开关，手机提示重启，**点击重启**。
   - 重启开机解锁后，屏幕会弹窗提示“要开启开发者模式吗？”，点击 **「开启」** 并输入锁屏密码。
2. **信任此电脑**：
   - 用 USB 数据线将手机连接到 Mac，解锁手机屏幕，点击弹出的 **「信任此电脑」** 并输入密码。

> 💡 **Mac 环境轻量说明**：  
> 本软件直接利用系统内置的 `devicectl` 通信。如果你的 Mac 极其干净未装过任何命令行工具，首次使用若系统提示需要 Command Line Tools，直接在弹窗中点击「安装」即可（几百兆，通常 1-2 分钟装好），**不需要**下载 15GB+ 的完整 Xcode。

### 第三步：即刻开始模拟
1. 双击运行 `GPSSimulator.app`，顶部设备列表会自动识别你的真机（如 `🔌 USB 🟢 iPhone`）。
2. 在地图上任意点击一个位置，或者在搜索框输入地址（如“洛杉矶尔湾”），亦可在下拉列表选择“官方热门地标”。
3. 点击 **「📍 瞬移到此位置」**，或切换到 **「🛣️ 道路导航」** 规划多途经点路线，点击开始模拟，手机全局 GPS 立即同步生效！

---

## ✨ 核心特性


- 🗺️ **MapKit 交互式可视化地图**：
  - 采用现代 macOS 双栏布局，集成高分辨率 Apple 原生地图（支持标准、卫星、混合图层）。
  - 地图任意位置**点击选点**、**双击瞬移**，全局地名/地址联想搜索（基于 `MKLocalSearch`）。
  - **地图缩放控制（Zoom In / Out）**：右下角悬浮毛玻璃控制卡片（`+` 放大、`-` 缩小、一键复位居中）、顶部工具栏快捷缩放及 `⌘ +` / `⌘ -` 键盘快捷键。
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
- ⭐ **全球热门地标与自定义收藏**：
  - 内置经典热门地标：🇺🇸 苹果总部 Apple Park、🇺🇸 洛杉矶尔湾 (Irvine)、🇺🇸 尔湾光谱中心 (Irvine Spectrum)、🇺🇸 纽约中央公园、🇺🇸 旧金山金门大桥、🇭🇰 香港中环维港、🇯🇵 东京涩谷、🇬🇧 伦敦大本钟、🇫🇷 巴黎埃菲尔铁塔、🇨🇳 深圳湾人才公园等。
  - 支持将任意经纬度一键收藏并持久化存储。

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
