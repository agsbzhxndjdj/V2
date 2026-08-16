import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core.dart';
import 'ui.dart';
import 'tv.dart';
import 'lang.dart';
import 'notify.dart';

/* ======== نقطة البداية ======== */

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعدادات النظام
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // تهيئة Hive
  await Hive.initFlutter();
  await Store.init();

  // تهيئة الإشعارات
  await Notify.init();

  // ربط المزامنة بالإشعارات
  Sync.onNewMovies = (n, t) => Notify.newMovies(n, t);

  // ✅ التحسين: بدء المزامنة بشكل ذكي
  _startSmartSync();

  // إعداد اللغة
  Lang.locale.value = Store.locale;

  // تشغيل التطبيق
  runApp(const Root());
}

/* ======== المزامنة الذكية ======== */

void _startSmartSync() {
  // ابدأ المزامنة بعد 5 ثواني (لإعطاء التطبيق وقت للتحميل الأولي)
  Timer(const Duration(seconds: 5), () {
    Sync.checkAll();
  });

  // Timer دوري للتحديث (كل ساعتين داخل Sync.start)
  Sync.start();
}

/* ======== الجذر الرئيسي ======== */

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool _isTvMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkTvMode();
  }

  void _checkTvMode() {
    final isTv = Store.getBool('tvMode', false);
    if (mounted && isTv != _isTvMode) {
      setState(() => _isTvMode = isTv);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ✅ عند العودة للتطبيق من الخلفية، تحقق من المزامنة
    if (state == AppLifecycleState.resumed) {
      Sync.checkAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: Lang.locale,
      builder: (_, locale, __) {
        return MaterialApp(
          title: Lang.t('appName'),
          debugShowCheckedModeBanner: false,
          locale: Locale(locale),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0B0F14),
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFFFC107),
              secondary: const Color(0xFFFFC107),
              surface: const Color(0xFF151B23),
            ),
          ),
          // ✅ الواجهة القديمة بخمسة تبويبات بدل الثلاثة
          home: _isTvMode ? const TvHome() : const HomeShell(),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
