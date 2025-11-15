import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Flutter Web 専用の Google ログイン処理。
Future<UserCredential?> signInWithGoogleWeb() async {
  try {
    if (!kIsWeb) {
      throw UnsupportedError('この関数は Web 専用です');
    }

    final googleProvider = GoogleAuthProvider();

    // オプション: プロンプトを強制表示したい場合
    // googleProvider.setCustomParameters({'prompt': 'select_account'});

    return await FirebaseAuth.instance.signInWithPopup(googleProvider);
  } catch (e) {
    debugPrint('Googleログイン失敗: $e');
    return null;
  }
}
