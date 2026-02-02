import 'package:flutter/material.dart';
import '../services/food_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> _foodsFuture;

  @override
  void initState() {
    super.initState();
    _foodsFuture = FoodService.getFoods();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _foodsFuture = FoodService.getFoods();
        });
      },
      child: FutureBuilder<List<dynamic>>(
        future: _foodsFuture,
        builder: (context, snapshot) {
          // กำลังโหลด
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // error
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "เกิดข้อผิดพลาด\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final foods = snapshot.data ?? [];
          if (foods.isEmpty) {
            return const Center(child: Text("ไม่มีข้อมูลอาหาร"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: foods.length,
            itemBuilder: (context, index) {
              final f = foods[index];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.restaurant, color: Colors.white),
                  ),
                  title: Text(
                    f['name_th'] ?? '-',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      "พลังงาน ${f['nutrition']} kcal\n"
                          "โปรตีน ${f['protein_g']}g | ไขมัน ${f['fat_g']}g | คาร์บ ${f['carbs_g']}g",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    _showFoodDetail(context, f);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ============================
  /// Popup รายละเอียดอาหาร
  /// ============================
  void _showFoodDetail(BuildContext context, Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name_th'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  food['name_en'] ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(height: 30),

                _infoRow("ภูมิภาค", food['region']),
                _infoRow("พลังงาน", "${food['nutrition']} kcal"),
                _infoRow("โปรตีน", "${food['protein_g']} g"),
                _infoRow("ไขมัน", "${food['fat_g']} g"),
                _infoRow("คาร์โบไฮเดรต", "${food['carbs_g']} g"),

                const SizedBox(height: 16),
                const Text(
                  "ส่วนผสม",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(food['ingredients'] ?? '-'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
