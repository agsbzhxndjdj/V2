import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'core.dart';

class Auth {
  static final FirebaseAuth _fa = FirebaseAuth.instance;
  static User? get user => _fa.currentUser;
  static bool get hasChosen => Store.getString('authMode', '') != '';
  static bool get isGuest => Store.getString('authMode', '') != 'user';
  static String get displayName =>
      user?.displayName ?? user?.email?.split('@').first ?? 'ضيف';

  static Future chooseGuest() => Store.setString('authMode', 'guest');

  static Future google() async {
    final g = await GoogleSignIn().signIn();
    if (g == null) throw Exception('cancelled');
    final a = await g.authentication;
    await _fa.signInWithCredential(GoogleAuthProvider.credential(
        idToken: a.idToken, accessToken: a.accessToken));
    await Store.setString('authMode', 'user');
  }

  static Future email(String e, String p, {bool reg = false}) async {
    if (reg) {
      await _fa.createUserWithEmailAndPassword(email: e, password: p);
    } else {
      await _fa.signInWithEmailAndPassword(email: e, password: p);
    }
    await Store.setString('authMode', 'user');
  }

  static Future logout() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _fa.signOut();
    await Store.setString('authMode', 'guest');
  }
}

/* ======== إرسال التقييمات للسحابة ======== */
class CloudRate {
  static Future send(Movie m, int stars) async {
    if (Auth.isGuest || Auth.user == null) return;
    try {
      await FirebaseFirestore.instance.collection('ratings').doc(m.id).set({
        'title': m.title, 'user': Auth.user!.uid,
        'name': Auth.displayName, 'stars': stars,
        'date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

/* ======== شاشة تسجيل الدخول ======== */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _e = TextEditingController(), _p = TextEditingController();
  bool _reg = false, _busy = false;

  Future _wrap(Future Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (ex) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الدخول: ${ex.toString().replaceAll('Exception: ', '')}')));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/iconic.png', width: 96, height: 96)),
        const SizedBox(height: 14),
        Text('تلي سينما', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        const SizedBox(height: 6),
        const Text('ادخل كضيف أو سجّل لحفظ بياناتك', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 26),
        FilledButton.icon(
            onPressed: _busy ? null : () async { await Auth.chooseGuest(); Navigator.pushReplacementNamed(context, '/home'); },
            icon: const Icon(Icons.person_outline), label: const Text('دخول كضيف'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppTheme.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _wrap(Auth.google),
            icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('المتابعة بجوجل'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
        const SizedBox(height: 18),
        TextField(controller: _e, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(hintText: 'البريد الإلكتروني', filled: true, fillColor: const Color(0xFF151B23), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 10),
        TextField(controller: _p, obscureText: true,
            decoration: InputDecoration(hintText: 'كلمة المرور', filled: true, fillColor: const Color(0xFF151B23), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(
              onPressed: _busy ? null : () => _wrap(() => Auth.email(_e.text.trim(), _p.text)),
              child: const Text('دخول'))),
          const SizedBox(width: 10),
          Expanded(child: TextButton(
              onPressed: () => setState(() => _reg = !_reg),
              child: Text(_reg ? 'لديك حساب؟ دخول' : 'إنشاء حساب جديد'))),
        ]),
        if (_reg) const SizedBox(height: 6),
        if (_reg) FilledButton(
            onPressed: _busy ? null : () => _wrap(() => Auth.email(_e.text.trim(), _p.text, reg: true)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: Colors.green),
            child: const Text('تسجيل الحساب')),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: CircularProgressIndicator()),
      ]))));
}
