import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ログイン情報を表示する共通フッターウィジェット
class LoginInfoFooter extends StatefulWidget {
  const LoginInfoFooter({super.key});

  @override
  State<LoginInfoFooter> createState() => _LoginInfoFooterState();
}

class _LoginInfoFooterState extends State<LoginInfoFooter> {
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    setState(() {
      if (!mounted) return;
      _displayName = doc.data()?['name'] ?? user.displayName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final uid = user.uid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              final controller = TextEditingController(text: _displayName);
              final newName = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('表示名を修正'),
                    content: TextField(controller: controller),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final newName = controller.text.trim();
                          if (newName.isEmpty) {
                            Navigator.pop(context);
                            return;
                          }

                          // Firestore の users コレクションを更新
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                                'name': newName,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                          Navigator.pop(context, newName);
                        },
                        child: const Text('保存'),
                      ),

                      // 匿名ログインでない場合のみリセットボタンを追加
                      if (!FirebaseAuth.instance.currentUser!.isAnonymous)
                        TextButton(
                          onPressed: () async {
                            // ユーザー情報を最新化
                            await FirebaseAuth.instance.currentUser!.reload();
                            final refreshedUser =
                                FirebaseAuth.instance.currentUser!;

                            // 最新の Google アカウントの表示名を取得
                            final googleName = refreshedUser.displayName ?? '';
                            debugPrint(
                              "Resetting name to Google account name: $googleName",
                            );
                            if (googleName.isEmpty) {
                              Navigator.pop(context);
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({
                                  'name': googleName,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                            Navigator.pop(context, googleName);
                          },
                          child: const Text('表示名リセット'),
                        ),
                    ],
                  );
                },
              );

              if (newName != null && newName.isNotEmpty) {
                setState(() {
                  if (!mounted) return;
                  _displayName = newName; // ← Firestoreの値を優先して表示
                });
              }
            },
            child: Text(
              'ログイン中: $_displayName',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(
            'UID: ${uid.substring(0, 8)}...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
