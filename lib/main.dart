import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';
import 'pages/profile_page.dart';
import 'pages/login_page.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),
        '/main': (_) => const MainPage(),
      },
    );
  }
}

/* ================= SPLASH / AUTH CHECK ================= */

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = await AuthService.me();
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      user == null ? '/login' : '/main',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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

  final List<Widget> _pages = const [
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
