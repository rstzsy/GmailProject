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
      // msgIdSnap.key là messageId
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
      if (msgSnap.exists) {
        final data = Map<String, dynamic>.from(msgSnap.value as Map);
        data['message_id'] = messageId;
        
        // Thêm thông tin receiver_id cho inbox (chính là currentUserId)
        data['receiver_id'] = currentUserId;
        
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
}