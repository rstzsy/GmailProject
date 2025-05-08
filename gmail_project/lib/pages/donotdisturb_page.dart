import 'package:flutter/material.dart';

class DoNotDisturbPage extends StatelessWidget {
  const DoNotDisturbPage({super.key});

  @override
  Widget build(BuildContext context) {
    final durations = [15, 30, 60, 120, 180]; // in minutes
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Do Not Disturb"),
        backgroundColor: const Color(0xFF121212),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Select time duration for Do Not Disturb mode:",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: ListView.builder(
              itemCount: durations.length,
              itemBuilder: (context, index) {
                final minutes = durations[index];
                String displayText;
                
                if (minutes < 60) {
                  displayText = "$minutes minutes";
                } else if (minutes == 60) {
                  displayText = "1 hour";
                } else {
                  final hours = minutes ~/ 60;
                  final remainingMinutes = minutes % 60;
                  
                  if (remainingMinutes == 0) {
                    displayText = "$hours hours";
                  } else {
                    displayText = "$hours hours $remainingMinutes minutes";
                  }
                }
                
                return ListTile(
                  title: Text(
                    displayText,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
                  onTap: () {
                    
                    Navigator.pop(context, minutes);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Do Not Disturb enabled for $displayText",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold
                          )
                        ),
                        duration: const Duration(seconds: 10),
                        backgroundColor: Color(0xFFffcad4),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Add a custom option
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // canceled
                Navigator.pop(context, null);
                // Show message that we're staying active
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Staying active",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold
                    )
                  ),
                    duration: Duration(seconds: 10),
                    backgroundColor: Color(0xFFffcad4),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF4538A),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}