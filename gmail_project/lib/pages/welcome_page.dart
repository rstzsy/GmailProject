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
      body: Stack(
        children: [
          Center(
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
              ],
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: textColor),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      isDarkMode = !isDarkMode;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 70,
                    height: 40,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Color.fromARGB(80, 245, 128, 149) : Color(0xFFffcad4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: AnimatedAlign(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? Color(0xFF0D0D5B) : Colors.white,
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: isDarkMode
                                ? Icon(Icons.nightlight_round, key: ValueKey('moon'), color: Colors.white)
                                : Icon(Icons.wb_sunny, key: ValueKey('sun'), color: Colors.orange),
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
    );
  }
}
