import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core.dart';
import 'lang.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await Hive.initFlutter();
  await Store.init();
  Lang.locale.value = Store.locale;
  runApp(const Root());
}

class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: Lang.locale,
      builder: (_, lang, __) => MaterialApp(
            title: Lang.t('appName'),
            debugShowCheckedModeBanner: false,
            locale: Locale(lang),
            theme: AppTheme.build(Store.theme),
            home: const Splash(),
          ));
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeShell()));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0B0F14),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/iconic.png',
                  width: 120, height: 120)),
          const SizedBox(height: 18),
          Text(Lang.t('appName'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent)),
          const SizedBox(height: 24),
          CircularProgressIndicator(color: AppTheme.accent),
        ])),
      );
}
