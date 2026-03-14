#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating iOS minimum to 13.0 and fixing CocoaPods xcconfig includes"

cd ios

# 1) Podfile: raise platform to 13.0
if grep -qE "^platform :ios, '12\.0'" Podfile; then
  sed -i.bak "s/^platform :ios, '12\.0'/platform :ios, '13.0'/" Podfile
elif ! grep -qE "^platform :ios" Podfile; then
  # add a platform line if it's missing
  sed -i.bak "1s|^|platform :ios, '13.0'\n|" Podfile
fi
echo "✓ Podfile set to iOS 13.0"

# 2) Ensure Runner.xcodeproj build settings default to 13.0
add_include_if_missing () {
  local file="$1" inc="$2"
  if [ -f "$file" ] && ! grep -qF "$inc" "$file"; then
    printf '\n%s\n' "$inc" >> "$file"
    echo "✓ Added include to $file"
  fi
}

add_include_if_missing "Flutter/Debug.xcconfig"  '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"'
add_include_if_missing "Flutter/Release.xcconfig" '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"'
add_include_if_missing "Flutter/Profile.xcconfig" '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"'

# 3) Clean & re-install pods
rm -rf Pods Podfile.lock
pod repo update
pod install

cd ..

# 4) Flutter clean & get
flutter clean
flutter pub get

echo "==> Done."
echo "If Xcode still shows iOS 12, open ios/Runner.xcworkspace and set:"
echo "  - Runner target > Build Settings > iOS Deployment Target = 13.0"
echo "  - Runner target > Info > iOS Deployment Target = 13.0"

