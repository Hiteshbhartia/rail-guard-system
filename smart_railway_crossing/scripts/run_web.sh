#!/usr/bin/env bash
# Start the Flask web simulator for the Smart Railway Crossing controller.
set -e

cd "$(dirname "$0")/.."

if ! python3 -c "import flask" 2>/dev/null; then
    echo "Flask not found. Installing from requirements.txt ..."
    python3 -m pip install -r requirements.txt
fi

echo "Starting web simulator on http://127.0.0.1:5000"
python3 web/app.py
