# iOS Location Anywhere (GPSSimulator)

<p align="center">
  <strong>[ 简体中文 ]</strong> &nbsp;|&nbsp; <strong><a href="README_en.md">English</a></strong>
</p>

> 🚀 **原生 macOS 桌面端 iOS / iPadOS 全局 GPS 轨迹与真实路网导航模拟器（完美兼容 iOS 17 / iOS 18 / iOS 27+）。**  
> 直接基于 Apple 官方最新的底层 `CoreDevice` 与 `xcrun devicectl` 架构构建，**无需越狱、无需任何第三方外部依赖、无私有越权 API**。

---

## ⚡ 普通用户极简上手（3 步开箱即用，无需懂编程）

如果你不是开发者，不需要下载源码或安装庞大的 Xcode，只需按以下步骤操作：

### 第一步：下载并安装 App
1. 前往 👉 [**GitHub Releases 页面**](https://github.com/AtnothDob/ios27-location-anywhere/releases/latest) 下载最新构建包 `GPSSimulator-macOS-v1.0.0.zip`。
2. 双击解压得到 `GPSSimulator.app`，直接拖拽到 Mac 的 **「应用程序 (Applications)」** 文件夹中。
3. **首次打开安全提示解决**：
   - 苹果系统对未购买年费企业签名的开源软件会提示“无法验证开发者”；
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
> 本软件直接利用系统内置的 `devicectl` 通信。如果你的 Mac 未装过任何命令行工具，首次使用若系统提示需要 Command Line Tools，直接在弹窗中点击「安装」即可（几百兆，通常 1-2 分钟装好），**不需要**下载 15GB+ 的完整 Xcode。

### 第三步：即刻开始模拟
1. 双击运行 `GPSSimulator.app`，顶部设备列表会自动识别你的真机（如 `🔌 USB 🟢 iPhone 17 Pro Max`）。
2. 在地图上任意点击一个位置，或者在搜索框输入全球地址/地名，亦可在下拉列表选择“官方热门地标”。
3. 点击 **「📍 瞬移到此位置」**，或切换到 **「🛣️ 道路导航」** 规划多途经点路线，点击开始模拟，手机全局 GPS 立即同步生效！

---

## ✨ 核心特性

### 🌐 1. 全球境外 0 漂移与中国区自动防偏转（彻底根治 500m 偏移）
- **五层高精度地理边界引擎（Ray-Casting PIP）**：
  - 内置精细化中国大陆多边形边界，精准识别全国 31 个省市口岸与陆地边界。
  - **专属剔除港澳台与海外区域**：香港特别行政区、澳门、中国台湾省、日本全境（含关西/九州/冲绳）、韩国全境、东南亚及欧美等所有境外区域，**100% 原始标准 WGS-84 纯净直通（位移量严格为 0.000000 米）**。
- **中国境内自动逆解防漂移**：
  - 在中国大陆境内自动将 GCJ-02 火星坐标精准逆解为 WGS-84 后注入真机，抵消 iOS 内部加偏，手机端高德/微信/系统地图完全 0 漂移！

### 🛣️ 2. 全球双节点 HTTPS OSRM 真实路网导航
- **突破 macOS ATS 限制**：
  - 彻底解决 macOS App Transport Security (`-1022`) 明文拦截，配置主备双节点全球高可用 HTTPS 路由服务。
- **境内外智能路由分流**：
  - 中国大陆：优先接入 Apple Maps 高德底层数据；
  - 境外区域：秒级直达全球 OSRM 引擎，支持自选终点、A → B → C 多途经点及八方位智能顺路巡航。
- **拟真转弯语音与 HUD 指引**：
  - 自动翻译 OSRM 转弯动作为自然流畅的中文指引（如“向右转，进入 De Anza Blvd”），提供高保真车载导航体验。

### 🚦 3. 路口红绿灯智能等待与平稳起步仿真
- **拟真交通灯等待**：
  - 途经道路交叉口时，依据概率模型（默认 40%）智能模拟红灯停车等待（随机 12 ~ 35 秒）。
  - 支持绿灯直接平稳匀速通过路口机制，真实模拟都市驾车/骑行体验。

### 🏎️ 4. 实时巡航速度自然漂移（Anti-Detection Jitter）
- **动态巡航时速浮动**：
  - 行进过程中速度以设定时速为基准，产生 ±12% 的平滑自然浮动，避免匀速机械行驶特征。
- **静态微物理漂移**：
  - 停车或静态驻留时模拟卫星信号微弱抖动（±0.5m ~ 4m），避免固定坐标被风控算法识别。

### ☕ 5. 全天智能自主漫游引擎（RoamingEngine）
- **自动化生活轨迹探索**：
  - 依据生活作息在周边自动检索餐饮、咖啡厅、公园、商场、健身房等真实生活 POI。
  - 规划全天多站点无缝环形回路，自动驻留与启程，适合长时间挂机与社交动态打卡。

### 🗺️ 6. 多源全球搜索与可视化交互地图
- **三擎融合搜索**：集成 OpenStreetMap (Nominatim) + Komoot (Photon) + Apple Maps 本地搜索，全球地名、景点、道路、经纬度秒级联想。
- **现代化双栏布局**：
  - 支持标准地图、卫星实景、混合地图多样式切换。
  - 右下角悬浮毛玻璃缩放控制卡片（`+` 放大、`-` 缩小、一键复位居中）及 `⌘ +` / `⌘ -` 键盘快捷键。
- **八方向虚拟摇杆**：
  - 支持鼠标微调（步长 5m ~ 100m）及物理键盘方向键 **↑ ↓ ← →** 即时平滑走位。

---

## 🛠️ 运行与使用前提

### 1. 手机 / 平板端（iOS / iPadOS）
- **系统支持**：iOS 17.0 ~ iOS 18.x 及更高版本（完美向前兼容 iOS 27+）。
- **开启「开发者模式」**：在「设置」→「隐私与安全性」最下方开启，按提示重启即可。
- **信任电脑**：首次连接用数据线插入 Mac，在手机屏幕点击「信任此电脑」。
- **无需越狱**：完全支持官方正版未越狱设备。

### 2. Mac 电脑端
- **操作系统**：macOS 14.0 Sonoma 或更高版本（原生支持 Apple Silicon M 系列与 Intel 芯片）。
- **环境依赖**：具备 Command Line Tools 或 Xcode 15.0+（终端能执行 `xcrun devicectl` 即可）。

---

## 🏗️ 开发者编译构建

```bash
# 1. 克隆代码仓库
git clone https://github.com/AtnothDob/ios27-location-anywhere.git
cd ios27-location-anywhere

# 2. 命令行一键构建
xcodebuild -project GPSSimulator.xcodeproj -scheme GPSSimulator -destination 'platform=macOS' build

# 3. 运行构建产物
open ~/Library/Developer/Xcode/DerivedData/GPSSimulator-*/Build/Products/Debug/GPSSimulator.app
```

---

## 🔒 隐私与安全性声明

- **设备通信本地完成**：坐标通过 Mac 本机的 `xcrun devicectl` 直接下发到 USB / 局域网连接的设备，不经过任何中转服务器，也不收集、上传设备 UDID。
- **会访问的第三方服务**：以下功能需要联网，相关数据会发送给对应的公共服务：
  - 地点搜索：搜索词发送给 Apple Maps、OpenStreetMap Nominatim、Komoot Photon；
  - 路线规划：起点 / 终点坐标发送给 Apple Maps 及公共 OSRM 服务器（`router.project-osrm.org`、`routing.openstreetmap.de`）；
  - 智能漫游：周边 POI 检索通过 Apple Maps 完成。
  
  这些公共服务均有调用频率限制，请勿高频滥用。
- **开源合规**：代码纯净透明，无任何硬编码个人凭据或私有越权行为。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源。欢迎 Star、Fork 与提 Issue！
