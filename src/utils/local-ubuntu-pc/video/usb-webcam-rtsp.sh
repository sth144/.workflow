#!/usr/bin/env bash
set -euo pipefail

VIDEO_DEVICE="${VIDEO_DEVICE:-/dev/video0}"
RTSP_PORT="${RTSP_PORT:-8554}"
RTSP_PATH="${RTSP_PATH:-usbcam}"
VIDEO_BITRATE="${VIDEO_BITRATE:-1200}"

if [ ! -e "$VIDEO_DEVICE" ]; then
	echo "Video device not found: $VIDEO_DEVICE" >&2
	exit 1
fi

exec cvlc "v4l2://$VIDEO_DEVICE" \
	--sout "#transcode{vcodec=h264,vb=${VIDEO_BITRATE},acodec=none}:rtp{sdp=rtsp://:${RTSP_PORT}/${RTSP_PATH}}" \
	--no-sout-all \
	--sout-keep
