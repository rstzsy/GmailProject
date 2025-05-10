import 'package:flutter/material.dart';
import '../pages/emailDetail_page.dart';

class MyListView extends StatefulWidget {
  const MyListView({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyListViewState createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  final List<Map<String, dynamic>> users = [
    {"id": 1, "fullName": "John Doe", "jobTitle": "Software Engineer"},
    {"id": 2, "fullName": "Jane Smith", "jobTitle": "Product Manager"},
    {"id": 3, "fullName": "Michael Johnson", "jobTitle": "UX Designer"},
    {"id": 4, "fullName": "Sarah Lee", "jobTitle": "Data Scientist"},
    {"id": 5, "fullName": "David Brown", "jobTitle": "DevOps Engineer"},
    {"id": 6, "fullName": "Emily Davis", "jobTitle": "Quality Assurance Analyst"},
    {"id": 7, "fullName": "William Garcia", "jobTitle": "Front-end Developer"},
    {"id": 8, "fullName": "Ashley Rodriguez", "jobTitle": "Business Analyst"},
    {"id": 9, "fullName": "Matthew Wilson", "jobTitle": "Full-stack Developer"},
    {"id": 10, "fullName": "Olivia Taylor", "jobTitle": "Project Manager"},
    {"id": 11, "fullName": "James Anderson", "jobTitle": "Database Administrator"},
    {"id": 12, "fullName": "Isabella Thomas", "jobTitle": "Data Analyst"},
    {"id": 13, "fullName": "Alexander Jackson", "jobTitle": "Mobile Developer"},
    {"id": 14, "fullName": "Ava Miller", "jobTitle": "Quality Engineer"},
    {"id": 15, "fullName": "Ethan Davis", "jobTitle": "Systems Administrator"}
  ];

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          var user = users[index];
          return ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailDetailPage(
                    fullName: user["fullName"],
                    jobTitle: user["jobTitle"],
                    imageUrl: 'https://randomuser.me/api/portraits/men/${user['id']}.jpg',
                  ),
                ),
              );
            },

            leading: CircleAvatar(
              backgroundImage: NetworkImage(
                'https://randomuser.me/api/portraits/men/${user['id']}.jpg',
              ),
              radius: 25,
            ),
            title: Text(user["fullName"].toString()),
            subtitle: Text(user["jobTitle"].toString()),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "7 Mar",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                SizedBox(height: 4),
                Icon(Icons.star_border, color: Colors.grey[600]),
              ],
            ),
          );
        },
      ),
    );
  }
}
