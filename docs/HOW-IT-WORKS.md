# How it works

## Keyboard lighting

The Fnatic USB ID is `2F0E:0103` (`0102` is also accepted). The lighting channel is the vendor-defined HID interface
(usage page `0xFF00`, 64-byte output reports). The other interface is the normal keyboard.

Requests are sent in 57-byte chunks: `[command, total length (3 bytes little-endian), offset (3 bytes), 57 data bytes]`.
A frame is `[0x0F, 0x03]` followed by 106 LEDs of RGB, and `[0x07]` is a keepalive. The loop runs every 40 ms (a full
frame takes about 6 ms). LED numbers come from the OpenRGB map. Other software that drives the lights must be closed.
Without keepalives the keyboard returns to its own lighting after a few seconds.

## Key capture

A session event tap sees every key press before any app. It only acts on events whose `keyboardType` equals the
Fnatic's (40 on the author's board; a Mac's built-in keyboard reports 88). The "Detect" button re-learns it.

Matching keys send MIDI and can be swallowed (only while Lightkey is in front, always, or never) so Lightkey does not
also receive the typed character. Cmd, Ctrl and Option combinations always pass through. Modifier keys cannot be
Toggle, Flash, Tap, ×2 or ÷2.

A key remapped inside the keyboard's own software looks like the key it was remapped to. The app cannot tell them
apart.

## Why a virtual MIDI device and not the IAC Driver

Lightkey treats an input and an output with the same name as one controller and sends feedback to that pair. One IAC
bus for both directions makes a MIDI loop, and Lightkey then disables feedback for it. Two separate buses break the
pairing. A virtual device with matching names, created by the app, avoids both.

Lightkey stores bindings per device, so renaming the device means re-mapping every cue.

## Notes

Keys 1-9 are notes 36-44 (Lightkey shows 36 as C1). Every other non-modifier key takes the next free note from 45
upward, then 0-35. Notes are stored in settings, so they stay stable.

## Tempo

The clock is a high-priority timer sending MIDI clock (`0xF8`, 24 pulses per beat). Every BPM change also sends MIDI
Stop then Start. In testing, Lightkey drops straight to a lower tempo with this; without it, it counts down gradually.
Upward jumps are slow either way. The range is 10-300 BPM. A BPM change also moves the beat to "now", and Beat keys
count from the same moment.

## Known issues

- Lightkey's BPM number can lag for many seconds, especially after upward jumps, until its window is redrawn. The
  clock the app sends was measured as correct.
- If another macOS user is running Lightkey, it may compete for the MIDI ports.

## Ideas

Dim idle keys, global brightness, beat accent on the first beat, beat re-sync and nudge keys, Ableton Link,
layers or pages, blackout and level keys, "learn this key", saved profiles, BPM in the menu bar, launch at login,
a MIDI monitor panel.
