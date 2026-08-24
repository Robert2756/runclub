import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'signup_page.dart';
import 'main_page.dart';
import 'theme/appearance.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'onboarding_page.dart';
import 'checkEmailPage.dart';
import 'package:app_links/app_links.dart';
import 'reset_password_page.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
final supabase = Supabase.instance.client;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

// authentification changed -> propagate to listeners
class SupabaseAuthListenable extends ChangeNotifier {
  bool ready = false;

  SupabaseAuthListenable() {
    supabase.auth.onAuthStateChange.listen((data) {
      debugPrint(
        'AUTH EVENT: ${data.event}, session: ${data.session != null}',
      );
      // Password recovery:
      // Supabase has created a recovery session.
      // Send the user to the password reset page.
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('NAV: password recovery → /reset-password');
        router.go('/reset-password');
        return;
      }
      ready = true; // we know the real auth state now
      // notify GoRouter so its redirect() runs again.
      notifyListeners();
    }, onError: (error, stackTrace) {
      debugPrint('AUTH STREAM ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
    });
  }
  void markReadyFromInitialize() {
    if (ready) return;
    ready = true;
    notifyListeners();
  }
}
final authListenable = SupabaseAuthListenable();



// routing
final GoRouter router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  refreshListenable: authListenable,
  redirect: (context, state) {
    if (authListenable.ready == false) {
      return null; // don't decide anything until we know the real auth state
    }
    final user = supabase.auth.currentUser;

    final location = state.matchedLocation;
    final loggingIn = location == '/signin' || location == '/signup';
    final checkingEmail = location == '/check-email';
    final resettingPassword = location == '/reset-password';

    debugPrint('');
    debugPrint('========== GO ROUTER REDIRECT ==========');
    debugPrint('Requested location: ${state.uri}');
    debugPrint('Matched location: $location');

    debugPrint('--- Supabase session ---');
    debugPrint('currentUser: ${user?.id}');
    debugPrint('email: ${user?.email}');
    debugPrint('emailConfirmedAt: ${user?.emailConfirmedAt}');
    debugPrint('session exists: ${supabase.auth.currentSession != null}');
    debugPrint(
      'access token exists: ${supabase.auth.currentSession?.accessToken != null}',
    );

    debugPrint('--- Route flags ---');
    debugPrint('loggingIn: $loggingIn');
    debugPrint('checkingEmail: $checkingEmail');
    debugPrint('resettingPassword: $resettingPassword');

    String? result;

    if (user == null) {
      result = (loggingIn || checkingEmail) ? null : '/signin';
    } else if (user.emailConfirmedAt == null) {
      result = (checkingEmail || loggingIn) ? null : '/check-email';   // ← add loggingIn here
    } else if (loggingIn || checkingEmail) {
      result = '/';
    } else if (resettingPassword) {
      result = null;
    } else {
      result = null;
    }

    debugPrint('REDIRECT RESULT: ${result ?? "STAY"}');
    debugPrint('========================================');
    debugPrint('');

    return result;
  },
  routes: [
    GoRoute(path: '/signin', builder: (_, __) => const SignInPage()),
    // GoRoute(
    //   path: '/check-email',
    //   builder: (_, __) => CheckEmailPage(email: supabase.auth.currentUser?.email ?? ''),
    // ),
    GoRoute(
      path: '/check-email',
      builder: (_, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return CheckEmailPage(email: email);
      },
    ),
    GoRoute(path: '/reset-password', builder: (_, __) => ResetPasswordPage(onRecoveryFinished: () => router.go('/'))),
    GoRoute(path: '/signup', builder: (_, __) => const SignUpPage()),
    GoRoute(path: '/', builder: (_, __) => authListenable.ready ? const ProfileGate() : const SplashPage(),), // your existing widget, unchanged
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  debugPrint("APP STARTED");

  await Supabase.initialize(
    url: 'https://wczdhrcvwlghrkjmskaa.supabase.co', 
    anonKey: 'sb_publishable_4M-s15nTEGZ7IflPJaRYgA_v2WvjakI',
    debug: true,
    authOptions: const FlutterAuthClientOptions(
    detectSessionInUri: false,
  ),);
  authListenable.markReadyFromInitialize();
  final appLinks = AppLinks();

  // Handle the link that launched the app (cold start) — was missing before.
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    debugPrint("Initial deep link: $initialUri");
    await _handleDeepLink(initialUri);
  }

  // deep link nadler picks up deep link and establishes a new session that is detected by the auth state listener on top
  appLinks.uriLinkStream.listen((uri) async {
    debugPrint("Deep link arrived: $uri");
    await _handleDeepLink(uri);
  });

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('de_DE', null);
  runApp(const MyApp());
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

