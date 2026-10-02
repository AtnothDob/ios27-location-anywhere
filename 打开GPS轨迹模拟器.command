#!/bin/bash
# 依次查找：脚本同目录 → 「应用程序」→ 最近一次 Xcode Debug 构建产物
DIR="$(cd "$(dirname "$0")" && pwd)"
for APP in \
    "$DIR/GPSSimulator.app" \
    "/Applications/GPSSimulator.app" \
    "$HOME/Applications/GPSSimulator.app" \
    $(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/GPSSimulator-*/Build/Products/Debug/GPSSimulator.app 2>/dev/null); do
    if [ -d "$APP" ]; then
        open "$APP"
        exit 0
    fi
done
echo "未找到 GPSSimulator.app：请从 Releases 下载并放入「应用程序」，或先用 xcodebuild 编译。"
exit 1
