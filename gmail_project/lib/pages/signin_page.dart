import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';  
import './inbox_page.dart';
import '../components/dialog.dart';
import '../services/theme_service.dart';

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController backupCodeController = TextEditingController();

  final AuthService _authService = AuthService();
  
  bool isLoading = false;
  bool showBackupCodeInput = false;
  String? pendingUserId;
  String? pendingPhone;
  String? pendingPassword;

  // Helper method to safely parse API response
  Map<String, dynamic>? _parseApiResponse(dynamic response) {
    try {
      print("DEBUG: Response type: ${response.runtimeType}");
      print("DEBUG: Response content: $response");
      
      if (response == null) {
        print("DEBUG: Response is null");
        return null;
      }
      
      // Handle Map<String, dynamic>
      if (response is Map<String, dynamic>) {
        print("DEBUG: Response is Map<String, dynamic>");
        return response;
      }
      
      // Handle other Map types
      if (response is Map) {
        print("DEBUG: Response is Map, converting to Map<String, dynamic>");
        return response.cast<String, dynamic>();
      }
      
      // Handle List types
      if (response is List) {
        print("DEBUG: Response is List with ${response.length} items");
        if (response.isEmpty) {
          print("DEBUG: List is empty");
          return {'success': false, 'message': 'Empty response'};
        }
        
        final firstItem = response[0];
        print("DEBUG: First item type: ${firstItem.runtimeType}");
        print("DEBUG: First item content: $firstItem");
        
        if (firstItem is Map<String, dynamic>) {
          return firstItem;
        }
        
        if (firstItem is Map) {
          return firstItem.cast<String, dynamic>();
        }
        
        // If first item is not a Map, treat the list as an error
        print("DEBUG: First item is not a Map: ${firstItem.runtimeType}");
        return {'success': false, 'message': 'Invalid response format'};
      }
      
      print("DEBUG: Unexpected response format: ${response.runtimeType}");
      return {'success': false, 'message': 'Unexpected response format'};
      
    } catch (e, stackTrace) {
      print("DEBUG: Error parsing response: $e");
      print("DEBUG: Stack trace: $stackTrace");
      return {'success': false, 'message': 'Failed to parse response'};
    }
  }

  Future<void> _handleSignIn() async {
    String phone = phoneController.text.trim();
    String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Please, Fill all fields!",
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _authService.signIn(
        phone: phone,
        password: password,
      );

      setState(() {
        isLoading = false;
      });

      final result = _parseApiResponse(response);
      
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid response from server"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (result['success'] == true) {
        _showSuccessAndNavigate();
      } else if (result['requiresTwoStep'] == true) {
        setState(() {
          showBackupCodeInput = true;
          pendingUserId = result['userId']?.toString();
          pendingPhone = result['phone']?.toString();
          pendingPassword = result['password']?.toString();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please enter your backup code to continue"),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Login failed: ${result['message'] ?? 'Unknown error'}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      print("Sign in error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("System error: Please try again"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBackupCodeVerification() async {
    String backupCode = backupCodeController.text.trim();

    if (backupCode.isEmpty) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Please enter your backup code!",
        icon: Icons.error_outline,
      );
      return;
    }

    if (pendingUserId == null || pendingPhone == null || pendingPassword == null) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Session expired. Please try signing in again.",
        icon: Icons.error_outline,
      );
      _resetToNormalSignIn();
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _authService.verifyBackupCodeAndSignIn(
        userId: pendingUserId!,
        phone: pendingPhone!,
        password: pendingPassword!,
        backupCode: backupCode,
      );

      setState(() {
        isLoading = false;
      });

      final result = _parseApiResponse(response);
      
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid response from server"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (result['success'] == true) {
        _showSuccessAndNavigate();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification failed: ${result['message'] ?? 'Invalid backup code'}"),
            backgroundColor: Colors.red,
          ),
        );
        
        backupCodeController.clear();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      
      print("Backup code verification error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Verification error: Please try again"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessAndNavigate() {
    CustomDialog.show(
      context,
      title: "Success",
      content: "Sign in successful!",
      icon: Icons.check_circle_outline,
      buttonText: "Continue",
      onConfirmed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MyHomePage()),
        );
      },
    );
  }

  void _resetToNormalSignIn() {
    setState(() {
      showBackupCodeInput = false;
      pendingUserId = null;
      pendingPhone = null;
      pendingPassword = null;
      backupCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          backgroundColor: themeService.backgroundColor,
          appBar: AppBar(
            backgroundColor: themeService.backgroundColor, 
            elevation: 0,
            iconTheme: IconThemeData(color: themeService.iconColor),
            leading: showBackupCodeInput 
              ? IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: _resetToNormalSignIn,
                )
              : null,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    Icon(
                      themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: themeService.iconColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        themeService.toggleTheme();
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        width: 50,
                        height: 26,
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: themeService.isDarkMode 
                            ? Color.fromARGB(80, 245, 128, 149) 
                            : Color(0xFFffcad4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AnimatedAlign(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: themeService.isDarkMode 
                            ? Alignment.centerRight 
                            : Alignment.centerLeft,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: themeService.isDarkMode 
                                ? Color(0xFF0D0D5B) 
                                : Colors.white,
                            ),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(scale: animation, child: child),
                                child: themeService.isDarkMode
                                    ? Icon(Icons.nightlight_round, key: ValueKey('moon'), color: Colors.white, size: 12)
                                    : Icon(Icons.wb_sunny, key: ValueKey('sun'), color: Colors.orange, size: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 400), 
                  child: Image.asset(
                    'assets/images/login.png',
                    height: 500,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    minHeight: 280,
                  ),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFffcad4),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showBackupCodeInput) ...[
                          // Two-Step Verification UI
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.security,
                                  size: 50,
                                  color: Color(0xFFF4538A),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  "Two-Step Verification",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Enter your backup code to complete sign in",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 25),
                          
                          _buildTextField(
                            "Backup Code (XXXX-XXXX)", 
                            backupCodeController,
                            hintText: "1234-5678"
                          ),
                          SizedBox(height: 20),
                          
                          Text(
                            "• Each backup code can only be used once\n• Format: XXXX-XXXX (8 digits with dash)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: 25),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF4538A),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            onPressed: isLoading ? null : _handleBackupCodeVerification,
                            child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Verifying...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  "Verify Code",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20
                                  ),
                                ),
                          ),
                        ] else ...[
                          // Normal Sign In UI
                          _buildTextField("Phone Number", phoneController),
                          SizedBox(height: 20),
                          _buildTextField("Password", passwordController, obscureText: true),
                          SizedBox(height: 30),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFF4538A),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            onPressed: isLoading ? null : _handleSignIn,
                            child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Signing In...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  "Sign In",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20
                                  ),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false, String? hintText}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
          suffixIcon: obscureText ? Icon(Icons.visibility_off) : null,
          border: InputBorder.none, 
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: TextStyle(
          color: Colors.black
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    backupCodeController.dispose();
    super.dispose();
  }
}