#!/usr/bin/env bash
#
# Shared notification utility for Claude Code hooks.
# Usage: notify.sh <title> <message>
#

osascript -e "display notification \"$2\" with title \"$1\" sound name \"Glass\""
