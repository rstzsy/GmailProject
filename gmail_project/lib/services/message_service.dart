import 'package:firebase_database/firebase_database.dart';

class MessageService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Lưu draft email với hỗ trợ CC, BCC và HTML body
  Future<String> saveDraft({
    required String senderId,
    required String recipientPhone,
    String? ccPhones,
    String? bccPhones,
    required String subject,
    required String body,
    String? htmlBody,
    String? draftId,
    required List<Map<String, String>> attachments,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    
    // Tìm recipient ID từ phone number (TO)
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

    // Xử lý CC recipients
    List<Map<String, String>> ccRecipients = [];
    if (ccPhones != null && ccPhones.isNotEmpty) {
      ccRecipients = await _parseAndValidateRecipients(ccPhones);
    }

    // Xử lý BCC recipients
    List<Map<String, String>> bccRecipients = [];
    if (bccPhones != null && bccPhones.isNotEmpty) {
      bccRecipients = await _parseAndValidateRecipients(bccPhones);
    }

    final draftData = {
      'sender_id': senderId,
      'recipient_phone': recipientPhone,
      'recipient_id': recipientId,
      'recipient_name': recipientName,
      'cc_phones': ccPhones ?? '',
      'bcc_phones': bccPhones ?? '',
      'cc_recipients': ccRecipients,
      'bcc_recipients': bccRecipients,
      'subject': subject,
      'body': body,
      'html_body': htmlBody ?? '',
      'attachments': attachments,
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

  /// Parse và validate danh sách phone numbers
  Future<List<Map<String, String>>> _parseAndValidateRecipients(String phones) async {
    final List<Map<String, String>> recipients = [];
    final phoneList = phones.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    if (phoneList.isEmpty) return recipients;

    final usersSnapshot = await _db.child('users').get();
    
    for (String phone in phoneList) {
      for (var user in usersSnapshot.children) {
        if (user.child('phone_number').value == phone) {
          recipients.add({
            'user_id': user.key!,
            'phone': phone,
            'name': user.child('username').value?.toString() ?? 
                   user.child('name').value?.toString() ?? 
                   'Unknown User',
          });
          break;
        }
      }
    }

    return recipients;
  }

  /// Gửi message với CC, BCC và HTML body
  Future<String> sendMessage({
    required String senderId,
    required String recipientPhone,
    String? ccPhones,
    String? bccPhones,
    required String subject,
    required String body,
    String? htmlBody,
    required List<Map<String, String>> attachments,
  }) async {
    final timestamp = DateTime.now().toIso8601String();

    // Validate và lấy thông tin recipients
    final toRecipients = recipientPhone.isNotEmpty 
        ? await _parseAndValidateRecipients(recipientPhone) 
        : <Map<String, String>>[];
    
    final ccRecipients = ccPhones != null && ccPhones.isNotEmpty 
        ? await _parseAndValidateRecipients(ccPhones) 
        : <Map<String, String>>[];
    
    final bccRecipients = bccPhones != null && bccPhones.isNotEmpty 
        ? await _parseAndValidateRecipients(bccPhones) 
        : <Map<String, String>>[];

    // Tạo message
    final messageRef = _db.child('internal_messages').push();
    final messageId = messageRef.key!;

    Map<String, dynamic> messageData = {
      'sender_id': senderId,
      'subject': subject,
      'body': body,
      'html_body': htmlBody ?? '',
      'sent_at': timestamp,
      'is_draft': false,
      'is_starred': false,
      'is_read': false,
      'is_trashed': false,
      'has_cc': ccRecipients.isNotEmpty,
      'has_bcc': bccRecipients.isNotEmpty,
      'cc_count': ccRecipients.length,
      'bcc_count': bccRecipients.length,
    };

    if (attachments.isNotEmpty) {
      messageData['attachments'] = attachments;
      messageData['has_attachments'] = true;
      messageData['attachment_count'] = attachments.length;
    }

    await messageRef.set(messageData);

    // Lưu recipients với loại (TO, CC, BCC)
    final allRecipients = [
      ...toRecipients.map((r) => {...r, 'type': 'TO'}),
      ...ccRecipients.map((r) => {...r, 'type': 'CC'}),
      ...bccRecipients.map((r) => {...r, 'type': 'BCC'}),
    ];

    for (var recipient in allRecipients) {
      await _db
          .child('internal_message_recipients')
          .child(messageId)
          .child(recipient['user_id']!)
          .set({
        'recipient_type': recipient['type'],
        'recipient_phone': recipient['phone'],
        'recipient_name': recipient['name'],
        'is_draft_recip': false,
        'is_starred_recip': false,
        'is_read_recip': false,
        'is_trashed_recip': false,
        'received_at': timestamp,
      });

      // Tạo notification
      await _createNotification(
        recipientId: recipient['user_id']!,
        senderId: senderId,
        messageId: messageId,
        subject: subject,
        recipientType: recipient['type']!,
        hasAttachments: attachments.isNotEmpty,
        attachmentCount: attachments.length,
      );
    }

    return messageId;
  }

  /// Tạo notification cho recipient
  Future<void> _createNotification({
    required String recipientId,
    required String senderId,
    required String messageId,
    required String subject,
    required String recipientType,
    bool hasAttachments = false,
    int attachmentCount = 0,
  }) async {
    // Lấy thông tin sender
    final senderInfo = await getUserInfo(senderId);
    final senderName = senderInfo?['username'] ?? 
                      senderInfo?['name'] ?? 
                      senderInfo?['email'] ?? 
                      'Unknown Sender';

    String notificationBody = 'From: $senderName\nSubject: $subject';
    
    if (recipientType == 'CC') {
      notificationBody = 'CC: $senderName\nSubject: $subject';
    } else if (recipientType == 'BCC') {
      notificationBody = 'BCC: $senderName\nSubject: $subject';
    }

    if (hasAttachments) {
      notificationBody += '\n📎 $attachmentCount attachment(s)';
    }

    final notificationRef = _db.child('notifications').child(recipientId).push();
    await notificationRef.set({
      'title': 'You have a new message',
      'body': notificationBody,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
      'message_id': messageId,
      'recipient_type': recipientType,
      'is_read': false,
    });
  }

  /// Lấy danh sách drafts của user (đã cập nhật để hỗ trợ CC/BCC)
  Future<List<Map<String, dynamic>>> loadDrafts(String senderId) async {
    final draftsSnapshot = await _db.child('drafts').get();
    final List<Map<String, dynamic>> drafts = [];

    for (var draftSnap in draftsSnapshot.children) {
      final data = Map<String, dynamic>.from(draftSnap.value as Map);
      
      if (data['sender_id'] == senderId) {
        data['draft_id'] = draftSnap.key;
        
        // Đảm bảo backward compatibility
        data['cc_phones'] = data['cc_phones'] ?? '';
        data['bcc_phones'] = data['bcc_phones'] ?? '';
        data['html_body'] = data['html_body'] ?? '';
        data['attachments'] = data['attachments'] ?? [];
        data['cc_recipients'] = data['cc_recipients'] ?? [];
        data['bcc_recipients'] = data['bcc_recipients'] ?? [];
        
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

  /// Lấy danh sách thư đã gửi với thông tin CC/BCC
  Future<List<Map<String, dynamic>>> loadSentMessages(String currentUserId) async {
    final messagesSnapshot = await _db.child('internal_messages').get();
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    
    final List<Map<String, dynamic>> messages = [];

    for (var msgSnap in messagesSnapshot.children) {
      final data = Map<String, dynamic>.from(msgSnap.value as Map);

      // Chỉ lấy tin nhắn của user hiện tại và chưa bị xóa
      if (data['sender_id'] == currentUserId && data['is_trashed'] != true) {
        data['message_id'] = msgSnap.key;

        // Lấy thông tin recipients chi tiết
        final messageId = msgSnap.key!;
        final messageRecipients = recipientsSnapshot.child(messageId);

        if (messageRecipients.exists) {
          final Map<String, List<Map<String, String>>> recipientsByType = {
            'TO': [],
            'CC': [],
            'BCC': [],
          };

          for (var recipientSnap in messageRecipients.children) {
            final recipientData = Map<String, dynamic>.from(recipientSnap.value as Map);
            final recipientType = recipientData['recipient_type'] ?? 'TO';
            
            recipientsByType[recipientType]!.add({
              'user_id': recipientSnap.key!,
              'name': recipientData['recipient_name'] ?? 'Unknown User',
              'phone': recipientData['recipient_phone'] ?? '',
            });
          }

          data['to_recipients'] = recipientsByType['TO'];
          data['cc_recipients'] = recipientsByType['CC'];
          data['bcc_recipients'] = recipientsByType['BCC'];
          
          // Backward compatibility
          final allRecipientIds = [
            ...recipientsByType['TO']!.map((r) => r['user_id']!),
            ...recipientsByType['CC']!.map((r) => r['user_id']!),
            ...recipientsByType['BCC']!.map((r) => r['user_id']!),
          ];
          data['recipient_ids'] = allRecipientIds;
          
          if (allRecipientIds.isNotEmpty) {
            data['receiver_id'] = allRecipientIds.first;
          }
        }

        // Đảm bảo backward compatibility cho các trường mới
        data['html_body'] = data['html_body'] ?? '';
        data['has_cc'] = data['has_cc'] ?? false;
        data['has_bcc'] = data['has_bcc'] ?? false;
        data['cc_count'] = data['cc_count'] ?? 0;
        data['bcc_count'] = data['bcc_count'] ?? 0;
        data['has_attachments'] = data['has_attachments'] ?? false;
        data['attachment_count'] = data['attachment_count'] ?? 0;

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

  /// Lấy danh sách thư trong inbox với thông tin CC/BCC
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

      if (msgSnap.exists && recipSnap.exists) {
        final data = Map<String, dynamic>.from(msgSnap.value as Map);
        final recipData = Map<String, dynamic>.from(recipSnap.value as Map);
        
        data['message_id'] = messageId;
        data['receiver_id'] = currentUserId;
        data['is_starred_recip'] = recipData['is_starred_recip'] ?? false;
        data['is_read_recip'] = recipData['is_read_recip'] ?? false;
        data['recipient_type'] = recipData['recipient_type'] ?? 'TO';
        data['received_at'] = recipData['received_at'] ?? data['sent_at'];

        // Đảm bảo backward compatibility
        data['html_body'] = data['html_body'] ?? '';
        data['has_cc'] = data['has_cc'] ?? false;
        data['has_bcc'] = data['has_bcc'] ?? false;
        data['cc_count'] = data['cc_count'] ?? 0;
        data['bcc_count'] = data['bcc_count'] ?? 0;
        data['has_attachments'] = data['has_attachments'] ?? false;
        data['attachment_count'] = data['attachment_count'] ?? 0;

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

  /// Đánh dấu tin nhắn đã đọc
  Future<void> markMessageAsRead(String messageId, String userId, {bool isSender = false}) async {
    try {
      if (isSender) {
        await _db.child('internal_messages').child(messageId).update({
          'is_read': true,
        });
      } else {
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .update({'is_read_recip': true});
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Lấy chi tiết message với HTML body
  Future<Map<String, dynamic>?> getMessageDetail(String messageId, String userId) async {
    try {
      final msgSnap = await _db.child('internal_messages').child(messageId).get();
      if (!msgSnap.exists) return null;

      final data = Map<String, dynamic>.from(msgSnap.value as Map);
      data['message_id'] = messageId;

      // Lấy thông tin recipient
      final recipSnap = await _db
          .child('internal_message_recipients')
          .child(messageId)
          .child(userId)
          .get();

      if (recipSnap.exists) {
        final recipData = Map<String, dynamic>.from(recipSnap.value as Map);
        data['recipient_type'] = recipData['recipient_type'] ?? 'TO';
        data['is_starred_recip'] = recipData['is_starred_recip'] ?? false;
        data['is_read_recip'] = recipData['is_read_recip'] ?? false;
      }

      // Lấy tất cả recipients
      final allRecipientsSnap = await _db
          .child('internal_message_recipients')
          .child(messageId)
          .get();

      if (allRecipientsSnap.exists) {
        final Map<String, List<Map<String, String>>> recipientsByType = {
          'TO': [],
          'CC': [],
          'BCC': [],
        };

        for (var recipientSnap in allRecipientsSnap.children) {
          final recipientData = Map<String, dynamic>.from(recipientSnap.value as Map);
          final recipientType = recipientData['recipient_type'] ?? 'TO';
          
          // Chỉ hiển thị BCC cho sender hoặc chính người nhận BCC đó
          if (recipientType == 'BCC' && 
              data['sender_id'] != userId && 
              recipientSnap.key != userId) {
            continue;
          }
          
          recipientsByType[recipientType]!.add({
            'user_id': recipientSnap.key!,
            'name': recipientData['recipient_name'] ?? 'Unknown User',
            'phone': recipientData['recipient_phone'] ?? '',
          });
        }

        data['to_recipients'] = recipientsByType['TO'];
        data['cc_recipients'] = recipientsByType['CC'];
        data['bcc_recipients'] = recipientsByType['BCC'];
      }

      // Đảm bảo có HTML body
      data['html_body'] = data['html_body'] ?? '';
      
      return data;
    } catch (e) {
      print('Error getting message detail: $e');
      return null;
    }
  }

  // Các methods khác giữ nguyên từ code cũ...
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

  Future<void> updateStarStatus(
    String messageId,
    bool isStarred,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        await _db.child('internal_messages').child(messageId).update({
          'is_starred': isStarred,
        });
      } else {
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

  Future<void> moveMessageToTrash(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        await _db.child('internal_messages').child(messageId).update({
          'is_trashed': true,
        });
      } else {
        await _db
            .child('internal_message_recipients')
            .child(messageId)
            .child(userId)
            .update({'is_trashed_recip': true});
      }
    } catch (e) {
      print('Error moving message to trash: $e');
      rethrow;
    }
  }

  Future<void> restoreMessageFromTrash(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        await _db.child('internal_messages').child(messageId).update({
          'is_trashed': false,
        });
      } else {
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

  Future<void> permanentlyDeleteMessage(
    String messageId,
    String userId, {
    bool isSender = false,
  }) async {
    try {
      if (isSender) {
        await _db.child('internal_messages').child(messageId).remove();
        await _db.child('internal_message_recipients').child(messageId).remove();
      } else {
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

  Future<void> deleteDraft(String draftId) async {
    await _db.child('drafts').child(draftId).remove();
  }

  Future<Map<String, dynamic>?> getDraft(String draftId) async {
    final snapshot = await _db.child('drafts').child(draftId).get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data['draft_id'] = draftId;
      
      // Đảm bảo backward compatibility
      data['cc_phones'] = data['cc_phones'] ?? '';
      data['bcc_phones'] = data['bcc_phones'] ?? '';
      data['html_body'] = data['html_body'] ?? '';
      data['attachments'] = data['attachments'] ?? [];
      data['cc_recipients'] = data['cc_recipients'] ?? [];
      data['bcc_recipients'] = data['bcc_recipients'] ?? [];
      
      return data;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> loadTrashedSentMessages(String currentUserId) async {
    final messagesSnapshot = await _db.child('internal_messages').get();
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    
    final List<Map<String, dynamic>> messages = [];

    for (var msgSnap in messagesSnapshot.children) {
      final data = Map<String, dynamic>.from(msgSnap.value as Map);

      if (data['sender_id'] == currentUserId && data['is_trashed'] == true) {
        data['message_id'] = msgSnap.key;

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

  Future<List<Map<String, dynamic>>> loadTrashedInboxMessages(String currentUserId) async {
    final recipientsSnapshot = await _db.child('internal_message_recipients').get();
    final List<String> messageIds = [];

    for (var msgIdSnap in recipientsSnapshot.children) {
      final recipients = msgIdSnap.children;
      for (var recipientSnap in recipients) {
        if (recipientSnap.key == currentUserId) {
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
        }

        messages.add(data);
      }
    }

    return messages;
  }

  Future<List<Map<String, dynamic>>> loadAllTrashedMessages(String currentUserId) async {
    final trashedSent = await loadTrashedSentMessages(currentUserId);
    final trashedInbox = await loadTrashedInboxMessages(currentUserId);
    
    final allTrashed = [...trashedSent, ...trashedInbox];
    
    allTrashed.sort((a, b) {
      final aTime = a['sent_at'] ?? '';
      final bTime = b['sent_at'] ?? '';
      return bTime.compareTo(aTime);
    });

    return allTrashed;
  }
}