import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ログイン情報を表示する共通フッターウィジェット
class LoginInfoFooter extends StatelessWidget {
  const LoginInfoFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: FutureBuilder<User?>(
        future: Future.value(FirebaseAuth.instance.currentUser),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) return const SizedBox.shrink();

          final uid = user.uid;
          final name = user.displayName ?? '（未設定）';
          final isAnonymous = user.isAnonymous;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ログイン中: ${isAnonymous ? "匿名" : name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                'UID: ${uid.substring(0, 8)}...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
