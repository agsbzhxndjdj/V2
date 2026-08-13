import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'core.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return IconButton(
        icon: Icon(u != null ? Icons.manage_accounts : Icons.login_outlined),
        onPressed: () {
          if (u == null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            return;
          }
          showModalBottomSheet(context: context, builder: (_) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: CircleAvatar(child: Text(u.displayName?.isNotEmpty == true
                    ? u.displayName![0] : 'ح')),
                title: Text(u.displayName ?? ''), subtitle: Text(u.email ?? '')),
            ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  await Store.setGuest(true);
                  App.tick.value++;
                  if (context.mounted) Navigator.pop(context);
                }),
          ])));
        });
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future _google(BuildContext context) async {
    try {
      final acc = await GoogleSignIn().signIn();
      if (acc == null) return;
      final a = await acc.authentication;
      await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(
          idToken: a.idToken, accessToken: a.accessToken));
      await Store.sync();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFF151B23),
            borderRadius: BorderRadius.circular(28)),
        child: const Icon(Icons.movie_filter, size: 70, color: Colors.amber)),
    const SizedBox(height: 18),
    const Text('تلي سينما',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.amber)),
    const SizedBox(height: 6),
    Text('أفلام قنواتك العامة… بواجهة تليق بها',
        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
    const SizedBox(height: 40),
    Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: FilledButton.icon(
            onPressed: () => _google(context),
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('تسجيل الدخول عبر Google'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    ),
    const SizedBox(height: 8),
    TextButton(
        onPressed: () async {
          await Store.setGuest(true);
          App.tick.value++;
        },
        child: const Text('المتابعة كضيف')),
  ])));
}
