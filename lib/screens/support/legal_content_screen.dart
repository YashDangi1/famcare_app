import 'package:flutter/material.dart';

class LegalContentScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalContentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}
