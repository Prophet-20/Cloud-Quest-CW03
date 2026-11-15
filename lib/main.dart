import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-cloud-quest-not-a-real-key',
      appId: '1:123456789:android:123456789abcdef',
      messagingSenderId: '123456789',
      projectId: 'demo-cloud-quest',
    ),
  );
  final host = const String.fromEnvironment('EMULATOR_HOST').isNotEmpty
      ? const String.fromEnvironment('EMULATOR_HOST')
      : Platform.isAndroid
      ? '10.0.2.2'
      : '127.0.0.1';
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  runApp(const CloudQuestApp());
}

// Local callable protocol transport avoids a stalled native Functions request
// observed on the installed Android preview image.
// Auth tokens are still verified by the real onCall Functions emulator.
Future<Map<String, dynamic>> callLocalFunction(
  String name,
  Map<String, dynamic> data,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseFunctionsException(
      code: 'unauthenticated',
      message: 'Sign in first.',
    );
  }
  final token = await user.getIdToken();
  final host = const String.fromEnvironment('EMULATOR_HOST').isNotEmpty
      ? const String.fromEnvironment('EMULATOR_HOST')
      : Platform.isAndroid
      ? '10.0.2.2'
      : '127.0.0.1';
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(
      Uri.parse('http://$host:5001/demo-cloud-quest/us-central1/$name'),
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode({'data': data}));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = jsonDecode(
      await response.transform(utf8.decoder).join(),
    ) as Map<String, dynamic>;
    if (body['error'] != null) {
      final error = body['error'] as Map<String, dynamic>;
      throw FirebaseFunctionsException(
        code: (error['status'] as String).toLowerCase().replaceAll('_', '-'),
        message: error['message'] as String? ?? 'Callable failed.',
      );
    }
    if (response.statusCode != 200 || body['result'] is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'Invalid callable response.',
      );
    }
    return Map<String, dynamic>.from(body['result'] as Map);
  } finally {
    client.close(force: true);
  }
}

