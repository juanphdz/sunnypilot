#!/usr/bin/env bash
# Starts a virtual display + VNC server so the UI/simulator can render without GPU passthrough
# or a host X server's (e.g. XQuartz) indirect GLX, which doesn't support the OpenGL core profile
# raylib/GLFW requests. Source this or run it before launch_openpilot.sh / run_bridge.py:
#
#   source tools/sim/start_xvfb_vnc.sh
#   ./tools/sim/launch_openpilot.sh
#
# Then, on the host, connect a VNC viewer to localhost:5900 (container must be started with
# -p 5900:5900). On macOS: open vnc://127.0.0.1:5900

set -e

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1

if ! pgrep -f "Xvfb :99" > /dev/null; then
  Xvfb :99 -screen 0 1920x1080x24 &
  sleep 1
fi

if ! pgrep -f "x11vnc.*:99" > /dev/null; then
  x11vnc -display :99 -forever -nopw -listen 0.0.0.0 -xkb -quiet &
fi

echo "DISPLAY=$DISPLAY, VNC listening on :5900 (container must publish -p 5900:5900)"
