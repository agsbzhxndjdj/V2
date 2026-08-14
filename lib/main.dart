import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Store.init();
  runApp(const TeleCinemaApp());
}

class TeleCinemaApp extends StatelessWidget {
  const TeleCinemaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'تلي سينما',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE5B13D),
            secondary: Color(0xFFE5B13D),
            surface: Color(0xFF0B0F14),
          ),
          scaffoldBackgroundColor: const Color(0xFF0B0F14),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: Color(0xFF12161F),
            indicatorColor: Color(0xFFE5B13D),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF12161F),
            centerTitle: true,
          ),
          cardTheme: const CardTheme(color: Color(0xFF151B23)),
        ),
        home: const HomeShell(),
      );
}
