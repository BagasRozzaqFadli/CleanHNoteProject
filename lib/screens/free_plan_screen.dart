import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_services.dart';
import '../services/user_service.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';
import '../widgets/premium_upgrade_dialog.dart';
import 'task/task_list_screen.dart';
import 'task/task_detail_screen.dart';
import 'task/create_task_screen.dart';
import 'notification_screen.dart';
import 'team/team_list_screen.dart';
import 'premium/premium_plans_screen.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';
import 'team/team_detail_screen.dart';

class FreePlanScreen extends StatefulWidget {
  final String userId;

  const FreePlanScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<FreePlanScreen> createState() => _FreePlanScreenState();
}

class _FreePlanScreenState extends State<FreePlanScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  List<TaskModel> _recentTasks = [];
  bool _loadingTasks = false;
  List<TeamModel> _teams = [];
  bool _loadingTeams = false;

  @override
  void initState() {
    super.initState();
    _loadRecentTasks();
    _loadTeams();
  }

  Future<void> _loadRecentTasks() async {
    setState(() {
      _loadingTasks = true;
    });

    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final tasks = await taskService.getPersonalTasks(widget.userId);
      
      // Hanya tampilkan 5 tugas terbaru yang belum selesai
      final filteredTasks = tasks
          .where((task) => task.status != TaskStatus.completed && task.status != TaskStatus.cancelled)
          .take(5)
          .toList();
          
      setState(() {
        _recentTasks = filteredTasks;
        _loadingTasks = false;
      });
    } catch (e) {
      debugPrint('Error saat memuat tugas terbaru: $e');
      setState(() {
        _loadingTasks = false;
      });
    }
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loadingTeams = true;
    });
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.loadUserTeams();
      setState(() {
        _teams = teamService.teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _loadingTeams = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CleanHNote Free Plan'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationScreen(
                      userId: widget.userId,
                      isPremium: false,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildFeaturesSection(),
                      const SizedBox(height: 24),
                      _buildTeamsSectionFree(),
                      const SizedBox(height: 24),
                      _buildJoinTeamCard(),
                      const SizedBox(height: 24),
                      _buildUpgradeToPremiumCard(),
                      const SizedBox(height: 24),
                      _buildTasksSection(),
                      const SizedBox(height: 24),
                      _buildNotificationsSection(),
                    ],
                  ),
                ),
              ),
        drawer: _buildDrawer(),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder(
                        future: _userService.getUserById(widget.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('Memuat...');
                          }
                          if (snapshot.hasError) {
                            return const Text('Pengguna');
                          }
                          final user = snapshot.data;
                          return Text(
                            'Selamat datang, ${user?.name ?? 'Pengguna'}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const Text('Free Plan'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Anda menggunakan versi gratis dari CleanHNote. Upgrade ke Premium untuk mendapatkan fitur lengkap.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fitur yang Tersedia',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFeatureItem(
          icon: Icons.task_alt,
          title: 'Tugas Personal Dasar',
          description: 'Buat dan kelola tugas pribadi Anda',
          isAvailable: true,
        ),
        _buildFeatureItem(
          icon: Icons.notifications,
          title: 'Notifikasi Dasar',
          description: 'Dapatkan pengingat untuk tugas yang akan datang',
          isAvailable: true,
        ),
        _buildFeatureItem(
          icon: Icons.people,
          title: 'Manajemen Tim',
          description: 'Buat tim dan kelola anggota tim (Gabung tim tersedia)',
          isAvailable: true,
          isPartial: true,
        ),
        _buildFeatureItem(
          icon: Icons.photo,
          title: 'Upload Foto',
          description: 'Tambahkan gambar ke tugas Anda',
          isAvailable: false,
        ),
        _buildFeatureItem(
          icon: Icons.bar_chart,
          title: 'Laporan Lengkap',
          description: 'Analisis kinerja dan produktivitas',
          isAvailable: false,
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isAvailable,
    bool isPartial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isAvailable ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.black : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (isPartial)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Sebagian',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeToPremiumCard() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Upgrade ke Premium',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Dapatkan akses ke semua fitur premium:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const _BulletPoint(text: 'Manajemen tim dan kolaborasi'),
            const _BulletPoint(text: 'Upload foto dan lampiran'),
            const _BulletPoint(text: 'Laporan dan analitik lengkap'),
            const _BulletPoint(text: 'Penugasan dan delegasi'),
            const _BulletPoint(text: 'Notifikasi lanjutan'),
            const SizedBox(height: 16),
            
            // Pilihan paket premium
            _buildPremiumPackageOptions(),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showPremiumInfoDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade Sekarang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPackageOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Paket Premium:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        _buildPackageOption(
          title: '1 Bulan',
          price: 'Rp 50.000',
          isPopular: false,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '1 Bulan'),
        ),
        const SizedBox(height: 8),
        _buildPackageOption(
          title: '3 Bulan',
          price: 'Rp 135.000',
          isPopular: true,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '3 Bulan'),
        ),
        const SizedBox(height: 8),
        _buildPackageOption(
          title: '12 Bulan',
          price: 'Rp 480.000',
          isPopular: false,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '12 Bulan'),
        ),
      ],
    );
  }

  Widget _buildPackageOption({
    required String title,
    required String price,
    required bool isPopular,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPopular ? Colors.amber.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPopular ? Colors.amber : Colors.grey.shade300,
            width: isPopular ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPopular ? Colors.amber.shade800 : Colors.black,
                  ),
                ),
                if (isPopular) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'BEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumInfoDialog({String? selectedPeriod}) {
    showDialog(
      context: context,
      builder: (context) => PremiumUpgradeDialog(selectedPeriod: selectedPeriod),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tugas Saya',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskListScreen(
                      userId: widget.userId,
                      isPremium: false,
                    ),
                  ),
                ).then((_) => _loadRecentTasks());
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : _recentTasks.isEmpty
                  ? _buildEmptyTasksView()
                  : _buildTasksListView(),
        ),
      ],
    );
  }

  Widget _buildEmptyTasksView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 50,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada tugas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateTaskScreen(userId: widget.userId),
                ),
              ).then((result) {
                if (result == true) {
                  _loadRecentTasks();
                }
              });
            },
            icon: const Icon(Icons.add_task),
            label: const Text('Buat Tugas Baru'),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksListView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _recentTasks.length,
            itemBuilder: (context, index) {
              final task = _recentTasks[index];
              final Color statusColor = _getStatusColor(task.status);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.description.length > 50
                            ? '${task.description.substring(0, 50)}...'
                            : task.description,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              task.status.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(task.dueDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailScreen(
                          taskId: task.id,
                          isPremium: false,
                        ),
                      ),
                    ).then((_) => _loadRecentTasks());
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateTaskScreen(userId: widget.userId),
                ),
              ).then((result) {
                if (result == true) {
                  _loadRecentTasks();
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Tugas Baru'),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.orange;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationScreen(
                      userId: widget.userId,
                      isPremium: false,
                    ),
                  ),
                );
              },
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Dapatkan pengingat untuk tugas yang mendekati tenggat waktu',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationScreen(
                            userId: widget.userId,
                            isPremium: false,
                          ),
                        ),
                      );
                    },
                    child: const Text('Lihat Notifikasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Text(
              'CleanHNote',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Beranda'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Premium'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumPlansScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Tim'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamListScreen(userId: widget.userId, isPremium: false),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await _handleLogout(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    ) ?? false;
    
    if (confirm) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal logout: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await _handleLogout(context);
  }

  Widget _buildJoinTeamCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.people, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Gabung dengan Tim',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Meskipun Anda menggunakan versi gratis, Anda tetap dapat bergabung dengan tim yang sudah ada menggunakan kode undangan.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamListScreen(
                            userId: widget.userId,
                            isPremium: false,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('Gabung Tim Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Gunakan kode undangan dari teman untuk bergabung',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsSectionFree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tim Saya',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Tidak ada tombol "Lihat Semua" atau "Buat Tim Baru" di versi free
          ],
        ),
        const SizedBox(height: 8),
        _loadingTeams
            ? const Center(child: CircularProgressIndicator())
            : _teams.isEmpty
                ? _buildEmptyTeamsCardFree()
                : SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _teams.length,
                      itemBuilder: (context, index) {
                        final team = _teams[index];
                        return _buildTeamItemFree(team);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildEmptyTeamsCardFree() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              Icons.people,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            const Text(
              'Belum ada tim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gabung tim untuk berkolaborasi',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamItemFree(TeamModel team) {
    final teamService = Provider.of<TeamService>(context, listen: false);
    return SizedBox(
      width: 100,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.withOpacity(0.3)),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamDetailScreen(
                  team: team,
                  isLeader: team.createdBy == widget.userId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                FutureBuilder<String>(
                  future: teamService.getUserName(team.createdBy),
                  builder: (context, snapshot) {
                    final leaderName = snapshot.data ?? 'Memuat...';
                    return Text(
                      leaderName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}