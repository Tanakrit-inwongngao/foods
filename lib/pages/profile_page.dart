import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _editing = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _allergenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ===============================
  // LOAD PROFILE
  // ===============================
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    _nameCtrl.text = prefs.getString('user_name') ?? 'demo';
    _emailCtrl.text = prefs.getString('user_email') ?? 'demo@example.com';

    final allergens = prefs.getStringList('user_allergens') ?? [];
    _allergenCtrl.text = allergens.join(', ');
    setState(() {});
  }

  // ===============================
  // SAVE PROFILE
  // ===============================
  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', _nameCtrl.text.trim());
    await prefs.setString('user_email', _emailCtrl.text.trim());

    if (_passwordCtrl.text.isNotEmpty) {
      await prefs.setString('user_password', _passwordCtrl.text);
    }

    final allergens = _allergenCtrl.text
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    await prefs.setStringList('user_allergens', allergens);

    setState(() => _editing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ บันทึกโปรไฟล์เรียบร้อย')),
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
        backgroundColor: Colors.orange,
        title: const Text('โปรไฟล์ผู้ใช้'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() => _editing = !_editing);
            },
          ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 20),
            _buildField('ชื่อผู้ใช้', _nameCtrl, enabled: _editing),
            _buildField('อีเมล', _emailCtrl, enabled: false),
            if (_editing)
              _buildField(
                'รหัสผ่านใหม่',
                _passwordCtrl,
                obscure: true,
              ),

            // 🔴 ALLERGEN FIELD
            _buildAllergenField(),

            if (_editing)
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ===============================
  // AVATAR
  // ===============================
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.deepPurple.shade100,
      child: const Icon(Icons.person, size: 50, color: Colors.deepPurple),
    );
  }

  // ===============================
  // TEXT FIELD
  // ===============================
  Widget _buildField(
      String label,
      TextEditingController controller, {
        bool enabled = true,
        bool obscure = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ===============================
  // ALLERGEN FIELD
  // ===============================
  Widget _buildAllergenField() {
    final allergens = _allergenCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _allergenCtrl,
          enabled: _editing,
          decoration: InputDecoration(
            labelText: 'อาหารที่แพ้ (คั่นด้วย ,)',
            hintText: 'เช่น กุ้ง, นม, ถั่ว',
            filled: true,
            fillColor: _editing ? Colors.white : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (allergens.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: allergens
                .map(
                  (a) => Chip(
                label: Text(a),
                backgroundColor: Colors.red.shade50,
                labelStyle:
                const TextStyle(color: Colors.red, fontSize: 13),
              ),
            )
                .toList(),
          ),
      ],
    );
  }
}
