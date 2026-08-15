import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core.dart';
import 'lang.dart';
import 'ui.dart';
import 'tv.dart';
import 'notify.dart';
import 'auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(); } catch (_) {}
  await Hive.initFlutter();
  await Store.init();
  await Notify.init();
  Sync.onNewMovies = (n, t) => Notify.newMovies(n, t);
  Sync.start();
  Lang.locale.value = Store.locale;
  runApp(const Root());
}

class Root extends StatelessWidget {
  const Root({super.key});

  ThemeData _th() {
    final t = AppTheme.build(Store.theme);
    if (Store.getBool('autoTheme')) {
      final h = DateTime.now().hour;
      if (h >= 19 || h < 6) {
        return t.copyWith(scaffoldBackgroundColor: Colors.black, canvasColor: Colors.black,
            cardColor: const Color(0xFF101010), appBarTheme: const AppBarTheme(backgroundColor: Colors.black));
      }
    }
    return t;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: Lang.locale,
      builder: (_, lang, __) => MaterialApp(
            title: Lang.t('appName'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: _th(),
            routes: {'/home': (_) => const Splash()},
            home: Auth.hasChosen ? const Splash() : const LoginScreen(),
          ));
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  Future<bool> _isTv() async {
    try {
      final v = await const MethodChannel('tele_cinema/device').invokeMethod<bool>('isTv');
      return v ?? false;
    } catch (_) { return false; }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      final tv = await _isTv();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => tv ? const TvHome() : const HomeShell()));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/iconic.png', width: 120, height: 120)),
          const SizedBox(height: 18),
          Text(Lang.t('appName'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.accent)),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: AppTheme.accent),
        ])),
      );
}
