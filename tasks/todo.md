# NinjaCamera Implementation Todo

- [x] Audit current time-lapse, lifecycle, and audio-session behavior.
- [x] Add bounded diagnostics logging and shared event models.
- [x] Add Bugs159 reporting service and in-app report flow.
- [x] Split camera/session logic into core services.
- [x] Add 2-second default interval with persistence.
- [x] Add PiP-first background coordination and retry handling.
- [x] Add Diagnostics screen and bug report UI.
- [x] Update README with background and reporting behavior.
- [x] Add/expand unit tests for diagnostics and bug payloads.
- [x] Build and run the unit test suite.

## Kill List

- Rejected `BGAppRefreshTask` for 2-second capture cadence.
- Rejected audio playback keep-alive tricks that could stomp user media.
- Rejected stopping the capture session immediately on app resign-active.
- Rejected pretending lock-screen capture is guaranteed forever on iOS.

## Review

- `xcodebuild -scheme NinjaCamera -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeded.
- `xcodebuild -scheme NinjaCamera -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NinjaCameraTests test` succeeded.
- UI tests were not exercised as part of verification.
