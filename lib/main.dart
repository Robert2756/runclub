import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'main_page.dart';
import 'theme/appearance.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'onboarding_page.dart';
import 'checkEmailPage.dart';
import 'package:app_links/app_links.dart';
import 'reset_password_page.dart';
import 'package:go_router/go_router.dart';
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
    final loggingIn = location == '/signin';
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
      result = checkingEmail ? null : '/check-email';
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
    GoRoute(path: '/', builder: (_, __) => const ProfileGate()), // your existing widget, unchanged
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("APP STARTED");

  await Supabase.initialize(
    url: 'https://wczdhrcvwlghrkjmskaa.supabase.co', 
    anonKey: 'sb_publishable_4M-s15nTEGZ7IflPJaRYgA_v2WvjakI',
    debug: true,
    authOptions: const FlutterAuthClientOptions(
    detectSessionInUri: false,
  ),);
  final appLinks = AppLinks();

  // deep link nadler picks up deep link and establishes a new session that is detected by the auth state listener on top
  appLinks.uriLinkStream.listen((uri) async {
    debugPrint("Deep link arrived: $uri");

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
  });

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('de_DE', null);
  runApp(const MyApp());
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

// initial app location -> /
class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  Future<Widget> _resolve() async {
    try {
      debugPrint("PROFILE GATE: starting");
      final response =await Supabase.instance.client.auth.getUser();
      final user = response.user;

      if (user == null) {
        debugPrint("PROFILE GATE: no valid user");
        await Supabase.instance.client.auth.signOut();
        return const SignInPage();
      }
      debugPrint("PROFILE GATE: verified user ${user.id}");

      await ensureProfileExists(user);
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('onboarding_completed')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        debugPrint("PROFILE GATE: profile doesn't exist");
        await Supabase.instance.client.auth.signOut();
        return const SignInPage();
      }

      final done = profile['onboarding_completed'] == true;
      debugPrint("PROFILE GATE: onboarding completed = $done");
      return done
          ? const MainPage()
          : const OnboardingPage();

    } catch (e, stackTrace) {
      debugPrint("PROFILE GATE ERROR: $e");
      debugPrintStack(stackTrace: stackTrace);

      // Session is invalid OR some other request failed.
      await Supabase.instance.client.auth.signOut();

      return const SignInPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolve(),
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
  final supabase = Supabase.instance.client;

  final profile = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (profile == null) {
    await supabase.from('profiles').insert({
      'id': user.id,
      'onboarding_completed': false,
      'avatar_url': "https://wczdhrcvwlghrkjmskaa.supabase.co/storage/v1/object/public/ProfileImages/defaultAvatar.jpeg",
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}