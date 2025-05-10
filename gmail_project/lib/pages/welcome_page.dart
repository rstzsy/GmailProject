import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'signin_page.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isDarkMode = true;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Color(0xFFF4538A) : Colors.pink;
    final buttonColor = isDarkMode ? Color(0xFFffcad4) : Colors.pink[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/welcome.png', height: 400),

            const SizedBox(height: 20),

            Text(
              "Welcome to Email Service",
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
              ),
              child: Text("Sign Up", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpScreen()));
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 15),
              ),
              child: Text("Sign In", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignInScreen()));
              },
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: textColor,),
                const SizedBox(width: 10),
                Text("Dark Mode", style: TextStyle(color: textColor, fontSize: 20)),
                Switch(
                  value: isDarkMode,
                  activeColor: textColor,
                  onChanged: (value) {
                    setState(() {
                      isDarkMode = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
