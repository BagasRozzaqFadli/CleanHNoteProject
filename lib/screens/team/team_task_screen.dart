import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';
import 'team_task_calendar_screen.dart';

class TeamTaskScreen extends StatefulWidget {
  final TeamModel team;
  final bool isLeader;

  const TeamTaskScreen({
    super.key,
    required this.team,
    required this.isLeader,
  });

  @override
  State<TeamTaskScreen> createState() => _TeamTaskScreenState();
}

class _TeamTaskScreenState extends State<TeamTaskScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _myTasks = [];
  List<Map<String, dynamic>> _filteredAllTasks = [];
  List<Map<String, dynamic>> _filteredMyTasks = [];
  String? _currentUserId;
  String _selectedFilter = 'all'; // all, pending, in_progress, completed, overdue
  String _selectedSort = 'due_date'; // due_date, title, status, created_at
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadTasks();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      _currentUserId = teamService.currentUserId;
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final tasks = await teamService.getTeamTasksData(widget.team.id);
      
      setState(() {
        _allTasks = tasks;
        _myTasks = tasks.where((task) => task['assigned_to'] == _currentUserId).toList();
        _isLoading = false;
      });
      
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat tugas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
        setState(() {
      _filteredAllTasks = _filterAndSortTasks(_allTasks);
      _filteredMyTasks = _filterAndSortTasks(_myTasks);
    });
  }

  List<Map<String, dynamic>> _filterAndSortTasks(List<Map<String, dynamic>> tasks) {
    var filteredTasks = tasks.where((task) {
      // Filter by status
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'overdue') {
          final dueDate = DateTime.parse(task['due_date']);
          final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
          if (!isOverdue) return false;
        } else {
          if (task['status'] != _selectedFilter) return false;
        }
      }

      // Filter by search text
      final searchText = _searchController.text.toLowerCase();
      if (searchText.isNotEmpty) {
        final title = (task['title'] ?? '').toLowerCase();
        final description = (task['description'] ?? '').toLowerCase();
        if (!title.contains(searchText) && !description.contains(searchText)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort tasks
    filteredTasks.sort((a, b) {
      switch (_selectedSort) {
        case 'title':
          return (a['title'] ?? '').compareTo(b['title'] ?? '');
        case 'status':
          return (a['status'] ?? '').compareTo(b['status'] ?? '');
        case 'created_at':
          return DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']));
        case 'due_date':
        default:
          return DateTime.parse(a['due_date']).compareTo(DateTime.parse(b['due_date']));
      }
    });

    return filteredTasks;
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _applyFilters();
        },
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildTaskSummary(List<Map<String, dynamic>> tasks) {
    final pending = tasks.where((task) => task['status'] == 'pending').length;
    final inProgress = tasks.where((task) => task['status'] == 'in_progress').length;
    final completed = tasks.where((task) => task['status'] == 'completed').length;
    final overdue = tasks.where((task) {
      final dueDate = DateTime.parse(task['due_date']);
      return dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    }).length;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Tugas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Tertunda', pending, Colors.grey),
                _buildSummaryItem('Proses', inProgress, Colors.orange),
                _buildSummaryItem('Selesai', completed, Colors.green),
                _buildSummaryItem('Terlambat', overdue, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tugas Tim ${widget.team.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamTaskCalendarScreen(
                    team: widget.team,
                    isLeader: widget.isLeader,
                  ),
                ),
              );
            },
            tooltip: 'Lihat Kalender',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _selectedSort = value;
              });
              _applyFilters();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'due_date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today),
                    SizedBox(width: 8),
                    Text('Urutkan: Tenggat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    Icon(Icons.title),
                    SizedBox(width: 8),
                    Text('Urutkan: Judul'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(Icons.flag),
                    SizedBox(width: 8),
                    Text('Urutkan: Status'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'created_at',
                child: Row(
                  children: [
                    Icon(Icons.access_time),
                    SizedBox(width: 8),
                    Text('Urutkan: Terbaru'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Ringkasan',
            ),
            Tab(
              icon: Icon(Icons.group),
              text: 'Semua Tugas',
            ),
            Tab(
              icon: Icon(Icons.person),
              text: 'Tugas Saya',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari tugas...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                // Filter chips
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    children: [
                      _buildFilterChip('Semua', 'all', Icons.list),
                      _buildFilterChip('Tertunda', 'pending', Icons.pending),
                      _buildFilterChip('Proses', 'in_progress', Icons.hourglass_empty),
                      _buildFilterChip('Selesai', 'completed', Icons.check_circle),
                      _buildFilterChip('Terlambat', 'overdue', Icons.warning),
                    ],
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(),
                      _buildTaskList(_filteredAllTasks, 'semua'),
                      _buildTaskList(_filteredMyTasks, 'saya'),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: widget.isLeader
          ? FloatingActionButton(
              onPressed: () {
                // Placeholder for create task functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur buat tugas baru akan segera tersedia'),
                  ),
                );
              },
              child: const Icon(Icons.add),
              tooltip: 'Buat Tugas Baru',
            )
          : null,
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTaskSummary(_allTasks),
          if (widget.isLeader) ...[
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                                                 Expanded(
                           child: ElevatedButton.icon(
                             onPressed: () {
                               // Placeholder for create task functionality
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Fitur buat tugas akan segera tersedia'),
                                 ),
                               );
                             },
                             icon: const Icon(Icons.add),
                             label: const Text('Buat Tugas'),
                           ),
                         ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _tabController.animateTo(1);
                            },
                            icon: const Icon(Icons.list),
                            label: const Text('Lihat Semua'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_allTasks.isNotEmpty) ...[
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tugas Terbaru',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_allTasks.take(3).map((task) => _buildCompactTaskCard(task))),
                    if (_allTasks.length > 3)
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        child: Text('Lihat ${_allTasks.length - 3} tugas lainnya'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTaskCard(Map<String, dynamic> task) {
    final dueDate = DateTime.parse(task['due_date']);
    final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    final status = task['status'] ?? 'pending';
    
    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(
            _getStatusIcon(status),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          task['title'] ?? 'Tugas Tanpa Judul',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            decoration: status == 'completed' ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          'Tenggat: ${DateFormat('dd MMM yyyy').format(dueDate)}',
          style: TextStyle(
            color: isOverdue ? Colors.red : Colors.grey[600],
            fontWeight: isOverdue ? FontWeight.bold : null,
          ),
        ),
        trailing: isOverdue
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TERLAMBAT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          // Placeholder for task detail navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Detail tugas: ${task['title'] ?? 'Tugas'}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList(List<Map<String, dynamic>> tasks, String type) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty || _selectedFilter != 'all'
                  ? 'Tidak ada tugas yang sesuai filter'
                  : type == 'semua' 
                      ? 'Belum ada tugas tim' 
                      : 'Belum ada tugas untuk Anda',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.isLeader && type == 'semua' && _searchController.text.isEmpty && _selectedFilter == 'all')
              const Text(
                'Klik tombol + untuk membuat tugas baru',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
          final dueDate = DateTime.parse(task['due_date']);
          final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    final status = task['status'] ?? 'pending';
    
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
    }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Placeholder for task detail navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Detail tugas: ${task['title'] ?? 'Tugas'}'),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task['title'] ?? 'Tugas Tanpa Judul',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: status == 'completed'
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task['description'] != null && task['description'].isNotEmpty)
                Text(
                  task['description'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tenggat: ${DateFormat('dd MMM yyyy').format(dueDate)}',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: isOverdue ? FontWeight.bold : null,
                      fontSize: 12,
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'TERLAMBAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<String>(
                future: _getAssignedUserName(task['assigned_to']),
                builder: (context, snapshot) {
                  return Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Ditugaskan: ${snapshot.data ?? 'Loading...'}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
          );
        },
      ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Selesai';
      case 'in_progress':
        return 'Proses';
      case 'cancelled':
        return 'Dibatal';
      default:
        return 'Tertunda';
    }
  }

  Future<String> _getAssignedUserName(String userId) async {
                try {
                  final teamService = Provider.of<TeamService>(context, listen: false);
      return await teamService.getUserName(userId);
                } catch (e) {
      debugPrint('Error getting user name: $e');
      return 'Unknown User';
    }
  }
}

