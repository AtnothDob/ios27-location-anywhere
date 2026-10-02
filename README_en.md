# iOS Location Anywhere (GPSSimulator)

<p align="center">
  <strong><a href="README.md">简体中文</a></strong> &nbsp;|&nbsp; <strong>[ English ]</strong>
</p>

> 🚀 **Native macOS desktop GPS trajectory and realistic road network simulation suite for iOS / iPadOS (fully compatible with iOS 17 / iOS 18 / iOS 27+).**  
> Built directly on Apple's latest official `CoreDevice` and `xcrun devicectl` infrastructure. **No jailbreak required, zero external dependencies, no private APIs.**

---

## ⚡ Quick Start for Regular Users (3 Steps, No Coding Required)

If you are not a developer and don't want to install Xcode or deal with source code, simply follow these steps:

### Step 1: Download & Install App
1. Go to the 👉 [**GitHub Releases Page**](https://github.com/AtnothDob/ios27-location-anywhere/releases/latest) and download the latest `GPSSimulator-macOS-v1.0.0.zip`.
2. Unzip and drag `GPSSimulator.app` into your Mac's **Applications** folder.
3. **First-Launch Gatekeeper Notice**:
   - macOS may display an "Unverified Developer" prompt for open-source apps without a paid enterprise certificate.
   - **How to open**: Hold the `Control` key, click (or right-click) `GPSSimulator.app`, choose **Open**, and click **Open** in the system dialog (only needed on the first run).
   - Alternatively, run this in Terminal: `xattr -cr /Applications/GPSSimulator.app`.

### Step 2: Prepare Your iPhone / iPad (One-Time Setup)
1. **Enable Developer Mode**:
   - Go to iPhone / iPad **Settings** → **Privacy & Security** → scroll to the bottom and tap **Developer Mode**.
   - Toggle the switch on, tap **Restart** when prompted.
   - After restarting and unlocking, a dialog will appear: tap **Turn On** and enter your passcode.
2. **Trust This Computer**:
   - Connect your iPhone to your Mac via a USB cable, unlock the screen, tap **Trust This Computer** when prompted, and enter your passcode.

> 💡 **Lightweight Mac Requirement Note**:  
> GPSSimulator communicates directly with the built-in system `devicectl`. If your Mac has never had developer tools installed, the system will prompt to install "Command Line Tools" on first launch. Simply click **Install** (a few hundred megabytes, takes 1-2 minutes). **You do NOT need the full 15GB+ Xcode.**

### Step 3: Start Simulating
1. Launch `GPSSimulator.app`. Your device will be automatically detected in the top device picker (e.g., `🔌 USB 🟢 iPhone 17 Pro Max`).
2. Click anywhere on the map, search for any global address/landmark in the search bar, or choose from popular preset locations.
3. Click **"📍 Teleport Here"**, or switch to **"🛣️ Road Navigation"** to calculate a multi-stop road route. Your physical device's global GPS location will update instantly!

---

## ✨ Core Features

### 🌐 1. Zero-Drift Overseas WGS-84 Pass-Through & China Anti-Drift Engine
- **5-Tier High-Precision Boundary Engine (Ray-Casting PIP)**:
  - Built-in boundary polygon covering all 31 mainland provinces and border ports.
  - **Explicit Exclusion of SARs & Overseas Regions**: Hong Kong SAR, Macau SAR, Taiwan, Japan (including Kansai, Kyushu, Okinawa), South Korea, Southeast Asia, Europe, and the Americas are **100% pure standard WGS-84 direct pass-through (measured drift = exactly 0.000000m)**. Completely eliminates the notorious 500~650m coordinate shift!
- **Automatic Mainland China GCJ-02 Decryption**:
  - Automatically reverses GCJ-02 (Mars coordinates) back to standard WGS-84 before hardware injection in Mainland China, canceling iOS's built-in offset and guaranteeing road-aligned accuracy.

### 🛣️ 2. Global Dual-Node HTTPS OSRM Road Navigation
- **macOS ATS Compliance**:
  - Resolves App Transport Security (`-1022`) plaintext blocking by routing through secure, dual-node HTTPS endpoints with automatic failover.
- **Intelligent Routing Dispatch**:
  - **Mainland China**: Prioritizes Apple Maps / AutoNavi road network data.
  - **Overseas**: Instantly routes via global high-speed OSRM HTTPS, supporting custom destinations, multi-stop waypoints (A → B → C), and 8-compass-direction autonomous route exploration.
- **Turn-by-Turn Guidance & Natural Voice**:
  - Converts raw OSRM maneuvers into natural navigation instructions with CarPlay-grade HUD cards.

### 🚦 3. Traffic Light Intersection Waiting & Smooth Acceleration
- **Realistic Urban Intersection Simulation**:
  - When crossing intersections, a probabilistic model (default 40%) triggers a realistic stop for red lights with randomized wait intervals (12–35 seconds).
  - Includes smooth deceleration, realistic red-light waiting, and progressive acceleration upon green light.

### 🏎️ 4. Dynamic Real-Time Speed Fluctuation & Anti-Detection Jitter
- **Dynamic Speed Drift**:
  - Fluctuates simulated vehicle/biking speed by ±12% around your target speed to avoid artificial mechanical constant-speed footprints.
- **Micro-Physical GPS Jitter**:
  - Simulates natural multi-path satellite signal dispersion (±0.5m ~ 4m) during stationary stops to bypass anti-spoofing detection algorithms.

### ☕ 5. All-Day Autonomous Roaming Engine (`RoamingEngine`)
- **Automated Lifestyle Trajectory Simulation**:
  - Automatically discovers realistic nearby points of interest (cafes, restaurants, parks, shopping malls, fitness centers).
  - Generates seamless closed-loop routes with realistic dwell times and sequential stops, perfect for long-running simulation and social check-ins.

### 🗺️ 6. Multi-Source Global Search & Interactive Visual MapKit
- **Tri-Engine Search**: Combines OpenStreetMap (Nominatim) + Komoot (Photon) + Apple Maps local search. Search by place name, address, landmark, or lat/lon coordinates in any language.
- **Modern Dual-Panel Interface**:
  - Supports Standard, Satellite, and Hybrid map styles.
  - Floating frosted-glass zoom controls (`+` Zoom In, `-` Zoom Out, Recenter) and `⌘ +` / `⌘ -` keyboard shortcuts.
- **8-Direction Virtual Joystick**:
  - Micro-step walking adjustments (5m to 100m) with direct Mac physical keyboard arrow key support (**↑ ↓ ← →**).

---

## 🛠️ Prerequisites

### 1. iOS / iPadOS Device
- **Compatible Versions**: iOS 17.0 ~ iOS 18.x and above (fully forward-compatible with iOS 27+).
- **Developer Mode**: Enable in **Settings** → **Privacy & Security** → **Developer Mode**, then restart.
- **Trust Connection**: Connect via USB cable and tap **Trust This Computer**.
- **No Jailbreak Required**: 100% works on stock, non-jailbroken devices.

### 2. Mac Computer
- **Operating System**: macOS 14.0 Sonoma or later (native Apple Silicon M-series & Intel support).
- **Environment**: Command Line Tools or Xcode 15.0+ installed (`xcrun devicectl` accessible in Terminal).

---

## 🏗️ Developer Build Instructions

```bash
# 1. Clone repository
git clone https://github.com/AtnothDob/ios27-location-anywhere.git
cd ios27-location-anywhere

# 2. Build via command line
xcodebuild -project GPSSimulator.xcodeproj -scheme GPSSimulator -destination 'platform=macOS' build

# 3. Launch compiled application
open ~/Library/Developer/Xcode/DerivedData/GPSSimulator-*/Build/Products/Debug/GPSSimulator.app
```

---

## 🔒 Privacy & Security

- **Device communication stays local**: Coordinates are sent straight from your Mac to the USB / Wi-Fi connected device via `xcrun devicectl`. No relay server is involved, and device UDIDs are never collected or uploaded.
- **Third-party services used**: The following features need network access and send data to public services:
  - Place search: your query is sent to Apple Maps, OpenStreetMap Nominatim and Komoot Photon;
  - Route planning: start / destination coordinates are sent to Apple Maps and public OSRM servers (`router.project-osrm.org`, `routing.openstreetmap.de`);
  - Auto-roaming: nearby POI lookup goes through Apple Maps.
  
  These public services are rate-limited — please don't hammer them.
- **Clean & Open Source**: Zero telemetry, zero private unauthorized APIs, completely transparent.

---

## 📄 License

This project is open-source under the [MIT License](LICENSE). Stars, Forks, and Pull Requests are welcome!
