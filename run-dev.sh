#!/bin/bash
set -eu
cd "$(dirname $0)"
. env.sh
exec ./prioritize-app-server
