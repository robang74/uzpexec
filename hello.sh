#!/bin/sh
echo "Hello ${1:-}${1:+ }World"\!
echo "lsfd: "$(command ls -q /proc/$$/fd/)
echo "args: '$@'"
echo "HOME: '$HOME'"
echo "WORLD: '$WORLD'"
exit $?
