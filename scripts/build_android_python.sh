#!/usr/bin/env bash
# Compile the JNI launcher in Zig; use the NDK linker for Android's libc ABI.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
sdk="$1"; ndk="$2"; out="$3"
zig="${ZIG:-zig}"
toolchain="$sdk/ndk/$ndk/toolchains/llvm/prebuilt/linux-x86_64"
include="$toolchain/sysroot/usr/include"
for abi in arm64-v8a armeabi-v7a x86_64; do
  case "$abi" in
    arm64-v8a) target=aarch64-linux-android.29; clang_target=aarch64-linux-android29; headers=aarch64-linux-android; cpu=baseline ;;
    armeabi-v7a) target=arm-linux-androideabi.29; clang_target=armv7a-linux-androideabi29; headers=arm-linux-androideabi; cpu=cortex_a7 ;;
    x86_64) target=x86_64-linux-android.29; clang_target=x86_64-linux-android29; headers=x86_64-linux-android; cpu=baseline ;;
  esac
  mkdir -p "$out/$abi"
  "$zig" translate-c -target "$target" -I "$include/$headers" -I "$include" android/app/src/main/zig/jni_import.h > "$out/$abi/jni.zig"
  "$zig" build-obj -O ReleaseFast -fPIC -target "$target" -mcpu="$cpu" -lc --dep jni \
    -Mroot=android/app/src/main/zig/python_sandbox.zig -Mjni="$out/$abi/jni.zig" \
    -femit-bin="$out/$abi/launcher.o"
  "$toolchain/bin/clang" --target="$clang_target" --sysroot="$toolchain/sysroot" \
    -shared -Wl,-z,max-page-size=16384 -Wl,-soname,libtixun_python_sandbox.so \
    -o "$out/$abi/libtixun_python_sandbox.so" "$out/$abi/launcher.o" -ldl -lc
  rm "$out/$abi/jni.zig" "$out/$abi/launcher.o"
done
