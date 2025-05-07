import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'signin_page.dart';


class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/welcome.png', height: 400),

            SizedBox(height: 20),

            Text("Welcome to Email Service", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),

            SizedBox(height: 40),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFffcad4),
                padding: EdgeInsets.symmetric(horizontal: 120, vertical: 15),
              ),
              child: Text("Sign Up", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF4538A))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpScreen()));
              },
            ),

            SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFffcad4),
                padding: EdgeInsets.symmetric(horizontal: 120, vertical: 15),
              ),
              child: Text("Sign In", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFF4538A))),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignInScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
