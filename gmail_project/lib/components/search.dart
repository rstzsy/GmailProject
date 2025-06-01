import 'package:flutter/material.dart';

class Search extends StatelessWidget {
  final Function(String)? onChanged;
  final VoidCallback? onDateFilterTap;
  const Search({super.key, this.onChanged, this.onDateFilterTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: "Search in mail",
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: onDateFilterTap,
          ),
        ],
      ),
    );
  }
}
