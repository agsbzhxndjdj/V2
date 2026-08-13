import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'core.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Store.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TeleCinema());
}

class TeleCinema extends StatelessWidget {
  const TeleCinema({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'تلي سينما',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B0F14),
          cardColor: const Color(0xFF151B23),
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE5B13D), secondary: Color(0xFFE50914)),
        ),
        home: ValueListenableBuilder<int>(
            valueListenable: App.tick,
            builder: (_, __, ___) => StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.data != null) {
                    Store.sync();
                    return const HomeShell();
                  }
                  return Store.isGuest() ? const HomeShell() : const LoginScreen();
                })),
      );
}
