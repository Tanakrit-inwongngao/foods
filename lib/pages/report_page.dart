import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/user_service.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Map<String, dynamic>> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await UserService.loadHistory();
    setState(() {
      history = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🕒 ประวัติการตรวจจับอาหาร"),
        backgroundColor: Colors.orange,
      ),
      backgroundColor: Colors.orange.shade50,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
          ? const Center(child: Text("ยังไม่มีประวัติการตรวจจับ"))
          : ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final h = history[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: ListTile(
              leading: h['image_base64'] != null
                  ? Image.memory(
                base64Decode(h['image_base64']),
                width: 50,
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.fastfood),
              title: Text(
                h['food_name_th'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${h['calories']} kcal"),
                  if (h['ingredients'] != null)
                    Text(
                      "วัตถุดิบ: ${h['ingredients']}",
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              trailing: Text(
                h['created_at']
                    .toString()
                    .replaceAll('T', ' ')
                    .substring(0, 16),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        },
      ),
    );
  }
}
