import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signin_page.dart';
import 'main_page.dart';
import 'theme/appearance.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'onboarding_page.dart';


final supabase = Supabase.instance.client;
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wczdhrcvwlghrkjmskaa.supabase.co', 
    anonKey: 'sb_publishable_4M-s15nTEGZ7IflPJaRYgA_v2WvjakI',
  );

  // await Supabase.instance.client.auth.signOut();

  supabase.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final user = session?.user;

    if (user == null) return;

    await ensureProfileExists(user);

    final profile = await supabase
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', user.id)
        .maybeSingle();

    final onboardingDone = profile?['onboarding_completed'] ?? false;

    if (onboardingDone == true) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage()),
        (_) => false,
      );
    } else {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (_) => false,
      );
    }
  });

  // Enable edge-to-edge mode
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await initializeDateFormatting('de_DE', null);
  runApp(const MyApp());
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        home: const SignInPage(),// AuthGate(),
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
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          return const SignInPage();
        }

        return const ProfileGate();
      },
    );
  }
}

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  Future<Widget> _resolve() async {
    final resUser = await Supabase.instance.client.auth.getUser();
    final resSession = await Supabase.instance.client.auth.refreshSession();
    final session = resSession.session;
    final user = resUser.user;

    if (session == null) {
      await Supabase.instance.client.auth.signOut();
      return const SignInPage();
    }

    if (user == null) {
      await Supabase.instance.client.auth.signOut();
      return const SignInPage();
    }

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('onboarding_completed')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      await Supabase.instance.client.auth.signOut();
      return const SignInPage();
    }

    final done = profile['onboarding_completed'] == true;

    return done ? const MainPage() : const OnboardingPage();
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