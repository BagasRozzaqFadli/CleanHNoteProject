import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';

class TeamPerformanceReportScreen extends StatefulWidget {
  final TeamModel team;

  const TeamPerformanceReportScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamPerformanceReportScreen> createState() => _TeamPerformanceReportScreenState();
}

class _TeamPerformanceReportScreenState extends State<TeamPerformanceReportScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};
  String _selectedPeriod = 'minggu';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTeamStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final stats = await teamService.getTeamTaskStatistics(widget.team.id);
      
      // Pastikan data stats tidak null dan memiliki struktur yang diperlukan
      if (stats.isEmpty) {
        // Berikan data dummy jika tidak ada data
        setState(() {
          _statistics = {
            'totalTasks': 0,
            'completedTasks': 0,
            'inProgressTasks': 0,
            'pendingTasks': 0,
            'completionRate': 0.0,
            'memberTaskCounts': <String, int>{},
            'memberCompletedCounts': <String, int>{},
            'members': <Map<String, dynamic>>[],
            'tasks': <Map<String, dynamic>>[],
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading team statistics: $e');
      // Berikan data default saat error
      setState(() {
        _statistics = {
          'totalTasks': 0,
          'completedTasks': 0,
          'inProgressTasks': 0,
          'pendingTasks': 0,
          'completionRate': 0.0,
          'memberTaskCounts': <String, int>{},
          'memberCompletedCounts': <String, int>{},
          'members': <Map<String, dynamic>>[],
          'tasks': <Map<String, dynamic>>[],
        };
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat data statistik. Menampilkan data kosong.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Laporan Kinerja - ${widget.team.name}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'minggu', child: Text('Minggu Ini')),
              const PopupMenuItem(value: 'bulan', child: Text('Bulan Ini')),
              const PopupMenuItem(value: 'kuartal', child: Text('3 Bulan Terakhir')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Detail Anggota'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildMemberDetailTab(),
              ],
            ),
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodHeader(),
          const SizedBox(height: 16),
          _buildKPICards(),
          const SizedBox(height: 16),
          _buildTeamEfficiencyCard(),
          const SizedBox(height: 16),
          _buildTopPerformers(),
        ],
      ),
    );
  }

  Widget _buildMemberDetailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodHeader(),
          const SizedBox(height: 16),
          _buildMemberComparisonChart(),
          const SizedBox(height: 16),
          _buildPerformanceRanking(),
          const SizedBox(height: 16),
          _buildDetailedMemberStats(),
        ],
      ),
    );
  }

  Widget _buildPeriodHeader() {
    String periodText = '';
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'minggu':
        final startWeek = now.subtract(const Duration(days: 7));
        periodText = 'Minggu ${DateFormat('dd MMM').format(startWeek)} - ${DateFormat('dd MMM yyyy').format(now)}';
        break;
      case 'bulan':
        periodText = DateFormat('MMMM yyyy').format(now);
        break;
      case 'kuartal':
        periodText = '3 Bulan Terakhir';
        break;
    }

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Periode: $periodText',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards() {
    final totalTasks = _statistics['totalTasks'] ?? 0;
    final completionRate = _statistics['completionRate'] ?? 0.0;
    final members = _statistics['members'] as List<dynamic>? ?? [];
    final averageTasksPerMember = members.isNotEmpty ? totalTasks / members.length : 0.0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 100,
          child: _buildKPICard(
            'Total Tugas',
            totalTasks.toString(),
            Icons.assignment,
            Colors.blue,
          ),
        ),
        SizedBox(
          width: 100,
          child: _buildKPICard(
            'Completion Rate',
            '${(completionRate * 100).toStringAsFixed(1)}%',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(
          width: 100,
          child: _buildKPICard(
            'Avg/Member',
            averageTasksPerMember.toStringAsFixed(1),
            Icons.person,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamEfficiencyCard() {
    final completionRate = _statistics['completionRate'] ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Efisiensi Tim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.visible,
            ),
            const SizedBox(height: 12),
            _buildEfficiencyItem('Tingkat Penyelesaian', completionRate, Colors.green),
            _buildEfficiencyItem('Kualitas Kerja', 0.85, Colors.orange),
            _buildEfficiencyItem('Kolaborasi Tim', 0.78, Colors.blue),
            _buildEfficiencyItem('Ketepatan Waktu', 0.72, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyItem(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    final memberPerformance = _calculateMemberPerformance();
    try {
      memberPerformance.sort((a, b) => (b['completionRate'] as double).compareTo(a['completionRate'] as double));
    } catch (e) {
      debugPrint('Error sorting member performance: $e');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (memberPerformance.isEmpty)
              const Center(child: Text('Belum ada data anggota'))
            else
              ...memberPerformance.take(3).map((member) => _buildPerformerItem(member)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformerItem(Map<String, dynamic> member) {
    final memberName = (member['name'] as String? ?? 'Unknown').toString();
    final completed = (member['completed'] as num? ?? 0).toInt();
    final total = (member['total'] as num? ?? 0).toInt();
    final completionRate = (member['completionRate'] as double? ?? 0.0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$completed dari $total tugas',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(completionRate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberComparisonChart() {
    final memberPerformance = _calculateMemberPerformance();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Perbandingan Kinerja Anggota',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (memberPerformance.isEmpty)
              const Center(child: Text('Belum ada data anggota'))
            else
              Column(
                children: memberPerformance.map((member) => _buildMemberComparisonItem(member)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberComparisonItem(Map<String, dynamic> member) {
    final completionRate = member['completionRate'] as double;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member['name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${member['completed']}/${member['total']} tugas',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(completionRate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: completionRate,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              completionRate >= 0.8 ? Colors.green :
              completionRate >= 0.5 ? Colors.orange : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRanking() {
    final memberPerformance = _calculateMemberPerformance();
    try {
      memberPerformance.sort((a, b) => (b['completionRate'] as double).compareTo(a['completionRate'] as double));
    } catch (e) {
      debugPrint('Error sorting member performance: $e');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ranking Kinerja',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (memberPerformance.isEmpty)
              const Center(child: Text('Belum ada data anggota'))
            else
              ...memberPerformance.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final member = entry.value;
                return _buildRankingItem(rank, member);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingItem(int rank, Map<String, dynamic> member) {
    Color rankColor = Colors.grey;
    if (rank == 1) {
      rankColor = Colors.amber;
    } else if (rank == 2) {
      rankColor = Colors.grey[400]!;
    } else if (rank == 3) {
      rankColor = Colors.brown;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    rank.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completion Rate: ${(member['completionRate'] * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${member['completed']}/${member['total']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'tugas selesai',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMemberStats() {
    final memberPerformance = _calculateMemberPerformance();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistik Detail per Anggota',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (memberPerformance.isEmpty)
              const Center(child: Text('Belum ada data anggota'))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nama', overflow: TextOverflow.ellipsis)),
                    DataColumn(label: Text('Total', overflow: TextOverflow.ellipsis)),
                    DataColumn(label: Text('Selesai', overflow: TextOverflow.ellipsis)),
                    DataColumn(label: Text('Rate', overflow: TextOverflow.ellipsis)),
                    DataColumn(label: Text('Status', overflow: TextOverflow.ellipsis)),
                  ],
                  rows: memberPerformance.map((member) {
                    final completionRate = member['completionRate'] as double;
                    String status = '';
                    Color statusColor = Colors.grey;
                    
                    if (completionRate >= 0.8) {
                      status = 'Excellent';
                      statusColor = Colors.green;
                    } else if (completionRate >= 0.6) {
                      status = 'Good';
                      statusColor = Colors.orange;
                    } else {
                      status = 'Needs Improvement';
                      statusColor = Colors.red;
                    }
                    
                    return DataRow(
                      cells: [
                        DataCell(Text(member['name'], overflow: TextOverflow.ellipsis)),
                        DataCell(Text(member['total'].toString(), overflow: TextOverflow.ellipsis)),
                        DataCell(Text(member['completed'].toString(), overflow: TextOverflow.ellipsis)),
                        DataCell(Text('${(completionRate * 100).toStringAsFixed(1)}%', overflow: TextOverflow.ellipsis)),
                        DataCell(
                          Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateMemberPerformance() {
    final members = _statistics['members'] as List<dynamic>? ?? [];
    final memberTaskCounts = _statistics['memberTaskCounts'] as Map<String, dynamic>? ?? {};
    final memberCompletedCounts = _statistics['memberCompletedCounts'] as Map<String, dynamic>? ?? {};

    return members.map((member) {
      // Pastikan member adalah Map
      if (member is! Map<String, dynamic>) {
        return {
          'id': '',
          'name': 'Unknown',
          'total': 0,
          'completed': 0,
          'completionRate': 0.0,
        };
      }

      final memberId = member['id']?.toString() ?? '';
      final memberName = member['name']?.toString() ?? 'Unknown';
      final totalTasks = (memberTaskCounts[memberId] as num?)?.toInt() ?? 0;
      final completedTasks = (memberCompletedCounts[memberId] as num?)?.toInt() ?? 0;
      final completionRate = totalTasks > 0 ? completedTasks.toDouble() / totalTasks.toDouble() : 0.0;

      return {
        'id': memberId,
        'name': memberName,
        'total': totalTasks,
        'completed': completedTasks,
        'completionRate': completionRate,
      };
    }).toList();
  }
}