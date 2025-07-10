import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/premium/admin_payment_screen.dart'; // Import layar admin
import 'screens/admin/super_admin_screen.dart'; // Import layar super admin
import 'screens/admin/user_list_screen.dart';
import 'screens/free_plan_screen.dart';
import 'screens/premium_plan_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/premium_service.dart';
import 'services/team_service.dart';
import 'services/documentation_service.dart';
import 'services/user_service.dart';
import 'services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_services.dart';
import 'models/user.dart';
import 'utils/responsive_theme.dart';
import 'utils/responsive_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set orientasi yang diizinkan (opsional, hapus jika ingin mendukung landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PremiumService()),
        ChangeNotifierProvider(create: (_) => TeamService()),
        ChangeNotifierProvider(create: (_) => DocumentationService()),
        ChangeNotifierProvider(create: (_) => TaskService()),
        Provider(create: (_) => UserService()),
        Provider(create: (_) => AuthService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleanHNote',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Tambahkan konfigurasi tema dasar di sini
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      builder: (context, child) {
        // Terapkan tema responsif ke seluruh aplikasi
        final mediaQueryData = MediaQuery.of(context);
        final scale = mediaQueryData.textScaleFactor.clamp(0.8, 1.2);
        
        // Gunakan ResponsiveTheme untuk mendapatkan tema yang responsif
        final responsiveTheme = ResponsiveTheme.getResponsiveThemeData(
          context, 
          Theme.of(context)
        );
        
        return MediaQuery(
          data: mediaQueryData.copyWith(textScaleFactor: scale),
          child: Theme(
            data: responsiveTheme,
            child: child!,
          ),
        );
      },
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/admin/payments': (context) => const AdminPaymentScreen(), // Rute untuk layar admin
        '/admin/super': (context) => const SuperAdminScreen(), // Rute untuk layar super admin
        '/admin/users': (context) => const UserListScreen(),
        // Rute baru untuk mengarahkan pengguna berdasarkan status premium
        '/home': (context) => HomeRouter(),
      },
      home: FutureBuilder<bool>(
        future: _shouldShowRateLimitInfo(),
        builder: (context, snapshot) {
          // Tampilkan halaman login terlebih dahulu
          final loginScreen = LoginScreen();
          
          if (snapshot.connectionState == ConnectionState.done && 
              snapshot.data == true) {
            // Tampilkan dialog info rate limit setelah widget tree dibangun
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showRateLimitInfoDialog(context);
            });
          }
          return loginScreen;
        },
      ),
    );
  }

  Future<bool> _shouldShowRateLimitInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShown = prefs.getString('last_rate_limit_info') ?? '';
      final now = DateTime.now();
      
      // Matikan popup untuk sementara dengan mengembalikan false
      return false;
      
      // Kode asli (dinonaktifkan)
      /*
      // Jika belum pernah ditampilkan atau sudah lebih dari 1 hari
      if (lastShown.isEmpty) {
        await prefs.setString('last_rate_limit_info', now.toIso8601String());
        return true;
      }
      
      final lastDate = DateTime.parse(lastShown);
      if (now.difference(lastDate).inHours > 24) {
        await prefs.setString('last_rate_limit_info', now.toIso8601String());
        return true;
      }
      
      return false;
      */
    } catch (e) {
      return false; // Jangan tampilkan dialog meskipun terjadi error
    }
  }

  void _showRateLimitInfoDialog(BuildContext context) {
    final isSmallScreen = ResponsiveLayout.isMobile(context) && 
                         MediaQuery.of(context).size.width < 360;
    final dialogWidth = isSmallScreen ? 
                       MediaQuery.of(context).size.width * 0.9 : 
                       MediaQuery.of(context).size.width * 0.8;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informasi Penting'),
          content: Container(
            width: dialogWidth,
            child: const Text(
              'Saat ini, server Appwrite sedang mengalami pembatasan rate limit. '
              'Jika Anda mengalami kesulitan login, harap tunggu beberapa saat dan coba lagi. '
              'Sistem akan mencoba login beberapa kali secara otomatis dengan jeda waktu tertentu.'
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Mengerti'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// Widget router untuk mengarahkan pengguna ke halaman yang sesuai
class HomeRouter extends StatefulWidget {
  @override
  _HomeRouterState createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String _userId = '';
  
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }
  
  Future<void> _checkUserStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);
      
      // Dapatkan data user saat ini
      final user = await authService.getCurrentUser();
      
      // Cek status admin
      bool isAdmin = false;
      try {
        isAdmin = await userService.checkAdminStatus(user.id);
      } catch (e) {
        print('Error checking admin status: $e');
        // Fallback untuk admin
        isAdmin = user.email == 'admin@cleanhnote.com';
      }
      
      // Load status premium
      await premiumService.loadCurrentUser();
      await premiumService.checkPremiumStatus();
      
      setState(() {
        _isAdmin = isAdmin;
        _userId = user.id;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking user status: $e');
      // Jika gagal, arahkan ke halaman login
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Gunakan MediaQuery untuk mendapatkan informasi ukuran layar
    final screenSize = MediaQuery.of(context).size;
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: screenSize.width * 0.1,
            height: screenSize.width * 0.1,
            child: CircularProgressIndicator(
              strokeWidth: 3 * paddingScale,
            ),
          ),
        ),
      );
    }
    
    // Dapatkan status premium dari provider
    final premiumService = Provider.of<PremiumService>(context);
    final bool isPremium = premiumService.isPremium;
    
    // Arahkan ke halaman yang sesuai
    if (_isAdmin) {
      // Untuk admin, tampilkan dashboard admin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(),
          ),
        );
      });
    } else if (isPremium) {
      // Untuk pengguna premium
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PremiumPlanScreen(userId: _userId),
          ),
        );
      });
    } else {
      // Untuk pengguna free plan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FreePlanScreen(userId: _userId),
          ),
        );
      });
    }
    
    // Tampilkan loading screen sementara navigasi diproses
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: screenSize.width * 0.1,
              height: screenSize.width * 0.1,
              child: CircularProgressIndicator(
                strokeWidth: 3 * paddingScale,
              ),
            ),
            SizedBox(height: 16 * paddingScale),
            Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 16 * ResponsiveLayout.getFontScale(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