class CloudQuestApp extends StatelessWidget {
  const CloudQuestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cloud Quest',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff245d50)),
      scaffoldBackgroundColor: const Color(0xfff5f5ef),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0),
    ),
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = auth.data;
        return user == null
            ? const SignInScreen()
            : QuestScreen(key: ValueKey(user.uid), user: user);
      },
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> authenticate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (email.text.trim().isEmpty || password.text.length < 6) {
      setState(
        () =>
            error = 'Enter an email and a password with at least 6 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (register) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error = e.code == 'network-request-failed'
              ? 'Cannot reach Authentication. Check the emulators and try again.'
              : 'Unable to sign in or create this account. Check your details and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(
                Icons.landscape_rounded,
                size: 64,
                color: Color(0xff245d50),
              ),
              const SizedBox(height: 16),
              Text(
                'Cloud Quest',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'One small challenge. One step forward.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const Text(
                'LOCAL EMULATOR · UNDERGRADUATE',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                register ? 'Create your learner account' : 'Welcome back',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('email'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('password'),
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: (_) {
                  if (!busy) authenticate();
                },
              ),
              const SizedBox(height: 16),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('authenticate'),
                onPressed: busy ? null : authenticate,
                child: Text(
                  busy
                      ? 'Please wait…'
                      : register
                      ? 'Create account'
                      : 'Sign in',
                ),
              ),
              TextButton(
                key: const Key('toggle-register'),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        register = !register;
                        error = null;
                      }),
                child: Text(
                  register
                      ? 'Already registered? Sign in'
                      : 'New here? Create account',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in to see your challenge, ask for a hint, and earn your first badge. Use a test account here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key, required this.user});
  final User user;
  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  final question = TextEditingController(text: 'Can you give me a hint?');
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> challenge;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> progress;
  bool coachBusy = false;
  bool rewardBusy = false;
  String? reply;
  String? coachError;
  String? rewardMessage;
  String failure = 'none';
  @override
  void initState() {
    super.initState();
    challenge = FirebaseFirestore.instance.doc('challenges/today').snapshots();
    progress = FirebaseFirestore.instance
        .doc('users/${widget.user.uid}/progress/today')
        .snapshots();
  }

  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  Future<void> askCoach() async {
    debugPrint('Coach: requesting read-only hint');
    FocusManager.instance.primaryFocus?.unfocus();
    final text = question.text.trim();
    if (text.isEmpty || text.length > 300) {
      setState(() => coachError = 'Enter a question of 1–300 characters.');
      return;
    }
    setState(() {
      coachBusy = true;
      coachError = null;
      reply = null;
    });
    try {
      final result = await callLocalFunction('askQuestCoach', {
        'question': text,
        if (failure != 'none') 'simulateFailure': failure,
      });
      if (mounted) setState(() => reply = result['reply'] as String);
    } on FirebaseFunctionsException {
      if (mounted) {
        setState(
          () => coachError = 'The coach is unavailable. Try again. Your progress has not changed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => coachError =
              'Could not load a hint. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => coachBusy = false);
      }
    }
  }

  Future<void> complete() async {
    setState(() {
      rewardBusy = true;
      rewardMessage = null;
    });
    try {
      final result = await callLocalFunction('completeToday', {
        'challengeId': 'today',
      });
      if (mounted) {
        setState(
          () => rewardMessage = result['alreadyCompleted'] == true
              ? 'Already completed. Your reward stays at 10 points.'
              : 'Quest complete! You earned 10 points and the First Quest badge.',
        );
      }
    } on FirebaseFunctionsException {
      if (mounted) {
        setState(
          () => rewardMessage = 'Could not confirm completion. Retry safely; rewards are awarded only once.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => rewardMessage =
              'Connection interrupted. Retry to check your reward.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => rewardBusy = false);
      }
    }
  }

  Widget panel(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Cloud Quest'),
      actions: [
        TextButton(
          key: const Key('sign-out'),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
            key: const Key('quest-list'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'TODAY’S EXPEDITION',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Hello, learner.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(widget.user.email ?? 'Signed-in learner'),
              const SizedBox(height: 20),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: challenge,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return panel(
                      const Text(
                        'Challenge unavailable. Check Firestore and try again.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!.data();
                  if (data == null) {
                    return panel(
                      const Text(
                        'No challenge yet. Run the local seed script.',
                      ),
                    );
                  }
                  return panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.explore_outlined,
                          color: Color(0xff245d50),
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['title'] as String,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(data['prompt'] as String),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: progress,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return panel(
                      const Text('Progress unavailable. Please reconnect.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!.data();
                  final done = data?['completed'] == true;
                  return panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data?['points'] ?? 0} points',
                          key: const Key('points'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          done
                              ? '★ First Quest badge earned'
                              : 'First Quest badge · ready to earn',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'After completing the activity, confirm it yourself. The coach cannot award points.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('complete'),
                          onPressed: rewardBusy ? null : complete,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            rewardBusy
                                ? 'Checking…'
                                : done
                                ? 'Check completion again'
                                : 'Complete quest',
                          ),
                        ),
                        if (rewardMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              rewardMessage!,
                              key: const Key('reward-result'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quest Coach',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text('Read-only · local mock, not a live AI model'),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('question'),
                      controller: question,
                      maxLength: 300,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ask for a hint',
                      ),
                    ),
                    FilledButton.tonal(
                      key: const Key('ask-coach'),
                      onPressed: coachBusy ? null : askCoach,
                      child: Text(coachBusy ? 'Reading quest…' : 'Get hint'),
                    ),
                    if (reply != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(reply!, key: const Key('coach-reply')),
                      ),
                    if (coachError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          coachError!,
                          key: const Key('coach-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const Divider(height: 32),
                    DropdownButtonFormField<String>(
                      key: const Key('failure-mode'),
                      initialValue: failure,
                      decoration: const InputDecoration(
                        labelText: 'Local verification',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'none',
                          child: Text('Normal response'),
                        ),
                        DropdownMenuItem(
                          value: 'tool',
                          child: Text('Simulate tool failure'),
                        ),
                        DropdownMenuItem(
                          value: 'model',
                          child: Text('Simulate model failure'),
                        ),
                      ],
                      onChanged: coachBusy
                          ? null
                          : (value) =>
                                setState(() => failure = value ?? 'none'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Local Firebase emulators · one challenge · one reward',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
