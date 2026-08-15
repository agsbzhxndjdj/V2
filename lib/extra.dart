import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'core.dart';
import 'lang.dart';

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
          activeColor: null,
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
              /* ---- الأوضاع الذكية ✨ ---- */
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
              //* ---- الحساب (محذوف) ---- */
          
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

  Future _export(BuildContext context) async {
    final data = await Store.exportAll();
    final s = jsonEncode(data);
    final dir = await getExternalStorageDirectory();
    final f = File('${dir!.path}/tele_cinema_backup.json');
    await f.writeAsString(s);
    await Clipboard.setData(ClipboardData(text: s));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${Lang.t('exportData')} ✅\n${f.path}')));
    }
  }

  void _importDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF151B23),
            title: Text(Lang.t('importData')),
            content: TextField(
                controller: ctrl,
                maxLines: 6,
                decoration: const InputDecoration(
                    hintText: 'Paste backup JSON…')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(Lang.t('close'))),
              FilledButton(
                  onPressed: () async {
                    try {
                      final m = Map<String, dynamic>.from(
                          jsonDecode(ctrl.text));
                      await Store.importAll(m);
                      if (context.mounted) Navigator.pop(context);
                    } catch (_) {}
                  },
                  child: Text(Lang.t('importData'))),
            ]));
  }
}

/* ======== الإحصائيات والإنجازات ======== */
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = Store.stats();
    final secs = (st['seconds'] as int?) ?? 0;
    final count = (st['count'] as int?) ?? 0;
    final hours = (secs / 3600).toStringAsFixed(1);
    final favs = Store.favorites().length;
    final dls = Store.downloads().length;
    final rts = Store.ratings().length;
    final ach = <Map<String, dynamic>>[
      {'icon': '🎬', 'on': count >= 1, 't': 'أول فيلم / First movie'},
      {'icon': '🔟', 'on': count >= 10, 't': '10 أفلام / 10 movies'},
      {'icon': '💯', 'on': count >= 50, 't': '50 فيلماً / 50 movies'},
      {'icon': '⏰', 'on': secs >= 36000, 't': '10 ساعات / 10 hours'},
      {'icon': '🌙', 'on': secs >= 108000, 't': '30 ساعة / 30 hours'},
      {'icon': '❤️', 'on': favs >= 5, 't': '5 مفضلة / 5 favorites'},
      {'icon': '⭐', 'on': rts >= 1, 't': 'أول تقييم / First rating'},
      {'icon': '📥', 'on': dls >= 1, 't': 'أول تحميل / First download'},
      {'icon': '🔥', 'on': Store.bestStreak >= 3, 't': 'ستريك 3 أيام / 3-day streak'},
      {'icon': '🏆', 'on': Store.bestStreak >= 7, 't': 'أسبوع كامل / Full week'},
    ];
    return Scaffold(
        appBar: AppBar(title: Text(Lang.t('stats'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            _statCard(hours, Lang.t('hoursWatched')),
            const SizedBox(width: 10),
            _statCard('$count', Lang.t('moviesWatched')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _statCard('🔥 ${Store.streak}', 'ستريك حالي'),
            const SizedBox(width: 10),
            _statCard('🏅 ${Store.bestStreak}', 'أفضل ستريك'),
          ]),
          const SizedBox(height: 20),
          Text(Lang.t('achievements'),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent)),
          const SizedBox(height: 10),
          ...ach.map((a) => Opacity(
              opacity: a['on'] ? 1 : 0.35,
              child: ListTile(
                  leading: Text(a['icon'], style: const TextStyle(fontSize: 28)),
                  title: Text(a['t'], style: const TextStyle(fontSize: 13)),
                  trailing: Icon(
                      a['on']
                          ? Icons.verified
                          : Icons.lock_outline,
                      color: a['on'] ? AppTheme.accent : Colors.grey,
                      size: 20)))),
        ]));
  }

  Widget _statCard(String v, String l) => Expanded(
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFF151B23),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent.withOpacity(0.4))),
          child: Column(children: [
            Text(v,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent)),
            const SizedBox(height: 4),
            Text(l,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])));
}

/* ======== شاشة التريلر ======== */
class TrailerScreen extends StatelessWidget {
  final String query;
  const TrailerScreen({super.key, required this.query});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(Lang.t('trailer'))),
      body: InAppWebView(
          initialUrlRequest: URLRequest(
              url: WebUri(
                  'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$query trailer')}'))));
}

/* ======== حوارات القوائم ======== */
void newPlaylistDialog(BuildContext context) {
  final ctrl = TextEditingController();
  showDialog(
      context: context,
      builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF151B23),
          title: Text(Lang.t('newPlaylist')),
          content: TextField(
              controller: ctrl,
              decoration:
                  const InputDecoration(hintText: '…')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(Lang.t('close'))),
            FilledButton(
                onPressed: () async {
                  if (ctrl.text.trim().isNotEmpty) {
                    await Store.addPlaylist(ctrl.text.trim());
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(Lang.t('addChannel'))),
          ]));
}

void showPlaylistDialog(BuildContext context, Movie m) {
  showDialog(
      context: context,
      builder: (_) => ValueListenableBuilder<int>(
          valueListenable: Store.tick,
          builder: (_, __, ___) {
            final names = Store.playlists().keys.toList();
            return AlertDialog(
                backgroundColor: const Color(0xFF151B23),
                title: Text(Lang.t('playlists')),
                content: SizedBox(
                    width: double.maxFinite,
                    child: names.isEmpty
                        ? Text(Lang.t('newPlaylist'))
                        : ListView(
                            shrinkWrap: true,
                            children: names.map((n) {
                              final inside = Store.playlistMovies(n)
                                  .any((e) => e.id == m.id);
                              return ListTile(
                                  dense: true,
                                  title: Text(n,
                                      style: const TextStyle(fontSize: 13)),
                                  trailing: Icon(
                                      inside
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      color: inside
                                          ? AppTheme.accent
                                          : Colors.grey),
                                  onTap: () =>
                                      Store.toggleInPlaylist(n, m));
                            }).toList())));
          }));
}
