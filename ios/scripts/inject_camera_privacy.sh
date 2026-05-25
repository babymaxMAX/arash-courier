#!/bin/sh
# Privacy keys must be in the final Runner.app/Info.plist (iOS kills the app without them).
set -e

PLIST="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Info.plist"
if [ ! -f "$PLIST" ]; then
  PLIST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist"
fi

if [ ! -f "$PLIST" ]; then
  echo "error: Info.plist not found (TARGET_BUILD_DIR=${TARGET_BUILD_DIR}, WRAPPER_NAME=${WRAPPER_NAME})" >&2
  exit 1
fi

CAMERA_TEXT="Приложению нужен доступ к камере для сканирования QR-кодов и создания фотоотчетов."
PHOTOS_TEXT="Приложению нужен доступ к галерее для загрузки фотографий заказов."
MIC_TEXT="Приложению нужен доступ к микрофону для записи видеоотчетов."

set_privacy_key() {
  key="$1"
  value="$2"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :${key} \"${value}\"" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :${key} string \"${value}\"" "$PLIST"
  fi
}

set_privacy_key "NSCameraUsageDescription" "$CAMERA_TEXT"
set_privacy_key "NSPhotoLibraryUsageDescription" "$PHOTOS_TEXT"
set_privacy_key "NSMicrophoneUsageDescription" "$MIC_TEXT"

/usr/libexec/PlistBuddy -c "Print :NSCameraUsageDescription" "$PLIST" >/dev/null
echo "Privacy keys injected into ${PLIST}"
