import 'package:flutter/material.dart';

class CustomDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    String buttonText = "OK",
    VoidCallback? onConfirmed,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCAD4), // Nền hồng
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50, color: const Color.fromARGB(255, 253, 80, 138)), 
              SizedBox(height: 15),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                  color: const Color.fromARGB(255, 253, 80, 138),
                ),
              ),
              SizedBox(height: 10),
              Text(
                content,
                style: TextStyle(fontSize: 24, color: Colors.black, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 253, 80, 138), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (onConfirmed != null) onConfirmed();
                },
                child: Text(
                  buttonText,
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), 
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
