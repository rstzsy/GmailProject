import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LabelService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Tạo một label mới
  Future<void> createLabel(String labelName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print(' Người dùng chưa đăng nhập');
      return;
    }

    final newLabelRef = _dbRef.child('users').child(uid).child('labels').push();
    await newLabelRef.set({
      'name': labelName,
      'created_at': ServerValue.timestamp,
    });

    print('Đã tạo label: $labelName');
  }

  //  Lấy danh sách các label
  Future<List<Map<String, dynamic>>> getLabels() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print(' Người dùng chưa đăng nhập');
      return [];
    }

    try {
      final snapshot = await _dbRef.child('users').child(uid).child('labels').get();

      if (!snapshot.exists) {
        print(' Không có label nào tại /users/$uid/labels');
        return [];
      }

      final data = snapshot.value;
      if (data is! Map) {
        print(' Dữ liệu không đúng định dạng: $data');
        return [];
      }

      final labels = <Map<String, dynamic>>[];
      data.forEach((key, value) {
        if (value is Map) {
          labels.add({
            'id': key,
            'name': value['name']?.toString() ?? 'Label Không Tên',
            'created_at': value['created_at']?.toString() ?? '',
          });
        }
      });

      print(' Danh sách label: $labels');
      return labels;
    } catch (e) {
      print(' Lỗi khi lấy label: $e');
      return [];
    }
  }

  //  Cập nhật tên label
  Future<void> updateLabel(String labelId, String newName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('Người dùng chưa đăng nhập');
      return;
    }

    final labelRef = _dbRef.child('users').child(uid).child('labels').child(labelId);
    await labelRef.update({'name': newName});

    print('Đã cập nhật label $labelId thành "$newName"');
  }

  //  Xoá một label
  Future<void> deleteLabel(String labelId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print(' Người dùng chưa đăng nhập');
      return;
    }

    final labelRef = _dbRef.child('users').child(uid).child('labels').child(labelId);
    await labelRef.remove();

    print('Đã xoá label: $labelId');
  }

  //  Gắn messageId vào label
  Future<void> addMessageToLabel(String labelId, String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _dbRef
        .child('users')
        .child(uid)
        .child('labels')
        .child(labelId)
        .child('messages')
        .child(messageId)
        .set(true);

    print('Đã thêm message $messageId vào label $labelId');
  }

  //  Gỡ messageId khỏi label
  Future<void> removeMessageFromLabel(String labelId, String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _dbRef
        .child('users')
        .child(uid)
        .child('labels')
        .child(labelId)
        .child('messages')
        .child(messageId)
        .remove();

    print('Đã gỡ message $messageId khỏi label $labelId');
  }

  //  Lấy danh sách messageId từ label
  Future<List<String>> getMessageIdsFromLabel(String labelId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _dbRef
        .child('users')
        .child(uid)
        .child('labels')
        .child(labelId)
        .child('messages')
        .get();

    if (!snapshot.exists) return [];

    return snapshot.children.map((e) => e.key!).toList();
  }
}
