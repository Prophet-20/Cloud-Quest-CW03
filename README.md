# Cloud Quest

**Pathway:** Undergraduate  
**Tested platform:** Android emulator (`emulator-5554`, Android 37.1)

Cloud Quest gives a learner one daily challenge, a coach hint, and a small reward for completing the activity. After signing in, the learner can read the challenge and their own progress. Completing it earns **10 points and the First Quest badge**. Pressing the completion button again returns the same reward instead of adding more points.

This project uses its own starter code, following Professor Henry’s November 15 clarification that new starter code would not be provided.

## Getting it running

I tested the app with Flutter 3.47.3 and Dart 3.13.3. You’ll also need an Android emulator, Node.js 22 with npm, the Firebase CLI, and Java 21 or newer. The standalone Firebase CLI used for these checks bundled Node 20; the Functions project declares Node 22. The npm version of the Firebase CLI can use your installed Node runtime.

From the project folder, install the dependencies and start Firebase:

```sh
flutter pub get
npm ci --prefix functions
firebase emulators:start --project demo-cloud-quest --only auth,firestore,functions
```

Leave that terminal running. In a second terminal, add the challenge and launch the app:

```sh
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/seed.cjs
flutter devices
flutter run -d emulator-5554
```

Create a test account in the app, read the challenge, and select **Get hint**. When you’ve finished the activity, select **Complete quest**. You can then select **Check completion again** to see that the reward stays at 10 points. The **Local verification** menu lets you try a tool or model failure and check the error message.

The Android emulator connects to the computer at `10.0.2.2`. The debug network configuration allows HTTP only for that address and localhost. These are local test accounts; they are not production accounts. Restarting the Firebase emulators clears their data unless you export it. iOS scaffolding is included, but only Android was tested.

## How the pieces fit together

Firebase Authentication handles sign-up, sign-in, and sign-out. The app watches the authentication state, so signing out removes the challenge, private progress, and coach response from the screen.

Firestore holds two kinds of data:

| Document | What it stores |
|---|---|
| `challenges/today` | The shared challenge’s `title` and `prompt` |
| `users/{uid}/progress/today` | `completed`, `points`, `badgeId`, and `completedAt` |

Signed-in learners can read the challenge and their own progress. Firestore rules deny direct client writes and reads of another learner’s progress.

The Quest Coach uses **`readMyQuestState`**, a read-only Genkit tool. Before each response, the server calls this tool to read the challenge and the signed-in learner’s progress. The UID comes from verified Firebase Authentication, not a UID supplied in the question or request. The tool cannot write to Firestore or call the reward function. If the tool fails, the coach returns an error instead of making up a hint.

The local version uses a deterministic coach mock with real Firebase emulator data, as shown in the app and evidence.

Rewards go through a separate callable function, **`completeToday`**. It verifies the caller, checks the challenge ID, and uses a Firestore transaction to create the reward only if it does not already exist. The server fixes the award at 10 points and one badge. Only the learner’s completion button requests that award; the coach cannot do it.

On the tested Android preview image, the native Functions client stalled before reaching the backend. The local app therefore uses Firebase’s [documented callable HTTP protocol](https://firebase.google.com/docs/functions/callable-reference). It sends the signed-in learner’s Auth token, and the real Functions emulator verifies that token before handling the request.

## Evidence and results

The Android learner journey passed, all eight backend verification groups passed, and the form passed a separate 320×568 small-screen check. Flutter analysis reported no issues. These results were recorded on November 13, 2026.

| Required check | Observed result | Evidence |
|---|---|---|
| Signed-out view | Sign-in is available; challenge, coach, and completion are gated. | [Signed out](evidence/01-signed-out.png), [after sign-out](evidence/08-sign-out-gated.png) |
| Grounded coach hint | The response refers to the current challenge and learner’s progress. | [Hint](evidence/03-grounded-hint.png) |
| Adversarial coach request | Asking for 999 points returns a refusal; no progress document is created. | [Response](evidence/04-adversarial-no-write.png), [before/after check](evidence/backend-verification.json) |
| First completion | The learner receives 10 points and the First Quest badge. | [Reward](evidence/05-first-reward.png), [Firestore records](evidence/firestore-records.json) |
| Repeated completion | Points remain at 10 and the original completion timestamp stays unchanged. | [Retry](evidence/06-duplicate-completion.png), [concurrent-call results](evidence/backend-verification.json) |

### Signed-out view
![Signed-out view](evidence/01-signed-out.png)

### Grounded hint
![Grounded coach hint](evidence/03-grounded-hint.png)

### Adversarial request
![Adversarial request refused](evidence/04-adversarial-no-write.png)

### First reward and retry
![First reward](evidence/05-first-reward.png)
![Retry keeps the same reward](evidence/06-duplicate-completion.png)

The [evidence folder](evidence/README.md) also includes sign-in, service-error, and retained-progress screenshots, along with logs and the actual Firestore records. The backend checks confirm that client reward writes and cross-user reads are denied. Five concurrent completion requests followed by a retry still produce just one reward.

To repeat the checks while the emulators are running:

```sh
flutter analyze
flutter test test/small_screen_test.dart
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node scripts/verify.cjs
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/quest_flow_test.dart -d emulator-5554
```

See [the reflection](REFLECTION.md) for the 100–150 word response. Push notifications and other optional features are not included.
