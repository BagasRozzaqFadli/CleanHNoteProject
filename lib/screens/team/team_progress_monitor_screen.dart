import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';

class TeamProgressMonitorScreen extends StatefulWidget {
  final TeamModel team;

  const TeamProgressMonitorScreen({
    Key? key,
    required this.team,
  }) : super(key: key);

  @override
  State<TeamProgressMonitorScreen> createState() => _TeamProgressMonitorScreenState();
}

class _TeamProgressMonitorScreenState extends State<TeamProgressMonitorScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadTeamStatistics();
  }

  Future<void> _loadTeamStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final stats = await teamService.getTeamTaskStatistics(widget.team.id);
      
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading team statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Progress Tim - ${widget.team.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeamStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeamStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverallProgressCard(),
                    const SizedBox(height: 16),
                    _buildMemberProgressList(),
                    const SizedBox(height: 16),
                    _buildTaskStatusBreakdown(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallProgressCard() {
    final totalTasks = _statistics['totalTasks'] ?? 0;
    final completedTasks = _statistics['completedTasks'] ?? 0;
    final inProgressTasks = _statistics['inProgressTasks'] ?? 0;
    final pendingTasks = _statistics['pendingTasks'] ?? 0;
    final completionRate = _statistics['completionRate'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Keseluruhan Tim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: CircularProgressIndicator(
                          value: completionRate,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(completionRate * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Selesai'),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildStatRow('Total Tugas', totalTasks.toString(), Icons.assignment, Colors.blue),
                      _buildStatRow('Selesai', completedTasks.toString(), Icons.check_circle, Colors.green),
                      _buildStatRow('Dalam Proses', inProgressTasks.toString(), Icons.hourglass_empty, Colors.orange),
                      _buildStatRow('Tertunda', pendingTasks.toString(), Icons.pending, Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberProgressList() {
    final members = _statistics['members'] as List<dynamic>? ?? [];
    final memberTaskCounts = _statistics['memberTaskCounts'] as Map<String, dynamic>? ?? {};
    final memberCompletedCounts = _statistics['memberCompletedCounts'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress per Anggota',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (members.isEmpty)
              const Center(
                child: Text('Belum ada anggota tim'),
              )
            else
              ...members.map((member) => _buildMemberProgressItem(
                member, 
                memberTaskCounts, 
                memberCompletedCounts
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberProgressItem(
    Map<String, dynamic> member, 
    Map<String, dynamic> taskCounts, 
    Map<String, dynamic> completedCounts
  ) {
    final memberId = member['id'] ?? '';
    final memberName = member['name'] ?? 'Unknown';
    final totalTasks = taskCounts[memberId] ?? 0;
    final completedTasks = completedCounts[memberId] ?? 0;
    final completionRate = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  memberName.isNotEmpty ? memberName[0].toUpperCase() : 'U',
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '$completedTasks dari $totalTasks tugas selesai',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(completionRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: completionRate >= 0.8 ? Colors.green : 
                         completionRate >= 0.5 ? Colors.orange : Colors.red,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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

  Widget _buildTaskStatusBreakdown() {
    final totalTasks = _statistics['totalTasks'] ?? 0;
    final completedTasks = _statistics['completedTasks'] ?? 0;
    final inProgressTasks = _statistics['inProgressTasks'] ?? 0;
    final pendingTasks = _statistics['pendingTasks'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Tugas Tim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (totalTasks == 0)
              const Center(
                child: Text('Belum ada tugas untuk ditampilkan'),
              )
            else ...[
              _buildStatusItem('Selesai', completedTasks, totalTasks, Colors.green),
              _buildStatusItem('Dalam Proses', inProgressTasks, totalTasks, Colors.orange),
              _buildStatusItem('Tertunda', pendingTasks, totalTasks, Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$count dari $total (${(percentage * 100).toStringAsFixed(1)}%)',
                style: TextStyle(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
} 