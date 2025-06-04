import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/two_step_verification_service.dart';
import '../components/dialog.dart';
import 'inbox_page.dart';

class BackupCodeVerificationPage extends StatefulWidget {
  const BackupCodeVerificationPage({super.key});

  @override
  State<BackupCodeVerificationPage> createState() => _BackupCodeVerificationPageState();
}

class _BackupCodeVerificationPageState extends State<BackupCodeVerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  final TwoStepVerificationService _twoStepService = TwoStepVerificationService();
  bool isVerifying = false;
  int remainingCodes = 0;

  @override
  void initState() {
    super.initState();
    _loadRemainingCodes();
  }

  Future<void> _loadRemainingCodes() async {
    try {
      final remaining = await _twoStepService.getRemainingCodesCount();
      setState(() {
        remainingCodes = remaining;
      });
    } catch (e) {
      print('Error loading remaining codes: $e');
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Please enter a backup code",
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      isVerifying = true;
    });

    try {
      final isValid = await _twoStepService.verifyBackupCode(code);
      
      if (isValid) {
        CustomDialog.show(
          context,
          title: "Success",
          content: "Verification successful!",
          icon: Icons.check_circle_outline,
          buttonText: "Continue",
          onConfirmed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MyHomePage()),
              (route) => false,
            );
          },
        );
      } else {
        CustomDialog.show(
          context,
          title: "Invalid Code",
          content: "The backup code you entered is invalid or has already been used.",
          icon: Icons.error_outline,
        );
        _codeController.clear();
        await _loadRemainingCodes(); // Refresh remaining codes
      }
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Verification failed: $e",
        icon: Icons.error_outline,
      );
    } finally {
      setState(() {
        isVerifying = false;
      });
    }
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Icon section
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF48FB1).withOpacity(0.1),
                      const Color(0xFFD5C4F1).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF48FB1).withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  FontAwesomeIcons.key,
                  size: 60,
                  color: Color(0xFFF48FB1),
                ),
              ),

              const SizedBox(height: 30),

              // Title and description
              const Text(
                'Enter Backup Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              
              Text(
                'Enter one of your backup codes to verify your identity',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              // Remaining codes info
              if (remainingCodes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '$remainingCodes backup codes remaining',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              // Code input field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFF48FB1).withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'XXXX-XXXX',
                    hintStyle: TextStyle(
                      color: Colors.white38,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                  onSubmitted: (_) => _verifyCode(),
                ),
              ),

              const SizedBox(height: 30),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isVerifying ? null : _verifyCode,
                  icon: isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          FontAwesomeIcons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    isVerifying ? 'Verifying...' : 'Verify Code',
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

              const Spacer(),

              // Help section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need help?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '• Use any of your saved backup codes\n'
                      '• Each code can only be used once\n'
                      '• Format should be: XXXX-XXXX\n'
                      '• Contact support if you lost all codes',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}