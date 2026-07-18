#!/bin/sh
echo
echo "Hello ${1:-}${1:+ }World"\!
pid=$$
echo "  ls/fd: "$(command ls -q /proc/$pid/fd/ 2>&1)
echo "  ARGV0: '$0'"
echo "   ARGS: '$@'"
echo "   HOME: '$HOME'"
echo "  WORLD: '$WORLD'"
echo
