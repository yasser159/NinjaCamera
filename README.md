# Discreet Camera – iOS App

## Codex / AI Brief (One Screen)

Build a minimal iOS camera app that can capture photos or video with minimal on‑screen interaction, plus optional voice control and time‑lapse. Keep all behavior compliant with iOS permissions and background execution limits. The UI should be sparse and fast to configure.

**Goals**
- Screen‑off photo capture (no preview, no shutter animation).
- Voice commands: “Now” (photo), “Video” (start), “Stop” (stop).
- Time‑lapse intervals: 15/30/45/60 seconds; works with screen off.
- Haptic or optional audio confirmation.
- Clear opt‑in toggles for each mode.

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

Discreet Camera is an iOS camera application designed to capture photos or videos with minimal on-screen interaction. The app supports screen-off capture and voice-activated controls, allowing hands-free use in situations where visible phone interaction is undesirable.

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
- “Video” → Start video recording
- “Stop” → Stop video recording

**Notes:**
- Voice recognition runs locally where possible.
- Sensitivity and activation distance should be configurable.
- Optional audible or haptic confirmation can be enabled/disabled.

---

## Time-Lapse Mode

Automatically capture photos at fixed intervals.

**Interval options:**
- 15 seconds
- 30 seconds
- 45 seconds
- 60 seconds

**Activation methods:**
- Via UI controls
- Via voice command

**Behavior:**
- Photos continue to be captured while the screen is off.
- Time-lapse session can be paused or stopped manually or by voice.

---

## User Interface

- Minimal UI designed for quick setup.
- Clear toggles for:
  - Voice activation
  - Screen-off capture
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
