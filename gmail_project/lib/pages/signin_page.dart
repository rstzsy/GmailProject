import 'package:flutter/material.dart';
import '../services/auth_service.dart';  // import AuthService
import './inbox_page.dart';

class SignInScreen extends StatelessWidget {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService _authService = AuthService();  // Khởi tạo AuthService

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
                'assets/images/login.png',
                height: 500,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 300, 
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
                  _buildTextField("Password", passwordController, obscureText: true),
                  SizedBox(height: 30),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF4538A),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      String phone = phoneController.text.trim();
                      String password = passwordController.text.trim();

                      if (phone.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Please fill in all fields")),
                        );
                        return;
                      }

                      String? error = await _authService.signIn(
                        phone: phone,
                        password: password,
                      );

                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Login failed: $error")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Login successful")),
                        );
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => MyHomePage()),
                        );
                      }
                    },
                    child: Text(
                      "Sign In",
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
