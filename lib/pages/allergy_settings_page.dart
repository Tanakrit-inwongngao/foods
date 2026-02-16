import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'login_page.dart';
class AllergySettingsPage extends StatefulWidget {
  /// รับ token จากหน้าก่อนหน้า (เหมือนหน้าอื่น ๆ)
  /// ถ้าไม่ส่ง จะ fallback ไปอ่านจาก SharedPreferences
  final String? token;
  const AllergySettingsPage({super.key, this.token});

  @override
  State<AllergySettingsPage> createState() => _AllergySettingsPageState();
}

class _AllergySettingsPageState extends State<AllergySettingsPage> {
  // ========= API CONFIG =========
  static const String _basePath = '/api';

  // master list (ไม่ต้อง auth)
  static const String _masterAllergensEndpoint = '/foods/get_allergens.php';

  // user list + CRUD (ต้อง auth)
  static const String _userListEndpoint = '/auth/allergens/list.php';
  static const String _createEndpoint = '/auth/allergens/create.php';
  static const String _deleteEndpoint = '/auth/allergens/delete.php';

  static String get _host {
    // Android Emulator: 10.0.2.2 (เข้าถึง localhost ของเครื่องเรา)
    // ถ้าเป็นมือถือจริง ให้เปลี่ยนเป็น IP เครื่องที่รัน backend เช่น 192.168.1.x
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static Uri _uri(String endpoint) => Uri.parse('http://$_host$_basePath$endpoint');

  // ========= TOKEN =========
  static const String _tokenKey = 'auth_token';
  String? _token;

  bool get _hasToken => (_token != null && _token!.trim().isNotEmpty);

  Map<String, String> get _authHeaders {
    final t = _token?.trim() ?? '';
    if (t.isEmpty) return {};
    return {
      'Authorization': 'Bearer $t',
      'X-Auth-Token': t,
      // ช่วยกรณี PHP/Server ไม่ส่งต่อ Authorization header
      'Cookie': 'PHPSESSID=$t',
      'Accept': 'application/json',
    };
  }

  Future<void> _resolveToken() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) token ที่ส่งมาจากหน้าอื่นก่อน
    final passed = widget.token?.trim();
    _token = (passed != null && passed.isNotEmpty) ? passed : null;

