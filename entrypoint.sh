#!/bin/bash
# Initialize conda for this shell
source /opt/conda/etc/profile.d/conda.sh
conda activate SurfDock

# Run the python script and pass all arguments ($@)
exec python /app/SurfDock/SurfDock/bash_scripts/test_scripts/run_dock_easydock.py "$@"