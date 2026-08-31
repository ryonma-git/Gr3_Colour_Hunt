#!/bin/bash
# Color Hunt: iOS 向けの型チェック（Mac 上での簡易ビルド確認）
set -u
cd "$(dirname "$0")/ColorHunt.swiftpm" || exit 1
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
find . -name '*.swift' ! -name 'Package.swift' -print0 \
  | xargs -0 xcrun swiftc -sdk "$SDK" -target arm64-apple-ios16.0 -swift-version 5 -typecheck
echo "typecheck exit: $?"
