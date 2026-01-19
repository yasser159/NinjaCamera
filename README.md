# Zero Camera – iOS App

## Codex / AI Brief (One Screen)

Build a minimal iOS camera app that can capture photos with minimal on‑screen interaction, plus optional voice control, face-triggered shots, and time‑lapse. Keep all behavior compliant with iOS permissions and background execution limits. The UI should be sparse and fast to configure.

**Goals**
- Screen cover during capture sessions, with tap-to-reveal.
- Voice command: “Now” (photo).
- Time‑lapse intervals: 5/15/30/45/60 seconds.
- Haptic or optional audio confirmation.
- Clear opt‑in controls for each mode.

**Guardrails**
- Must require explicit camera/mic permissions.
- No bypassing system security or hidden capture tricks.
- Respect privacy/consent laws; app is for lawful use only.

**Tech Notes**
- Use AVFoundation for capture.
- Voice recognition should run locally where possible and fail gracefully.
- Background behavior must use iOS‑approved modes/tasks.

**Non‑Goals & App Store Safety**
- Not a covert surveillance tool; no hidden background recording.
- No recording while the app is not in foreground beyond iOS‑allowed modes.
- No remote/stealth triggers; user action must be explicit.
- Avoid language or UI that suggests spying or secret recording.

---

## Overview

Zero Camera is an iOS camera application designed to capture photos with minimal on-screen interaction. The app supports a black screen cover and voice-activated controls, allowing hands-free use in situations where visible phone interaction is undesirable.

**Important:** This app is intended for lawful, ethical use only. Users are responsible for complying with local laws regarding photography, audio input, and consent.

---

## Core Features

### Screen-Off Capture

- Capture photos while the device screen is off.
- No visible camera preview or shutter animation.
- Designed to reduce visual cues during capture.

---

## Voice-Activated Mode

Hands-free camera control using simple voice commands.

**Supported commands:**
- “Now” → Capture a photo

**Notes:**
- Voice recognition runs locally where possible.
- Sensitivity and activation distance should be configurable.
- Optional audible or haptic confirmation can be enabled/disabled.

---

## Time-Lapse Mode

Automatically capture photos at fixed intervals.

**Interval options:**
- 5 seconds
- 15 seconds
- 30 seconds
- 45 seconds
- 60 seconds

**Activation methods:**
- Via UI controls

**Behavior:**
- Photos continue to be captured while the screen is covered.
- Time-lapse session can be paused or stopped manually.

---

## User Interface

- Minimal UI designed for quick setup.
- Clear toggles for:
  - Voice activation
  - Screen cover
  - Time-lapse interval selection
- Status indicators (subtle vibration or optional sound).

---

## Privacy & Legal Notice

- This app does not bypass iOS security or system permissions.
- Camera and microphone access require explicit user approval.
- Users must respect privacy laws and obtain consent where required.
- The developer assumes no liability for misuse.

---

## Technical Notes (Optional for README)

- Uses AVFoundation for camera and audio capture.
- Background execution limited to iOS-approved modes.
- Screen-off behavior relies on system-compliant background tasks.
- Voice recognition should degrade gracefully when unavailable.
