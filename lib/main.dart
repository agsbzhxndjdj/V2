import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'core.dart';
import 'ui.dart';
import 'tv.dart';
import 'auth.dart';
import 'lang.dart';
import 'notify.dart';
import 'features.dart';
import 'features2.dart';
import 'extra.dart';
import 'announce.dart';

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
  runApp(
    DevicePreview(
      enabled: false, // تعطيل DevicePreview في الإنتاج
      builder: (context) => const Root(),
    ),
  );
}

/* ======== المزامنة الذكية ======== */

void _startSmartSync() {
  // ✅ التحقق من آخر تحديث
  final shouldSyncNow = Store.shouldSync();

  if (shouldSyncNow) {
    // مر أكثر من 24 ساعة، ابدأ المزامنة بعد 3 ثواني
    // (لإعطاء التطبيق وقت للتحميل الأولي)
    Timer(const Duration(seconds: 3), () {
      Sync.syncNow();
    });
  }

  // ✅ بدء Timer الدوري للتحديث كل 24 ساعة
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
    _initDisplayMode();
    _checkAnnouncements();
  }

  Future<void> _initDisplayMode() async {
    try {
      // محاولة تفعيل أعلى معدل تحديث للشاشة (120Hz)
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // تجاهل الخطأ إذا لم يكن مدعوماً
    }
  }

  Future<void> _checkTvMode() async {
    // التحقق من وضع التلفزيون (يمكن إضافة منطق إضافي هنا)
    final isTv = Store.getBool('tvMode', false);
    if (mounted && isTv != _isTvMode) {
      setState(() => _isTvMode = isTv);
    }
  }

  Future<void> _checkAnnouncements() async {
    // فحص الإعلانات/التحديثات المهمة
    try {
      await Announce.checkAndShow(context);
    } catch (_) {
      // تجاهل الأخطاء
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ✅ عند العودة للتطبيق من الخلفية، تحقق من المزامنة
    if (state == AppLifecycleState.resumed) {
      if (Store.shouldSync()) {
        Sync.syncNow();
      }
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
        return ValueListenableBuilder<String>(
          valueListenable: App.theme,
          builder: (_, theme, __) {
            return MaterialApp(
              title: Lang.t('appName'),
              debugShowCheckedModeBanner: false,
              locale: Locale(locale),
              theme: AppTheme.getTheme(theme),
              darkTheme: AppTheme.getTheme(theme),
              themeMode: ThemeMode.dark,
              home: _isTvMode ? const TvHome() : const MainShell(),
              builder: (context, child) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        );
      },
    );
  }
}

/* ======== الهيكل الرئيسي (Bottom Navigation) ======== */

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<Widget> _pages = const [
    HomePage(),
    ChannelsPage(),
    DownloadsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (_, tab, __) {
        return Scaffold(
          body: IndexedStack(
            index: tab,
            children: _pages,
          ),
          bottomNavigationBar: _buildBottomNav(tab),
        );
      },
    );
  }

  Widget _buildBottomNav(int currentTab) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Lang.t('home')),
              _navItem(1, Icons.subscriptions_rounded, Lang.t('channels')),
              _navItem(2, Icons.download_rounded, Lang.t('downloads')),
              _navItem(3, Icons.person_rounded, Lang.t('profile')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = App.tab.value == index;
    return GestureDetector(
      onTap: () => App.tab.value = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.accent : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.accent : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ======== الثيمات ======== */

class AppTheme {
  static Color get accent => const Color(0xFFFFC107); // ذهبي

  static ThemeData getTheme(String themeName) {
    Color primary;
    switch (themeName) {
      case 'blue':
        primary = const Color(0xFF2196F3);
        break;
      case 'red':
        primary = const Color(0xFFE53935);
        break;
      case 'green':
        primary = const Color(0xFF4CAF50);
        break;
      case 'purple':
        primary = const Color(0xFF9C27B0);
        break;
      default:
        primary = const Color(0xFFFFC107); // ذهبي
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: const Color(0xFF0B0F14),
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: const Color(0xFF151B23),
        background: const Color(0xFF0B0F14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0F14),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF151B23),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151B23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1B2430),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // للتوافق مع الكود القديم
  static Color accentColor(String themeName) {
    switch (themeName) {
      case 'blue':
        return const Color(0xFF2196F3);
      case 'red':
        return const Color(0xFFE53935);
      case 'green':
        return const Color(0xFF4CAF50);
      case 'purple':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFFFFC107);
    }
  }
}
