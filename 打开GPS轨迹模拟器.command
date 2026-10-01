#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$DIR/GPSSimulator.app" ]; then
    open "$DIR/GPSSimulator.app"
elif [ -d "/Volumes/HPT DISK 1_0 Media/Project/GPS/GPSSimulator.app" ]; then
    open "/Volumes/HPT DISK 1_0 Media/Project/GPS/GPSSimulator.app"
else
    open /Users/macstudio/Desktop/GPSSimulator.app
fi
