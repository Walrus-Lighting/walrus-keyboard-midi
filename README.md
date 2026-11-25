<p align="center">
  <img src="Resources/AppIcon-1024.png" width="128" alt="Walrus Keyboard MIDI icon">
</p>

# Walrus Keyboard MIDI

A Mac app that turns a **Fnatic miniSTREAK** keyboard into a **Lightkey** button board. Click keys in a picture of
the keyboard, pick a type and a colour, and the keyboard's LEDs and a virtual MIDI controller do the rest.
Open source, so change it however you like.

> **Made for one keyboard.** This app was written for the Fnatic miniSTREAK and only works with it. Other
> keyboards will not be detected, and their lighting protocols differ. If you want to use a different board, you
> will need to adapt the code yourself, mainly `Sources/HIDLink.swift` (finding the device and sending LED data) and
> `Sources/Keys.swift` (the key list and LED numbers). Pull requests adding other keyboards are welcome.

## Features

- **Key types:** Off, Static, Toggle, Flash, Tap, Beat, ×2, ÷2.
  - **Toggle:** press and the key flashes in its colour, press again to stop. Sends a MIDI note.
  - **Flash:** shows its colour, turns white while held. Note on at press, note off at release.
  - **Tap:** tap tempo. Four taps set the BPM.
  - **Beat:** pulses in its colour on every beat.
  - **×2 / ÷2:** double or halve the tempo.
- **Two-way MIDI:** shows up as one virtual controller, **Walrus Keyboard MIDI**, so Lightkey sends feedback and the
  keys follow what you click with the mouse.
- **Tempo source:** sends a MIDI clock so Lightkey's beat follows.
- Only the Fnatic keyboard is affected. Your Mac's own keyboard is never touched.

## Download

Grab the zip from the [latest release](../../releases/latest), unzip it, and move the app to Applications.

The app is not notarised, so the first time, **right-click it and choose Open**. It is built for Apple silicon
(arm64) on macOS 13 or newer. On an Intel Mac, build it yourself (see below).

## Set up

1. Close any other software that controls the keyboard's lights (such as the Fnatic app).
2. Open Walrus Keyboard MIDI. In System Settings, Privacy & Security, give it **Accessibility** and
   **Input Monitoring**.
3. In Lightkey, open Settings, External Control, and tick **Walrus Keyboard MIDI** for both Input and Output.
4. To map a cue, right-click it, choose External Control, Replace Trigger, then press the key. The app's
   "Send test note" button works too.
5. For tempo sync, set Lightkey's beat panel to External, Walrus Keyboard MIDI.

Settings are saved in `~/Library/Application Support/WalrusKeyboardMIDI/settings.json`.

## Build it yourself

You only need the Xcode Command Line Tools (`xcode-select --install`), not Xcode.

```bash
./build.sh
```

That produces `Walrus Keyboard MIDI.app`. To make macOS remember the permissions across rebuilds, create a
code-signing certificate in Keychain Access and build with `SIGN_IDENTITY="Your Certificate Name" ./build.sh`.
Without one, the app is signed ad hoc and macOS asks for permissions again after every build.

## Customise it

| File | What to change |
|---|---|
| `Sources/Keys.swift` | The key list, LED numbers, picture layout, note assignment |
| `Sources/Settings.swift` | Key types, defaults, settings format |
| `Sources/Engine.swift` | Key capture, lighting, tempo, Lightkey feedback |
| `Sources/HIDLink.swift` | Talking to the keyboard's lights |
| `Sources/MIDIPort.swift` | The virtual MIDI device |
| `Sources/ContentView.swift`, `App.swift` | The window and menu bar item |

[docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) explains the parts that aren't obvious.

## Contributing

Issues and pull requests are welcome. Please keep the app free of third-party dependencies, so it keeps building
with just the Command Line Tools.

## Licence

MIT for the code. The Walrus Lighting name, logo and icon are not licensed for reuse. See [LICENSE](LICENSE).
