#!/bin/bash
set -euo pipefail

log() {
  echo "[ci_post_clone] $*"
}

die() {
  echo "error: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
cd "$REPO_ROOT"

if [[ -f "$REPO_ROOT/pubspec.yaml" ]]; then
  PROJECT_ROOT="$REPO_ROOT"
else
  PROJECT_ROOT="$REPO_ROOT/b_smart"
fi

IOS_ROOT="$PROJECT_ROOT/ios"
METADATA_FILE="$PROJECT_ROOT/.metadata"

[[ -d "$PROJECT_ROOT" ]] || die "Could not find the Phase 1 project at $PROJECT_ROOT"
[[ -f "$METADATA_FILE" ]] || die "Missing Flutter metadata at $METADATA_FILE"

required_flutter_revision="$(sed -n 's/^  revision: "\(.*\)"/\1/p' "$METADATA_FILE" | head -n 1)"
required_flutter_channel="$(sed -n 's/^  channel: "\(.*\)"/\1/p' "$METADATA_FILE" | head -n 1)"

[[ -n "$required_flutter_revision" ]] || die "Could not read the required Flutter revision from $METADATA_FILE"
[[ -n "$required_flutter_channel" ]] || die "Could not read the required Flutter channel from $METADATA_FILE"

flutter_version_matches() {
  local flutter_root="$1"
  local framework_revision
  local framework_channel

  [[ -d "$flutter_root/.git" ]] || return 1

  framework_revision="$(git -C "$flutter_root" rev-parse HEAD)"
  framework_channel="$(git -C "$flutter_root" branch --show-current)"

  [[ "$framework_revision" == "$required_flutter_revision" ]] || return 1

  if [[ -n "$framework_channel" && "$framework_channel" != "$required_flutter_channel" ]]; then
    return 1
  fi

  return 0
}

ensure_flutter() {
  local flutter_bin=""
  local flutter_root=""
  local install_root="${CI_FLUTTER_ROOT:-${HOME:-/tmp}/flutter-sdk}"

  if command -v flutter >/dev/null 2>&1; then
    flutter_bin="$(command -v flutter)"
    flutter_root="$(cd "$(dirname "$flutter_bin")/.." && pwd)"
    if flutter_version_matches "$flutter_root"; then
      export PATH="$flutter_root/bin:$PATH"
      log "Using preinstalled Flutter at $flutter_root"
      return 0
    fi
    log "Preinstalled Flutter does not match the project revision; bootstrapping the pinned SDK instead"
  fi

  if [[ ! -d "$install_root/.git" ]]; then
    rm -rf "$install_root"
    log "Cloning Flutter SDK into $install_root"
    git clone https://github.com/flutter/flutter.git "$install_root"
  fi

  log "Fetching Flutter revision $required_flutter_revision"
  git -C "$install_root" fetch --depth 1 origin "$required_flutter_revision"
  git -C "$install_root" checkout --force "$required_flutter_revision"

  export PATH="$install_root/bin:$PATH"
  flutter_version_matches "$install_root" || die "Installed Flutter SDK at $install_root does not match revision $required_flutter_revision on channel $required_flutter_channel"
  log "Using pinned Flutter SDK at $install_root"
}

ensure_flutter

cd "$PROJECT_ROOT"

log "Running flutter precache --ios"
flutter precache --ios

log "Running flutter pub get"
flutter pub get

[[ -f "$IOS_ROOT/Flutter/Generated.xcconfig" ]] || die "flutter pub get did not generate $IOS_ROOT/Flutter/Generated.xcconfig"

if ! command -v pod >/dev/null 2>&1; then
  die "CocoaPods is not available on PATH"
fi

log "Running pod install"
cd "$IOS_ROOT"
pod install

required_files=(
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-input-files.xcfilelist"
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks-Release-output-files.xcfilelist"
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-input-files.xcfilelist"
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner-resources-Release-output-files.xcfilelist"
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
  "$IOS_ROOT/Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
)

for required_file in "${required_files[@]}"; do
  [[ -f "$required_file" ]] || die "Missing generated CocoaPods file: $required_file"
done

log "Xcode Cloud preparation completed successfully"
