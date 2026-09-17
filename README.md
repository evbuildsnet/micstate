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
scripts/build.sh      # build/MicState.app, ad-hoc signed
scripts/install.sh    # build, copy to /Applications, launch
```

Requires Xcode command line tools. First launch during a meeting asks for microphone access once.
