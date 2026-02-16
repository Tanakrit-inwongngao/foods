import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';
import 'pages/profile_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FoodDetectorApp());
}

class FoodDetectorApp extends StatelessWidget {
  const FoodDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "🍜 Thai Food Detector",
      debugShowCheckedModeBanner: false,
      // ✅ รองรับภาษาไทย (Material/Cupertino) + ตั้ง locale เริ่มต้นเป็นไทย
      locale: const Locale('th', 'TH'),
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ✅ บังคับฟอนต์ที่รองรับไทยทั้งแอป (รวม TextField/AlertDialog)
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        textTheme: GoogleFonts.sarabunTextTheme(),
      ),

      // ✅ เปิดแอปมาให้เริ่มที่หน้า Login ก่อนเสมอ
      initialRoute: '/',
      routes: {
        '/': (_) => LoginPage(),
        '/login': (_) => LoginPage(),

        // เผื่ออยากใช้ named route แทน push(MaterialPageRoute)
        '/home': (_) => HomePage(),

        // หน้าหลักแบบ Bottom Navigation (ถ้าคุณอยากใช้)
        '/main': (_) => const MainPage(),
      },
    );
  }
}

/* ================= MAIN PAGE (BOTTOM NAV) ================= */

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    HistoryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ไม่มี AppBar ที่นี่ → ให้แต่ละ page จัดการเอง
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood),
            label: "หน้าแรก",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "ประวัติ",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "โปรไฟล์",
          ),
        ],
      ),
    );
  }
}
