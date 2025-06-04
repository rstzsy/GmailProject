import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import './signin_page.dart';
import '../components/dialog.dart';
import '../services/theme_service.dart';

class SignUpScreen extends StatelessWidget {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();

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
            actions: [
              // Theme toggle button in app bar
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
                    'assets/images/signup.png',
                    height: 500,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 450,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFffcad4),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTextField("Phone Number", phoneController),
                      SizedBox(height: 20),
                      _buildTextField("Username", usernameController),
                      SizedBox(height: 20),
                      _buildTextField("Password", passwordController, obscureText: true),
                      SizedBox(height: 30),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF4538A),
                          minimumSize: Size(double.infinity, 50),
                        ),
                        onPressed: () async {
                          String phone = phoneController.text.trim();
                          String username = usernameController.text.trim();
                          String password = passwordController.text.trim();

                          if (phone.isEmpty || username.isEmpty || password.isEmpty) {
                            CustomDialog.show(
                              context,
                              title: "Error",
                              content: "Please, Fill all fields!",
                              icon: Icons.error_outline,
                            );
                            return;
                          }

                          String? error = await _authService.signUp(
                            phone: phone,
                            username: username,
                            password: password,
                          );

                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: $error")),
                            );
                          } else {
                            CustomDialog.show(
                              context,
                              title: "Success",
                              content: "Sign up successful!",
                              icon: Icons.check_circle_outline,
                              buttonText: "Continue",
                              onConfirmed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignInScreen()),
                                );
                              },
                            );
                          }
                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false}) {
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
          labelStyle: TextStyle(color: Colors.grey[700]),
          suffixIcon: obscureText ? Icon(Icons.visibility_off) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
        style: TextStyle(color: Colors.black),
      ),
    );
  }
}