#!/bin/bash
set -eu
cd "$(dirname $0)"
. env.sh
mkdir -p "$PAPP_DATA_DIR"
exec ./prioritize-app-server
