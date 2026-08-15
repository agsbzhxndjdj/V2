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

  // ✅ التحسين: بدء المزامنة بشكل ذكي (مرة كل 24 ساعة)
  _startSmartSync();

  // إعداد اللغة
  Lang.locale.value = Store.locale;

  // تشغيل التطبيق
  runApp(const Root());
}

/* ======== المزامنة الذكية ======== */

void _startSmartSync() {
  // ✅ التحقق من آخر تحديث
  if (Store.shouldSync()) {
    // مر أكثر من 24 ساعة، ابدأ المزامنة بعد 5 ثواني
    // (لإعطاء التطبيق وقت للتحميل الأولي)
    Timer(const Duration(seconds: 5), () {
      Sync.syncNow();
    });
  }
  
  // ✅ بدء Timer الدوري للتحديث كل 24 ساعة (لا يشتغل إلا إذا مر 24 ساعة)
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
  }
}

/* ======== الهيكل الرئيسي (Bottom Navigation) ======== */

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: App.tab,
      builder: (_, tab, __) {
        return Scaffold(
          body: IndexedStack(
            index: tab,
            children: [
              const HomePage(),
              const ChannelsPage(),
              _buildDownloadsOrSettings(),
            ],
          ),
          bottomNavigationBar: _buildBottomNav(tab),
        );
      },
    );
  }

  Widget _buildDownloadsOrSettings() {
    // استخدم DownloadsPage إذا كانت موجودة، أو SettingsPage
    return const DownloadsPage();
  }

  Widget _buildBottomNav(int currentTab) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
        border: Border(top: BorderSide(color: Color(0xFF1B2430), width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, Lang.t('home')),
              _navItem(1, Icons.subscriptions_rounded, Lang.t('channels')),
              _navItem(2, Icons.settings_rounded, Lang.t('settings')),
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
          color: isActive ? const Color(0xFFFFC107).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFFFC107) : Colors.grey,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFFFFC107) : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
