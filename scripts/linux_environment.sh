#!/usr/bin/env bash
# Optional rootless native tools. Normal system installations need no overrides.
# Sourced by scripts/flutter so subsequent builds reuse the local toolchain.
linux_sysroot="$PROJECT_ROOT/.tooling/linux-sysroot/usr"
if [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 && -d "$linux_sysroot" ]]; then
  export PATH="$linux_sysroot/bin:$PATH"
  export LD_LIBRARY_PATH="$linux_sysroot/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export LIBRARY_PATH="$linux_sysroot/lib/x86_64-linux-gnu${LIBRARY_PATH:+:$LIBRARY_PATH}"
  export PKG_CONFIG_PATH="$linux_sysroot/lib/x86_64-linux-gnu/pkgconfig:$linux_sysroot/share/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export CMAKE_PREFIX_PATH="$linux_sysroot${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
fi
unset linux_sysroot
