# MicState

Menu bar microphone switch for macOS. One icon, always visible, as narrow as the menu bar allows.

- Dimmed mic: nobody is recording.
- Red mic: a meeting has the mic and you are live.
- Slashed mic: a meeting has the mic and you are muted at the hardware level.

Left click toggles. Right click opens the menu with Settings and Quit.

## How it mutes

MicState flips the input mute flag on the default input device through CoreAudio. Meeting apps keep their own
"unmuted" state and simply receive silence. Keep the meeting app unmuted and drive everything from MicState.

## AirPods button

On macOS 14+ the AirPods press-to-mute gesture is delivered to the process that registers the input-mute handler
and holds an input stream. MicState does that only while another app is recording. macOS delivers the gesture to
nobody when two eligible processes exist, so apps that handle the button themselves (native Teams by default) are
listed in Settings and MicState steps aside while they record.

## Build

```
scripts/build.sh      # build/MicState.app, signed with a local identity when available
scripts/install.sh    # build, copy to /Applications, launch
```

Requires Xcode command line tools. First launch during a meeting asks for microphone access once.

The build prefers a Developer ID Application certificate, then Apple Development, and falls back to
ad-hoc signing. Keep the same signing identity to preserve microphone permission across rebuilds.

## Feedback

Settings controls MicState's sound and one-second notice below the notch. AirPods gestures can also
show macOS's own "Microphone On/Off" banner. Apple provides no documented API to suppress that
system banner; the app's feedback settings only affect MicState's own feedback.
Apple describes the system banner in its [AirPods mute-control overview](https://developer.apple.com/videos/play/wwdc2023/10233/).

## Implementation notes

The AirPods mute handler must be registered before any other CoreAudio or audio-engine access.
It stays registered for the process lifetime; the input stream runs only while another non-ignored
app records and no configured native meeting app owns the gesture. A one-second process rescan
detects when a meeting ends even if macOS sends no activity event while MicState's stream is open.
Captured samples are discarded.

Runtime diagnostics are written to `~/Library/Logs/MicState.log`.
