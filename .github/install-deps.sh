#!/bin/bash
# Installs build dependencies inside a CI container (runs as root).
#   install-deps.sh node        pica-node only
#   install-deps.sh client-qt5  client + node against Qt 5
#   install-deps.sh client-qt6  client + node against Qt 6
# Debian/Ubuntu, Arch and Fedora are told apart by /etc/os-release.
# Where the archive has no webrtc-audio-processing 1.x, the client variants
# leave it to build-webrtc-audio-processing.sh (meson is installed for that).
set -euo pipefail

what=${1:?usage: $0 node|client-qt5|client-qt6}
. /etc/os-release

case "$ID" in
debian|ubuntu)
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -qq
	pkgs="build-essential autoconf automake libtool pkgconf ca-certificates
	      libssl-dev zlib1g-dev libevent-dev libsqlite3-dev sqlite3 libminiupnpc-dev"
	case "$what" in client-*)
		pkgs="$pkgs libasound2-dev libpulse-dev libva-dev libegl-dev libgl-dev libx11-dev
		      libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev libswresample-dev libswscale-dev
		      curl xz-utils ninja-build python3-pip"
		[ "$what" = client-qt5 ] && pkgs="$pkgs qtbase5-dev qtbase5-dev-tools" || pkgs="$pkgs qt6-base-dev"
		# 1.x where the archive has it (Debian 13, Ubuntu >= 25.10); otherwise build it
		if apt-cache show libwebrtc-audio-processing-dev 2>/dev/null | grep -q '^Version: 1\.\|^Version: 2\.'; then
			pkgs="$pkgs libwebrtc-audio-processing-dev"
		fi
	esac
	# shellcheck disable=SC2086
	apt-get install -qq -y --no-install-recommends $pkgs
	case "$what" in client-*)
		# webrtc-audio-processing 1.3 needs a newer meson than Ubuntu 22.04's 0.61
		pip3 install meson 2>/dev/null || pip3 install --break-system-packages meson
	esac
	;;
arch)
	pkgs="base-devel autoconf automake pkgconf openssl zlib libevent sqlite miniupnpc"
	case "$what" in
	client-qt5) echo "Arch is built with Qt 6 only" >&2; exit 1 ;;
	client-qt6) pkgs="$pkgs qt6-base ffmpeg webrtc-audio-processing-1 alsa-lib libpulse libva libx11 libglvnd" ;;
	esac
	# shellcheck disable=SC2086
	pacman -Syu --noconfirm --needed $pkgs
	;;
fedora)
	pkgs="gcc gcc-c++ make autoconf automake libtool pkgconf-pkg-config sqlite
	      pkgconfig(openssl) pkgconfig(zlib) pkgconfig(libevent) pkgconfig(sqlite3) pkgconfig(miniupnpc)"
	case "$what" in
	client-qt5) echo "Fedora is built with Qt 6 only" >&2; exit 1 ;;
	client-qt6)
		pkgs="$pkgs curl xz meson ninja-build pkgconfig(Qt6Widgets) pkgconfig(Qt6Sql) pkgconfig(Qt6Network)
		      pkgconfig(Qt6OpenGL) pkgconfig(Qt6OpenGLWidgets)
		      pkgconfig(libavcodec) pkgconfig(libavdevice) pkgconfig(libavformat)
		      pkgconfig(libavutil) pkgconfig(libswresample) pkgconfig(libswscale)
		      pkgconfig(alsa) pkgconfig(libpulse) pkgconfig(libva) pkgconfig(libva-drm)
		      pkgconfig(libva-x11) pkgconfig(egl) pkgconfig(gl) pkgconfig(x11)
		      pkgconfig(webrtc-audio-processing-1) pkgconfig(webrtc-audio-processing-2)" ;;
	esac
	# --skip-unavailable: Fedora carries webrtc-audio-processing 1.x or 2.x, configure takes either
	# shellcheck disable=SC2086
	dnf install -y --skip-unavailable $pkgs
	;;
*)
	echo "unsupported distribution $ID" >&2; exit 1 ;;
esac
