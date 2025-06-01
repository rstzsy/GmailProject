import 'package:firebase_database/firebase_database.dart';

class MessageService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Lưu draft email
  Future<String> saveDraft({
    required String senderId,
    required String recipientPhone,
    required String subject,
    required String body,
    String? draftId,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    
    // Tìm recipient ID từ phone number
    String? recipientId;
    String recipientName = 'Unknown User';
    
    if (recipientPhone.isNotEmpty) {
      final usersSnapshot = await _db.child('users').get();
      for (var user in usersSnapshot.children) {
        if (user.child('phone_number').value == recipientPhone) {
          recipientId = user.key;
          recipientName = user.child('username').value?.toString() ?? 
                        user.child('name').value?.toString() ?? 
                        'Unknown User';
          break;
        }
      }
    }

    final draftData = {
      'sender_id': senderId,
      'recipient_phone': recipientPhone,
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      'subject': subject,
      'body': body,
      'updated_at': timestamp,
    };

    if (draftId != null) {
      // Cập nhật draft hiện có
      await _db.child('drafts').child(draftId).update(draftData);
      return draftId;
    } else {
      // Tạo draft mới
      draftData['created_at'] = timestamp;
      final draftRef = _db.child('drafts').push();
      await draftRef.set(draftData);
      return draftRef.key!;
    }
  }

  /// Lấy danh sách drafts của user
  Future<List<Map<String, dynamic>>> loadDrafts(String senderId) async {
    final draftsSnapshot = await _db.child('drafts').get();
    final List<Map<String, dynamic>> drafts = [];

    for (var draftSnap in draftsSnapshot.children) {
      final data = Map<String, dynamic>.from(draftSnap.value as Map);
      
      if (data['sender_id'] == senderId) {
        data['draft_id'] = draftSnap.key;
        drafts.add(data);
      }
    }

    // Sắp xếp theo thời gian cập nhật (mới nhất trước)
    drafts.sort((a, b) {
      final aTime = a['updated_at'] ?? a['created_at'] ?? '';
      final bTime = b['updated_at'] ?? b['created_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    return drafts;
  }

  /// Xóa draft
  Future<void> deleteDraft(String draftId) async {
    await _db.child('drafts').child(draftId).remove();
  }

  /// Lấy thông tin draft theo ID
  Future<Map<String, dynamic>?> getDraft(String draftId) async {
    final snapshot = await _db.child('drafts').child(draftId).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['draft_id'] = draftId;
      return data;
    }
    return null;
  }


  /// Lấy danh sách thư đã gửi của user với thông tin người nhận
  Future<List<Map<String, dynamic>>> loadSentMessages(String currentUserId) async {
    final messagesSnapshot = await _db.child('internal_messages').get();
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    
    final List<Map<String, dynamic>> messages = [];

    for (var msgSnap in messagesSnapshot.children) {
      final data = Map<String, dynamic>.from(msgSnap.value as Map);

      // Chỉ lấy tin nhắn của user hiện tại và chưa bị xóa
      if (data['sender_id'] == currentUserId && data['is_trashed'] != true) {
        data['message_id'] = msgSnap.key;

        // Lấy người nhận
        final messageId = msgSnap.key!;
        final messageRecipients = recipientsSnapshot.child(messageId);

        if (messageRecipients.exists) {
          final List<String> recipientIds = [];
          for (var recipientSnap in messageRecipients.children) {
            recipientIds.add(recipientSnap.key!);
          }

          data['recipient_ids'] = recipientIds;
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

  /// Lấy danh sách thư trong inbox của user (chỉ lấy thư chưa bị xóa)
  Future<List<Map<String, dynamic>>> loadInboxMessages(String currentUserId) async {
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    final List<String> messageIds = [];

    for (var msgIdSnap in recipientsSnapshot.children) {
      final recipients = msgIdSnap.children;
      for (var recipientSnap in recipients) {
        if (recipientSnap.key == currentUserId) {
          // Kiểm tra xem tin nhắn có bị xóa không
          final recipData = recipientSnap.value as Map<dynamic, dynamic>?;
          if (recipData == null || recipData['is_trashed_recip'] != true) {
            messageIds.add(msgIdSnap.key!);
          }
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

  /// Chuyển tin nhắn vào thùng rác
  Future<void> moveMessageToTrash(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      print('Debug - moveMessageToTrash called');
      print('Debug - messageId: $messageId');
      print('Debug - userId: $userId');
      print('Debug - isSender: $isSender');

      if (isSender) {
        // Nếu là người gửi, đánh dấu tin nhắn chính là đã xóa
        await _db.child('internal_messages').child(messageId).update({
          'is_trashed': true,
        });
        print('Debug - Updated internal_messages for sender');
      } else {
        // Nếu là người nhận, đánh dấu trong bảng recipients
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .update({'is_trashed_recip': true});
        print('Debug - Updated internal_message_recipients for receiver');
      }
      
      print('Debug - moveMessageToTrash completed successfully');
    } catch (e) {
      print('Lỗi khi chuyển vào thùng rác: $e');
      rethrow; 
    }
  }

  Future<List<Map<String, dynamic>>> loadTrashedSentMessages(String currentUserId) async {
    final messagesSnapshot = await _db.child('internal_messages').get();
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    
    final List<Map<String, dynamic>> messages = [];

    for (var msgSnap in messagesSnapshot.children) {
      final data = Map<String, dynamic>.from(msgSnap.value as Map);

      // Chỉ lấy tin nhắn của user hiện tại và ĐÃ BỊ XÓA
      if (data['sender_id'] == currentUserId && data['is_trashed'] == true) {
        data['message_id'] = msgSnap.key;

        // Lấy người nhận
        final messageId = msgSnap.key!;
        final messageRecipients = recipientsSnapshot.child(messageId);

        if (messageRecipients.exists) {
          final List<String> recipientIds = [];
          for (var recipientSnap in messageRecipients.children) {
            recipientIds.add(recipientSnap.key!);
          }

          data['recipient_ids'] = recipientIds;
          if (recipientIds.isNotEmpty) {
            data['receiver_id'] = recipientIds.first;
          }
        }

        messages.add(data);
      }
    }

    return messages;
  }

  /// Lấy danh sách thư trong inbox bị trash của user
  Future<List<Map<String, dynamic>>> loadTrashedInboxMessages(String currentUserId) async {
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    final List<String> messageIds = [];

    for (var msgIdSnap in recipientsSnapshot.children) {
      final recipients = msgIdSnap.children;
      for (var recipientSnap in recipients) {
        if (recipientSnap.key == currentUserId) {
          // Chỉ lấy tin nhắn ĐÃ BỊ XÓA
          final recipData = recipientSnap.value as Map<dynamic, dynamic>?;
          if (recipData != null && recipData['is_trashed_recip'] == true) {
            messageIds.add(msgIdSnap.key!);
          }
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
          data['is_trashed_recip'] = recipData['is_trashed_recip'] ?? false;
        } else {
          data['is_starred_recip'] = false;
          data['is_trashed_recip'] = false;
        }

        messages.add(data);
      }
    }

    return messages;
  }

  /// Method tổng hợp để lấy tất cả tin nhắn đã trash
  Future<List<Map<String, dynamic>>> loadAllTrashedMessages(String currentUserId) async {
    final trashedSent = await loadTrashedSentMessages(currentUserId);
    final trashedInbox = await loadTrashedInboxMessages(currentUserId);
    
    final allTrashed = [...trashedSent, ...trashedInbox];
    
    // Sắp xếp theo thời gian gửi (mới nhất trước)
    allTrashed.sort((a, b) {
      final aTime = a['sent_at'] ?? '';
      final bTime = b['sent_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    return allTrashed;
  }

  /// Khôi phục tin nhắn từ thùng rác
  Future<void> restoreMessageFromTrash(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        // Khôi phục cho sender
        await _db.child('internal_messages').child(messageId).update({
          'is_trashed': false,
        });
      } else {
        // Khôi phục cho receiver
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .update({'is_trashed_recip': false});
      }
    } catch (e) {
      print('Error restoring message: $e');
      rethrow;
    }
  }

  /// Xóa vĩnh viễn tin nhắn
  Future<void> permanentlyDeleteMessage(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        // Xóa hoàn toàn tin nhắn (chỉ nên làm nếu tất cả recipients cũng đã xóa)
        await _db.child('internal_messages').child(messageId).remove();
        await _db.child('internal_message_recipients').child(messageId).remove();
      } else {
        // Xóa recipient khỏi danh sách
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .remove();
      }
    } catch (e) {
      print('Error permanently deleting message: $e');
      rethrow;
    }
  }
}

