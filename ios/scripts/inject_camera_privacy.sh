#!/bin/sh
# Гарантирует privacy-ключи в финальном Info.plist (иначе iOS сразу закрывает камеру).
set -e

PLIST="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Info.plist"
if [ ! -f "$PLIST" ]; then
  PLIST="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Info.plist"
fi

if [ ! -f "$PLIST" ]; then
  echo "warning: Info.plist not found for privacy injection"
  exit 0
fi

set_privacy_key() {
  key="$1"
  value="$2"
  if /usr/libexec/PlistBuddy -c "Print :${key}" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "$PLIST"
  fi
}

set_privacy_key "NSCameraUsageDescription" "Приложению нужен доступ к камере для сканирования QR-кодов и создания фотоотчетов."
set_privacy_key "NSPhotoLibraryUsageDescription" "Приложению нужен доступ к галерее для загрузки фотографий заказов."
set_privacy_key "NSMicrophoneUsageDescription" "Приложению нужен доступ к микрофону для записи видеоотчетов."

echo "Privacy keys injected into ${PLIST}"
