import 'package:flutter/material.dart';
import '../services/otp_service.dart';
import 'resetpass_page.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String? phoneNumber; // Thêm phoneNumber

  const OtpVerificationScreen({
    Key? key, 
    required this.verificationId,
    this.phoneNumber,
  }) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final OtpAuthService otpService = OtpAuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Mã OTP phải gồm 6 chữ số');
      return;
    }

    setState(() => _isLoading = true);

    otpService.verifyOtp(
      verificationId: widget.verificationId,
      smsCode: otp,
      onSuccess: () {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              phoneNumber: widget.phoneNumber, // truyền số điện thoại để hiển thị
            ),
          ),
        );

      },
      onFailed: (error) {
        setState(() => _isLoading = false);
        _showError(error);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Enter OTP code', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFFF48FB1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.sms,
                    size: 80,
                    color: Color(0xFFF48FB1),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'OTP Confirmation',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF48FB1),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter 6 numbers sent to your number phone',
                    style: TextStyle(
                      fontSize: 19,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.phoneNumber != null) ...[
                    SizedBox(height: 8),
                    Text(
                      widget.phoneNumber!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF48FB1),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // OTP Input
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'OTP code',
                hintText: '000000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFF48FB1)),
              ),
            ),

            SizedBox(height: 24),

            // Verify Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF48FB1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Confirmating...'),
                        ],
                      )
                    : Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            SizedBox(height: 16),

            // Resend OTP
            TextButton(
              onPressed: _isLoading ? null : () {
                _showError('Tính năng gửi lại OTP sẽ được thêm vào sau');
              },
              child: Text(
                'Do not receive code? Send again',
                style: TextStyle(
                  color: Color(0xFFF48FB1),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}