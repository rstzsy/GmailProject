import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/two_step_verification_service.dart';
import '../components/dialog.dart';
import 'backupCode_page.dart';

class TwoStepVerificationPage extends StatefulWidget {
  const TwoStepVerificationPage({super.key});

  @override
  State<TwoStepVerificationPage> createState() => _TwoStepVerificationPageState();
}

class _TwoStepVerificationPageState extends State<TwoStepVerificationPage> {
  final TwoStepVerificationService _twoStepService = TwoStepVerificationService();
  bool isLoading = true;
  bool isTwoStepEnabled = false;
  int remainingCodes = 0;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadTwoStepStatus();
  }

  Future<void> _loadTwoStepStatus() async {
    try {
      final enabled = await _twoStepService.isTwoStepEnabled();
      final remaining = await _twoStepService.getRemainingCodesCount();
      
      setState(() {
        isTwoStepEnabled = enabled;
        remainingCodes = remaining;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Error loading two-step verification status: $e');
    }
  }

  Future<void> _enableTwoStep() async {
    setState(() {
      isUpdating = true;
    });

    try {
      // Tạo backup codes
      final codes = await _twoStepService.generateBackupCodes();
      
      // Lưu vào Firebase
      await _twoStepService.saveBackupCodes(codes);
      
      setState(() {
        isTwoStepEnabled = true;
        remainingCodes = codes.length;
        isUpdating = false;
      });

      // Hiển thị backup codes cho user
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BackupCodesPage(
            backupCodes: codes,
            isFirstTime: true,
          ),
        ),
      );

    } catch (e) {
      setState(() {
        isUpdating = false;
      });
      _showErrorDialog('Error enabling two-step verification: $e');
    }
  }

  Future<void> _disableTwoStep() async {
    final confirmed = await _showConfirmDialog(
      'Disable Two-Step Verification',
      'Are you sure you want to disable two-step verification? This will make your account less secure.',
      'Disable',
    );

    if (confirmed == true) {
      setState(() {
        isUpdating = true;
      });

      try {
        await _twoStepService.disableTwoStep();
        
        setState(() {
          isTwoStepEnabled = false;
          remainingCodes = 0;
          isUpdating = false;
        });

        _showSuccessDialog('Two-step verification has been disabled.');

      } catch (e) {
        setState(() {
          isUpdating = false;
        });
        _showErrorDialog('Error disabling two-step verification: $e');
      }
    }
  }

  Future<void> _regenerateCodes() async {
    final confirmed = await _showConfirmDialog(
      'Generate New Backup Codes',
      'This will invalidate all existing backup codes. Make sure to download and save the new codes.',
      'Generate',
    );

    if (confirmed == true) {
      setState(() {
        isUpdating = true;
      });

      try {
        final newCodes = await _twoStepService.regenerateBackupCodes();
        
        setState(() {
          remainingCodes = newCodes.length;
          isUpdating = false;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BackupCodesPage(
              backupCodes: newCodes,
              isFirstTime: false,
            ),
          ),
        );

      } catch (e) {
        setState(() {
          isUpdating = false;
        });
        _showErrorDialog('Error generating new backup codes: $e');
      }
    }
  }

  void _showErrorDialog(String message) {
    CustomDialog.show(
      context,
      title: "Error",
      content: message,
      icon: Icons.error_outline,
    );
  }

  void _showSuccessDialog(String message) {
    CustomDialog.show(
      context,
      title: "Success",
      content: message,
      icon: Icons.check_circle_outline,
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content, String confirmText) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText, style: const TextStyle(color: Color(0xFFF48FB1))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Two-Step Verification',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF48FB1)),
      ),
      body: SafeArea(
        child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF48FB1)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF48FB1).withOpacity(0.1),
                            const Color(0xFFD5C4F1).withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFF48FB1).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            FontAwesomeIcons.shield,
                            size: 50,
                            color: isTwoStepEnabled ? const Color(0xFF4CAF50) : const Color(0xFFF48FB1),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            isTwoStepEnabled ? 'Two-Step Verification Enabled' : 'Two-Step Verification Disabled',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isTwoStepEnabled 
                              ? 'Your account is protected with backup codes'
                              : 'Add an extra layer of security to your account',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Status and actions
                  if (isTwoStepEnabled) ...[
                    _buildInfoCard(
                      'Backup Codes Status',
                      '$remainingCodes codes remaining',
                      FontAwesomeIcons.key,
                      remainingCodes > 3 ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    ),

                    const SizedBox(height: 20),

                    _buildActionButton(
                      'Generate New Backup Codes',
                      'Create a new set of backup codes',
                      FontAwesomeIcons.arrowsRotate,
                      const Color(0xFF2196F3),
                      _regenerateCodes,
                    ),

                    const SizedBox(height: 15),

                    _buildActionButton(
                      'Disable Two-Step Verification',
                      'Turn off two-step verification',
                      FontAwesomeIcons.userShield,
                      const Color(0xFFFF5722),
                      _disableTwoStep,
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    
                    _buildInfoSection(),

                    const SizedBox(height: 30),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isUpdating ? null : _enableTwoStep,
                          icon: isUpdating 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(FontAwesomeIcons.shield, color: Colors.white),
                          label: Text(
                            isUpdating ? 'Enabling...' : 'Enable Two-Step Verification',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF48FB1),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: isUpdating 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF48FB1)),
            )
          : Icon(Icons.arrow_forward_ios, color: color, size: 16),
        onTap: isUpdating ? null : onTap,
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How it works:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        
        _buildInfoItem(
          FontAwesomeIcons.key,
          'Backup Codes',
          'Get 12 backup codes that you can use to access your account',
        ),
        
        _buildInfoItem(
          FontAwesomeIcons.download,
          'Download & Save',
          'Download codes as a text file and keep them in a safe place',
        ),
        
        _buildInfoItem(
          FontAwesomeIcons.lockOpen,
          'One-Time Use',
          'Each backup code can only be used once for security',
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFFF48FB1).withOpacity(0.1),
            child: Icon(icon, color: const Color(0xFFF48FB1), size: 16),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}