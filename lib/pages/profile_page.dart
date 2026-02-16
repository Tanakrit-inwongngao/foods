import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'allergen_page.dart';


const Color kBrandOrange = Color(0xFFFF9800);

/// หน้าตั้งค่าผู้ใช้: แก้ชื่อ/รหัสผ่าน + Logout
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ✅ endpoint ของคุณอยู่ที่ /api/auth/...
  static const String _basePath = '/api';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _avatarKey = 'profile_avatar_b64';

  static String get _host {
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static Uri _uri(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  Uint8List? _avatarBytes;
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  String? _token;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadLocal();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey) ?? prefs.getString('token');
    final rawUser = prefs.getString(_userKey);
    final avatarB64 = prefs.getString(_avatarKey);

    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        _user = jsonDecode(rawUser) as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }

    _usernameCtrl.text = (_user?['username'] ?? '').toString();
    _emailCtrl.text = (_user?['email'] ?? '').toString();

    Uint8List? avatarBytes;
    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        avatarBytes = base64Decode(avatarB64);
      } catch (_) {
        avatarBytes = null;
      }
    }

    setState(() {
      _avatarBytes = avatarBytes;
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickAvatar() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 900,
      );
      if (xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarKey, base64Encode(bytes));

      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
      _snack('อัปเดตรูปโปรไฟล์แล้ว');
    } catch (e) {
      _snack('เลือกรูปไม่สำเร็จ: $e');
    }
  }

  Future<void> _removeAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarKey);
    if (!mounted) return;
    setState(() => _avatarBytes = null);
    _snack('ลบรูปโปรไฟล์แล้ว');
  }

  Future<void> _saveProfile() async {
    if (_token == null || _token!.isEmpty) {
      _snack('ไม่พบ token กรุณาเข้าสู่ระบบใหม่');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    final newPass = _newPassCtrl.text;

    if (newPass.isNotEmpty && newPass != _confirmPassCtrl.text) {
      _snack('รหัสผ่านใหม่ไม่ตรงกัน');
      return;
    }

    setState(() => _saving = true);

    try {
      final url = _uri('/auth/update_profile.php');
      final body = <String, dynamic>{
        'username': username,
        if (newPass.isNotEmpty) 'password': newPass,
      };

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      );

      // ignore: avoid_print
      print('UPDATE URL => $url');
      // ignore: avoid_print
      print('UPDATE STATUS => ${res.statusCode}');
      // ignore: avoid_print
      print('UPDATE BODY => ${res.body}');

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = json['ok'] == true;

      if (!ok) {
        _snack((json['message'] ?? json['error'] ?? 'อัปเดตไม่สำเร็จ').toString());
        return;
      }

      final data = (json['data'] is Map)
          ? (json['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      // รองรับ 2 แบบ: data.user หรือ data (คุณเลือกได้)
      final user = (data['user'] is Map)
          ? (data['user'] as Map).cast<String, dynamic>()
          : data.cast<String, dynamic>();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
      _user = user;

      _emailCtrl.text = (user['email'] ?? _emailCtrl.text).toString();

      _newPassCtrl.clear();
      _confirmPassCtrl.clear();

      setState(() => _editing = false);
      _snack('บันทึกสำเร็จ');
    } catch (_) {
      _snack('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey) ?? prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          _uri('/auth/logout.php'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {}
    }

    await prefs.remove(_tokenKey);
    await prefs.remove('token');
    await prefs.remove(_userKey);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBrandOrange,
        foregroundColor: Colors.white,

        title: const Text('ตั้งค่าผู้ใช้'),
        actions: [
          IconButton(
            tooltip: _editing ? 'ยกเลิก' : 'แก้ไข',
            icon: Icon(_editing ? Icons.close : Icons.edit),
            onPressed: _saving
                ? null
                : () {
              setState(() => _editing = !_editing);
              if (!_editing) {
                _usernameCtrl.text = (_user?['username'] ?? '').toString();
                _emailCtrl.text = (_user?['email'] ?? '').toString();
                _newPassCtrl.clear();
                _confirmPassCtrl.clear();
              }
            },
          ),
          if (_editing)
            IconButton(
              tooltip: 'บันทึก',
              icon: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.check),
              onPressed: _saving ? null : _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                onLongPress: _removeAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                      child: _avatarBytes == null
                          ? Text(
                        (_usernameCtrl.text.isNotEmpty ? _usernameCtrl.text[0] : 'U').toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kBrandOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('ข้อมูลบัญชี', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _usernameCtrl,
                enabled: _editing && !_saving,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
                  if (s.length < 3) return 'ชื่อผู้ใช้อย่างน้อย 3 ตัวอักษร';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'อีเมล',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('เปลี่ยนรหัสผ่าน', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _newPassCtrl,
                enabled: _editing && !_saving,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านใหม่ (เว้นว่างถ้าไม่เปลี่ยน)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (!_editing) return null;
                  final s = (v ?? '');
                  if (s.isEmpty) return null;
                  if (s.length < 6) return 'รหัสผ่านอย่างน้อย 6 ตัวอักษร';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassCtrl,
                enabled: _editing && !_saving,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัสผ่านใหม่',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (!_editing) return null;
                  if (_newPassCtrl.text.isEmpty) return null;
                  if ((v ?? '') != _newPassCtrl.text) return 'รหัสผ่านไม่ตรงกัน';
                  return null;
                },
              ),

              const SizedBox(height: 26),

              // ✅ ปุ่มไปหน้าอาหารที่แพ้
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('อาหารที่แพ้'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AllergenPage(token: _token)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandOrange,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('ออกจากระบบ'),
                  onPressed: _saving ? null : _logout,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'API: http://$_host$_basePath',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
