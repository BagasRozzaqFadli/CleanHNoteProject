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
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/responsive_layout.dart';
import '../utils/responsive_theme.dart';
import '../widgets/responsive_builder.dart';

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
    _loadNotifications();
  }
  
  Future<void> _loadNotifications() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.loadUserNotifications();
    } catch (e) {
      debugPrint('Error saat memuat notifikasi: $e');
    }
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
    // Menghitung skala responsif berdasarkan ukuran layar
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    final fontScale = ResponsiveLayout.getFontScale(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final responsivePadding = ResponsiveTheme.getResponsivePadding(context, EdgeInsets.all(16));
    
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'CleanHNote Free Plan',
            style: TextStyle(fontSize: 20 * fontScale),
          ),
          automaticallyImplyLeading: false,
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    size: 24 * fontScale,
                  ),
                  iconSize: 24 * fontScale,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationScreen(
                          userId: widget.userId,
                          isPremium: false,
                        ),
                      ),
                    );
                    
                    // Jika kembali dengan nilai true, berarti notifikasi telah dibaca
                    if (result == true) {
                      // Refresh notifikasi
                      final teamService = Provider.of<TeamService>(context, listen: false);
                      await teamService.loadUserNotifications();
                    }
                  },
                ),
                Consumer<TeamService>(
                  builder: (context, teamService, child) {
                    final hasUnreadNotifications = teamService.unreadNotifications.isNotEmpty;
                    
                    return hasUnreadNotifications
                      ? Positioned(
                          right: 8 * paddingScale,
                          top: 8 * paddingScale,
                          child: Container(
                            padding: EdgeInsets.all(2 * paddingScale),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6 * paddingScale),
                            ),
                            constraints: BoxConstraints(
                              minWidth: 12 * paddingScale,
                              minHeight: 12 * paddingScale,
                            ),
                          ),
                        )
                      : SizedBox.shrink();
                  },
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                size: 24 * fontScale,
              ),
              iconSize: 24 * fontScale,
              onPressed: () => _handleLogout(context),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(
                strokeWidth: 2 * paddingScale,
              ))
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0 * paddingScale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildFeaturesSection(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildTeamsSectionFree(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildJoinTeamCard(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildUpgradeToPremiumCard(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildTasksSection(context, paddingScale, fontScale),
                      SizedBox(height: 24 * paddingScale),
                      _buildNotificationsSection(context, paddingScale, fontScale),
                    ],
                  ),
                ),
              ),
        drawer: _buildDrawer(context, paddingScale, fontScale),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, double paddingScale, double fontScale) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * paddingScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0 * paddingScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20 * paddingScale,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24 * fontScale,
                  ),
                ),
                SizedBox(width: 16 * paddingScale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder(
                        future: _userService.getUserById(widget.userId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Text(
                              'Memuat...',
                              style: TextStyle(fontSize: 14 * fontScale),
                            );
                          }
                          if (snapshot.hasError) {
                            return Text(
                              'Pengguna',
                              style: TextStyle(fontSize: 14 * fontScale),
                            );
                          }
                          final user = snapshot.data;
                          return Text(
                            'Selamat datang, ${user?.name ?? 'Pengguna'}!',
                            style: TextStyle(
                              fontSize: 18 * fontScale,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      Text(
                        'Free Plan',
                        style: TextStyle(fontSize: 14 * fontScale),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16 * paddingScale),
            Text(
              'Anda menggunakan versi gratis dari CleanHNote. Upgrade ke Premium untuk mendapatkan fitur lengkap.',
              style: TextStyle(fontSize: 14 * fontScale),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fitur Tersedia',
          style: TextStyle(
            fontSize: 18 * fontScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16 * paddingScale),
        _buildFeatureItem(
          icon: 'assets/images/task_alt_icon.svg',
          title: 'Tugas Personal Dasar',
          description: 'Buat dan kelola tugas pribadi Anda',
          isAvailable: true,
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        _buildFeatureItem(
          icon: Icons.notifications,
          title: 'Notifikasi Dasar',
          description: 'Dapatkan pengingat untuk tugas yang akan datang',
          isAvailable: true,
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        _buildFeatureItem(
          icon: Icons.people,
          title: 'Manajemen Tim',
          description: 'Buat tim dan kelola anggota tim (Gabung tim tersedia)',
          isAvailable: true,
          isPartial: true,
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        _buildFeatureItem(
          icon: Icons.photo,
          title: 'Upload Foto',
          description: 'Tambahkan gambar ke tugas Anda',
          isAvailable: false,
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        _buildFeatureItem(
          icon: Icons.bar_chart,
          title: 'Laporan Lengkap',
          description: 'Analisis kinerja dan produktivitas',
          isAvailable: false,
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required dynamic icon, // Dapat berupa IconData atau String (path SVG)
    required String title,
    required String description,
    required bool isAvailable,
    bool isPartial = false,
    BuildContext? context,
    double paddingScale = 1.0,
    double fontScale = 1.0,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0 * paddingScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8 * paddingScale),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green[50] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8 * paddingScale),
            ),
            child: icon is IconData
                ? Icon(
                    icon,
                    color: isAvailable ? Colors.green : Colors.grey,
                    size: 24 * fontScale,
                  )
                : SvgPicture.asset(
                    icon,
                    width: 24 * fontScale,
                    height: 24 * fontScale,
                    colorFilter: ColorFilter.mode(
                      isAvailable ? Colors.green : Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
          SizedBox(width: 16 * paddingScale),
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
                        fontSize: 14 * fontScale,
                        color: isAvailable ? Colors.black : Colors.grey,
                      ),
                    ),
                    SizedBox(width: 8 * paddingScale),
                    if (!isAvailable)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8 * paddingScale, vertical: 2 * paddingScale),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12 * paddingScale),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 10 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (isPartial)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8 * paddingScale, vertical: 2 * paddingScale),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12 * paddingScale),
                        ),
                        child: Text(
                          'Sebagian',
                          style: TextStyle(
                            fontSize: 10 * fontScale,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4 * paddingScale),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12 * fontScale,
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

  Widget _buildUpgradeToPremiumCard(BuildContext context, double paddingScale, double fontScale) {
    return Card(
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * paddingScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0 * paddingScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24 * fontScale),
                SizedBox(width: 8 * paddingScale),
                Text(
                  'Upgrade ke Premium',
                  style: TextStyle(
                    fontSize: 18 * fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16 * paddingScale),
            Text(
              'Dapatkan akses ke semua fitur premium:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14 * fontScale,
              ),
            ),
            SizedBox(height: 8 * paddingScale),
            _BulletPoint(text: 'Manajemen tim dan kolaborasi', paddingScale: paddingScale, fontScale: fontScale),
            _BulletPoint(text: 'Upload foto dan lampiran', paddingScale: paddingScale, fontScale: fontScale),
            _BulletPoint(text: 'Laporan dan analitik lengkap', paddingScale: paddingScale, fontScale: fontScale),
            _BulletPoint(text: 'Penugasan dan delegasi', paddingScale: paddingScale, fontScale: fontScale),
            _BulletPoint(text: 'Notifikasi lanjutan', paddingScale: paddingScale, fontScale: fontScale),
            SizedBox(height: 16 * paddingScale),
            
            // Pilihan paket premium
            _buildPremiumPackageOptions(context, paddingScale, fontScale),
            
            SizedBox(height: 16 * paddingScale),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showPremiumInfoDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12 * paddingScale),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8 * paddingScale),
                  ),
                ),
                child: Text(
                  'Upgrade Sekarang',
                  style: TextStyle(fontSize: 16 * fontScale),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumPackageOptions(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Paket Premium:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16 * fontScale,
          ),
        ),
        SizedBox(height: 8 * paddingScale),
        _buildPackageOption(
          title: '1 Bulan',
          price: 'Rp 50.000',
          isPopular: false,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '1 Bulan'),
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        SizedBox(height: 8 * paddingScale),
        _buildPackageOption(
          title: '3 Bulan',
          price: 'Rp 135.000',
          isPopular: true,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '3 Bulan'),
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
        SizedBox(height: 8 * paddingScale),
        _buildPackageOption(
          title: '12 Bulan',
          price: 'Rp 480.000',
          isPopular: false,
          onTap: () => _showPremiumInfoDialog(selectedPeriod: '12 Bulan'),
          context: context,
          paddingScale: paddingScale,
          fontScale: fontScale,
        ),
      ],
    );
  }

  Widget _buildPackageOption({
    required String title,
    required String price,
    required bool isPopular,
    required VoidCallback onTap,
    BuildContext? context,
    double paddingScale = 1.0,
    double fontScale = 1.0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12 * paddingScale),
        decoration: BoxDecoration(
          color: isPopular ? Colors.amber.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(8 * paddingScale),
          border: Border.all(
            color: isPopular ? Colors.amber : Colors.grey.shade300,
            width: isPopular ? 2 * paddingScale : 1 * paddingScale,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16 * fontScale,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16 * fontScale,
                    color: isPopular ? Colors.amber.shade800 : Colors.black,
                  ),
                ),
                if (isPopular) ...[                  
                  SizedBox(width: 8 * paddingScale),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8 * paddingScale, vertical: 4 * paddingScale),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12 * paddingScale),
                    ),
                    child: Text(
                      'BEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10 * fontScale,
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

  Widget _buildTasksSection(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tugas Saya',
              style: TextStyle(
                fontSize: 18 * fontScale,
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
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8 * paddingScale, vertical: 4 * paddingScale),
                textStyle: TextStyle(fontSize: 14 * fontScale),
              ),
              child: Text('Lihat Semua'),
            ),
          ],
        ),
        SizedBox(height: 8 * paddingScale),
        SizedBox(
          height: 220 * paddingScale,
          child: _loadingTasks
              ? Center(child: CircularProgressIndicator(strokeWidth: 2 * paddingScale))
              : _recentTasks.isEmpty
                  ? _buildEmptyTasksView(context, paddingScale, fontScale)
                  : _buildTasksListView(context, paddingScale, fontScale),
        ),
      ],
    );
  }

  Widget _buildEmptyTasksView(BuildContext context, double paddingScale, double fontScale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 50 * fontScale,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16 * paddingScale),
          Text(
            'Belum ada tugas',
            style: TextStyle(
              fontSize: 16 * fontScale,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16 * paddingScale),
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
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
              textStyle: TextStyle(fontSize: 14 * fontScale),
            ),
            icon: Icon(Icons.add_task, size: 18 * fontScale),
            label: Text('Buat Tugas Baru'),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksListView(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _recentTasks.length,
            itemBuilder: (context, index) {
              final task = _recentTasks[index];
              final Color statusColor = _getStatusColor(task.status);
              
              return Card(
                margin: EdgeInsets.only(bottom: 8 * paddingScale),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * paddingScale),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
                  title: Text(
                    task.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 * fontScale),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4 * paddingScale),
                      Text(
                        task.description.length > 50
                            ? '${task.description.substring(0, 50)}...'
                            : task.description,
                        style: TextStyle(fontSize: 14 * fontScale),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      SizedBox(height: 4 * paddingScale),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6 * paddingScale, vertical: 2 * paddingScale),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4 * paddingScale),
                            ),
                            child: Text(
                              task.status.name,
                              style: TextStyle(
                                fontSize: 12 * fontScale,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8 * paddingScale),
                          Icon(Icons.calendar_today, size: 12 * fontScale, color: Colors.grey[600]),
                          SizedBox(width: 4 * paddingScale),
                          Flexible(
                            child: Text(
                              _formatDate(task.dueDate),
                              style: TextStyle(
                                fontSize: 12 * fontScale,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
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
        SizedBox(height: 8 * paddingScale),
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
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
              textStyle: TextStyle(fontSize: 14 * fontScale),
            ),
            icon: Icon(Icons.add, size: 18 * fontScale),
            label: Text('Tambah Tugas Baru'),
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

  Widget _buildNotificationsSection(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 18 * fontScale,
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
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8 * paddingScale, vertical: 4 * paddingScale),
                textStyle: TextStyle(fontSize: 14 * fontScale),
              ),
              child: Text('Lihat Semua'),
            ),
          ],
        ),
        SizedBox(height: 8 * paddingScale),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * paddingScale),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0 * paddingScale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8 * paddingScale),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8 * paddingScale),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: Colors.orange,
                        size: 24 * fontScale,
                      ),
                    ),
                    SizedBox(width: 16 * paddingScale),
                    Expanded(
                      child: Text(
                        'Dapatkan pengingat untuk tugas yang mendekati tenggat waktu',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14 * fontScale,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16 * paddingScale),
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

  Widget _buildDrawer(BuildContext context, double paddingScale, double fontScale) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Text(
              'CleanHNote',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24 * fontScale,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home, size: 24 * fontScale),
            title: Text('Beranda', style: TextStyle(fontSize: 16 * fontScale)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.star, size: 24 * fontScale),
            title: Text('Premium', style: TextStyle(fontSize: 16 * fontScale)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
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
            leading: Icon(Icons.group, size: 24 * fontScale),
            title: Text('Tim', style: TextStyle(fontSize: 16 * fontScale)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
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
          Divider(thickness: 1 * paddingScale),
          ListTile(
            leading: Icon(Icons.logout, size: 24 * fontScale),
            title: Text('Logout', style: TextStyle(fontSize: 16 * fontScale)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
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
    // Menghitung skala responsif
    final paddingScale = ResponsiveLayout.getPaddingScale(context);
    final fontScale = ResponsiveLayout.getFontScale(context);
    
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Logout', style: TextStyle(fontSize: 18 * fontScale)),
          content: Text('Apakah Anda yakin ingin keluar dari aplikasi?', style: TextStyle(fontSize: 16 * fontScale)),
          actionsPadding: EdgeInsets.all(16 * paddingScale),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * paddingScale)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
                textStyle: TextStyle(fontSize: 14 * fontScale),
              ),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
                textStyle: TextStyle(fontSize: 14 * fontScale),
              ),
              child: Text('Logout'),
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
              content: Text('Gagal logout: ${e.toString()}', style: TextStyle(fontSize: 14 * fontScale)),
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 10 * paddingScale),
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    await _handleLogout(context);
  }

  Widget _buildJoinTeamCard(BuildContext context, double paddingScale, double fontScale) {
    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * paddingScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0 * paddingScale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue, size: 24 * fontScale),
                SizedBox(width: 8 * paddingScale),
                Text(
                  'Gabung dengan Tim',
                  style: TextStyle(
                    fontSize: 18 * fontScale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * paddingScale),
            Text(
              'Meskipun Anda menggunakan versi gratis, Anda tetap dapat bergabung dengan tim yang sudah ada menggunakan kode undangan.',
              style: TextStyle(fontSize: 14 * fontScale),
            ),
            SizedBox(height: 16 * paddingScale),
            
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
                    icon: Icon(Icons.group_add, size: 18 * fontScale),
                    label: Text('Gabung Tim Sekarang', style: TextStyle(fontSize: 14 * fontScale)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16 * paddingScale, vertical: 8 * paddingScale),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * paddingScale),
            Center(
              child: Text(
                'Gunakan kode undangan dari teman untuk bergabung',
                style: TextStyle(
                  fontSize: 12 * fontScale,
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

  Widget _buildTeamsSectionFree(BuildContext context, double paddingScale, double fontScale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tim Saya',
              style: TextStyle(
                fontSize: 18 * fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Tidak ada tombol "Lihat Semua" atau "Buat Tim Baru" di versi free
          ],
        ),
        SizedBox(height: 8 * paddingScale),
        _loadingTeams
            ? Center(child: CircularProgressIndicator(strokeWidth: 2 * paddingScale))
            : _teams.isEmpty
                ? _buildEmptyTeamsCardFree(context, paddingScale, fontScale)
                : SizedBox(
                    height: 140 * paddingScale,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _teams.length,
                      itemBuilder: (context, index) {
                        final team = _teams[index];
                        return _buildTeamItemFree(team, context, paddingScale, fontScale);
                      },
                    ),
                  ),
      ],
    );
  }

  Widget _buildEmptyTeamsCardFree(BuildContext context, double paddingScale, double fontScale) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * paddingScale),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0 * paddingScale),
        child: Column(
          children: [
            Icon(
              Icons.people,
              size: 48 * fontScale,
              color: Colors.grey[400],
            ),
            SizedBox(height: 8 * paddingScale),
            Text(
              'Belum ada tim',
              style: TextStyle(
                fontSize: 16 * fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4 * paddingScale),
            Text(
              'Gabung tim untuk berkolaborasi',
              style: TextStyle(fontSize: 14 * fontScale, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamItemFree(TeamModel team, BuildContext context, double paddingScale, double fontScale) {
    final teamService = Provider.of<TeamService>(context, listen: false);
    // Menggunakan MediaQuery untuk mendapatkan lebar layar
    final screenWidth = MediaQuery.of(context).size.width;
    // Menghitung lebar item berdasarkan lebar layar (sekitar 25% dari lebar layar)
    final itemWidth = screenWidth * 0.25;
    
    return SizedBox(
      width: itemWidth,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * paddingScale),
          side: BorderSide(color: Colors.green.withOpacity(0.3), width: 1 * paddingScale),
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
          borderRadius: BorderRadius.circular(12 * paddingScale),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0 * paddingScale, horizontal: 6.0 * paddingScale),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16 * fontScale,
                  backgroundColor: Colors.green,
                  child: Text(
                    team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14 * fontScale,
                    ),
                  ),
                ),
                SizedBox(height: 6 * paddingScale),
                Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13 * fontScale,
                  ),
                ),
                FutureBuilder<String>(
                  future: teamService.getUserName(team.createdBy),
                  builder: (context, snapshot) {
                    final leaderName = snapshot.data ?? 'Memuat...';
                    return Text(
                      leaderName,
                      style: TextStyle(
                        fontSize: 11 * fontScale,
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
  final double paddingScale;
  final double fontScale;

  const _BulletPoint({
    required this.text,
    this.paddingScale = 1.0,
    this.fontScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.0 * paddingScale),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14 * fontScale,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14 * fontScale),
            ),
          ),
        ],
      ),
    );
  }
}