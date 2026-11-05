#!/bin/bash
# Make the Xcode project from project.yml and open it.
# Double-click this file in Finder, or run ./open-in-xcode.command in Terminal.
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null; then
    echo "xcodegen is missing. Install it with: brew install xcodegen"
    exit 1
fi

xcodegen generate || exit 1
open BeadLab.xcodeproj
