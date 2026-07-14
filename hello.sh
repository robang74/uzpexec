#!/bin/sh
echo
echo "Hello ${1:-}${1:+ }World"\!
echo "   lsfd: "$(command ls -q /proc/$$/fd/)
echo "  ARGV0: '$0'"
echo "   ARGS: '$@'"
echo "   HOME: '$HOME'"
echo "  WORLD: '$WORLD'"
echo
