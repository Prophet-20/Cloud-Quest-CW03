# Verification evidence

Local project: `demo-cloud-quest`. Backend behavior uses real Firebase emulators; coach wording is deterministic mock output. Test identities are disposable `example.test` accounts.

- [Backend result details](backend-verification.json): all eight groups passed, including actual rule denials and concurrent reward retries.
- [Actual Firestore challenge and reward records](firestore-records.json).
- [Backend console output](backend-verification.log).
- [Flutter analysis](flutter-analyze.txt).
- [Small-screen form check](small-screen-test.txt): 320×568 logical pixels.
- [Android integration log](android-integration.log): actual installed Flutter app and native Firebase plugins.

Verified Android target: `emulator-5554`, `sdk_gphone16k_arm64`, Android 37.1 preview image, 1344×2992 physical pixels. Screenshots are captured by Flutter integration tests from the running native app. The separate small-screen check exercises a 320×568 logical viewport.

## Android journey screenshots

1. [Signed out](01-signed-out.png)
2. [Signed in, challenge loaded](02-signed-in-challenge.png)
3. [Grounded coach hint](03-grounded-hint.png)
4. [Adversarial request, read-only response](04-adversarial-no-write.png)
5. [First reward](05-first-reward.png)
6. [Duplicate completion](06-duplicate-completion.png)
7. [Safe service error](07-safe-error.png)
8. [Sign-out gates private content](08-sign-out-gated.png)
9. [Sign-in retains prior progress](09-sign-in-progress-retained.png)
