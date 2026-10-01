#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Apple iOS GPS Trajectory Simulator for Mac
Powered by CoreDevice & devicectl | UI: PyQt5
"""

import sys, os, re, subprocess, threading, time, math
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QComboBox, QPushButton, QRadioButton, QButtonGroup,
    QLineEdit, QTextEdit, QFrame, QCheckBox, QMessageBox, QGroupBox
)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QObject
from PyQt5.QtGui import QFont, QColor, QPalette, QTextCursor

# ── 预设地点 ──────────────────────────────────────────
PRESETS = {
    "🇺🇸 苹果总部 (Apple Park, CA)":            (37.3349,   -122.0090),
    "🇺🇸 纽约中央公园 (Central Park, NY)":       (40.785091,  -73.968285),
    "🇺🇸 旧金山金门大桥 (Golden Gate, SF)":      (37.8199,   -122.4783),
    "🇯🇵 东京涩谷十字路口 (Shibuya, Tokyo)":     (35.6595,    139.7004),
    "🇬🇧 伦敦大本钟 (Big Ben, London)":          (51.5007,    -0.1246),
    "🇫🇷 巴黎埃菲尔铁塔 (Eiffel Tower, Paris)":  (48.8584,     2.2945),
}

SCENARIOS = {
    "🚶 步行 / 慢跑 (City Run ≈ 8 km/h)":         "City Run",
    "🚴 城市骑行 (City Bicycle Ride ≈ 18 km/h)":  "City Bicycle Ride",
    "🚗 高速公路 (Freeway Drive ≈ 90 km/h)":       "Freeway Drive",
}

AUTO_SCAN_INTERVAL = 3   # 秒


# ── 设备扫描 ──────────────────────────────────────────
def scan_devices():
    """返回 [(name, udid), ...]，只含物理真机。"""
    devices = []
    try:
        out = subprocess.check_output(
            "xcrun devicectl list devices 2>&1",
            shell=True, text=True, timeout=8
        )
        for line in out.splitlines():
            if "physical" not in line.lower():
                continue
            stripped = line.strip()
            if not stripped or stripped.startswith("-") or stripped.startswith("Name"):
                continue
            cols = re.split(r"  +", stripped)
            name = cols[0].strip() if cols else ""
            m = re.search(r'\b([0-9A-Fa-f]{8}-[0-9A-Fa-f]{16,})\b', line)
            udid = m.group(1) if m else "unknown"
            if name and udid:
                devices.append((name, udid))
    except Exception:
        pass
    return devices


# ── 信号桥（子线程 → 主线程）────────────────────────
class Bridge(QObject):
    devices_changed  = pyqtSignal(list)   # [(name, udid)]
    log_signal       = pyqtSignal(str)
    status_signal    = pyqtSignal(str)
    dot_signal       = pyqtSignal(str)
    new_device_alert = pyqtSignal(list)   # [name, ...]


# ── 主窗口 ────────────────────────────────────────────
class GPSApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("📱 iOS GPS 轨迹模拟器")
        self.setFixedSize(660, 760)

        self._bridge = Bridge()
        self._bridge.devices_changed.connect(self._update_combo)
        self._bridge.log_signal.connect(self._append_log)
        self._bridge.status_signal.connect(self._set_status)
        self._bridge.dot_signal.connect(self._set_dot)
        self._bridge.new_device_alert.connect(self._show_device_alert)

        self._last_udids = set()
        self._auto_scan_running = True
        self._auto_scan_on = True
        self._is_looping = False
        self._loop_stop = threading.Event()

        self._build_ui()
        self._apply_dark()

        # 首次扫描
        threading.Thread(target=self._do_refresh, kwargs={"initial": True}, daemon=True).start()
        # 热插拔后台线程
        threading.Thread(target=self._scan_loop, daemon=True, name="AutoScan").start()

    # ─────────────────────────── UI ──────────────────
    def _build_ui(self):
        root = QVBoxLayout(self)
        root.setSpacing(8)
        root.setContentsMargins(14, 12, 14, 12)

        # ── 设备区 ──────────────────────────────────
        dev_box = QGroupBox("📱  目标 iOS 设备")
        dev_box.setFont(QFont("PingFang SC", 12, QFont.Bold))
        dv = QVBoxLayout(dev_box)

        row1 = QHBoxLayout()
        self.dev_combo = QComboBox()
        self.dev_combo.setMinimumWidth(420)
        self.dev_combo.addItem("正在扫描…")
        self.dev_combo.setFont(QFont("PingFang SC", 12))
        row1.addWidget(self.dev_combo, stretch=1)
        btn_refresh = QPushButton("🔄 刷新")
        btn_refresh.setFixedWidth(90)
        btn_refresh.clicked.connect(self._manual_refresh)
        row1.addWidget(btn_refresh)
        dv.addLayout(row1)

        row2 = QHBoxLayout()
        self._dot_lbl = QLabel("●")
        self._dot_lbl.setStyleSheet("color:#00dd55; font-size:14px;")
        self._status_lbl = QLabel("初始化中…")
        self._status_lbl.setStyleSheet("color:gray; font-size:11px;")
        self._auto_chk = QCheckBox("自动识别热插拔")
        self._auto_chk.setChecked(True)
        self._auto_chk.stateChanged.connect(self._toggle_auto)
        row2.addWidget(self._dot_lbl)
        row2.addWidget(self._status_lbl, stretch=1)
        row2.addWidget(self._auto_chk)
        dv.addLayout(row2)
        root.addWidget(dev_box)

        # ── Apple 原生轨迹 ───────────────────────────
        scen_box = QGroupBox("🏃  Apple 原生拟真轨迹模式")
        scen_box.setFont(QFont("PingFang SC", 12, QFont.Bold))
        sv = QVBoxLayout(scen_box)
        sv.addWidget(QLabel("调用 Apple CoreLocation 运动学模型，轨迹最逼真"))
        self.scen_combo = QComboBox()
        self.scen_combo.addItems(list(SCENARIOS.keys()))
        self.scen_combo.setFont(QFont("PingFang SC", 12))
        sv.addWidget(self.scen_combo)
        btn_scen = QPushButton("▶  开始模拟该运动轨迹")
        btn_scen.setFixedHeight(36)
        btn_scen.clicked.connect(self._start_scenario)
        sv.addWidget(btn_scen)
        root.addWidget(scen_box)

        # ── 环形巡航 ─────────────────────────────────
        circ_box = QGroupBox("🚲  自定义速度环形巡航")
        circ_box.setFont(QFont("PingFang SC", 12, QFont.Bold))
        cv = QVBoxLayout(circ_box)

        loc_row = QHBoxLayout()
        loc_row.addWidget(QLabel("中心地标:"))
        self.preset_combo = QComboBox()
        self.preset_combo.addItems(list(PRESETS.keys()))
        self.preset_combo.setFont(QFont("PingFang SC", 11))
        self.preset_combo.currentTextChanged.connect(self._on_preset)
        loc_row.addWidget(self.preset_combo, stretch=1)
        cv.addLayout(loc_row)

        coord_row = QHBoxLayout()
        coord_row.addWidget(QLabel("纬度:"))
        self.lat_edit = QLineEdit(str(list(PRESETS.values())[0][0]))
        self.lat_edit.setMaximumWidth(130)
        coord_row.addWidget(self.lat_edit)
        coord_row.addSpacing(16)
        coord_row.addWidget(QLabel("经度:"))
        self.lon_edit = QLineEdit(str(list(PRESETS.values())[0][1]))
        self.lon_edit.setMaximumWidth(130)
        coord_row.addWidget(self.lon_edit)
        coord_row.addStretch()
        cv.addLayout(coord_row)

        speed_row = QHBoxLayout()
        speed_row.addWidget(QLabel("速度:"))
        self._speed_grp = QButtonGroup(self)
        for i, (txt, val) in enumerate([("🚶 步行 5km/h", "walk"),
                                         ("🚴 骑行 18km/h", "bike"),
                                         ("🚗 汽车 60km/h", "car")]):
            rb = QRadioButton(txt)
            rb.setProperty("speed_val", val)
            if i == 0:
                rb.setChecked(True)
            self._speed_grp.addButton(rb)
            speed_row.addWidget(rb)
        speed_row.addStretch()
        cv.addLayout(speed_row)

        btn_row = QHBoxLayout()
        self.btn_loop = QPushButton("🔄 启动环形巡航")
        self.btn_loop.setFixedHeight(34)
        self.btn_loop.clicked.connect(self._toggle_loop)
        btn_teleport = QPushButton("📍 瞬移（静态）")
        btn_teleport.setFixedHeight(34)
        btn_teleport.clicked.connect(self._teleport)
        btn_row.addWidget(self.btn_loop)
        btn_row.addWidget(btn_teleport)
        cv.addLayout(btn_row)
        root.addWidget(circ_box)

        # ── 停止 ─────────────────────────────────────
        btn_stop = QPushButton("🛑  停止模拟，恢复手机真实 GPS")
        btn_stop.setFixedHeight(42)
        btn_stop.setStyleSheet(
            "QPushButton{background:#c0392b;color:white;font-size:13px;font-weight:bold;"
            "border-radius:6px;}"
            "QPushButton:hover{background:#922b21;}"
        )
        btn_stop.clicked.connect(self._clear)
        root.addWidget(btn_stop)

        # ── 日志 ─────────────────────────────────────
        log_box = QGroupBox("📋  运行日志")
        lv = QVBoxLayout(log_box)
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setFont(QFont("Menlo", 10))
        self.log_view.setStyleSheet(
            "QTextEdit{background:#111111;color:#00ff66;border:none;border-radius:6px;}"
        )
        self.log_view.setMinimumHeight(130)
        lv.addWidget(self.log_view)
        root.addWidget(log_box, stretch=1)

    def _apply_dark(self):
        self.setStyleSheet("""
            QWidget { background-color: #1e1e2e; color: #cdd6f4; font-family: 'PingFang SC'; }
            QGroupBox { border: 1px solid #45475a; border-radius: 8px; margin-top: 8px;
                        padding: 10px 8px 8px 8px; }
            QGroupBox::title { subcontrol-origin: margin; left: 10px; padding: 0 4px; }
            QComboBox { background:#313244; border:1px solid #45475a; border-radius:5px;
                        padding:4px 8px; font-size:12px; }
            QComboBox QAbstractItemView { background:#313244; selection-background-color:#585b70; }
            QPushButton { background:#585b70; color:#cdd6f4; border:none; border-radius:6px;
                          padding:6px 12px; font-size:12px; }
            QPushButton:hover { background:#6c6f85; }
            QLineEdit { background:#313244; border:1px solid #45475a; border-radius:5px;
                        padding:4px 8px; }
            QCheckBox { font-size:11px; }
            QRadioButton { font-size:12px; }
            QLabel { font-size:12px; }
        """)

    # ─────────────────────── 日志 ────────────────────
    def _append_log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self.log_view.append(f"<span style='color:#6c6f85'>[{ts}]</span> {msg}")
        self.log_view.moveCursor(QTextCursor.End)

    def _set_status(self, s):
        self._status_lbl.setText(s)

    def _set_dot(self, d):
        self._dot_lbl.setText(d)

    def log(self, msg):
        self._bridge.log_signal.emit(msg)

    # ─────────────────────── 热插拔 ──────────────────
    def _scan_loop(self):
        dots = ["◐", "◓", "◑", "◒"]
        tick = 0
        while self._auto_scan_running:
            time.sleep(AUTO_SCAN_INTERVAL)
            tick += 1
            self._bridge.dot_signal.emit(dots[tick % 4])

            if not self._auto_scan_on:
                continue

            devices = scan_devices()
            cur = {u for _, u in devices}
            if cur != self._last_udids:
                added = cur - self._last_udids
                removed = self._last_udids - cur
                if self._last_udids:
                    if added:
                        new_names = [n for n, u in devices if u in added]
                        self._bridge.log_signal.emit(f"🟢 新设备接入: {', '.join(new_names)}")
                        self._bridge.new_device_alert.emit(new_names)
                    if removed:
                        self._bridge.log_signal.emit(f"🔴 设备断开 (UDID: {list(removed)[0][:8]}…)")
                self._last_udids = cur
                self._bridge.devices_changed.emit(devices)
            else:
                n = len(devices)
                label = (f"✅ {n} 台设备已连接，每 {AUTO_SCAN_INTERVAL}s 扫描"
                         if n else f"⚠️ 未发现设备，每 {AUTO_SCAN_INTERVAL}s 扫描")
                self._bridge.status_signal.emit(label)

    def _update_combo(self, devices):
        prev = self.dev_combo.currentText()
        self.dev_combo.blockSignals(True)
        self.dev_combo.clear()
        if devices:
            entries = [f"{n}  ({u})" for n, u in devices]
            self.dev_combo.addItems(entries)
            # 恢复之前选中
            restored = False
            if prev and "(" in prev:
                prev_u = prev.split("(")[-1].rstrip(")").strip()
                for i, e in enumerate(entries):
                    if prev_u in e:
                        self.dev_combo.setCurrentIndex(i)
                        restored = True
                        break
            if not restored:
                sato_idx = next((i for i, e in enumerate(entries) if "sato" in e.lower()), 0)
                self.dev_combo.setCurrentIndex(sato_idx)
            self._bridge.status_signal.emit(f"✅ {len(devices)} 台设备已连接，每 {AUTO_SCAN_INTERVAL}s 扫描")
        else:
            self.dev_combo.addItem("⚠️ 未发现物理设备")
            self._bridge.status_signal.emit(f"⚠️ 未发现设备，每 {AUTO_SCAN_INTERVAL}s 扫描")
        self.dev_combo.blockSignals(False)

    def _do_refresh(self, initial=False):
        devices = scan_devices()
        self._last_udids = {u for _, u in devices}
        self._bridge.devices_changed.emit(devices)
        n = len(devices)
        if initial:
            if n:
                self._bridge.log_signal.emit(f"发现 {n} 台物理设备: {', '.join(nm for nm, _ in devices)}")
            else:
                self._bridge.log_signal.emit("未发现物理真机，请检查数据线或开启开发者模式。")
        else:
            self._bridge.log_signal.emit(f"刷新完成，发现 {n} 台设备。")

    def _manual_refresh(self):
        self._bridge.status_signal.emit("🔍 扫描中…")
        self._bridge.log_signal.emit("手动触发设备扫描…")
        threading.Thread(target=self._do_refresh, daemon=True).start()

    def _toggle_auto(self, state):
        self._auto_scan_on = bool(state)
        if self._auto_scan_on:
            self._bridge.log_signal.emit("自动识别已开启。")
        else:
            self._bridge.dot_signal.emit("○")
            self._bridge.log_signal.emit("自动识别已暂停。")

    def _show_device_alert(self, names):
        QMessageBox.information(self, "设备已连接",
            "🟢 新设备接入：\n" + "\n".join(f"  • {n}" for n in names) + "\n\n已自动刷新列表！")

    # ─────────────────────── 辅助 ────────────────────
    def _get_udid(self):
        val = self.dev_combo.currentText()
        if not val or "⚠️" in val or "扫描" in val:
            QMessageBox.warning(self, "提示", "未找到连接的 iOS 设备，请检查数据线！")
            return None
        if "(" in val and ")" in val:
            return val.split("(")[-1].rstrip(")").strip()
        return val.strip()

    def _on_preset(self, name):
        if name in PRESETS:
            lat, lon = PRESETS[name]
            self.lat_edit.setText(str(lat))
            self.lon_edit.setText(str(lon))

    def _get_speed(self):
        for btn in self._speed_grp.buttons():
            if btn.isChecked():
                return btn.property("speed_val")
        return "walk"

    def _stop_loop(self):
        if self._is_looping:
            self._is_looping = False
            self._loop_stop.set()
            self.btn_loop.setText("🔄 启动环形巡航")
            self.log("已停止环形巡航。")

    # ─────────────────────── GPS ─────────────────────
    def _run_cmd(self, cmd, success_msg, fail_prefix):
        def worker():
            try:
                subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
                self._bridge.log_signal.emit(f"🟢 {success_msg}")
            except subprocess.CalledProcessError as e:
                self._bridge.log_signal.emit(f"🔴 {fail_prefix}: {e.output.strip()}")
            except Exception as e:
                self._bridge.log_signal.emit(f"🔴 {fail_prefix}: {e}")
        threading.Thread(target=worker, daemon=True).start()

    def _start_scenario(self):
        udid = self._get_udid()
        if not udid:
            return
        self._stop_loop()
        name = self.scen_combo.currentText()
        scen = SCENARIOS.get(name, "")
        if not scen:
            return
        self.log(f"下发轨迹模式: {scen}…")
        self._run_cmd(
            f'xcrun devicectl device simulate location scenario --device "{udid}" "{scen}"',
            f"成功启动: {name}", "下发失败"
        )

    def _teleport(self):
        udid = self._get_udid()
        if not udid:
            return
        self._stop_loop()
        try:
            lat = float(self.lat_edit.text().strip())
            lon = float(self.lon_edit.text().strip())
        except ValueError:
            QMessageBox.critical(self, "错误", "经纬度格式不正确！")
            return
        self.log(f"瞬移到: ({lat}, {lon})…")
        self._run_cmd(
            f'xcrun devicectl device simulate location coordinate --device "{udid}" --latitude {lat} --longitude={lon}',
            f"成功定位: {lat}, {lon}", "定位失败"
        )

    def _toggle_loop(self):
        if self._is_looping:
            self._stop_loop()
            return
        udid = self._get_udid()
        if not udid:
            return
        try:
            lat = float(self.lat_edit.text().strip())
            lon = float(self.lon_edit.text().strip())
        except ValueError:
            QMessageBox.critical(self, "错误", "经纬度格式不正确！")
            return

        s = self._get_speed()
        if s == "walk":
            radius, step_sec, astep, desc = 0.002, 2.0, 0.08, "步行 5km/h"
        elif s == "bike":
            radius, step_sec, astep, desc = 0.006, 1.5, 0.15, "骑行 18km/h"
        else:
            radius, step_sec, astep, desc = 0.015, 1.0, 0.20, "汽车 60km/h"

        self._is_looping = True
        self._loop_stop.clear()
        self.btn_loop.setText("⏹ 停止巡航")
        self.log(f"启动 {desc} 环形巡航…")

        def worker():
            angle = 0.0
            while not self._loop_stop.is_set():
                clat = lat + radius * math.sin(angle)
                clon = lon + (radius / math.cos(math.radians(lat))) * math.cos(angle)
                cmd = (f'xcrun devicectl device simulate location coordinate '
                       f'--device "{udid}" --latitude {clat:.6f} --longitude={clon:.6f}')
                try:
                    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    pass
                angle += astep
                self._loop_stop.wait(timeout=step_sec)

        threading.Thread(target=worker, daemon=True).start()

    def _clear(self):
        self._stop_loop()
        udid = self._get_udid()
        if not udid:
            return
        self.log("恢复真实 GPS…")
        self._run_cmd(
            f'xcrun devicectl device simulate location clear --device "{udid}"',
            "已恢复真实物理定位！", "恢复失败"
        )

    def closeEvent(self, event):
        self._auto_scan_running = False
        self._is_looping = False
        self._loop_stop.set()
        event.accept()


# ── 入口 ──────────────────────────────────────────────
if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("iOS GPS 轨迹模拟器")
    win = GPSApp()
    win.show()
    sys.exit(app.exec_())
