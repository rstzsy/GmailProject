import 'package:firebase_database/firebase_database.dart';

class MessageService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Lấy danh sách thư đã gửi của user với thông tin người nhận
  Future<List<Map<String, dynamic>>> loadSentMessages(String currentUserId) async {
    final messagesSnapshot = await _db.child('internal_messages').get();
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    
    final List<Map<String, dynamic>> messages = [];

    for (var msgSnap in messagesSnapshot.children) {
      final data = Map<String, dynamic>.from(msgSnap.value as Map);
      
      // Chỉ lấy tin nhắn do user hiện tại gửi
      if (data['sender_id'] == currentUserId) {
        data['message_id'] = msgSnap.key;
        
        // Tìm người nhận của tin nhắn này
        final messageId = msgSnap.key!;
        final messageRecipients = recipientsSnapshot.child(messageId);
        
        if (messageRecipients.exists) {
          // Lấy danh sách người nhận
          final List<String> recipientIds = [];
          for (var recipientSnap in messageRecipients.children) {
            recipientIds.add(recipientSnap.key!);
          }
          
          // Thêm thông tin người nhận vào data
          data['recipient_ids'] = recipientIds;
          // Nếu chỉ có 1 người nhận, set receiver_id để tương thích
          if (recipientIds.isNotEmpty) {
            data['receiver_id'] = recipientIds.first;
          }
        }
        
        messages.add(data);
      }
    }

    // Sắp xếp theo thời gian gửi (mới nhất trước)
    messages.sort((a, b) {
      final aTime = a['sent_at'] ?? '';
      final bTime = b['sent_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    return messages;
  }

  /// Lấy danh sách thư trong inbox của user
  Future<List<Map<String, dynamic>>> loadInboxMessages(String currentUserId) async {
  final recipientsSnapshot = await _db.child('internal_message_recipients').get();
  final List<String> messageIds = [];

  for (var msgIdSnap in recipientsSnapshot.children) {
    final recipients = msgIdSnap.children;
    for (var recipientSnap in recipients) {
      if (recipientSnap.key == currentUserId) {
        messageIds.add(msgIdSnap.key!);
        break;
      }
    }
  }

  final messages = <Map<String, dynamic>>[];
    for (var messageId in messageIds) {
      final msgSnap = await _db.child('internal_messages').child(messageId).get();
      final recipSnap = await _db
          .child('internal_message_recipients')
          .child(messageId)
          .child(currentUserId)
          .get();

      if (msgSnap.exists) {
        final data = Map<String, dynamic>.from(msgSnap.value as Map);
        data['message_id'] = messageId;
        data['receiver_id'] = currentUserId;

        if (recipSnap.exists) {
          final recipData = Map<String, dynamic>.from(recipSnap.value as Map);
          data['is_starred_recip'] = recipData['is_starred_recip'] ?? false;
        } else {
          data['is_starred_recip'] = false;
        }

        messages.add(data);
      }
    }

    // Sắp xếp theo thời gian gửi
    messages.sort((a, b) {
      final aTime = a['sent_at'] ?? '';
      final bTime = b['sent_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    return messages;
  }


  /// Lấy thông tin user theo ID
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final snapshot = await _db.child('users/$userId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      print('Error getting user info: $e');
    }
    return null;
  }

  /// Lấy danh sách tên người nhận theo list IDs
  Future<List<String>> getRecipientNames(List<String> recipientIds) async {
    final List<String> names = [];
    
    for (String recipientId in recipientIds) {
      final userInfo = await getUserInfo(recipientId);
      if (userInfo != null) {
        final name = userInfo['username'] ?? userInfo['name'] ?? 'Unknown User';
        names.add(name);
      } else {
        names.add('Unknown User');
      }
    }
    
    return names;
  }

  /// Cập nhật trạng thái đánh dấu sao cho tin nhắn
  Future<void> updateStarStatus(
    String messageId,
    bool isStarred,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        // Cập nhật trạng thái sao chung cho tin nhắn (dành cho sender)
        await _db.child('internal_messages').child(messageId).update({
          'is_starred': isStarred,
        });
      } else {
        // Cập nhật trạng thái sao cho từng người nhận trong internal_message_recipients
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .update({'is_starred_recip': isStarred});
      }
    } catch (e) {
      print('Error updating star status: $e');
    }
  }


}