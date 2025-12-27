import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:wari_can/utils/exception_utils.dart';

/// Flutter Web 環境において Google 認証（ポップアップ方式）を実行します。
///
/// 処理の流れ：
/// 1. プラットフォームのチェック（Web以外では動作させない安全策）
/// 2. GoogleAuthProvider の初期化
/// 3. ブラウザのポップアップウィンドウによるサインイン実行
/// 4. 成功時は [UserCredential] を返し、失敗時は `null` を返します。
Future<UserCredential?> signInWithGoogleWeb() async {
  try {
    // Web専用であることを型安全に保証
    if (!kIsWeb) {
      throw UnsupportedError(
        'この関数は Web 専用です。モバイル環境では google_sign_in パッケージを使用してください。',
      );
    }

    final googleProvider = GoogleAuthProvider();

    // ユーザーにアカウント選択画面を常に表示させたい場合は、以下のコメントを解除します
    // googleProvider.setCustomParameters({'prompt': 'select_account'});

    // signInWithPopup は Web ブラウザで最も直感的な認証体験を提供します
    // 注意: ブラウザの設定でポップアップがブロックされていると失敗することがあります
    final userCredential = await FirebaseAuth.instance.signInWithPopup(
      googleProvider,
    );

    debugPrint('Googleログイン成功: ${userCredential.user?.displayName}');
    return userCredential;
  } on Exception catch (e) {
    // ExceptionUtils を使用して、Firebase 特有の長いエラーメッセージを整形してログ出力
    debugPrint('Googleログイン失敗: ${ExceptionUtils.format(e)}');
    return null;
  }
}
