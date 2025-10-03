#!/bin/sh

# Colors
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

# Dependencies
deps="meson ninja patchelf unzip curl pip flex bison zip"

# Workspace variables
workdir="$(pwd)/mesa_glcore_workdir"
ndkver="android-ndk-r25c"
outputdir="$workdir/output"

clear

echo "Checking system for required Dependencies ..."
for deps_chk in $deps; do
  sleep 0.25
  if command -v $deps_chk >/dev/null 2>&1 ; then
    echo -e "$green - $deps_chk found $nocolor"
  else
    echo -e "$red - $deps_chk not found, can't continue. $nocolor"
    deps_missing=1
  fi
done

if [ "$deps_missing" == "1" ]; then
  echo "Please install missing dependencies" && exit 1
fi

echo "Upgrading Meson to latest version via pip..." $'\n'
pip install --upgrade meson

echo "Installing python Mako dependency (if missing) ..." $'\n'
pip install mako

echo "Creating and entering work directory ..." $'\n'
mkdir -p "$workdir" && cd "$workdir"

echo "Downloading Android NDK (~500MB) ..." $'\n'
curl -L "https://dl.google.com/android/repository/$ndkver-linux.zip" --output "$ndkver"-linux.zip

echo "Extracting Android NDK ..." $'\n'
unzip "$ndkver"-linux.zip

echo "Downloading Mesa source (~30MB) ..." $'\n'
curl -L "https://gitlab.freedesktop.org/mesa/mesa/-/archive/main/mesa-main.zip" --output mesa-main.zip

echo "Extracting Mesa source ..." $'\n'
unzip mesa-main.zip
cd mesa-main

echo "Creating Meson cross file ..." $'\n'
ndk="$workdir/$ndkver/toolchains/llvm/prebuilt/linux-x86_64/bin"
cat <<EOF >"android-aarch64"
[binaries]
ar = '$ndk/llvm-ar'
c = ['ccache', '$ndk/aarch64-linux-android31-clang']
cpp = ['ccache', '$ndk/aarch64-linux-android31-clang++', '-fno-exceptions', '-fno-unwind-tables', '-fno-asynchronous-unwind-tables', '-static-libstdc++']
c_ld = 'lld'
cpp_ld = 'lld'
strip = '$ndk/aarch64-linux-android-strip'
pkgconfig = ['env', 'PKG_CONFIG_LIBDIR=NDKDIR/pkgconfig', '/usr/bin/pkg-config']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
EOF

echo "Generating build files (OpenGL Core only) ..." $'\n'
meson build-android-glcore \
  --cross-file $workdir/mesa-main/android-aarch64 \
  -Dbuildtype=release \
  -Dplatforms=android \
  -Dplatform-sdk-version=31 \
  -Dandroid-stub=true \
  -Dgallium-drivers=freedreno \
  -Dvulkan-drivers= \
  -Dfreedreno-kmds= \
  -Dglx=disabled \
  -Degl=enabled \
  -Dgles1=disabled \
  -Dgles2=disabled \
  -Dopengl=true \
  -Dshared-glapi=enabled \
  -Db_lto=true

echo "Compiling Mesa (OpenGL Core) ..." $'\n'
ninja -C build-android-glcore

# ✅ Export all build output
echo "Exporting all build output to $outputdir ..." $'\n'
rm -rf "$outputdir"
mkdir -p "$outputdir"
cp -r $workdir/mesa-main/build-android-glcore/* "$outputdir"

echo -e "$green ✅ OpenGL Core build complete!$nocolor"
echo -e "$green Output: $outputdir $nocolor"
