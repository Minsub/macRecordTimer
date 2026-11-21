# RecordTimer

A small macOS menu bar app that displays elapsed time while the built-in macOS screen recorder is recording.

## Build and run

Requires macOS 13 or later and Swift 5.9 or later.

```sh
./make-app.sh
open RecordTimer.app
```

The app asks `lsof` for open files held by `replayd` and starts only when it finds an open `.mov` under the native Screenshot recording container. This avoids treating the screen selection UI as an active recording and ignores unrelated MOV files. Detection runs off the UI thread; the display clock uses the main run loop's common mode and continues independently of process polling. The menu bar uses a clock icon and only adds elapsed digits while recording.

macOS does not provide a public notification API for when the built-in Screenshot app starts recording, so this process check relies on current macOS implementation details. If Apple changes the executable or its behavior, the detector may need an update. It does not scan recording folders or infer status from old MOV files.

While recording, the app can show a large floating timer. Enable it from the menu bar menu, drag it to reposition it, and use the size slider to adjust its text. The chosen position and options are saved. Set the emphasis threshold in minutes and seconds (default: 2 minutes). Choose red or high-contrast red/yellow blinking once that time is reached. Emphasis applies only to the floating on-screen timer; the menu bar timer stays in its normal style.

Run `./verify-timer-clock.sh` to verify elapsed-time progression and blink threshold changes without starting a screen recording.
