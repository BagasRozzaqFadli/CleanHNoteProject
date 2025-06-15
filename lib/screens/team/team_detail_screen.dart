import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';
import 'invite_member_screen.dart';

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
      print('Error loading leader name: $e');
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
      print('Error loading member names: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
            content: Text('Error: $e'),
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
                          child: Text(memberName.substring(0, 1)),
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
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showTeamTasksDialog();
                      },
                      icon: const Icon(Icons.assignment),
                      label: const Text('Lihat Tugas Tim'),
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
      
      if (invitationCode != null) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan kode undangan'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tugas Tim ${widget.team.name}'),
        content: const Text(
          'Fitur tugas tim sedang dalam pengembangan.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
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
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Anggota berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refresh member names
                  _loadMemberNames();
                } else if (mounted) {
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
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tim berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Navigate back to team list
                  Navigator.pop(context);
                } else if (mounted) {
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