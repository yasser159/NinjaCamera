# Zero Camera

A minimal iOS camera that takes photos with as little on-screen interaction as possible: cover the screen, say "Now", or let a time-lapse run.

Built with Swift and AVFoundation. Voice recognition runs on-device where available.

## Features

**Screen cover**
Black out the display during a capture session; tap to reveal the controls again. No preview, no shutter animation.

**Voice capture**
Say "Now" to take a photo. Optional haptic or audible confirmation.

**Time-lapse**
Capture at a fixed interval: 5, 15, 30, 45 or 60 seconds. Pause or stop at any time; capture continues while the screen is covered.

**Sparse UI**
One screen with clear toggles for voice activation, screen cover and interval. Every mode is opt-in.

## Privacy and intended use

- Camera and microphone access require explicit iOS permission prompts.
- Nothing runs outside iOS-approved foreground and background modes. There is no hidden or remote capture.
- The app is for lawful use. You are responsible for local laws on photography and consent.

## Building

Open the Xcode project, select a device (the camera does not work in the Simulator) and run.

## License

MIT
