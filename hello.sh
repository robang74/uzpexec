#!/bin/sh
echo
echo "Hello ${1:-}${1:+ }World"\!
echo "  ls/fd:" $(command ls -q /proc/self/fd/ 2>&1)
echo "  p/pid: $$ ($PPID)"
echo "  ARGV0: '$0'"
echo "   ARGS: '$@'"
echo "   HOME: '$HOME'"
echo "  WORLD: '$WORLD'"
echo
