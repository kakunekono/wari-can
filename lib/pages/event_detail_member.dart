import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';

/// メンバー追加・編集・削除に関するロジック群。
///
/// UIから分離されたロジックとして、イベントの状態更新をコールバックで受け取ります。
/// 編集はローカルで完結し、保存時にのみ Firebase へ同期されます。

/// メンバー追加処理。
///
/// - 入力された名前が空でないかを確認します。
/// - 同名のメンバーがすでに存在する場合は追加を拒否します。
/// - 新しいメンバーを生成し、イベントに追加します。
/// - 成功後はコントローラーをクリアします。
Future<void> addMember(
  BuildContext context,
  Event event,
  TextEditingController controller, {
  required void Function(Event updated) onUpdate,
}) async {
  final name = controller.text.trim();
  if (name.isEmpty) return;

  if (event.members.any((m) => m.name == name)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「$name」はすでに登録されています')));
    return;
  }

  final now = DateTime.now();
  final newMember = Member(
    id: const Uuid().v4(),
    name: name,
    createAt: now,
    updateAt: now,
  );

  final updated = event.copyWith(
    members: [...event.members, newMember],
    updateAt: now,
  );

  onUpdate(updated);
  controller.clear();
}

/// メンバー削除処理。
///
/// - 対象メンバーが支出に使用されている場合は削除不可。
/// - 削除確認ダイアログを表示し、承認された場合のみ削除します。
Future<void> deleteMember(
  BuildContext context,
  Event event,
  String memberId, {
  required void Function(Event updated) onUpdate,
}) async {
  final member = event.members.firstWhere((m) => m.id == memberId);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("メンバー削除の確認"),
      content: Text("「${member.name}」を削除しますか？この操作は元に戻せません。"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text("削除"),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final used = event.details.any(
    (d) => d.payer == memberId || d.participants.contains(memberId),
  );

  if (used) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('このメンバーは支払に使用されています')));
    return;
  }

  final now = DateTime.now();
  final updatedMembers = event.members.where((m) => m.id != memberId).toList();
  final updated = event.copyWith(members: updatedMembers, updateAt: now);

  onUpdate(updated);

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text("「${member.name}」を削除しました")));
}

/// メンバー名編集処理。
///
/// - 編集ダイアログを表示し、変更された名前を反映します。
/// - 空文字や変更なしの場合は無視されます。
Future<void> editMemberName(
  BuildContext context,
  Event event,
  String memberId, {
  required void Function(Event updated) onUpdate,
}) async {
  final member = event.members.firstWhere((m) => m.id == memberId);
  final oldName = member.name;
  final controller = TextEditingController(text: oldName);

  final newName = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("メンバー名を編集"),
      content: TextField(controller: controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("OK"),
        ),
      ],
    ),
  );

  if (newName != null && newName.trim().isNotEmpty && newName != oldName) {
    final now = DateTime.now();
    final updatedMembers = event.members.map((m) {
      if (m.id == memberId) {
        return m.copyWith(name: newName.trim(), updateAt: now);
      }
      return m;
    }).toList();

    final updated = event.copyWith(members: updatedMembers, updateAt: now);
    onUpdate(updated);
  }
}

/// メンバー一覧セクションのUIを構築します。
///
/// - メンバー名入力欄と追加ボタンを表示します。
/// - 登録済みメンバーを一覧表示し、編集・削除ボタンを提供します。
Widget buildMemberSection(
  BuildContext context,
  Event event,
  TextEditingController controller, {
  required void Function(Event updated) onUpdate,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'メンバー名を入力',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () =>
                addMember(context, event, controller, onUpdate: onUpdate),
            icon: const Icon(Icons.person_add, color: Colors.blue),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'メンバー一覧',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      ...event.members.map(
        (m) => Card(
          child: ListTile(
            title: Text(m.name),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  onPressed: () =>
                      editMemberName(context, event, m.id, onUpdate: onUpdate),
                  icon: const Icon(Icons.edit, color: Colors.orange),
                ),
                IconButton(
                  onPressed: () =>
                      deleteMember(context, event, m.id, onUpdate: onUpdate),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
