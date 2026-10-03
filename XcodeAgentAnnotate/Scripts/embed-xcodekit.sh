#!/bin/sh
set -eu

# Xcode requires its own signed framework in the extension bundle. Do not re-sign it.
framework="${DEVELOPER_DIR}/Library/Frameworks/XcodeKit.framework"
destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ "${1:-}" = "containing-app" ]; then
    # Xcode's generated Copy App Extensions phase removes nested framework headers.
    # Restore the exact framework before the containing app is signed.
    destination="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/PlugIns/AnnotateEditorExtension.appex/Contents/Frameworks"
fi
test -d "$framework"
mkdir -p "$destination"
/usr/bin/ditto "$framework" "$destination/XcodeKit.framework"
