#!/bin/sh
# Run from any working directory; forward project and FFmpeg options unchanged.
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "${PYTHON:-python3}" -B "$studio_dir/tools/launch_studio.py" "$@"
