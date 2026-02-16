import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';

/// หน้า: อาหารที่แพ้
/// - อ่าน token จาก SharedPreferences (รองรับหลาย key)
/// - เรียก API: /api/auth/get_allergies.php
/// - บันทึก API: /api/auth/update_allergies.php
/// - ส่งทั้ง Authorization Bearer + Cookie(PHPSESSID) เพื่อรองรับฝั่ง PHP
/// - ถ้าเจอ 401 -> ล้าง token + เด้งไปหน้า Login ทันที
class AllergenPage extends StatefulWidget {
  final String? token; // ถ้าหน้าก่อนส่งมาให้ใช้ก่อน
  const AllergenPage({super.key, this.token});

  @override
  State<AllergenPage> createState() => _AllergenPageState();
}

class _AllergenPageState extends State<AllergenPage> {
  // ===== API config =====
  static const String _basePath = '/api';
  static const String _hostAndroidEmu = '10.0.2.2';
  static const String _hostOther = 'localhost';

  static String get _host => Platform.isAndroid ? _hostAndroidEmu : _hostOther;

  Uri _api(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  // ===== Auth =====
  static const String _tokenKey = 'auth_token';
  String? _token;

  Map<String, String> get _authHeaders {
    final t = _token?.trim();
    if (t == null || t.isEmpty) return const {};
    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $t',
      'X-Auth-Token': t,
      // สำคัญ: ถ้าฝั่ง PHP ใช้ session จาก cookie
      'Cookie': 'PHPSESSID=$t',
    };
  }

  // ===== UI state =====
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  // เก็บ 3 ช่อง allergy1-3
  final List<String> _slots = List.filled(3, '');

  bool get _hasToken => (_token != null && _token!.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();

    // token จาก widget ก่อน
    _token = widget.token?.trim();

    // รองรับหลาย key
    _token ??= prefs.getString(_tokenKey);
    _token ??= prefs.getString('token');
    _token ??= prefs.getString('access_token');
    _token ??= prefs.getString('jwt');

    if (!_hasToken) {
      setState(() {
        _loading = false;
        _error = 'ยังไม่เข้าสู่ระบบ (ไม่พบ token)';
      });
      return;
    }

    await _loadAllergies();

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('token');
    await prefs.remove('access_token');
    await prefs.remove('jwt');
  }

  Future<void> _handle401() async {
    await _clearAuth();
    if (!mounted) return;
    setState(() {
      _token = null;
      _error = 'เซสชันหมดอายุ/ยังไม่เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่';
      _busy = false;
      _loading = false;
    });

    // เด้งไปหน้า login เลย กันค้างหน้าเดิม
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadAllergies() async {
    if (!_hasToken) return;

    setState(() {
      _error = '';
    });

    final uri = _api('/auth/get_allergies.php');

    try {
      final res = await http.get(uri, headers: _authHeaders);

      if (res.statusCode == 401) {
        await _handle401();
        return;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _error = 'โหลดไม่สำเร็จ (HTTP ${res.statusCode})';
        });
        return;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {
        setState(() {
          _error = 'เซิร์ฟเวอร์ตอบกลับไม่ใช่ JSON';
        });
        return;
      }

      // รองรับ: { ok:true, data:{ allergy1..3 } } หรือ { allergy1..3 }
      Map<String, dynamic> data = {};
      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is Map) {
          data = Map<String, dynamic>.from(decoded['data'] as Map);
        } else {
          data = decoded;
        }
      }

      setState(() {
        _slots[0] = (data['allergy1'] ?? '').toString().trim();
        _slots[1] = (data['allergy2'] ?? '').toString().trim();
        _slots[2] = (data['allergy3'] ?? '').toString().trim();
      });
    } catch (e) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ';
      });
    }
  }

  Future<void> _saveAllergies() async {
    if (!_hasToken) {
      _snack('ยังไม่เข้าสู่ระบบ (ไม่พบ token)');
      return;
    }

    final uri = _api('/auth/update_allergies.php');

    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      final res = await http.post(
        uri,
        headers: <String, String>{
          ..._authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'allergy1': _slots[0].trim(),
          'allergy2': _slots[1].trim(),
          'allergy3': _slots[2].trim(),
        }),
      );

      if (res.statusCode == 401) {
        await _handle401();
        return;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _error = 'บันทึกไม่สำเร็จ (HTTP ${res.statusCode})';
        });
        return;
      }

      _snack('บันทึกแล้ว');
      await _loadAllergies();
    } catch (_) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addDialog() async {
    if (!_hasToken) {
      _snack('ยังไม่เข้าสู่ระบบ (ไม่พบ token)');
      return;
    }

    final idx = _slots.indexWhere((s) => s.trim().isEmpty);
    if (idx == -1) {
      _snack('เพิ่มได้สูงสุด 3 รายการ');
      return;
    }

    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('เพิ่มอาหารที่แพ้'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'เช่น กุ้ง, นม, ถั่วลิสง'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('เพิ่ม')),
        ],
      ),
    );

    if (ok != true) return;
    final v = ctrl.text.trim();
    if (v.isEmpty) return;

    setState(() {
      _slots[idx] = v;
    });
    await _saveAllergies();
  }

  Future<void> _removeAt(int idx) async {
    setState(() {
      _slots[idx] = '';
    });
    await _saveAllergies();
  }

  Widget _slotCard(int idx) {
    final label = 'รายการที่ ${idx + 1}';
    final value = _slots[idx].trim();

    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
        trailing: value.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _busy ? null : () => _removeAt(idx),
        ),
        onTap: _busy
            ? null
            : () async {
          final ctrl = TextEditingController(text: value);
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('แก้ไข $label'),
              content: TextField(controller: ctrl),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('บันทึก')),
              ],
            ),
          );
          if (ok != true) return;
          final v = ctrl.text.trim();
          setState(() {
            _slots[idx] = v;
          });
          await _saveAllergies();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : (!_hasToken)
        ? Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: 12),
            Text(
              _error.isEmpty ? 'ยังไม่เข้าสู่ระบบ' : _error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('ไปหน้าเข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    )
        : Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _slotCard(0),
              _slotCard(1),
              _slotCard(2),
              const SizedBox(height: 10),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'API: http://$_host$_basePath',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('อาหารที่แพ้'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _loadAllergies,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: !_hasToken
          ? null
          : FloatingActionButton(
        onPressed: _busy ? null : _addDialog,
        child: const Icon(Icons.add),
      ),
      body: body,
    );
  }
}
