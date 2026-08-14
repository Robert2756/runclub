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
import 'package:flutter/scheduler.dart';
import 'auth_loading_page.dart';
import 'reset_password_page.dart';

bool _passwordRecoveryInProgress = false;

void endPasswordRecovery() {
  _passwordRecoveryInProgress = false;
}

final supabase = Supabase.instance.client;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("APP STARTED");
  await Supabase.initialize(
    url: 'https://wczdhrcvwlghrkjmskaa.supabase.co', 
    anonKey: 'sb_publishable_4M-s15nTEGZ7IflPJaRYgA_v2WvjakI',
    debug: true,
    authOptions: const FlutterAuthClientOptions(
    // We already handle all deep links manually via AppLinks below —
    // Supabase's built-in observer was running in parallel with it,
    // causing duplicate events and letting the recovery session leak
    // into normal post-auth navigation.
    detectSessionInUri: false,
  ),
  );
  final appLinks = AppLinks();

  // deep link arrives
  appLinks.uriLinkStream.listen((uri) async {
    debugPrint("Deep link arrived: $uri");

    if (uri.scheme != 'com.enduvo.app' ||
        uri.host != 'login-callback') {
      return;
    }

    debugPrint("Handling PKCE deep link: $uri");

    try {
      // Session? session;

      if (uri.queryParameters.containsKey('code')) {
        await supabase.auth.getSessionFromUrl(uri);
        debugPrint("PKCE code exchanged successfully");
      } 
      // else if (uri.fragment.contains('access_token')) {
      //   debugPrint("Implicit handling: $uri");
      //   final fragment = Uri.splitQueryString(uri.fragment);
      //   final refreshToken = fragment['refresh_token'];

      //   if (refreshToken != null) {
      //     final response = await supabase.auth.setSession(refreshToken);
      //     session = response.session;
      //   }
      // }
    } catch (e) {
      debugPrint("PKCE session recovery FAILED: $e");
    }
  });

  // user clicked link in email
  supabase.auth.onAuthStateChange.listen((data) async {
    debugPrint("AUTH EVENT: ${data.event}, session: ${data.session != null}");
    final event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      if (_passwordRecoveryInProgress) return; // ignore duplicate fires
      _passwordRecoveryInProgress = true;

      debugPrint("NAV: password recovery event, opening ResetPasswordPage");
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ResetPasswordPage(
          onRecoveryFinished: () {
            _passwordRecoveryInProgress = false;
          },
        )),
      );
      return;
    }

    if (event != AuthChangeEvent.signedIn &&
        event != AuthChangeEvent.initialSession) {
      return;
    }

    if (_passwordRecoveryInProgress) {
      debugPrint("NAV: ignoring $event — password recovery still in progress");
      return;
    }

    final user = data.session?.user;
    if (user == null) return;

    await _handlePostAuthNavigation(user);
  }, onError: (error, stackTrace) {
    debugPrint("AUTH STREAM ERROR: $error");
    debugPrintStack(stackTrace: stackTrace);
  },);

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('de_DE', null);
  runApp(const MyApp());
}

Future<void> _handlePostAuthNavigation(User user) async {
  debugPrint("NAV: starting post-auth navigation for ${user.id}");

  if (navigatorKey.currentState == null) {
    debugPrint("NAV: navigatorKey.currentState is NULL, aborting");
    return;
  }

  // Replace whatever screen is currently showing (CheckEmailPage after
  // email confirmation, SignInPage after password sign-in, etc.) with a
  // neutral loading screen immediately, before doing any async work.
  navigatorKey.currentState!.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const AuthLoadingPage()),
    (_) => false,
  );

  await ensureProfileExists(user);

  final profile = await supabase
      .from('profiles')
      .select('onboarding_completed')
      .eq('id', user.id)
      .maybeSingle();

  final completed = profile?['onboarding_completed'] ?? false;

  if (navigatorKey.currentState == null) {
    debugPrint("NAV: navigatorKey.currentState is NULL, aborting");
    return;
  }

  navigatorKey.currentState!.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => completed ? const MainPage() : const OnboardingPage(),
    ),
    (_) => false,
  );
  debugPrint("NAV: pushAndRemoveUntil called directly");
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
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppAppearance.lightTheme,
        navigatorObservers: [routeObserver],
        home: const AuthGate(),
        locale: const Locale('de', 'DE'),
        supportedLocales: const [
          Locale('de', 'DE'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

// Sign in or Feed
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}


class _AuthGateState extends State<AuthGate> {

  @override
  Widget build(BuildContext context) {
    debugPrint("AuthGate build — currentUser: ${supabase.auth.currentUser?.id}, confirmed: ${supabase.auth.currentUser?.emailConfirmedAt}");

    final user =
        supabase.auth.currentUser;


    if(user == null){
      return const SignInPage();
    }


    // Email not verified yet
    debugPrint("Deep Link worked and rerouted back Email Page");
    if(user.emailConfirmedAt == null){

      return CheckEmailPage(
        email: user.email!,
      );

    }


    return const ProfileGate();

  }

}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  Future<Widget> _resolve() async {
    try {
      debugPrint("PROFILE GATE: starting");

      final response =
          await Supabase.instance.client.auth.getUser();

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