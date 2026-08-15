import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'core.dart';
import 'auth.dart';
import 'lang.dart';

class Announce {
  static const String adminEmail = 'YOUR_EMAIL@gmail.com';
  static bool get isAdmin => (Auth.user?.email ?? '') == adminEmail;

  static Future<List<Map<String, dynamic>>> all() async {
    final s = await FirebaseFirestore.instance
        .collection('announcements')
        .orderBy('date', descending: true).limit(50).get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future send(String t, String b) => FirebaseFirestore.instance
      .collection('announcements')
      .add({'title': t, 'body': b, 'date': FieldValue.serverTimestamp()});

  static List<String> _seen() => List<String>.from(Store.prefs()['seenAnn'] ?? []);

  static Future checkAndShow(BuildContext context) async {
    try {
      final list = await all();
      final seen = _seen();
      final unseen = list.where((a) => !seen.contains(a['id'])).toList();
      if (unseen.isEmpty || !context.mounted) return;
      await showDialog(context: context, barrierDismissible: false,
          builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF151B23),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Row(children: [
                Icon(Icons.campaign, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text('جديد من تلي سينما', style: TextStyle(fontSize: 16)),
              ]),
              content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: unseen.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a['title']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(a['body']?.toString() ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
                  ]))).toList())),
              actions: [
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً 👍')),
              ]));
      await Store.setPref('seenAnn', [...seen, ...unseen.map((a) => a['id'].toString())]);
    } catch (_) {}
  }
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _busy = true;

  @override
  void initState() { super.initState(); _load(); }

  Future _load() async {
    try { _list = await Announce.all(); } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  void _compose() {
    final t = TextEditingController(), b = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF151B23),
        title: const Text('منشور جديد 📢'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: const InputDecoration(hintText: 'العنوان')),
          const SizedBox(height: 8),
          TextField(controller: b, maxLines: 4, decoration: const InputDecoration(hintText: 'نص المنشور')),
        ]),
        actions: [
          FilledButton(onPressed: () async {
            if (t.text.trim().isNotEmpty && b.text.trim().isNotEmpty) {
              await Announce.send(t.text.trim(), b.text.trim());
              if (context.mounted) Navigator.pop(context);
              _load();
            }
          }, child: const Text('إرسال')),
        ]));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('الإعلانات 📢'), actions: [
        if (Announce.isAdmin) IconButton(icon: const Icon(Icons.add_comment), onPressed: _compose),
      ]),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('لا توجد إعلانات بعد', style: TextStyle(color: Colors.grey)))
              : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final a = _list[i];
                    return Card(margin: const EdgeInsets.only(bottom: 10), color: const Color(0xFF151B23),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.campaign, size: 18, color: AppTheme.accent),
                            const SizedBox(width: 8),
                            Expanded(child: Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          ]),
                          const SizedBox(height: 6),
                          Text(a['body']?.toString() ?? '', style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.5)),
                        ])));
                  }));
}
