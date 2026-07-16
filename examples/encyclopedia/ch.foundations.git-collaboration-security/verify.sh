#!/bin/zsh -f
set -eu

SCRIPT_DIR=${0:A:h}
exec /usr/bin/ruby --disable-gems "$SCRIPT_DIR/verify.rb"
