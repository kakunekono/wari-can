import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:wari_can/models/event.dart';
import 'package:wari_can/models/menber.dart';
import 'package:wari_can/utils/snackbar_utils.dart';

/// メンバー追加処理
///
/// 入力バリデーション（空文字・重複）を行い、新しい [Member] を生成します。
/// 更新は [onUpdate] コールバックを通じて親コンポーネントへ通知されます。
Future<void> addMember(
  BuildContext context,
  Event event,
  TextEditingController controller, {
  required void Function(Event updated) onUpdate,
}) async {
  final name = controller.text.trim();
  if (name.isEmpty) return;

  // 同じ名前のメンバーが既にいないかチェック
  if (event.members.any((m) => m.name == name)) {
    showAppSnackBar(
      context,
      message: '「$name」はすでに登録されています',
      type: SnackBarType.warning,
    );
    return;
  }

  final now = DateTime.now();
  final newMember = Member(
    id: const Uuid().v4(), // 一意のIDを発行
    name: name,
    createAt: now,
    updateAt: now,
  );

  // 既存のリストに新しいメンバーを追加した新しい Event インスタンスを生成
  final updated = event.copyWith(
    members: [...event.members, newMember],
    updateAt: now,
  );

  onUpdate(updated);
  controller.clear(); // 入力フィールドをリセット
}

/// メンバー削除処理
///
/// 1. 確認ダイアログの表示
/// 2. 使用状況チェック（支出明細に紐づいている場合は削除不可）
/// 3. リストからの除去
Future<void> deleteMember(
  BuildContext context,
  Event event,
  String memberId, {
  required void Function(Event updated) onUpdate,
}) async {
  final member = event.members.firstWhere((m) => m.id == memberId);

  // 削除の最終確認
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

  // 重要：このメンバーが「支払者」または「参加者」として支出に含まれているか確認
  final used = event.details.any(
    (d) => d.payer == memberId || d.participants.contains(memberId),
  );

  if (used) {
    showAppSnackBar(
      context,
      message: 'このメンバーは支払に使用されているため削除できません',
      type: SnackBarType.warning,
    );
    return;
  }

  final now = DateTime.now();
  final updatedMembers = event.members.where((m) => m.id != memberId).toList();
  final updated = event.copyWith(members: updatedMembers, updateAt: now);

  onUpdate(updated);

  showAppSnackBar(
    context,
    message: '「${member.name}」を削除しました',
    type: SnackBarType.info,
  );
}

/// メンバー名の編集処理
///
/// ダイアログを表示して名前の変更を受け付けます。
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
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: "新しい名前"),
      ),
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

  // 名前が変更されており、かつ空でない場合のみ更新
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

/// メンバー管理セクションのUI構築
///
/// 権限（Ownerかどうか）およびロック状態（自分が編集権を持っているか）に基づいて
/// 操作ボタン（追加・編集・削除）の表示を切り替えます。
Widget buildMemberSection(
  BuildContext context,
  Event event,
  TextEditingController controller, {
  required void Function(Event updated) onUpdate,
  required bool isLockedByMe,
}) {
  // 現在のユーザーがイベントのオーナーかどうかを判定
  final isOwner = event.ownerUid == FirebaseAuth.instance.currentUser?.uid;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 追加機能：オーナーのみに許可
      if (isOwner)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'メンバー名を入力',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onSubmitted: (_) =>
                    addMember(context, event, controller, onUpdate: onUpdate),
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

      // メンバーリストの表示
      if (event.members.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'メンバーが登録されていません',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        )
      else
        ...event.members.map(
          (m) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                m.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  // 編集・削除ボタン：オーナーであり、かつ自分が編集ロックを取得している時のみ表示
                  if (isOwner && isLockedByMe) ...[
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () => editMemberName(
                        context,
                        event,
                        m.id,
                        onUpdate: onUpdate,
                      ),
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () => deleteMember(
                        context,
                        event,
                        m.id,
                        onUpdate: onUpdate,
                      ),
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
