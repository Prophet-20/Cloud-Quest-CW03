# Cloud Quest

**Undergraduate pathway · Tested on an Android 37.1 emulator (`emulator-5554`)**

Cloud Quest lets a learner sign in, read one daily challenge, ask for a hint, and complete the activity for **10 points and the First Quest badge**. Repeating completion returns the same reward.

## Setup and run

Tested with Flutter 3.47.3 and Dart 3.13.3. You’ll also need Node.js 22 with npm, the Firebase CLI, Java 21+, and a running Android emulator. The standalone Firebase CLI used in testing bundled Node 20; the Functions project declares Node 22.

From the project folder:

```sh
flutter pub get
npm ci --prefix functions
firebase emulators:start --project demo-cloud-quest --only auth,firestore,functions
```

Leave that terminal running. In a second terminal:

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed.cjs
flutter devices
flutter run -d emulator-5554
```

Create a test account, read the challenge, and select **Get hint**. After doing the activity, select **Complete quest**, then **Check completion again** to verify the reward stays at 10 points. The **Local verification** menu simulates tool or model failures.

This build uses local Firebase emulators (`demo-cloud-quest`) and a labeled deterministic coach mock. It is not a production deployment or a connection to the course Firebase project. Android reaches the computer through `10.0.2.2`; debug HTTP access is limited to that address and localhost. Emulator data resets on restart unless exported. iOS scaffolding is included but untested.

## Data and safety boundaries

| Component | What it does |
|---|---|
| Firebase Authentication | Handles sign-up, sign-in, and sign-out. Signing out removes private progress and coach content from the screen. |
| `challenges/today` | Stores the shared challenge’s `title` and `prompt`. Signed-in learners can read it. |
| `users/{uid}/progress/today` | Stores `completed`, `points`, `badgeId`, and `completedAt`. Rules allow only the owner to read it and deny all client writes. |
| `readMyQuestState` | The Genkit flow calls this read-only tool before each hint. It reads the challenge and caller’s progress using the verified Auth UID, never a client-supplied UID. It cannot write data or grant rewards. Tool failure returns an error, not an invented hint. |
| `completeToday` | A separate callable verifies identity and the challenge ID, then uses a transaction to award fixed points and one badge exactly once. Only the learner’s completion button requests the reward. |

The Android native Functions client stalled on the tested preview image, so the app uses Firebase’s [callable HTTP protocol](https://firebase.google.com/docs/functions/callable-reference). Requests carry the learner’s Auth token, which the Functions emulator verifies. Coach wording is mocked; the authentication, Firestore reads, access rules, and reward transactions are real emulator operations.

## Evidence and results

Checks recorded on November 13, 2026: the Android journey passed, all eight backend verification groups passed, the form passed a 320×568 screen check, and Flutter analysis reported no issues.

| Required check | Result and evidence |
|---|---|
| Signed out | Challenge, coach, and completion are gated: [initial screen](evidence/01-signed-out.png), [after sign-out](evidence/08-sign-out-gated.png). |
| Grounded hint | The response uses the current challenge and progress: [coach hint](evidence/03-grounded-hint.png). |
| Adversarial request | Asking for 999 points returns a refusal; progress stays unchanged: [response](evidence/04-adversarial-no-write.png), [before/after verification](evidence/backend-verification.json). |
| One reward | Completion awards 10 points and First Quest: [reward screen](evidence/05-first-reward.png), [Firestore records](evidence/firestore-records.json). |
| Safe retry | Five concurrent requests and a retry produce one award with an unchanged timestamp: [retry screen](evidence/06-duplicate-completion.png), [test results](evidence/backend-verification.json). |

The [evidence index](evidence/README.md) includes all nine screenshots and logs, including service-error handling, retained progress after sign-in, and denied client writes and cross-user reads.

To repeat verification with the emulators running:

```sh
flutter analyze
flutter test test/small_screen_test.dart
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/verify.cjs
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/quest_flow_test.dart -d emulator-5554
```

The [132-word reflection](REFLECTION.md) covers the tool, a safety check and its result, and a next step. Push notifications are optional and are not included.
