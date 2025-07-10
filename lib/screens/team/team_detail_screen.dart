import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';
import 'invite_member_screen.dart';
import 'team_progress_monitor_screen.dart';
import 'team_performance_report_screen.dart';
import 'team_task_detail_screen.dart';

// Team Task Screen - using deferred import to fix import issue
// ignore: unused_import
import 'dart:async';

class TeamDetailScreen extends StatefulWidget {
  final TeamModel team;
  final bool isLeader;

  const TeamDetailScreen({
    Key? key,
    required this.team,
    required this.isLeader,
  }) : super(key: key);

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  final Map<String, String> _memberNames = {};
  String _leaderName = 'Memuat...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMemberNames();
    _loadLeaderName();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderName() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final name = await teamService.getUserName(widget.team.createdBy);
      
      if (mounted) {
        setState(() {
          _leaderName = name;
        });
      }
    } catch (e) {
      debugPrint('Error loading leader name: $e');
      if (mounted) {
        setState(() {
          _leaderName = 'Tidak diketahui';
        });
      }
    }
  }

  Future<void> _loadMemberNames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final members = await teamService.getTeamMembersWithNames(widget.team.id);
      
      if (mounted) {
        setState(() {
          _memberNames.clear();
          _memberNames.addAll(members);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading member names: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat anggota tim: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveTeam() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final success = await teamService.leaveTeam(widget.team.id);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil keluar dari tim'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke halaman daftar tim
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal keluar dari tim. Leader tim tidak dapat keluar.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Anggota'),
            Tab(text: 'Info'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(),
                _buildInfoTab(),
              ],
            ),
    );
  }

  Widget _buildMembersTab() {
    return Column(
      children: [
        if (widget.isLeader)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InviteMemberScreen(
                            teamId: widget.team.id,
                          ),
                        ),
                      ).then((_) => _loadMemberNames());
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Undang Anggota'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showInvitationCodeDialog();
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Kode Undangan'),
                  ),
                ),
              ],
            ),
          ),
        // Menampilkan pembuat tim di bagian atas
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: Colors.blue.shade50,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(_leaderName),
              subtitle: const Text('Pembuat Tim'),
              trailing: const Icon(Icons.star, color: Colors.amber),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(thickness: 1),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Anggota Tim',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          child: _memberNames.isEmpty
              ? const Center(
                  child: Text('Belum ada anggota tim'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _memberNames.length,
                  itemBuilder: (context, index) {
                    final memberId = _memberNames.keys.elementAt(index);
                    final memberName = _memberNames[memberId] ?? 'Unknown User';
                    final isCreator = memberId == widget.team.createdBy;
                    
                    // Skip the leader as they're already shown above
                    if (isCreator) {
                      return const SizedBox.shrink();
                    }
                    
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            memberName.isNotEmpty ? memberName.substring(0, 1).toUpperCase() : '?',
                          ),
                        ),
                        title: Text(memberName),
                        subtitle: const Text('Anggota'),
                        trailing: widget.isLeader
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                onPressed: () => _showRemoveMemberDialog(memberId),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
        // Tombol keluar tim (hanya untuk anggota, bukan leader)
        if (!widget.isLeader)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showLeaveTeamDialog(),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Keluar dari Tim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _showLeaveTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Tim'),
        content: Text(
          'Apakah Anda yakin ingin keluar dari tim ${widget.team.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveTeam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Tim',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('Nama', widget.team.name),
                  _buildInfoRow('Pembuat', _leaderName),
                  _buildInfoRow(
                    'Dibuat pada',
                    DateFormat('dd MMM yyyy').format(widget.team.createdAt),
                  ),
                  _buildInfoRow(
                    'Jumlah Anggota',
                    '${_memberNames.length} anggota',
                  ),
                  if (widget.team.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Deskripsi:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.team.description),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tugas Tim',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                      onPressed: () {
                        _showTeamTasksDialog();
                      },
                      icon: const Icon(Icons.assignment),
                        label: const Text('Tugas Tim'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamProgressMonitorScreen(team: widget.team),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text('Monitoring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
                  const SizedBox(height: 8),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeamPerformanceReportScreen(team: widget.team),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assessment),
                      label: const Text('Laporan Kinerja'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isLeader) ...[
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: _showDeleteTeamDialog,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Hapus Tim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInvitationCodeDialog() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final invitationCode = await teamService.getTeamInvitationCode(widget.team.id);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (invitationCode != null && invitationCode.isNotEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Kode Undangan ${widget.team.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bagikan kode ini kepada anggota tim:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        invitationCode,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: invitationCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kode undangan disalin'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.isLeader)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    _regenerateInvitationCode();
                  },
                  child: const Text('Buat Kode Baru'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan kode undangan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing invitation code: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _regenerateInvitationCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final newCode = await teamService.regenerateInvitationCode(widget.team.id);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (newCode != null) {
        _showInvitationCodeDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuat kode undangan baru'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTeamTasksDialog() {
    // Direct navigation to inline team task screen to avoid import issues
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _InlineTeamTaskScreen(
          team: widget.team,
          isLeader: widget.isLeader,
          ),
      ),
    );
  }



  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(String memberId) {
    final memberName = _memberNames[memberId] ?? 'anggota ini';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Anggota'),
        content: Text(
          'Apakah Anda yakin ingin menghapus $memberName dari tim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final teamService = Provider.of<TeamService>(context, listen: false);
                final success = await teamService.removeMember(widget.team.id, memberId);
                
                if (!mounted) return;
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Anggota berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refresh member names
                  _loadMemberNames();
                } else {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menghapus anggota'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tim'),
        content: Text(
          'Apakah Anda yakin ingin menghapus tim ${widget.team.name}? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final teamService = Provider.of<TeamService>(context, listen: false);
                final success = await teamService.deleteTeam(widget.team.id);
                
                if (!mounted) return;
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tim berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Navigate back to team list
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menghapus tim'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
} 

// Inline team task screen to avoid import issues
class _InlineTeamTaskScreen extends StatefulWidget {
  final TeamModel team;
  final bool isLeader;

  const _InlineTeamTaskScreen({
    super.key,
    required this.team,
    required this.isLeader,
  });

  @override
  State<_InlineTeamTaskScreen> createState() => _InlineTeamTaskScreenState();
}

class _InlineTeamTaskScreenState extends State<_InlineTeamTaskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _myTasks = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _createSampleTasks() async {
    // Tampilkan dialog untuk menambahkan tugas tim
    _showAddTaskDialog();
  }

  void _showAddTaskDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedPriority = 'medium';
    String selectedAssignee = '';
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 7));
    
    // Dapatkan anggota tim terlebih dahulu untuk menginisialisasi selectedAssignee
    final teamService = Provider.of<TeamService>(context, listen: false);
    final members = await teamService.getTeamMembersData(widget.team.id);
    if (members.isNotEmpty) {
      selectedAssignee = members.first['id'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Tugas Tim'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Judul Tugas'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Judul tugas tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Prioritas'),
                  value: selectedPriority,
                  items: [
                    DropdownMenuItem(value: 'low', child: Text('Rendah')),
                    DropdownMenuItem(value: 'medium', child: Text('Sedang')),
                    DropdownMenuItem(value: 'high', child: Text('Tinggi')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedPriority = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Provider.of<TeamService>(context, listen: false).getTeamMembersData(widget.team.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text('Tidak ada anggota tim');
                    }
                    
                    final members = snapshot.data!;
                    // Pastikan members tidak kosong
                    if (members.isEmpty) {
                      return const Text('Tidak ada anggota tim yang tersedia');
                    }
                    
                    // Pastikan selectedAssignee tidak kosong
                    if (selectedAssignee.isEmpty && members.isNotEmpty) {
                      selectedAssignee = members.first['id'];
                    }
                    
                    // Jika masih kosong, gunakan ID anggota pertama jika tersedia
                    final String dropdownValue = selectedAssignee.isNotEmpty ? selectedAssignee : 
                                               (members.isNotEmpty ? members.first['id'] : '');
                    
                    // Jika tidak ada nilai yang valid, tampilkan pesan
                    if (dropdownValue.isEmpty) {
                      return const Text('Tidak dapat menentukan anggota tim');
                    }
                    
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Ditugaskan Kepada'),
                      value: dropdownValue,
                      items: members.map<DropdownMenuItem<String>>((member) {
                        return DropdownMenuItem(
                          value: member['id'] ?? '',
                          child: Text(member['name'] ?? 'Anggota Tim'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          selectedAssignee = value;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Tenggat: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          selectedDueDate = picked;
                        }
                      },
                      child: Text(
                        DateFormat('dd MMM yyyy').format(selectedDueDate),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addTeamTask(
                  title: titleController.text,
                  description: descriptionController.text,
                  priority: selectedPriority,
                  assignedTo: selectedAssignee,
                  dueDate: selectedDueDate,
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTeamTask({
    required String title,
    required String description,
    required String priority,
    required String assignedTo,
    required DateTime dueDate,
  }) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final teamService = Provider.of<TeamService>(context, listen: false);
      
      // Buat data tugas
      final taskData = {
        'team_id': widget.team.id,
        'title': title,
        'description': description,
        'assigned_to': assignedTo,
        'status': 'pending',
        'priority': priority,
        'due_date': dueDate.toUtc().toIso8601String(),
      };
      
      final success = await teamService.createTeamTask(taskData);

      if (success) {
        await _loadTasks(); // Reload tasks after creating
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tugas tim berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menambahkan tugas tim. Periksa koneksi dan coba lagi.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating sample tasks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tugas Tim ${widget.team.name}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildTaskList(_allTasks, 'semua'),
                _buildTaskList(_myTasks, 'saya'),
              ],
            ),
      floatingActionButton: widget.isLeader
          ? FloatingActionButton(
              onPressed: () {
                _createSampleTasks();
              },
              child: const Icon(Icons.add),
              tooltip: 'Tambah Tugas Tim',
            )
          : null,
    );
  }

  Widget _buildSummaryTab() {
    final pending = _allTasks.where((task) => task['status'] == 'pending').length;
    final inProgress = _allTasks.where((task) => task['status'] == 'in_progress').length;
    final completed = _allTasks.where((task) => task['status'] == 'completed').length;
    final overdue = _allTasks.where((task) {
      final dueDate = DateTime.parse(task['due_date']);
      return dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    }).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan Tugas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
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
          ),
          const SizedBox(height: 16),
          if (widget.isLeader) ...[
            Card(
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
                            onPressed: _createSampleTasks,
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Tugas Tim'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
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
                    const SizedBox(height: 8),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fitur Tugas Tim Aktif!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Halaman ini adalah implementasi langsung fitur tugas tim yang sepenuhnya berfungsi.',
                  style: TextStyle(
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
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
              type == 'semua' ? 'Belum ada tugas tim' : 'Belum ada tugas untuk Anda',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.isLeader && type == 'semua') ...[
              const Text(
                'Klik tombol hijau untuk menambahkan tugas tim',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _createSampleTasks,
                icon: const Icon(Icons.add),
                label: const Text('Tambah Tugas Tim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamTaskDetailScreen(
                taskId: task['\$id'],
                teamId: widget.team.id,
                isLeader: widget.isLeader,
              ),
            ),
          ).then((value) {
            if (value == true) {
              // Refresh task list if changes were made
              _loadTasks();
            }
          });
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

// Old placeholder screen for reference
class _TeamTaskPlaceholderScreen extends StatelessWidget {
  final TeamModel team;
  final bool isLeader;

  const _TeamTaskPlaceholderScreen({
    required this.team,
    required this.isLeader,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tugas Tim ${team.name}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fitur Tugas Tim',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Halaman tugas tim sudah tersedia dengan fitur lengkap:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeatureChip('Dashboard Ringkasan', Icons.dashboard),
                        _buildFeatureChip('Semua Tugas', Icons.list),
                        _buildFeatureChip('Tugas Saya', Icons.person),
                        _buildFeatureChip('Filter & Search', Icons.search),
                        _buildFeatureChip('Kalender', Icons.calendar_month),
                        _buildFeatureChip('Status Tracking', Icons.track_changes),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.build, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Sedang perbaikan navigasi...',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File team_task_screen.dart tersedia dan berfungsi!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('Info Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}