    // 2) fallback: SharedPreferences
    _token ??= prefs.getString(_tokenKey);
    _token ??= prefs.getString('token');
    _token ??= prefs.getString('access_token');
    _token ??= prefs.getString('jwt');
  }

  // ========= DATA =========
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String _error = '';

  List<Map<String, dynamic>> _allAllergens = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Map<String, dynamic>> _selected = []; // items ที่ผู้ใช้เลือกไว้ (จาก user list)

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ========= HELPERS =========
  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) return data;
      if (data is Map && data['items'] is List) return data['items'] as List;

      for (final k in ['items', 'results', 'allergens']) {
        final v = decoded[k];
        if (v is List) return v;
        if (v is Map && v['items'] is List) return v['items'] as List;
      }
    }
    return const <dynamic>[];
  }

  Map<String, dynamic> _normalizeMaster(dynamic row) {
    final m = (row as Map).cast<String, dynamic>();
    final id = int.tryParse((m['allergen_id'] ?? m['id'] ?? '').toString()) ?? 0;
    final name = (m['allergen_name'] ?? m['name'] ?? '').toString().trim();
    return {
      'allergen_id': id,
      'name': name.isEmpty ? 'Allergen' : name,
    };
  }

  String _nameForId(int id) {
    final found = _allAllergens.firstWhere(
          (e) => (e['allergen_id'] ?? e['id']) == id,
      orElse: () => const <String, dynamic>{},
    );
    return (found['name'] ?? found['allergen_name'] ?? 'Allergen').toString();
  }

  bool _isSelected(int allergenId) {
    return _selected.any((x) => (x['allergen_id'] ?? x['id']) == allergenId);
  }

  void _toggleSelect(Map<String, dynamic> item) {
    final id = int.tryParse((item['allergen_id'] ?? item['id'] ?? '').toString()) ?? 0;
    if (id <= 0) return;

    setState(() {
      if (_isSelected(id)) {
        _selected.removeWhere((x) => (x['allergen_id'] ?? x['id']) == id);
      } else {
        if (_selected.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เลือกได้ไม่เกิน 3 อย่าง')),
          );
          return;
        }
        _selected.add({
          'allergen_id': id,
          'name': (item['name'] ?? item['allergen_name'] ?? '').toString(),
        });
      }
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(_allAllergens);
      } else {
        _filtered = _allAllergens.where((e) {
          final name = (e['name'] ?? '').toString().toLowerCase();
          return name.contains(q);
        }).toList();
      }
    });
  }

  // ========= LOAD =========
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _resolveToken();
      if (!_hasToken) {
        setState(() {
          _error = 'ไม่พบ token กรุณาเข้าสู่ระบบใหม่';
          _loading = false;
        });
        return;
      }

      // 1) master list
      final listRes = await http.get(_uri(_masterAllergensEndpoint));
      if (listRes.statusCode < 200 || listRes.statusCode >= 300) {
        setState(() {
          _error = 'โหลดรายการสารก่อแพ้ไม่สำเร็จ (HTTP ${listRes.statusCode})';
          _loading = false;
        });
        return;
      }

      dynamic listDecoded;
      try {
        listDecoded = jsonDecode(listRes.body);
      } catch (_) {
        setState(() {
          _error = 'เซิร์ฟเวอร์ตอบกลับรายการสารก่อแพ้ไม่ใช่ JSON';
          _loading = false;
        });
        return;
      }

      final master = _extractList(listDecoded).map(_normalizeMaster).toList();
      _allAllergens = master;
      _filtered = List<Map<String, dynamic>>.from(_allAllergens);

      // 2) user list (ใช้ endpoint ที่มีอยู่จริงฝั่ง PHP: /api/auth/allergens/...)
      final t = _token!.trim();
      final myUri = _uri(_userListEndpoint).replace(queryParameters: {'token': t});
      final myRes = await http.get(myUri, headers: _authHeaders);

      if (myRes.statusCode == 401) {
        setState(() {
          _error = 'เซสชันหมดอายุ/ยังไม่เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่';
          _loading = false;
        });
        return;
      }

      if (myRes.statusCode < 200 || myRes.statusCode >= 300) {
        setState(() {
          _error = 'โหลดรายการที่เลือกไว้ไม่สำเร็จ (HTTP ${myRes.statusCode})';
          _loading = false;
        });
        return;
      }

      dynamic myDecoded;
      try {
        myDecoded = jsonDecode(myRes.body);
      } catch (_) {
        setState(() {
          _error = 'เซิร์ฟเวอร์ตอบกลับรายการที่เลือกไว้ไม่ใช่ JSON';
          _loading = false;
        });
        return;
      }

      final myItems = _extractList(myDecoded);
      // normalize ให้มี allergen_id และ name (แม้ backend จะส่งมาแค่ id)
      _selected = myItems.map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final id = int.tryParse((m['allergen_id'] ?? m['id'] ?? '').toString()) ?? 0;
        return {
          'allergen_id': id,
          'name': (m['name'] ?? m['allergen_name'] ?? _nameForId(id)).toString(),
        };
      }).where((e) => (e['allergen_id'] as int) > 0).toList();

      setState(() => _loading = false);
    } on SocketException {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ (ตรวจสอบ host/IP และ backend ทำงานอยู่ไหม)';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
        _loading = false;
      });
    }
  }

  // ========= SAVE =========
  Future<void> _save() async {
    if (_saving) return;

    await _resolveToken();
    if (!_hasToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบ token กรุณาเข้าสู่ระบบใหม่')),
      );
      return;
    }

    final targetIds = _selected
        .map((e) => e['allergen_id'])
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();

    setState(() => _saving = true);

    try {
      // โหลด current จาก server อีกครั้ง เพื่อให้ diff แม่น
      final t = _token!.trim();
      final myUri = _uri(_userListEndpoint).replace(queryParameters: {'token': t});
      final myRes = await http.get(myUri, headers: _authHeaders);

      if (myRes.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
        );
        setState(() => _saving = false);
        return;
      }

      final myDecoded = jsonDecode(myRes.body);
      final currentIds = _extractList(myDecoded)
          .map((e) => int.tryParse(((e as Map)['allergen_id'] ?? (e as Map)['id'] ?? '').toString()) ?? 0)
          .where((id) => id > 0)
          .toSet();

      final toAdd = targetIds.difference(currentIds).toList();
      final toRemove = currentIds.difference(targetIds).toList();

      // add
      for (final id in toAdd) {
        final uri = _uri(_createEndpoint).replace(queryParameters: {'token': t});
        final res = await http.post(
          uri,
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({'allergen_id': id}),
        );

        if (res.statusCode == 401) {

          await _forceLogout('เซสชันหมดอายุ/ยังไม่เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่');

          return;

        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('ADD_FAIL_$id');
        }
      }

      // remove
      for (final id in toRemove) {
        final uri = _uri(_deleteEndpoint).replace(queryParameters: {'token': t});
        final res = await http.post(
          uri,
          headers: {
            ..._authHeaders,
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({'allergen_id': id}),
        );

        if (res.statusCode == 401) {

          await _forceLogout('เซสชันหมดอายุ/ยังไม่เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่');

          return;

        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('DEL_FAIL_$id');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกสำเร็จ')),
        );
      }

      await _loadAll();
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ (เชื่อมต่อเซิร์ฟเวอร์ไม่ได้)')),
      );
    } on FormatException catch (e) {
      if (e.message == 'UNAUTH') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกไม่สำเร็จ')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่าภูมิแพ้'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error, textAlign: TextAlign.center),
      ))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ค้นหาสารก่อแพ้...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('เลือกแล้ว: ${_selected.length}/3'),
                ),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.save),
                  label: const Text('บันทึก'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _filtered[index];
                final id = (item['allergen_id'] as int?) ?? 0;
                final name = (item['name'] ?? 'Allergen').toString();
                final selected = _isSelected(id);

                return ListTile(
                  title: Text(name),
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? Colors.green : null,
                  ),
                  onTap: _saving ? null : () => _toggleSelect(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