Future<void> _handleDeepLink(Uri uri) async {
  if (uri.scheme != 'com.enduvo.app' ||
      uri.host != 'login-callback') {
    return;
  }

  // 1. PKCE flow: ?code=...
  final code = uri.queryParameters['code'];

  if (code != null) {
    try {
      await supabase.auth.exchangeCodeForSession(code);
      debugPrint("PKCE code exchanged successfully");
    } catch (e, stackTrace) {
      debugPrint("PKCE exchange FAILED: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
    return;
  }

  // 2. Implicit flow: #access_token=...&refresh_token=...
  if (uri.fragment.isNotEmpty) {
    try {
      final fragment = Uri.splitQueryString(uri.fragment);
      final accessToken = fragment['access_token'];
      final refreshToken = fragment['refresh_token'];

      if (accessToken != null && refreshToken != null) {
        await supabase.auth.setSession(refreshToken);
        debugPrint("Implicit session restored successfully");
      }
    } catch (e, stackTrace) {
      debugPrint("Implicit session restoration FAILED: $e");
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

// the main app widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppAppearance.lightTheme,
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      )
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

// initial app location -> /
class _ProfileGateState extends State<ProfileGate> {
  late Future<Widget> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<Widget> _resolve() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = session?.user;

    if (user == null) {
      debugPrint("PROFILE GATE: no session");
      return const SignInPage();
    }

    try {
      debugPrint("PROFILE GATE: verified user ${user.id}");
      await ensureProfileExists(user);
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Genuinely missing profile row — not a network hiccup.
        debugPrint("PROFILE GATE: profile doesn't exist");
        await Supabase.instance.client.auth.signOut();
        return const SignInPage();
      }

      final done = profile['onboarding_completed'] == true;
      debugPrint("PROFILE GATE: onboarding completed = $done");
      return done ? const MainPage() : OnboardingPage(onCompleted: _onOnboardingCompleted);
    } on AuthException catch (e) {
      // Token genuinely invalid/expired/revoked — this IS a real auth failure.
      debugPrint("PROFILE GATE AUTH ERROR: $e");
      await Supabase.instance.client.auth.signOut();
      return const SignInPage();
    } catch (e, stackTrace) {
      // Network/DB error, NOT an auth problem — don't punish the user
      // with a forced logout for a transient failure. Let them retry.
      debugPrint("PROFILE GATE TRANSIENT ERROR: $e");
      debugPrintStack(stackTrace: stackTrace);
      return _ProfileGateError(onRetry: () => setState(() => _future = _resolve()));
    }
  }

  void _onOnboardingCompleted() {
    setState(() {
      _future = _resolve();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

Future<void> ensureProfileExists(User user) async {
  await Supabase.instance.client.from('profiles').upsert({
    'id': user.id,
    'onboarding_completed': false,
    'avatar_url': 'https://wczdhrcvwlghrkjmskaa.supabase.co/storage/v1/object/public/ProfileImages/defaultAvatar.jpeg',
    'created_at': DateTime.now().toIso8601String(),
  }, onConflict: 'id', ignoreDuplicates: true);
}

class _ProfileGateError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileGateError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 28,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Verbindung fehlgeschlagen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wir konnten dein Profil nicht laden. Bitte überprüfe deine Internetverbindung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(26),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: onRetry,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'Erneut versuchen',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}