import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../components/dialog.dart';
import '../services/message_service.dart';

class ComposeEmailPage extends StatefulWidget {
  final String? draftId;
  final String? initialTo;
  final String? initialSubject;
  final String? initialBody;
  
  const ComposeEmailPage({
    super.key,
    this.draftId,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
  });

  @override
  State<ComposeEmailPage> createState() => _ComposeEmailPageState();
}

class _ComposeEmailPageState extends State<ComposeEmailPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController ccController = TextEditingController();
  final TextEditingController bccController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  
  
  // WYSIWYG Editor
  late QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<XFile> _attachedImages = [];
  List<Map<String, String>> _uploadedAttachments = [];
  final MessageService _messageService = MessageService();
  
  bool _hasUnsavedChanges = false;
  bool _isUploading = false;
  String? _currentDraftId;
  
  // UI State
  bool _showCC = false;
  bool _showBCC = false;
  bool _isAdvancedMode = false;

  @override
  void initState() {
    super.initState();
    _initializeQuillController();
    _loadCurrentUserName();
    _initializeFields();
    _setupChangeListeners();
  }

  void _initializeQuillController() {
    _quillController = QuillController.basic();
    if (widget.initialBody != null && widget.initialBody!.isNotEmpty) {
      // Parse HTML content if needed
      _quillController.document = Document()..insert(0, widget.initialBody!);
    }
    _quillController.addListener(_onContentChanged);
  }

  void _initializeFields() {
    if (widget.draftId != null) {
      _currentDraftId = widget.draftId;
    }
    
    toController.text = widget.initialTo ?? '';
    subjectController.text = widget.initialSubject ?? '';
  }

  void _setupChangeListeners() {
    toController.addListener(_onContentChanged);
    ccController.addListener(_onContentChanged);
    bccController.addListener(_onContentChanged);
    subjectController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _loadCurrentUserName() async {
    final auth = FirebaseAuth.instance;
    final database = FirebaseDatabase.instance.ref();

    final currentUser = auth.currentUser;
    if (currentUser != null) {
      final userSnapshot = await database.child('users').child(currentUser.uid).get();
      final username = userSnapshot.child('username').value?.toString() ?? currentUser.email!;
      setState(() {
        fromController.text = username;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedImages = await _picker.pickMultiImage();
    if (pickedImages != null && pickedImages.isNotEmpty) {
      setState(() {
        _attachedImages = pickedImages;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<List<Map<String, String>>> _uploadAttachments() async {
    if (_attachedImages.isEmpty) return [];

    setState(() {
      _isUploading = true;
    });

    List<Map<String, String>> uploadedFiles = [];
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    
    if (currentUser == null) return [];

    try {
      for (int i = 0; i < _attachedImages.length; i++) {
        final file = _attachedImages[i];
        
        final fileName = 'attachment_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.${file.path.split('.').last}';
        final ref = _storage.ref().child('message_attachments/$fileName');

        final uploadTask = ref.putFile(File(file.path));
        final snapshot = await uploadTask;
        
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        uploadedFiles.add({
          'name': file.name,
          'url': downloadUrl,
          'size': (await File(file.path).length()).toString(),
          'type': file.path.split('.').last.toLowerCase(),
        });
      }
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to upload attachments: $e",
        icon: Icons.error_outline,
      );
      return [];
    } finally {
      setState(() {
        _isUploading = false;
      });
    }

    return uploadedFiles;
  }

  String _getPlainTextFromQuill() {
    return _quillController.document.toPlainText();
  }

  String _getHtmlFromQuill() {
    // Convert Quill document to HTML
    // Note: You might need to add html package dependency
    return _quillController.document.toDelta().toString();
  }

  Future<void> _saveDraft() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final toPhone = toController.text.trim();
    final ccPhones = ccController.text.trim();
    final bccPhones = bccController.text.trim();
    final subject = subjectController.text.trim();
    final body = _getPlainTextFromQuill();

    if (toPhone.isEmpty && ccPhones.isEmpty && bccPhones.isEmpty && 
        subject.isEmpty && body.isEmpty && _attachedImages.isEmpty) {
      return;
    }

    try {
      List<Map<String, String>> attachments = [];
      if (_attachedImages.isNotEmpty) {
        attachments = await _uploadAttachments();
        if (attachments.isNotEmpty) {
          _uploadedAttachments = attachments;
          _attachedImages.clear();
        }
      }

      final draftId = await _messageService.saveDraft(
        senderId: currentUser.uid,
        recipientPhone: toPhone,
        ccPhones: ccPhones,
        bccPhones: bccPhones,
        subject: subject,
        body: body,
        htmlBody: _getHtmlFromQuill(),
        draftId: _currentDraftId,
        attachments: _uploadedAttachments,
      );

      if (_currentDraftId == null) {
        _currentDraftId = draftId;
      }

      setState(() {
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to save draft: $e",
        icon: Icons.error_outline,
      );
    }
  }

  List<String> _parseRecipients(String recipients) {
    return recipients
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<List<String>> _validateAndGetRecipientUids(List<String> phones) async {
    final database = FirebaseDatabase.instance.ref();
    final usersSnapshot = await database.child('users').get();
    
    List<String> validUids = [];
    List<String> invalidPhones = [];
    
    for (String phone in phones) {
      String? recipientUid;
      for (var user in usersSnapshot.children) {
        if (user.child('phone_number').value == phone) {
          recipientUid = user.key;
          break;
        }
      }
      
      if (recipientUid != null) {
        validUids.add(recipientUid);
      } else {
        invalidPhones.add(phone);
      }
    }
    
    if (invalidPhones.isNotEmpty) {
      throw Exception('Invalid phone numbers: ${invalidPhones.join(', ')}');
    }
    
    return validUids;
  }

  Future<void> _sendEmail() async {
    if (_isUploading) {
      CustomDialog.show(
        context,
        title: "Please wait",
        content: "Files are still uploading...",
        icon: Icons.info_outline,
      );
      return;
    }

    final database = FirebaseDatabase.instance.ref();
    final auth = FirebaseAuth.instance;

    final fromEmail = fromController.text.trim();
    final toPhones = _parseRecipients(toController.text.trim());
    final ccPhones = _parseRecipients(ccController.text.trim());
    final bccPhones = _parseRecipients(bccController.text.trim());
    final subject = subjectController.text.trim();
    final body = _getPlainTextFromQuill();
    final htmlBody = _getHtmlFromQuill();
    final timestamp = DateTime.now().toIso8601String();

    final fromUid = auth.currentUser?.uid ?? 'anonymous';

    if (toPhones.isEmpty && ccPhones.isEmpty && bccPhones.isEmpty) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Please add at least one recipient!",
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      // Validate all recipients
      final toUids = toPhones.isNotEmpty ? await _validateAndGetRecipientUids(toPhones) : <String>[];
      final ccUids = ccPhones.isNotEmpty ? await _validateAndGetRecipientUids(ccPhones) : <String>[];
      final bccUids = bccPhones.isNotEmpty ? await _validateAndGetRecipientUids(bccPhones) : <String>[];

      // Upload attachments
      List<Map<String, String>> finalAttachments = List.from(_uploadedAttachments);
      if (_attachedImages.isNotEmpty) {
        final newAttachments = await _uploadAttachments();
        finalAttachments.addAll(newAttachments);
      }

      // Create message
      final messageRef = database.child('internal_messages').push();
      final messageId = messageRef.key!;

      Map<String, dynamic> messageData = {
        'sender_id': fromUid,
        'subject': subject,
        'body': body,
        'html_body': htmlBody,
        'sent_at': timestamp,
        'is_draft': false,
        'is_starred': false,
        'is_read': false,
        'is_trashed': false,
      };

      if (finalAttachments.isNotEmpty) {
        messageData['attachments'] = finalAttachments;
      }

      await messageRef.set(messageData);

      // Save all recipients
      final allRecipients = [
        ...toUids.map((uid) => {'uid': uid, 'type': 'TO'}),
        ...ccUids.map((uid) => {'uid': uid, 'type': 'CC'}),
        ...bccUids.map((uid) => {'uid': uid, 'type': 'BCC'}),
      ];

      for (var recipient in allRecipients) {
        await database
            .child('internal_message_recipients')
            .child(messageId)
            .child(recipient['uid']!)
            .set({
          'recipient_type': recipient['type'],
          'is_draft_recip': false,
          'is_starred_recip': false,
          'is_read_recip': false,
          'is_trashed_recip': false,
        });

        // Create notification for each recipient
        final notificationRef = database.child('notifications').child(recipient['uid']!).push();
        await notificationRef.set({
          'title': 'You have a new message',
          'body': 'From: $fromEmail\nSubject: $subject${finalAttachments.isNotEmpty ? '\n📎 ${finalAttachments.length} attachment(s)' : ''}',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sender_id': fromUid,
          'message_id': messageId,
          'is_read': false,
        });
      }

      // Delete draft if exists
      if (_currentDraftId != null) {
        await _messageService.deleteDraft(_currentDraftId!);
      }

      // Clear form
      toController.clear();
      ccController.clear();
      bccController.clear();
      subjectController.clear();
      _quillController.clear();
      setState(() {
        _attachedImages.clear();
        _uploadedAttachments.clear();
        _hasUnsavedChanges = false;
        _showCC = false;
        _showBCC = false;
      });

      CustomDialog.show(
        context,
        title: "Success",
        content: "Email sent successfully!",
        icon: Icons.check_circle_outline,
      );

      Navigator.pop(context, true);
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to send email: $e",
        icon: Icons.error_outline,
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      if (index < _attachedImages.length) {
        _attachedImages.removeAt(index);
      } else {
        _uploadedAttachments.removeAt(index - _attachedImages.length);
      }
      _hasUnsavedChanges = true;
    });
  }

  Widget _buildAttachmentsSection() {
    final allAttachments = [
      ..._attachedImages.map((file) => {'type': 'local', 'data': file}),
      ..._uploadedAttachments.map((file) => {'type': 'uploaded', 'data': file}),
    ];

    if (allAttachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments:',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allAttachments.length,
            itemBuilder: (context, index) {
              final attachment = allAttachments[index];
              final isLocal = attachment['type'] == 'local';
              
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isLocal
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File((attachment['data'] as XFile).path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getFileIcon((attachment['data'] as Map<String, String>)['type'] ?? ''),
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (attachment['data'] as Map<String, String>)['name'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeAttachment(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                    if (isLocal && _isUploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFffcad4),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuillToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: QuillToolbar.simple(
        configurations: QuillSimpleToolbarConfigurations(
          controller: _quillController,
          sharedConfigurations: const QuillSharedConfigurations(
            locale: Locale('en'),
          ),
          showDividers: false,
          showFontFamily: false,
          showFontSize: true,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showColorButton: true,
          showBackgroundColorButton: true,
          showListNumbers: true,
          showListBullets: true,
          showCodeBlock: true,
          showQuote: true,
          showIndent: true,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showDirection: false,
          multiRowsDisplay: false,
        ),
      ),
    );
  }

  Widget _buildQuillEditor({bool isReadOnly = false}) {
  return Container(
    height: 200,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white54),
      borderRadius: BorderRadius.circular(8),
    ),
    child: AbsorbPointer(
      absorbing: isReadOnly, // Disable tương tác khi readOnly = true
      child: QuillEditor.basic(
        configurations: QuillEditorConfigurations(
          controller: _quillController,
          sharedConfigurations: const QuillSharedConfigurations(
            locale: Locale('en'),
          ),
          placeholder: isReadOnly ? '' : 'Compose your message...',
          expands: true,
          padding: const EdgeInsets.all(16),
          scrollable: true,
          autoFocus: !isReadOnly,
          showCursor: !isReadOnly,
        ),
      ),
    ),
  );
}

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Save Draft?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Do you want to save this email as draft before leaving?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save Draft', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );

      if (result == 'save') {
        await _saveDraft();
        return true;
      } else if (result == 'discard') {
        return true;
      } else {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    toController.removeListener(_onContentChanged);
    ccController.removeListener(_onContentChanged);
    bccController.removeListener(_onContentChanged);
    subjectController.removeListener(_onContentChanged);
    _quillController.removeListener(_onContentChanged);
    
    toController.dispose();
    ccController.dispose();
    bccController.dispose();
    subjectController.dispose();
    fromController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentDraftId != null ? 'Edit Draft' : 'Compose Email'),
          backgroundColor: Colors.black,
          titleTextStyle: const TextStyle(
            color: Color(0xFFffcad4),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isAdvancedMode ? Icons.edit_outlined : Icons.text_fields,
                color: const Color(0xFFffcad4),
              ),
              onPressed: () {
                setState(() {
                  _isAdvancedMode = !_isAdvancedMode;
                });
              },
              tooltip: _isAdvancedMode ? 'Simple Mode' : 'Advanced Mode',
            ),
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.save, color: Color(0xFFffcad4)),
                onPressed: _saveDraft,
                tooltip: 'Save Draft',
              ),
          ],
        ),
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // From field
              TextField(
                controller: fromController,
                decoration: const InputDecoration(
                  labelText: 'From',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                readOnly: true,
              ),
              
              // To field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: toController,
                      decoration: const InputDecoration(
                        labelText: 'To (Phone Numbers, separated by comma)',
                        labelStyle: TextStyle(color: Colors.white),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFFffcad4)),
                    onSelected: (value) {
                      setState(() {
                        if (value == 'CC') _showCC = true;
                        if (value == 'BCC') _showBCC = true;
                      });
                    },
                    itemBuilder: (context) => [
                      if (!_showCC)
                        const PopupMenuItem(value: 'CC', child: Text('Add CC')),
                      if (!_showBCC)
                        const PopupMenuItem(value: 'BCC', child: Text('Add BCC')),
                    ],
                  ),
                ],
              ),
              
              // CC field
              if (_showCC)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ccController,
                        decoration: const InputDecoration(
                          labelText: 'CC (Phone Numbers, separated by comma)',
                          labelStyle: TextStyle(color: Colors.white),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _showCC = false;
                          ccController.clear();
                        });
                      },
                    ),
                  ],
                ),
              
              // BCC field
              if (_showBCC)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bccController,
                        decoration: const InputDecoration(
                          labelText: 'BCC (Phone Numbers, separated by comma)',
                          labelStyle: TextStyle(color: Colors.white),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _showBCC = false;
                          bccController.clear();
                        });
                      },
                    ),
                  ],
                ),
              
              // Subject field
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              
              const SizedBox(height: 16),
              
              // Editor section
              Expanded(
                child: Column(
                  children: [
                    if (_isAdvancedMode) ...[
                      _buildQuillToolbar(),
                      const SizedBox(height: 8),
                      Expanded(child: _buildQuillEditor()),
                    ] else
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: _getPlainTextFromQuill()),
                          onChanged: (text) {
                            _quillController.document = Document()..insert(0, text);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Content',
                            labelStyle: TextStyle(color: Colors.white),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          maxLines: null,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildAttachmentsSection(),
                  ],
                ),
              ),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Color(0xFFF4538A),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.attach_file, color: Color(0xFFF4538A)),
                      label: Text(
                        _isUploading ? 'Uploading...' : 'Add Files',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      onPressed: _isUploading ? null : _pickImages,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(0xFFF4538A),
                        backgroundColor: const Color(0xFFffcad4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _sendEmail,
                      icon: const Icon(Icons.send, color: Color(0xFFF4538A)),
                      label: const Text(
                        'Send',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(0xFFF4538A),
                        backgroundColor: const Color(0xFFffcad4),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}