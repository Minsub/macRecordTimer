#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cp "$root/Scripts/TimerClockCheck.swift.template" "$tmpdir/main.swift"
swiftc "$root/Sources/RecordTimer/TimerClock.swift" "$tmpdir/main.swift" -o "$tmpdir/timer-clock-check"
"$tmpdir/timer-clock-check"
