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
    final user = FirebaseAuth.instance.currentUser;
    _displayName = user?.displayName ?? '（未設定）';
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

                          await user.updateDisplayName(newName);
                          await user.reload();

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
                    ],
                  );
                },
              );

              if (newName != null && newName.isNotEmpty) {
                setState(() {
                  _displayName = newName; // ← 表示内容を更新
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
