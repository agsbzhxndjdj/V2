import 'package:flutter/material.dart';
import 'core.dart';
import 'lang.dart';
import 'features.dart';
import 'auth.dart';

/* ======== صفحة الإعدادات ======== */
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _sw(String title, String? sub, bool v, Function(bool) f) =>
      SwitchListTile(
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: sub != null
              ? Text(sub, style: const TextStyle(fontSize: 11))
              : null,
          value: v,
          onChanged: (x) => f(x));

  Widget _header(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Text(t,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent)));

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: Store.tick,
      builder: (_, __, ___) => Scaffold(
            appBar: AppBar(title: Text(Lang.t('settings'))),
            body: ListView(children: [
              /* ---- اللغة ---- */
              _header(Lang.t('language')),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                        child: ChoiceChip(
                            label: Text(Lang.t('arabic')),
                            selected: Store.locale == 'ar',
                            onSelected: (_) async {
                              await Store.setPref('locale', 'ar');
                              Lang.set('ar');
                            })),
                    const SizedBox(width: 10),
                    Expanded(
                        child: ChoiceChip(
                            label: Text(Lang.t('english')),
                            selected: Store.locale == 'en',
                            onSelected: (_) async {
                              await Store.setPref('locale', 'en');
                              Lang.set('en');
                            })),
                  ])),
              /* ---- الثيم ---- */
              _header(Lang.t('appearance')),
              SizedBox(
                  height: 52,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['gold', 'blue', 'green', 'purple', 'red']
                          .map((n) => GestureDetector(
                              onTap: () => Store.setPref('theme', n),
                              child: Container(
                                  width: 52,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.build(n).colorScheme
                                          .primary,
                                      border: Store.theme == n
                                          ? Border.all(
                                              color: Colors.white, width: 3)
                                          : null),
                                  child: Store.theme == n
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 20)
                                      : null)))
                          .toList())),
              /* ---- العرض ---- */
              _header(Lang.t('viewMode')),
              _sw(Lang.t('list'), null, Store.getBool('listView'),
                  (v) => Store.setPref('listView', v)),
              _sw(Lang.t('hideWatched'), null, Store.getBool('hideWatched'),
                  (v) => Store.setPref('hideWatched', v)),
              /* ---- المشاهدة ---- */
              _header(Lang.t('movies')),
              _sw(Lang.t('incognito'), Lang.t('incognitoHint'),
                  Store.getBool('incognito'),
                  (v) => Store.setPref('incognito', v)),
              _sw(Lang.t('kidsMode'), Lang.t('kidsModeHint'),
                  Store.getBool('kidsMode'),
                  (v) => Store.setPref('kidsMode', v)),
              /* ---- الأوضاع الذكية ---- */
              _header('الأوضاع الذكية ⚙️'),
              _sw('ثيم تلقائي ليلي 🌙', null, Store.getBool('autoTheme'),
                  (v) => Store.setPref('autoTheme', v)),
              _sw('تحميل ذكي على Wi-Fi 📥', Lang.t('wifiNeeded'),
                  Store.getBool('smartDl'),
                  (v) => Store.setPref('smartDl', v)),
              _sw('توفير البيانات 📶', null, Store.getBool('dataSaver'),
                  (v) => Store.setPref('dataSaver', v)),
              _sw('وضع البطارية 🔋', null, Store.getBool('battery'),
                  (v) => Store.setPref('battery', v)),
              
              /* ---- ✅ المواقع الخارجية 🌐 ---- */
              _header('المواقع الخارجية 🌐'),
              _sw(
                'تفعيل المواقع',
                'إظهار زر المواقع في الأعلى وجلب الأفلام من المواقع المجانية',
                SitesSettings.sitesEnabled,
                (v) async {
                  await SitesSettings.setSitesEnabled(v);
                  Store.tick.value++;
                },
              ),
              if (SitesSettings.sitesEnabled) ...[
                _sw(
                  '🎬 Plex',
                  'أفلام مجانية من Plex (يحتاج Plex Token)',
                  SitesSettings.isSiteEnabled('plex'),
                  (v) async {
                    await SitesSettings.setSiteEnabled('plex', v);
                    Store.tick.value++;
                  },
                ),
                _sw(
                  '📺 Roku Channel',
                  'أفلام مجانية من Roku Channel',
                  SitesSettings.isSiteEnabled('roku'),
                  (v) async {
                    await SitesSettings.setSiteEnabled('roku', v);
                    Store.tick.value++;
                  },
                ),
                _sw(
                  '🎥 Crackle',
                  'أفلام مجانية من Crackle (Sony)',
                  SitesSettings.isSiteEnabled('crackle'),
                  (v) async {
                    await SitesSettings.setSiteEnabled('crackle', v);
                    Store.tick.value++;
                  },
                ),
                const Divider(height: 20),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: const Text(
                    'ملاحظة',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'البيانات والوصف والبوستر تُجلب من TMDB\nالترجمات تُجلب من OpenSubtitles\nالبث مباشر بدون تخزين',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
              
              /* ---- العرض والتنظيم 🆕 ---- */
              _header('العرض والتنظيم'),
              _sw('🔄 تجميع الأجزاء تلقائياً', null,
                  Store.getBool('groupParts', true),
                  (v) => Store.setPref('groupParts', v)),
              _sw('✨ انتقالات سينمائية', null, Store.getBool('heroFx', true),
                  (v) => Store.setPref('heroFx', v)),
              _sw('🌌 خلفية حية', 'بوستر آخر مشاهدة كخلفية',
                  Store.getBool('liveWall'), (v) => Store.setPref('liveWall', v)),
              /* ---- الحسابات 👥 ---- */
              _header('الحسابات 👥'),
              ...Profiles.all().map((n) => RadioListTile<String>(
                  dense: true,
                  value: n,
                  groupValue: Profiles.current,
                  title: Text(n, style: const TextStyle(fontSize: 13)),
                  onChanged: (v) => Profiles.switchTo(v!))),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_add_outlined, size: 20),
                  title: const Text('حساب جديد',
                      style: TextStyle(fontSize: 13)),
                  onTap: () => Profiles.addDialog(context)),
              /* ---- القبو السري 📦 ---- */
              _header('القبو السري 📦'),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.pin_outlined, size: 20),
                  title: const Text('تعيين/تغيير الرمز',
                      style: TextStyle(fontSize: 13)),
                  onTap: () => Profiles.setPinDialog(context)),
              ListTile(
                  dense: true,
                  leading: Icon(
                      Vault.unlocked ? Icons.lock_open : Icons.lock_outline,
                      size: 20),
                  title: Text(Vault.unlocked ? 'قفل القبو' : 'فتح القبو',
                      style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    if (Vault.unlocked) {
                      Vault.unlocked = false;
                      Store.tick.value++;
                    } else {
                      await Vault.ask(context);
                    }
                  }),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.visibility_off_outlined, size: 20),
                  title: const Text('إخفاء قنوات',
                      style: TextStyle(fontSize: 13)),
                  onTap: () => Profiles.vaultChannelsDialog(context)),
              /* ---- تصدير ومشاركة ---- */
              _header('تصدير ومشاركة'),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.history_outlined, size: 20),
                  title: const Text('تصدير السجل 📤',
                      style: TextStyle(fontSize: 13)),
                  onTap: () async {
                    final p = await Exporter.history();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('حُفظ: $p')));
                    }
                  }),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.upload_file, size: 20),
                  title: const Text('تصدير القوائم',
                      style: TextStyle(fontSize: 13)),
                  onTap: () async {
                    final p = await Exporter.playlists();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('حُفظ: $p')));
                    }
                  }),
              ListTile(
                  dense: true,
                  leading: const Icon(Icons.file_download, size: 20),
                  title: const Text('استيراد القوائم',
                      style: TextStyle(fontSize: 13)),
                  onTap: () => Exporter.importDialog(context)),
              /* ---- التحميل ---- */
              _header(Lang.t('downloads')),
              _sw(Lang.t('wifiOnly'), Lang.t('wifiNeeded'),
                  Store.getBool('wifiOnly'),
                  (v) => Store.setPref('wifiOnly', v)),
              /* ---- الإحصائيات ---- */
              _header(Lang.t('stats')),
              ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.bar_chart, size: 20)),
                  title: Text(Lang.t('stats'),
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StatsPage()))),
              /* ---- النسخ الاحتياطي ---- */
              _header(Lang.t('backup')),
              ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.upload_file, size: 20)),
                  title: Text(Lang.t('exportData'),
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => _export(context)),
              ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.file_download, size: 20)),
                  title: Text(Lang.t('importData'),
                      style: const TextStyle(fontSize: 14)),
                  onTap: () => _importDialog(context)),
            ]),
          ));

  /* ---- تصدير البيانات ---- */
  Future<void> _export(BuildContext context) async {
    try {
      final data = await Store.exportAll();
      final json = const JsonEncoder().convert(data);
      final path = await _saveFile(json, 'tele_cinema_backup.json');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم الحفظ: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل التصدير: $e')));
      }
    }
  }

  Future<String> _saveFile(String content, String name) async {
    final dir = await getExternalStorageDirectory();
    final file = File('${dir!.path}/$name');
    await file.writeAsString(content);
    return file.path;
  }

  /* ---- استيراد البيانات ---- */
  void _importDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Lang.t('importData')),
        content: TextField(
          controller: ctrl,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'الصق محتوى النسخة الاحتياطية هنا',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Lang.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final data = const JsonDecoder().convert(ctrl.text);
                await Store.importAll(data);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم الاستيراد بنجاح')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل الاستيراد: $e')));
                }
              }
            },
            child: Text(Lang.t('import')),
          ),
        ],
      ),
    );
  }
}
