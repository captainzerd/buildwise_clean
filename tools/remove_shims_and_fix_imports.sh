#!/usr/bin/env bash
set -euo pipefail

echo "==> Rewriting imports to point at core/* ..."

# BSD vs GNU sed inline flag
if sed --version >/dev/null 2>&1; then
  SED_I=(-i)
else
  SED_I=(-i '')
fi

# Target all Dart files under lib/ and test/
FILES=$(find lib test -type f -name "*.dart")

# Rewrite relative imports that used shims
for f in $FILES; do
  sed "${SED_I[@]}" \
    -e 's#\.\./\.\./services/project_service\.dart#\.\./\.\./core/services/project_service.dart#g' \
    -e 's#\.\./\.\./services/vendor_service\.dart#\.\./\.\./core/services/vendor_service.dart#g' \
    -e 's#\.\./\.\./services/complaint_service\.dart#\.\./\.\./core/services/complaint_service.dart#g' \
    -e 's#\.\./\.\./models/project\.dart#\.\./\.\./core/models/project.dart#g' \
    -e 's#\.\./\.\./models/vendor\.dart#\.\./\.\./core/models/vendor.dart#g' \
    -e 's#\.\./\.\./models/complaint\.dart#\.\./\.\./core/models/complaint.dart#g' \
    "$f"
done

# Rewrite potential package imports of shims too (if any)
for f in $FILES; do
  sed "${SED_I[@]}" \
    -e "s#package:${PWD##*/}/services/project_service\.dart#package:${PWD##*/}/core/services/project_service.dart#g" \
    -e "s#package:${PWD##*/}/services/vendor_service\.dart#package:${PWD##*/}/core/services/vendor_service.dart#g" \
    -e "s#package:${PWD##*/}/services/complaint_service\.dart#package:${PWD##*/}/core/services/complaint_service.dart#g" \
    -e "s#package:${PWD##*/}/models/project\.dart#package:${PWD##*/}/core/models/project.dart#g" \
    -e "s#package:${PWD##*/}/models/vendor\.dart#package:${PWD##*/}/core/models/vendor.dart#g" \
    -e "s#package:${PWD##*/}/models/complaint\.dart#package:${PWD##*/}/core/models/complaint.dart#g" \
    "$f"
done

echo "==> Deleting shim files (lib/services/*.dart and lib/models/*.dart that are re-exports) ..."

# Remove typical shim files if present
rm -f lib/services/project_service.dart || true
rm -f lib/services/vendor_service.dart || true
rm -f lib/services/complaint_service.dart || true
rm -f lib/models/project.dart || true
rm -f lib/models/vendor.dart || true
rm -f lib/models/complaint.dart || true

echo "==> Flutter clean & get (safe) ..."
flutter clean >/dev/null 2>&1 || true
flutter pub get

echo "==> Done. Next: flutter analyze"
flutter analyze || true

echo "==> If analyzer still complains, paste the exact errors and lines."