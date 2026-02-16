import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/user_service.dart';
import '../services/history_store.dart';

import 'history_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final String? token;

  const HomePage({super.key, this.token});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _imageBytes;
  int? _imgW;
  int? _imgH;
  bool _loading = false;
  List<dynamic> _items = [];
  List<Uint8List?> _itemCrops = [];
  int _bestIdx = -1; // index ของผลลัพธ์ที่ confidence สูงสุด

  final ImagePicker _picker = ImagePicker();



// ===== AUTH TOKEN & ALLERGIES =====
  static const String _tokenKey = 'auth_token';
  String? _token;

  static String get _host => Platform.isAndroid ? '10.0.2.2' : 'localhost';
  static Uri _u(String path) => Uri.parse('http://$_host$path');

  List<String> _userAllergies = [];
  bool _loadingAllergies = false;
  String? _allergyError;

  @override
  void initState() {
    super.initState();
    _initTokenAndAllergies();
  }

  Future<void> _initTokenAndAllergies() async {
    final prefs = await SharedPreferences.getInstance();

    // Prefer token passed from previous page; fallback to SharedPreferences.
    final passed = (widget.token ?? '').trim();
    final stored = (prefs.getString(_tokenKey) ?? '').trim();
    final token = passed.isNotEmpty ? passed : stored;

    // If a non-empty token was passed in, persist it (don't overwrite with empty).
    if (passed.isNotEmpty && passed != stored) {
      await prefs.setString(_tokenKey, passed);
    }

    if (!mounted) return;
    setState(() => _token = token.isEmpty ? null : token);

    await _loadUserAllergies();
  }

  Future<void> _loadUserAllergies() async {
    if (_loadingAllergies) return;

    final token = (_token?.trim().isNotEmpty ?? false) ? _token!.trim() : '';
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _userAllergies = [];
        _allergyError = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingAllergies = true;
      _allergyError = null;
    });

    try {
      final res = await http.get(
        _u('/api/auth/get_allergies.php'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Auth-Token': token,
          'Cookie': 'PHPSESSID=$token',
        },
      );

      if (res.statusCode == 401) {
        // token หมดอายุ/ไม่ถูกต้อง: ล้าง token แล้วให้ผู้ใช้ login ใหม่
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        if (!mounted) return;
        setState(() {
          _token = null;
          _userAllergies = [];
          _allergyError = 'UNAUTHORIZED: กรุณาเข้าสู่ระบบใหม่';
        });
        return;
      }

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      Map<String, dynamic>? data;
      if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is Map<String, dynamic>) {
          data = decoded['data'] as Map<String, dynamic>;
        } else {
          data = decoded;
        }
      }

      final a1 = (data?['allergy1'] ?? '').toString().trim();
      final a2 = (data?['allergy2'] ?? '').toString().trim();
      final a3 = (data?['allergy3'] ?? '').toString().trim();

      final list = <String>[];
      for (final a in [a1, a2, a3]) {
        if (a.isNotEmpty) list.add(a);
      }

      if (!mounted) return;
      setState(() {
        _userAllergies = list;
        _allergyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userAllergies = [];
        _allergyError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _loadingAllergies = false);
    }
  }

  void _resetToPick() {
    setState(() {
      _imageBytes = null;
      _items = [];
      _loading = false;
    });
  }

  // ===============================
  // PICK IMAGE
  // ===============================
  Future<void> _pickImage() async {
    final XFile? file =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    await _ensureImageSize(bytes);

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _items = [];
      _itemCrops = [];
      _bestIdx = -1;
    });
  }

  // ===============================
  // ANALYZE
  // ===============================
  Future<void> _analyze() async {
    if (_imageBytes == null) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService.analyze(_imageBytes!);
      final List items = (response['items'] as List?) ?? [];

      // pre-crop all bbox images (so UI won't be stuck on "กำลังตัด...")
      final crops = List<Uint8List?>.filled(items.length, null);

      await Future.wait(List.generate(items.length, (i) async {
        final imgW = _imgW ?? 0;
        final imgH = _imgH ?? 0;
        if (imgW <= 0 || imgH <= 0) return;

        final rawBox = _extractBbox(items[i]);
        if (rawBox == null) return;
        final nb = _toNormalizedBbox(rawBox, imgW: imgW, imgH: imgH);
        if (nb == null) return;

        crops[i] = await _cropFromBbox(_imageBytes!, nb);
      }));

      if (!mounted) return;

      setState(() {
        _items = items;
        _itemCrops = crops;
      });

// save history (safe)
      for (final item in items) {
        final food = item['food'];
        if (food == null) continue;

        await UserService.addHistory({
          'food_name_th': food['name_th'],
          'food_name_en': food['name_en'],
          'calories': food['nutrition'],
          'protein_g': food['protein_g'],
          'fat_g': food['fat_g'],
          'carbs_g': food['carbs_g'],
          'ingredients': food['ingredients'],
          'image_base64': base64Encode(_imageBytes!),
        });

        // also keep in-memory history for HistoryPage
        HistoryStore.add({
          'title': (food['name_th'] ?? food['name_en'] ?? '').toString(),
          'calories': food['nutrition'],
          'confidence': (((item['confidence'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(1),
          'ingredients': food['ingredients'],
          'image_base64': base64Encode(_imageBytes!),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ วิเคราะห์ไม่สำเร็จ: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===============================
  // HELPERS
  // ===============================
  List<String> _parseIngredients(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _prettyLabel(String? raw) {
    if (raw == null) return 'ไม่ทราบชนิด';
    switch (raw) {
      case 'fried_egg':
        return '🍳 ไข่ดาว';
      case 'minced_pork':
        return '🥩 หมูสับ';
      case 'rice':
        return '🍚 ข้าว';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  String _bboxLabelText(dynamic item) {
    if (item is! Map) return 'ไม่ทราบชนิด';

    // 1) Prefer DB-resolved food name (Thai/English) if available
    final food = item['food'];
    String name = '';
    if (food is Map) {
      name = (food['name_th'] ?? food['name_en'] ?? '').toString().trim();
    }

    // รองรับ key แบบเก่า/คนละโครงสร้าง (กันกรณี backend ส่งชื่อมาไม่อยู่ใน food)
    if (name.isEmpty) {
      name = (item['food_name_th'] ??
          item['food_name_en'] ??
          item['name_th'] ??
          item['name_en'] ??
          '')
          .toString()
          .trim();
    }

    if (name.isNotEmpty && name != 'null') return name;

    // 2) Fallback to model label (ลองหลาย key เพราะแต่ละ backend อาจใช้คนละชื่อ)
    final raw = (item['label'] ??
        item['class'] ??
        item['class_name'] ??
        item['cls'] ??
        item['name'])
        ?.toString()
        .trim();

    if (raw != null && raw.isNotEmpty && raw != 'null') {
      final guess = _prettyLabel(raw);
      // ให้ผู้ใช้รู้ว่าเป็นการคาดเดา (อาหารที่ใกล้เคียง)
      return (guess == 'ไม่ทราบชนิด') ? 'ไม่ทราบชนิด' : guess;
    }

    return 'ไม่ทราบชนิด';
  }


  // ===============================
  // BBOX HELPERS (รองรับ bbox หลายรูปแบบ + รองรับทั้ง normalized และ pixel)
  // ===============================
  Map<String, double>? _extractBbox(dynamic item) {
    dynamic b = item;
    // common nesting patterns
    if (item is Map) {
      b = item['bbox'] ??
          item['box'] ??
          item['bounding_box'] ??
          item['boundingBox'] ??
          item['rect'] ??
          item['detection']?['bbox'] ??
          item['det']?['bbox'] ??
          item['det']?['box'] ??
          item['result']?['bbox'] ??
          item['data']?['bbox'] ??
          item['coordinates'];

      // sometimes coords are top-level
      if (b == null &&
          item.containsKey('x1') &&
          item.containsKey('y1') &&
          item.containsKey('x2') &&
          item.containsKey('y2')) {
        b = {'x1': item['x1'], 'y1': item['y1'], 'x2': item['x2'], 'y2': item['y2']};
      }
    }

    if (b == null) return null;

    // Map formats
    if (b is Map) {
      // x1,y1,x2,y2
      if (b.containsKey('x1') && b.containsKey('y1') && b.containsKey('x2') && b.containsKey('y2')) {
        final x1 = (b['x1'] as num?)?.toDouble();
        final y1 = (b['y1'] as num?)?.toDouble();
        final x2 = (b['x2'] as num?)?.toDouble();
        final y2 = (b['y2'] as num?)?.toDouble();
        if ([x1, y1, x2, y2].contains(null)) return null;
        return {'x1': x1!, 'y1': y1!, 'x2': x2!, 'y2': y2!};
      }

      // left,top,right,bottom
      if (b.containsKey('left') && b.containsKey('top') && b.containsKey('right') && b.containsKey('bottom')) {
        final x1 = (b['left'] as num?)?.toDouble();
        final y1 = (b['top'] as num?)?.toDouble();
        final x2 = (b['right'] as num?)?.toDouble();
        final y2 = (b['bottom'] as num?)?.toDouble();
        if ([x1, y1, x2, y2].contains(null)) return null;
        return {'x1': x1!, 'y1': y1!, 'x2': x2!, 'y2': y2!};
      }

      // x,y,w,h
      if (b.containsKey('x') && b.containsKey('y') && b.containsKey('w') && b.containsKey('h')) {
        final x = (b['x'] as num?)?.toDouble();
        final y = (b['y'] as num?)?.toDouble();
        final w = (b['w'] as num?)?.toDouble();
        final h = (b['h'] as num?)?.toDouble();
        if ([x, y, w, h].contains(null)) return null;
        return {'x1': x!, 'y1': y!, 'x2': x! + w!, 'y2': y! + h!};
      }

      // x,y,width,height
      if (b.containsKey('x') && b.containsKey('y') && b.containsKey('width') && b.containsKey('height')) {
        final x = (b['x'] as num?)?.toDouble();
        final y = (b['y'] as num?)?.toDouble();
        final w = (b['width'] as num?)?.toDouble();
        final h = (b['height'] as num?)?.toDouble();
        if ([x, y, w, h].contains(null)) return null;
        return {'x1': x!, 'y1': y!, 'x2': x! + w!, 'y2': y! + h!};
      }
    }

    // List formats: [x1,y1,x2,y2] or [x,y,w,h]
    if (b is List && b.length >= 4) {
      final a = (b[0] as num?)?.toDouble();
      final c = (b[1] as num?)?.toDouble();
      final d = (b[2] as num?)?.toDouble();
      final e = (b[3] as num?)?.toDouble();
      if ([a, c, d, e].contains(null)) return null;
      return {'x1': a!, 'y1': c!, 'x2': d!, 'y2': e!};
    }

    return null;
  }

  // Convert bbox to normalized (0..1) based on original image size when bbox is pixel-based.
  Map<String, double>? _toNormalizedBbox(Map<String, double> b, {required int imgW, required int imgH}) {
    double x1 = b['x1'] ?? 0, y1 = b['y1'] ?? 0, x2 = b['x2'] ?? 0, y2 = b['y2'] ?? 0;

    // if looks like pixel coords, normalize them
    final looksPixel = (x2 > 1.2 || y2 > 1.2 || x1 > 1.2 || y1 > 1.2);
    if (looksPixel) {
      x1 = x1 / imgW;
      x2 = x2 / imgW;
      y1 = y1 / imgH;
      y2 = y2 / imgH;
    }

    // sanity clamp
    x1 = x1 < 0 ? 0 : x1;
    y1 = y1 < 0 ? 0 : y1;
    x2 = x2 < 0 ? 0 : x2;
    y2 = y2 < 0 ? 0 : y2;

    // ensure proper ordering
    final nx1 = x1 < x2 ? x1 : x2;
    final nx2 = x1 < x2 ? x2 : x1;
    final ny1 = y1 < y2 ? y1 : y2;
    final ny2 = y1 < y2 ? y2 : y1;

    final dx = (nx2 - nx1).abs();
    final dy = (ny2 - ny1).abs();
    final looksNorm = (nx2 <= 1.2 && ny2 <= 1.2 && nx1 <= 1.2 && ny1 <= 1.2);
    if (looksNorm) {
      if (dx < 0.005 || dy < 0.005) return null;
    } else {
      if (dx < 2 || dy < 2) return null; // pixel coords
    }
    return {'x1': nx1, 'y1': ny1, 'x2': nx2, 'y2': ny2};
  }

  Future<void> _ensureImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      _imgW = img.width;
      _imgH = img.height;
      img.dispose();
    } catch (_) {
      _imgW = null;
      _imgH = null;
    }
  }


  // ===============================
  // CROP IMAGE FROM BBOX (for preview)
  // ===============================
  Future<Uint8List?> _cropFromBbox(Uint8List bytes, Map bbox,
      {double pad = 0.02}) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ui.Image img = frame.image;

      final iw = img.width.toDouble();
      final ih = img.height.toDouble();

      double x1 = ((bbox['x1'] as num).toDouble() - pad).clamp(0.0, 1.0);
      double y1 = ((bbox['y1'] as num).toDouble() - pad).clamp(0.0, 1.0);
      double x2 = ((bbox['x2'] as num).toDouble() + pad).clamp(0.0, 1.0);
      double y2 = ((bbox['y2'] as num).toDouble() + pad).clamp(0.0, 1.0);

      final src = ui.Rect.fromLTRB(x1 * iw, y1 * ih, x2 * iw, y2 * ih);
      final outW = src.width.round();
      final outH = src.height.round();

      if (outW <= 1 || outH <= 1) {
        img.dispose();
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      canvas.drawImageRect(
        img,
        src,
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        paint,
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(outW, outH);
      final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);

      img.dispose();
      cropped.dispose();

      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }


  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: (_imageBytes == null && _items.isEmpty && !_loading)
              ? null
              : _resetToPick,
          tooltip: 'กลับไปเลือกภาพ',
        ),
        title: const Text('🍜 Thai Food Detector'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem),
            tooltip: 'รีเฟรชอาหารที่แพ้',
            onPressed: _loadUserAllergies,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'ประวัติ',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'โปรไฟล์',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _items.isEmpty ? _buildImageCard() : _buildImageWithBoxes(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 12),
            _buildUserAllergyBanner(),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (_items.isNotEmpty) _buildResultList(),
          ],
        ),
      ),
    );
  }


// ===============================
// USER ALLERGY BANNER
// ===============================
  Widget _buildUserAllergyBanner() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.report_problem, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'อาหารที่คุณแพ้',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingAllergies)
                    const Text('กำลังโหลด...', style: TextStyle(fontSize: 12)),
                  if (_allergyError != null)
                    Text(
                      'โหลดไม่สำเร็จ: ${_prettyAllergyError(_allergyError)}',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  if (!_loadingAllergies && _allergyError == null)
                    Text(
                      _userAllergies.isEmpty
                          ? 'ยังไม่ได้ตั้งค่า'
                          : _userAllergies.join(', '),
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'รีเฟรช',
              onPressed: _loadingAllergies ? null : _loadUserAllergies,
              icon: const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyAllergyError(String? raw) {
    final s = (raw ?? '').trim();

    if (s.isEmpty) return 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';

    // token/ยังไม่ login
    if (s.contains('UNAUTHORIZED') || s.contains('กรุณาเข้าสู่ระบบก่อน') || s.contains('HTTP 401')) {
      return 'กรุณาเข้าสู่ระบบใหม่ (token หมดอายุ/ไม่ถูกต้อง)';
    }

    // path ผิด/ไฟล์ไม่เจอ
    if (s.contains('404') || s.toLowerCase().contains('not found')) {
      return 'ไม่พบ API (เช็ค path /api/... และไฟล์ PHP)';
    }

    // cleartext http ถูกบล็อก
    if (s.toLowerCase().contains('cleartext')) {
      return 'Android บล็อก HTTP: เปิด usesCleartextTraffic ใน AndroidManifest.xml';
    }

    // แสดงสั้นๆ กันรกจอ
    return s.length > 180 ? '${s.substring(0, 180)}...' : s;
  }


// ===============================
  // IMAGE CARD
  // ===============================
  Widget _buildImageCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 220,
        child: _imageBytes == null
            ? const Center(
          child: Text('ยังไม่ได้เลือกรูป',
              style: TextStyle(color: Colors.grey)),
        )
            : ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }

  // ===============================
  // IMAGE + BOUNDING BOX
  // ===============================
  Widget _buildImageWithBoxes() {
    if (_imageBytes == null) return const SizedBox();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const h = 220.0;

        // find the highest-confidence item (for highlight)
        int bestIdx = -1;
        double bestConf = -1;
        for (int i = 0; i < _items.length; i++) {
          final c = (_items[i]['confidence'] as num?)?.toDouble() ?? 0;
          if (c > bestConf) {
            bestConf = c;
            bestIdx = i;
          }
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
              ),

              // boxes
              ..._items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final bbox = _extractBbox(item);
                if (bbox == null) return const SizedBox();

                final imgW = _imgW ?? 0;
                final imgH = _imgH ?? 0;

                // ต้องรู้ขนาดภาพต้นฉบับเพื่อแปลง bbox (ถ้า API ส่งเป็นพิกเซล)
                if (imgW <= 0 || imgH <= 0) {
                  return const SizedBox();
                }

                final nb = _toNormalizedBbox(bbox, imgW: imgW, imgH: imgH);
                if (nb == null) return const SizedBox();

                final x1 = nb['x1']!;
                final y1 = nb['y1']!;
                final x2 = nb['x2']!;
                final y2 = nb['y2']!;

                return Positioned(
                  left: x1 * w,
                  top: y1 * h,
                  width: (x2 - x1) * w,
                  height: (y2 - y1) * h,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: (i == bestIdx) ? Colors.green : Colors.orange,
                        width: (i == bestIdx) ? 3.5 : 2,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        color: (i == bestIdx) ? Colors.green : Colors.orange,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text(
                          _bboxLabelText(item),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // ===============================
  // BUTTONS
  // ===============================
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo),
            label: const Text('เลือกรูป'),
            style:
            ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white, // ตัวหนังสือ/ไอคอนสีขาว
              disabledForegroundColor: Colors.white70,
              disabledBackgroundColor: Colors.deepPurpleAccent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: const Icon(Icons.analytics),
            label: const Text('วิเคราะห์'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white, // ตัวหนังสือ/ไอคอนสีขาว
              disabledForegroundColor: Colors.white70,
              disabledBackgroundColor: Colors.orangeAccent,
            ),
          ),
        ),
      ],
    );
  }

  // ===============================
  // RESULT LIST
  // ===============================
  Widget _buildResultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          '📋 ผลลัพธ์การวิเคราะห์',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),


        // Gallery: split/cropped images (one per detected bbox)
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            '🧩 ภาพที่ตัดออกมา',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, i) {
              final item = _items[i];
              final displayName = _bboxLabelText(item);
              final conf = ((item['confidence'] as num?)?.toDouble() ?? 0) * 100;
              final img = (i < _itemCrops.length) ? _itemCrops[i] : null;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange, width: 2),
                  color: Colors.orange.withOpacity(0.05),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: (img != null)
                          ? Image.memory(img, width: double.infinity, fit: BoxFit.cover)
                          : Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text('ไม่มี bbox/ภาพตัด', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName.isEmpty ? 'ไม่ทราบชื่อ' : displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Confidence ${conf.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final food = item['food'];
          if (food == null) return const SizedBox();

          final double conf =
              (item['confidence'] as num?)?.toDouble() ?? 0;

          final List<String> allergens =
              (item['allergens'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];

          final List<String> dangerAllergens =
              (item['danger_allergens'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
                  [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${food['name_th']} (${food['name_en']})',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange, width: 2),
                              color: Colors.orange.shade50,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: (_itemCrops.length > i && _itemCrops[i] != null)
                                  ? Image.memory(_itemCrops[i]!, fit: BoxFit.cover)
                                  : const Center(
                                  child: Text('กำลังตัด...',
                                      style: TextStyle(fontSize: 13))),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ภาพที่ตัด: ${food['name_th'] ?? food['name_en'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.deepOrange, width: 1.6),
                              color: Colors.deepOrange.withOpacity(0.06),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.center_focus_strong,
                                    size: 18, color: Colors.deepOrange),
                                const SizedBox(width: 6),
                                Text(
                                  'Confidence ${(conf * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              _buildIngredientSection(food['ingredients']),
              _buildNutritionSection(food),
              _buildAllergenSection(allergens, dangerAllergens),
            ],
          );
        }).toList(),
      ],
    );
  }

  // ===============================
  // INGREDIENTS
  // ===============================
  Widget _buildIngredientSection(String? raw) {
    final ingredients = _parseIngredients(raw);
    if (ingredients.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: ingredients
              .map((i) => Chip(
            label: Text(i),
            backgroundColor: Colors.green.shade50,
          ))
              .toList(),
        ),
      ),
    );
  }

  // ===============================
  // NUTRITION
  // ===============================
  Widget _buildNutritionSection(Map<String, dynamic> food) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 คุณค่าโภชนาการ',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('🥩 โปรตีน ${food['protein_g']} g'),
            Text('🧈 ไขมัน ${food['fat_g']} g'),
            Text('🍚 คาร์บ ${food['carbs_g']} g'),
          ],
        ),
      ),
    );
  }

  // ===============================
  // ALLERGEN
  // ===============================
  Widget _buildAllergenSection(
      List<String> allergens, List<String> dangerAllergens) {
    if (allergens.isEmpty) return const SizedBox();

    final hasDanger = dangerAllergens.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: hasDanger ? Colors.red.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hasDanger ? '⚠️ สารก่อภูมิแพ้' : 'ℹ️ สารก่อภูมิแพ้',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasDanger ? Colors.red : Colors.orange)),
            Text('พบ: ${allergens.join(', ')}'),
            const SizedBox(height: 4),
            if (_loadingAllergies)
              const Text('กำลังโหลดรายการที่แพ้...', style: TextStyle(fontSize: 12)),
            if (_allergyError != null)
              Text('โหลดรายการที่แพ้ไม่สำเร็จ: $_allergyError',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            Text(
              _userAllergies.isEmpty
                  ? 'อาหารที่คุณตั้งค่าแพ้: (ยังไม่ได้ตั้งค่า)'
                  : 'อาหารที่คุณตั้งค่าแพ้: ${_userAllergies.join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (hasDanger)
              Text('❌ ผู้ใช้แพ้: ${dangerAllergens.join(', ')}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}