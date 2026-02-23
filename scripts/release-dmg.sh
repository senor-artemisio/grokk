#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Grokk.xcodeproj}"
SCHEME="${SCHEME:-Grokk}"
APP_NAME="${APP_NAME:-Grokk}"
CONFIGURATION="${CONFIGURATION:-Release}"
MIN_MACOS="${MIN_MACOS:-14.0}"
BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$BUILD_DIR/DerivedData}"
STAGE_DIR="${STAGE_DIR:-$BUILD_DIR/dmg-root}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DMG_NAME="${DMG_NAME:-${APP_NAME}-unsigned-${TIMESTAMP}.dmg}"
DMG_PATH="${DMG_PATH:-$BUILD_DIR/$DMG_NAME}"

usage() {
  cat <<EOF
Unsigned DMG build script for ${APP_NAME}.

Usage:
  $(basename "$0")

Optional environment variables:
  PROJECT_PATH      Xcode project path (default: ${PROJECT_PATH})
  SCHEME            Xcode scheme (default: ${SCHEME})
  APP_NAME          App bundle name (default: ${APP_NAME})
  CONFIGURATION     Build configuration (default: ${CONFIGURATION})
  MIN_MACOS         Override deployment target (default: ${MIN_MACOS})
  BUILD_DIR         Output directory (default: ${BUILD_DIR})
  DMG_NAME          Output DMG name (default: auto timestamped)
  DMG_PATH          Full output DMG path (overrides BUILD_DIR + DMG_NAME)

Notes:
  - This script creates an unsigned DMG.
  - On other Macs Gatekeeper may require right-click -> Open.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not installed (install Xcode Command Line Tools)." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "error: hdiutil is not available (macOS-only command)." >&2
  exit 1
fi

APP_PATH="${DERIVED_DATA_DIR}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
APP_BINARY_PATH="${APP_PATH}/Contents/MacOS/${APP_NAME}"

echo "==> Cleaning previous build artifacts"
rm -rf "${DERIVED_DATA_DIR}" "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}" "${BUILD_DIR}"

echo "==> Building ${APP_NAME}.app (${CONFIGURATION})"
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  MACOSX_DEPLOYMENT_TARGET="${MIN_MACOS}" \
  clean build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: app bundle was not produced at ${APP_PATH}" >&2
  exit 1
fi

echo "==> Preparing DMG contents"
cp -R "${APP_PATH}" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

echo "==> Creating DMG at ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -format UDZO \
  -ov \
  "${DMG_PATH}" >/dev/null

echo "==> Build complete"
if [[ -f "${APP_BINARY_PATH}" ]] && command -v lipo >/dev/null 2>&1; then
  echo "Architectures: $(lipo -archs "${APP_BINARY_PATH}" 2>/dev/null || echo "unknown")"
fi
echo "DMG: ${DMG_PATH}"
echo "Note: unsigned build. On other Macs use right-click -> Open if Gatekeeper blocks launch."
