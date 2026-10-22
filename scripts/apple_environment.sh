#!/usr/bin/env bash
# Dart native-asset hooks retain PATH but filter out DEVELOPER_DIR. Keep xcrun
# pointed at the selected Xcode without changing the machine's global settings.
if [[ "$(uname -s)" == Darwin ]]; then
  apple_developer_dir="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
  if [[ -z "${DEVELOPER_DIR:-}" && "$apple_developer_dir" == /Library/Developer/CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
    apple_developer_dir=/Applications/Xcode.app/Contents/Developer
  fi
  if [[ -d "$apple_developer_dir/Platforms/iPhoneSimulator.platform" ]]; then
    export DEVELOPER_DIR="$apple_developer_dir"
    mkdir -p "$PROJECT_ROOT/.tooling/apple-tools"
    {
      printf '#!/usr/bin/env bash\n'
      printf 'export DEVELOPER_DIR=%q\n' "$DEVELOPER_DIR"
      printf 'exec /usr/bin/xcrun "$@"\n'
    } > "$PROJECT_ROOT/.tooling/apple-tools/xcrun"
    chmod +x "$PROJECT_ROOT/.tooling/apple-tools/xcrun"
    export PATH="$PROJECT_ROOT/.tooling/apple-tools:$PATH"
  fi
  unset apple_developer_dir
fi
