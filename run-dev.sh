#!/bin/bash
set -eu
cd "$(dirname $0)"
. env.sh
exec ./server/prioritize-app-server
