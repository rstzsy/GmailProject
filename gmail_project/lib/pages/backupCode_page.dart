import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import '../services/two_step_verification_service.dart';
import '../components/dialog.dart';

class BackupCodesPage extends StatefulWidget {
  final List<String> backupCodes;
  final bool isFirstTime;

  const BackupCodesPage({
    super.key,
    required this.backupCodes,
    this.isFirstTime = false,
  });

  @override
  State<BackupCodesPage> createState() => _BackupCodesPageState();
}

class _BackupCodesPageState extends State<BackupCodesPage> {
  final TwoStepVerificationService _twoStepService = TwoStepVerificationService();
  bool isDownloading = false;
  bool hasDownloaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Backup Codes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)),
        actions: [
          if (!widget.isFirstTime)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.triangleExclamation,
                          color: const Color(0xFFFF9800),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Important!',
                          style: TextStyle(
                            color: Color(0xFFFF9800),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '• Keep these codes safe and secure\n'
                      '• Each code can only be used once\n'
                      '• Download and save them now\n'
                      '• Use when you cannot access your account',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Backup codes section
              const Text(
                'Your Backup Codes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF48FB1).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header with copy all button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${widget.backupCodes.length} Codes Generated',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _copyAllCodes,
                            icon: const Icon(
                              Icons.copy_all,
                              size: 16,
                              color: Color(0xFFF48FB1),
                            ),
                            label: const Text(
                              'Copy All',
                              style: TextStyle(
                                color: Color(0xFFF48FB1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const Divider(color: Colors.white24),
                      
                      // Codes list
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.backupCodes.length,
                          itemBuilder: (context, index) {
                            return _buildCodeItem(index, widget.backupCodes[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isDownloading ? null : _downloadCodes,
                      icon: isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              hasDownloaded ? Icons.check : FontAwesomeIcons.download,
                              color: Colors.white,
                              size: 16,
                            ),
                      label: Text(
                        isDownloading
                            ? 'Downloading...'
                            : hasDownloaded
                                ? 'Downloaded'
                                : 'Download',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasDownloaded 
                          ? const Color(0xFF4CAF50) 
                          : const Color(0xFFF48FB1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _copyAllCodes,
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: const Text(
                        'Copy All',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Note for first time users
              if (widget.isFirstTime) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Two-step verification is now enabled! Make sure to download these codes before continuing.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeItem(int index, String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF48FB1).withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF48FB1).withOpacity(0.1),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Color(0xFFF48FB1),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          code,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
            fontFamily: 'monospace',
          ),
        ),
        trailing: IconButton(
          onPressed: () => _copyCode(code),
          icon: const Icon(
            Icons.copy,
            color: Color(0xFFF48FB1),
            size: 18,
          ),
          tooltip: 'Copy code',
        ),
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code $code copied to clipboard'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copyAllCodes() async {
    final codesText = widget.backupCodes.join('\n');
    await Clipboard.setData(ClipboardData(text: codesText));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All backup codes copied to clipboard'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadCodes() async {
    setState(() {
      isDownloading = true;
    });

    try {
      final file = await _twoStepService.createBackupCodesFile(widget.backupCodes);
      
      setState(() {
        hasDownloaded = true;
        isDownloading = false;
      });

      CustomDialog.show(
        context,
        title: "Success",
        content: "Backup codes have been saved to:\n${file.path}",
        icon: Icons.check_circle_outline,
      );

    } catch (e) {
      setState(() {
        isDownloading = false;
      });
      
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to download backup codes: $e",
        icon: Icons.error_outline,
      );
    }
  }
}