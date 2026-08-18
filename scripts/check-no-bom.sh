#!/bin/sh
# Fails if any Java/Dart source carries a UTF-8 BOM.
# A BOM on a .java file makes javac fail with "illegal character: '﻿'".
# See PLAN.md T0.7. Wire this into CI when CI exists.
set -e
cd "$(dirname "$0")/.."
found=0
for f in $(find JeevikaService/src Yapan/lib -name "*.java" -o -name "*.dart"); do
  if [ "$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
    echo "BOM: $f"
    found=1
  fi
done
if [ "$found" = "1" ]; then
  echo "FAIL: strip BOMs with: tail -c +4 <file> > tmp && mv tmp <file>"
  exit 1
fi
echo "no BOMs"
