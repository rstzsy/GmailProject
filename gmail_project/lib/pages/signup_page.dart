import 'package:flutter/material.dart';
import '../services/auth_service.dart';  // import AuthService
import './signin_page.dart';

class SignUpScreen extends StatelessWidget {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();  // tạo instance AuthService

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please fill all fields")),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Sign up successful!")),
                        );

                        // Chuyển sang màn hình đăng nhập
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => SignInScreen()),
                        );
                      }
                    },
                    child: Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20
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
        style: TextStyle(
          color: Colors.black
        ),
      ),
    );
  }

}
