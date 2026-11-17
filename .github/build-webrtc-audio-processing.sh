#!/bin/bash
# Builds webrtc-audio-processing 1.3 (AEC3) into PREFIX for CI hosts whose
# package manager lacks a 1.x/2.x build: MSYS2 ships only 0.3.1, Homebrew none.
# Abseil comes from meson's wrap fallback and is linked in statically; its
# headers are installed too, because webrtc's public headers include them.
set -euo pipefail

PREFIX=${1:?usage: $0 PREFIX}
VER=1.3

[ -f "$PREFIX/lib/pkgconfig/webrtc-audio-processing-1.pc" ] && [ -d "$PREFIX/include/webrtc-audio-processing-1/absl" ] \
	&& { echo "already built in $PREFIX"; exit 0; }

work=$(mktemp -d)
cd "$work"
curl -fsSL -o apm.tar.xz "https://freedesktop.org/software/pulseaudio/webrtc-audio-processing/webrtc-audio-processing-$VER.tar.xz"
tar -xf apm.tar.xz
cd "webrtc-audio-processing-$VER"
meson setup build --prefix="$PREFIX" --libdir=lib --buildtype=release \
	--wrap-mode=forcefallback -Dabseil-cpp:default_library=static \
	-Dcpp_std=gnu++17 -Dabseil-cpp:cpp_std=gnu++17
meson compile -C build
meson install -C build
# the .pc file's Cflags already point at this directory
cp -R subprojects/abseil-cpp-*/absl "$PREFIX/include/webrtc-audio-processing-1/"
