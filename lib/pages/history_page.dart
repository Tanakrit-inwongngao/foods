import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../services/user_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  // ===============================
  // LOAD HISTORY (LOCAL)
  // ===============================
  Future<void> loadHistory() async {
    final data = await UserService.loadHistory();
    setState(() {
      _history = data;
      loading = false;
    });
  }

  // ===============================
  // CLEAR HISTORY
  // ===============================
  Future<void> clearHistory() async {
    await UserService.clearHistory();
    await loadHistory();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ล้างประวัติเรียบร้อยแล้ว")),
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: const Text("📜 ประวัติการตรวจจับอาหาร"),
        backgroundColor: Colors.orange,
        actions: [
          // 🔄 REFRESH BUTTON
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "รีเฟรช",
            onPressed: () {
              setState(() => loading = true);
              loadHistory();
            },
          ),
          // 🗑️ CLEAR HISTORY
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "ล้างประวัติ",
            onPressed: clearHistory,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: loadHistory,
        child: _history.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                "ยังไม่มีประวัติการตรวจจับ",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];

            Uint8List? image;
            if (item['image_base64'] != null) {
              try {
                image = base64Decode(item['image_base64']);
              } catch (_) {}
            }

            return Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: image != null
                          ? Image.memory(
                        image,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.fastfood),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // INFO
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['food_name_th'] ?? '-',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🔥 ${item['calories']} kcal',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '🥩 โปรตีน ${item['protein_g']}g | '
                                '🧈 ไขมัน ${item['fat_g']}g | '
                                '🍚 คาร์บ ${item['carbs_g']}g',
                            style:
                            const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '🍴 วัตถุดิบ: ${item['ingredients'] ?? "-"}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
