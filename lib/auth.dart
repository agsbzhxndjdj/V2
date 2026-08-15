import 'package:flutter/material.dart';

/* ======== Auth مبسّط: ضيف دائماً ======== */
class Auth {
  static bool get hasChosen => true;
  static bool get isGuest => true;
  static String get displayName => 'ضيف';
  static Future chooseGuest() async {}
  static Future logout() async {}
  static dynamic get user => null;
}
