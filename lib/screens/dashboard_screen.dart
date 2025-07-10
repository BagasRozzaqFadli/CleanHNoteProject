import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cleanhnoteapp/services/auth_services.dart';
import 'package:cleanhnoteapp/models/user.dart';
import 'package:cleanhnoteapp/services/premium_service.dart';
import 'package:cleanhnoteapp/services/user_service.dart';
import 'package:provider/provider.dart';
import 'team/team_list_screen.dart';
import 'premium/premium_plans_screen.dart';
import 'documentation/photo_gallery_screen.dart';
import 'report/report_dashboard_screen.dart';
import 'free_plan_screen.dart';
import 'premium_plan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  User? currentUser;
  bool _isLoading = true;
  int _selectedIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      
      // Cek status admin dari database
      bool isAdmin = false;
      if (user != null) {
        try {
          // Coba cek status admin dari database
          isAdmin = await _userService.checkAdminStatus(user.id);
        } catch (e) {
          print('Error checking admin status: $e');
          // Jika gagal memeriksa dari database, gunakan email admin utama sebagai fallback
          isAdmin = user.email == 'admin@cleanhnote.com';
        }
      }
      
      setState(() {
        currentUser = user;
        _isAdmin = isAdmin;
        _isLoading = false;
      });
      
      // Load premium status
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      await premiumService.loadCurrentUser();
      await premiumService.checkPremiumStatus();
      
      // Redirect ke halaman yang sesuai
      if (mounted && user != null) {
        if (_isAdmin) {
          // Tetap di dashboard admin
        } else if (premiumService.isPremium) {
          // Redirect ke premium plan screen jika premium
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PremiumPlanScreen(userId: user.id),
            ),
          );
        } else {
          // Redirect ke free plan screen jika bukan premium dan bukan admin
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => FreePlanScreen(userId: user.id),
            ),
          );
        }
      }
      
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _handleLogout() async {
    // Tampilkan dialog konfirmasi
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Logout'),
          content: Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    ) ?? false;
    
    // Jika pengguna mengonfirmasi logout
    if (confirm) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal logout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent() {
    final premiumService = Provider.of<PremiumService>(context);
    final bool isPremium = premiumService.isPremium;
    
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selamat datang,',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (!_isAdmin && isPremium)
                        Chip(
                          label: Text('Premium'),
                          backgroundColor: Colors.amber,
                          labelStyle: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (!_isAdmin)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PremiumPlansScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.star, color: Colors.amber),
                          label: Text('Upgrade ke Premium'),
                        ),
                      if (_isAdmin)
                        Chip(
                          label: Text('ADMIN'),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    currentUser?.name ?? 'User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  // User ID dengan overflow handling - struktur yang lebih sederhana dan efektif
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            child: Text(
                              'User ID: ${currentUser?.id ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _copyToClipboard(currentUser?.id ?? '', 'User ID');
                          },
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  // Tenant ID dengan overflow handling - struktur yang lebih sederhana dan efektif
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                            child: Text(
                              'Tenant ID: ${currentUser?.tenantId ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _copyToClipboard(currentUser?.tenantId ?? '', 'Tenant ID');
                          },
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tampilkan tombol admin jika pengguna adalah admin
                  if (_isAdmin) ...[
                    SizedBox(height: 16),
                    _buildAdminButton(),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          if (!_isAdmin) ...[
            Text(
              'Catatan Terbaru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  'Belum ada catatan',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Panel Admin',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildAdminCard(
                    'Daftar Pengguna',
                    Icons.people,
                    Colors.blue,
                    () => Navigator.of(context).pushNamed('/admin/users'),
                  ),
                  _buildAdminCard(
                    'Pembayaran',
                    Icons.payment,
                    Colors.green,
                    () => Navigator.of(context).pushNamed('/admin/payments'),
                  ),
                  _buildAdminCard(
                    'Progress Tim',
                    Icons.analytics,
                    Colors.orange,
                    () {
                      // Navigate to team list to select a team for monitoring
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamListScreen(
                            userId: currentUser?.id ?? '',
                            isPremium: true,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildAdminCard(
                    'Laporan Kinerja',
                    Icons.assessment,
                    Colors.purple,
                    () {
                      // Navigate to team list to select a team for reporting
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamListScreen(
                            userId: currentUser?.id ?? '',
                            isPremium: true,
                          ),
                        ),
                      );
                    },
                  ),
                  if (currentUser?.email == 'admin@cleanhnote.com')
                    _buildAdminCard(
                      'Super Admin',
                      Icons.admin_panel_settings,
                      Colors.black,
                      () => Navigator.of(context).pushNamed('/admin/super'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return _isAdmin ? 'Dashboard Admin' : 'Dashboard';
      case 1:
        return 'Tim Saya';
      case 2:
        return 'Dokumentasi';
      case 3:
        return 'Laporan';
      default:
        return 'CleanHNote';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final premiumService = Provider.of<PremiumService>(context);
    final bool isPremium = premiumService.isPremium;

    // Halaman yang akan ditampilkan
    final List<Widget> pages;
    final List<BottomNavigationBarItem> navigationItems;

    if (_isAdmin) {
      // Tampilan untuk admin (hanya beranda)
      pages = [
        _buildHomeContent(),
      ];
      navigationItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Beranda',
        ),
        // Tambahkan item kedua untuk memenuhi persyaratan minimal 2 item
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Pengaturan',
        ),
      ];
    } else {
      // Tampilan untuk pengguna biasa
      pages = [
        _buildHomeContent(),
        if (currentUser != null && isPremium)
          TeamListScreen(userId: currentUser!.id, isPremium: isPremium)
        else
          _buildPremiumPrompt('Tim'),
        if (currentUser != null && isPremium)
          PhotoGalleryScreen(userId: currentUser!.id)
        else
          _buildPremiumPrompt('Dokumentasi'),
        ReportDashboardScreen(userId: currentUser?.id ?? '', isPremium: isPremium),
      ];
      navigationItems = [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Tim',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.photo_library),
          label: 'Dokumentasi',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Laporan',
        ),
      ];
    }

    return PopScope(
      // Mencegah tombol kembali dari sistem
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getAppBarTitle()),
          automaticallyImplyLeading: false, // Menghilangkan tombol kembali
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _isAdmin 
          ? _buildHomeContent() // Untuk admin, langsung tampilkan konten beranda
          : IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
        bottomNavigationBar: _isAdmin
          ? null // Untuk admin, tidak perlu bottom navigation bar
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: navigationItems,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
        floatingActionButton: _selectedIndex == 0 && !_isAdmin
            ? FloatingActionButton(
                onPressed: () {
                  // TODO: Implementasi tambah catatan
                },
                child: Icon(Icons.add),
              )
            : null,
      ),
    );
  }

  Widget _buildPremiumPrompt(String feature) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Fitur $feature hanya tersedia untuk pengguna Premium',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PremiumPlansScreen(),
                ),
              );
            },
            icon: Icon(Icons.star),
            label: Text('Upgrade ke Premium'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminButton() {
    if (_isAdmin) {
      final bool isSuperAdmin = currentUser?.email == 'admin@cleanhnote.com';
      
      return Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/admin/users');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Daftar Pengguna',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Tombol Super Admin (hanya untuk admin utama)
          if (isSuperAdmin)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/admin/super');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Super Admin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label berhasil disalin ke clipboard'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }
}
