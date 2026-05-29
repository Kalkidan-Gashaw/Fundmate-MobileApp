import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'storage_upload_service.dart';

class ChatService {
  static CollectionReference<Map<String, dynamic>> get _chats =>
      FirebaseFirestore.instance.collection('chats');

  static String investmentChatId(String startupId, String investorId) =>
      'inv_${startupId}_$investorId';

  // ——— Chat rooms ———

  static Future<void> ensureChatRoom({
    required String mentorshipRequestId,
    required String mentorId,
    required String entrepreneurId,
    required String mentorName,
    required String entrepreneurName,
    required String startupName,
  }) async {
    final chatRef = _chats.doc(mentorshipRequestId);
    if ((await chatRef.get()).exists) return;

    await chatRef.set({
      'chatType': 'mentorship',
      'mentorshipRequestId': mentorshipRequestId,
      'mentorId': mentorId,
      'entrepreneurId': entrepreneurId,
      'mentorName': mentorName,
      'entrepreneurName': entrepreneurName,
      'startupName': startupName,
      'participantIds': [mentorId, entrepreneurId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCounts': {mentorId: 0, entrepreneurId: 0},
      'lastReadAt': <String, dynamic>{},
    });
  }

  static Future<void> ensureChatRoomFromRequest(
    String mentorshipRequestId,
    Map<String, dynamic> requestData,
  ) {
    final mentorId = requestData['mentorId']?.toString();
    final entrepreneurId = requestData['entrepreneurId']?.toString();
    if (mentorId == null || entrepreneurId == null) {
      throw Exception('Invalid mentorship request data');
    }
    return ensureChatRoom(
      mentorshipRequestId: mentorshipRequestId,
      mentorId: mentorId,
      entrepreneurId: entrepreneurId,
      mentorName: requestData['mentorName']?.toString() ?? 'Mentor',
      entrepreneurName:
          requestData['entrepreneurName']?.toString() ?? 'Entrepreneur',
      startupName: requestData['startupName']?.toString() ?? 'Startup',
    );
  }

  static Future<String> ensureInvestmentChat({
    required String startupId,
    required String investorId,
    required String investorName,
    required String entrepreneurId,
    required String entrepreneurName,
    required String startupName,
  }) async {
    final chatId = investmentChatId(startupId, investorId);
    final chatRef = _chats.doc(chatId);
    if ((await chatRef.get()).exists) return chatId;

    await chatRef.set({
      'chatType': 'investment',
      'startupId': startupId,
      'investorId': investorId,
      'investorName': investorName,
      'entrepreneurId': entrepreneurId,
      'entrepreneurName': entrepreneurName,
      'startupName': startupName,
      'participantIds': [investorId, entrepreneurId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCounts': {investorId: 0, entrepreneurId: 0},
      'lastReadAt': <String, dynamic>{},
    });
    return chatId;
  }

  static Future<String> ensureInvestmentChatFromStartup(
    String startupId,
    String investorId,
    String investorName,
  ) async {
    final startupDoc = await FirebaseFirestore.instance
        .collection('startups')
        .doc(startupId)
        .get();
    if (!startupDoc.exists) throw Exception('Startup not found');

    final data = startupDoc.data()!;
    final entrepreneurId = data['entrepreneurId']?.toString();
    if (entrepreneurId == null) throw Exception('Invalid startup');

    return ensureInvestmentChat(
      startupId: startupId,
      investorId: investorId,
      investorName: investorName,
      entrepreneurId: entrepreneurId,
      entrepreneurName: data['entrepreneurName']?.toString() ??
          data['name']?.toString() ??
          'Entrepreneur',
      startupName: data['name']?.toString() ?? 'Startup',
    );
  }

  static String? recipientId(Map<String, dynamic> chat, String senderId) {
    final participants =
        (chat['participantIds'] as List?)?.cast<String>() ?? [];
    for (final id in participants) {
      if (id != senderId) return id;
    }
    return null;
  }

  static String displayTitle(Map<String, dynamic> chat, String currentUserId) {
    final type = chat['chatType']?.toString() ?? 'mentorship';
    if (type == 'investment') {
      if (currentUserId == chat['investorId']) {
        return chat['entrepreneurName']?.toString() ?? 'Entrepreneur';
      }
      return chat['investorName']?.toString() ?? 'Investor';
    }
    if (currentUserId == chat['mentorId']) {
      return chat['entrepreneurName']?.toString() ?? 'Mentee';
    }
    return chat['mentorName']?.toString() ?? 'Mentor';
  }

  static String displaySubtitle(Map<String, dynamic> chat) {
    final startup = chat['startupName']?.toString() ?? '';
    final type = chat['chatType']?.toString() ?? '';
    if (type == 'investment')
      return startup.isEmpty ? 'Investor chat' : startup;
    return startup.isEmpty ? 'Mentorship' : startup;
  }

  // ——— Messages ———

  static Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    Map<String, dynamic>? forwardedFrom,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _sendMessagePayload(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      lastMessagePreview: trimmed,
      payload: {
        'type': 'text',
        'text': trimmed,
        'senderId': senderId,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': {senderId: FieldValue.serverTimestamp()},
        if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
      },
    );
  }

  /// Forwards an existing text or file message (optionally with a new comment).
  static Future<void> sendForwardedMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required Map<String, dynamic> forwardedFrom,
    String? comment,
  }) async {
    final type = forwardedFrom['type']?.toString() ?? 'text';
    final trimmedComment = comment?.trim() ?? '';

    if (type == 'file') {
      final fileName = forwardedFrom['fileName']?.toString() ?? 'file';
      final fileUrl = forwardedFrom['fileUrl']?.toString() ?? '';
      if (fileUrl.isEmpty) {
        throw Exception('Forwarded file is missing a download URL');
      }

      final storagePath = forwardedFrom['storagePath']?.toString();
      final preview = trimmedComment.isNotEmpty
          ? trimmedComment
          : '📎 $fileName (forwarded)';

      await _sendMessagePayload(
        chatId: chatId,
        senderId: senderId,
        senderName: senderName,
        lastMessagePreview: preview,
        payload: {
          'type': 'file',
          'text': trimmedComment,
          'fileUrl': fileUrl,
          'fileName': fileName,
          if (storagePath != null && storagePath.isNotEmpty)
            'storagePath': storagePath,
          'senderId': senderId,
          'senderName': senderName,
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': {senderId: FieldValue.serverTimestamp()},
          'forwardedFrom': forwardedFrom,
        },
      );
      return;
    }

    final originalText = forwardedFrom['text']?.toString() ?? '';
    final body =
        trimmedComment.isNotEmpty ? trimmedComment : originalText;
    if (body.isEmpty) {
      throw Exception('Nothing to forward');
    }

    await _sendMessagePayload(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      lastMessagePreview: body,
      payload: {
        'type': 'text',
        'text': body,
        'senderId': senderId,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': {senderId: FieldValue.serverTimestamp()},
        'forwardedFrom': forwardedFrom,
      },
    );
  }

  static Future<void> sendFileMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required Uint8List data,
    required String fileName,
  }) async {
    final safeName = StorageUploadService.sanitizeFileName(fileName);
    final objectPath =
        'chat_files/$chatId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final url = await StorageUploadService.uploadBytes(
      objectPath: objectPath,
      data: data,
      fileName: safeName,
    );

    await _sendMessagePayload(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      lastMessagePreview: '📎 $safeName',
      payload: {
        'type': 'file',
        'text': '',
        'fileUrl': url,
        'fileName': safeName,
        'storagePath': objectPath,
        'senderId': senderId,
        'senderName': senderName,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': {senderId: FieldValue.serverTimestamp()},
      },
    );
  }

  static Future<void> _sendMessagePayload({
    required String chatId,
    required String senderId,
    required String senderName,
    required String lastMessagePreview,
    required Map<String, dynamic> payload,
  }) async {
    final chatRef = _chats.doc(chatId);
    final chatDoc = await chatRef.get();
    final chatData = chatDoc.data();

    final messageRef = chatRef.collection('messages').doc();
    final batch = FirebaseFirestore.instance.batch();

    batch.set(messageRef, payload);

    final updates = <String, dynamic>{
      'lastMessage': lastMessagePreview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
    };

    if (chatData != null) {
      final rid = recipientId(chatData, senderId);
      if (rid != null) {
        updates['unreadCounts.$rid'] = FieldValue.increment(1);
      }
    }

    batch.update(chatRef, updates);
    await batch.commit();
  }

  static Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'text': trimmed,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _chats.doc(chatId).collection('messages').doc(messageId).update({
      'deleted': true,
      'text': 'This message was deleted',
    });
  }

  static Future<void> markAsRead(String chatId, String userId) async {
    final chatRef = _chats.doc(chatId);
    final snap = await chatRef.get();
    if (!snap.exists) return;

    // Ensure user read cursor is not behind lastMessageAt.
    Object readAt = FieldValue.serverTimestamp();
    final lastMessageAt = snap.data()?['lastMessageAt'];
    if (lastMessageAt is Timestamp) {
      readAt = lastMessageAt;
    }

    await chatRef.update({
      'unreadCounts.$userId': 0,
      'lastReadAt.$userId': readAt,
    });
  }

  static bool isMessageSeen(
    Map<String, dynamic> message,
    Map<String, dynamic> chat,
    String senderId,
  ) {
    if (message['senderId'] != senderId) return false;
    final recipient = recipientId(chat, senderId);
    if (recipient == null) return false;

    final readBy = message['readBy'];
    if (readBy is Map && readBy[recipient] != null) return true;

    final lastReadAt = chat['lastReadAt'];
    final msgTime = message['createdAt'];
    if (lastReadAt is Map && msgTime is Timestamp) {
      final recipientRead = lastReadAt[recipient];
      if (recipientRead is Timestamp) {
        return recipientRead.compareTo(msgTime) >= 0;
      }
    }
    return false;
  }

  static int unreadCountForUser(Map<String, dynamic> chat, String userId) {
    final counts = chat['unreadCounts'];
    if (counts is Map) {
      final value = counts[userId];
      if (value is num) return value.toInt().clamp(0, 999);
    }
    if (isChatUnread(chat, userId)) return 1;
    return 0;
  }

  static bool isChatUnread(Map<String, dynamic> chat, String userId) {
    final lastSenderId = chat['lastSenderId']?.toString();
    final lastMessage = chat['lastMessage']?.toString().trim() ?? '';
    if (lastMessage.isEmpty || lastSenderId == null || lastSenderId == userId) {
      return false;
    }
    final lastMessageAt = chat['lastMessageAt'];
    if (lastMessageAt is! Timestamp) return true;
    final lastReadAt = chat['lastReadAt'];
    if (lastReadAt is! Map) return true;
    final userRead = lastReadAt[userId];
    if (userRead is! Timestamp) return true;
    return lastMessageAt.compareTo(userRead) > 0;
  }

  static int totalUnreadFromChats(
    Iterable<Map<String, dynamic>> chats,
    String userId,
  ) {
    var total = 0;
    for (final chat in chats) {
      total += unreadCountForUser(chat, userId);
    }
    return total;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(
    String chatId,
  ) {
    return _chats.doc(chatId).collection('messages').snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> chatsForUser(
    String userId,
  ) {
    return _chats.where('participantIds', arrayContains: userId).snapshots();
  }

  static DocumentReference<Map<String, dynamic>> chatRef(String chatId) =>
      _chats.doc(chatId);
}
