import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../components/dialog.dart';


class ResetPasswordScreen extends StatefulWidget {
  final String? phoneNumber;
  const ResetPasswordScreen({Key? key, this.phoneNumber}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _debugInfo = '';

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty) {
      _showError('Vui lòng nhập mật khẩu cũ');
      return;
    }
    if (newPassword.length < 6) {
      _showError('Mật khẩu mới phải có ít nhất 6 ký tự');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('Mật khẩu xác nhận không khớp');
      return;
    }
    if (widget.phoneNumber == null) {
      _showError('Không có số điện thoại. Hãy quay lại bước xác minh OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _debugInfo = 'Đang xử lý...';
    });

    try {
      final result = await _authService.resetPassword(
        phoneNumber: widget.phoneNumber!,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      setState(() => _isLoading = false);

      if (result == null) {
        _showSuccess('Change password successfully! Please, sign in with new password.');
        await Future.delayed(Duration(seconds: 4));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showError(result);
        setState(() => _debugInfo = 'Lỗi: $result');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugInfo = 'Exception: $e';
      });
      _showError('Có lỗi xảy ra: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(
    //     content: Text(message),
    //     backgroundColor: Colors.green,
    //     duration: Duration(seconds: 3),
    //   ),
    // );
    CustomDialog.show(
      context,
      title: "Success",
      content: message,
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFFF48FB1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20,),
            if (widget.phoneNumber != null) ...[
              Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 252, 155, 187).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  //border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Phone number: ${widget.phoneNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF48FB1),
                    fontSize: 18,
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],

            // Mật khẩu cũ
            TextField(
              controller: _oldPasswordController,
              obscureText: _obscureOldPassword,
              decoration: InputDecoration(
                labelText: 'Old Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color.fromARGB(255, 245, 105, 152),)),
                prefixIcon: Icon(Icons.lock, color: Color(0xFFF48FB1),),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureOldPassword = !_obscureOldPassword);
                  },
                ),
              ),
            ),
            SizedBox(height: 20),

            // Mật khẩu mới
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color.fromARGB(255, 245, 105, 152),)),
                prefixIcon: Icon(Icons.lock, color: Color(0xFFF48FB1),),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            SizedBox(height: 16),

            // Xác nhận mật khẩu mới
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color.fromARGB(255, 245, 105, 152),)),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFF48FB1),),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
              ),
            ),
            SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Color(0xFFF48FB1),
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Processing...'),
                      ],
                    )
                  : Text('Reset Password',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                  ),
            ),

            SizedBox(height: 16),

            if (_debugInfo.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Debug: $_debugInfo',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
