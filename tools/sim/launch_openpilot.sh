#!/usr/bin/env bash

export PASSIVE="0"
export NOBOARD="1"
export SIMULATION="1"
export SKIP_FW_QUERY="1"
export FINGERPRINT="HONDA_CIVIC_2022"

export BLOCK="${BLOCK},camerad,loggerd,encoderd,micd,logmessaged,manage_athenad,manage_sunnylinkd,hardwared,mapd_manager,mapd,deleter,statsd,models_manager,locationd_llk,sunnylink_registration_manager,statsd_sp,backup_manager,soundd"
if [[ "$CI" ]]; then
  # TODO: offscreen UI should work
  export BLOCK="${BLOCK},ui"
fi

mkdir -p ~/.comma/media/0/osm

export DISPLAY="${DISPLAY:-:99}"
export LIBGL_ALWAYS_SOFTWARE=1

if ! pgrep -f "Xvfb :99" > /dev/null; then
  Xvfb :99 -screen 0 1920x1080x24 &
  sleep 1
fi

if ! pgrep -f "x11vnc.*:99" > /dev/null; then
  x11vnc -display :99 -forever -nopw -listen 0.0.0.0 -xkb -quiet &
fi

python3 -c "from openpilot.selfdrive.test.helpers import set_params_enabled; set_params_enabled()"

SCRIPT_DIR=$(dirname "$0")
OPENPILOT_DIR=$SCRIPT_DIR/../../

export PYTHONPATH="$OPENPILOT_DIR:$PYTHONPATH"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd $OPENPILOT_DIR/system/manager && exec ./manager.py
