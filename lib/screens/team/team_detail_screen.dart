import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/team.dart';
import '../../models/team_member.dart';
import '../../services/team_service.dart';
import '../../services/user_service.dart';
import 'package:appwrite/appwrite.dart';
import '../../appwrite_config.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;
  final String currentUserId;

  const TeamDetailScreen({
    Key? key,
    required this.team,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _TeamDetailScreenState createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final TeamService _teamService = TeamService(Databases(AppwriteConfig.client));
  final UserService _userService = UserService(Databases(AppwriteConfig.client));
  List<TeamMember> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final members = await _teamService.getTeamMembers(widget.team.id);
      
      // Dapatkan data user untuk setiap member
      for (var member in members) {
        try {
          final user = await _userService.getUser(member.userId);
          member.name = user.name;
          member.email = user.email;
        } catch (e) {
          // Jika gagal mendapatkan data user, gunakan userId sebagai nama
          member.name = 'User ${member.userId}';
        }
      }

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat anggota tim: ${e.toString()}')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveTeam() async {
    try {
      await _teamService.leaveTeam(widget.currentUserId, widget.team.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil keluar dari tim')),
        );
        Navigator.pop(context, true); // true menandakan perlu refresh list tim
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _deleteTeam() async {
    // Tampilkan dialog konfirmasi
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Tim'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus tim ini? '
            'Semua anggota akan dihapus dan tindakan ini tidak dapat dibatalkan.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _teamService.deleteTeam(widget.team.id, widget.currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tim berhasil dihapus')),
        );
        Navigator.pop(context, true); // true menandakan perlu refresh list tim
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _copyInvitationCode() async {
    await Clipboard.setData(ClipboardData(text: widget.team.invitationCode));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode undangan berhasil disalin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLeader = widget.team.leaderId == widget.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.team.teamName),
        actions: [
          if (isLeader)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteTeam,
              tooltip: 'Hapus Tim',
            )
          else
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _leaveTeam,
              tooltip: 'Keluar dari Tim',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Tim
                  Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Informasi Tim',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (isLeader)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text(
                                    'Hapus Tim',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: _deleteTeam,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Dibuat pada: ${widget.team.createdAt.toString()}'),
                          if (isLeader) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Kode Undangan: ${widget.team.invitationCode}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: _copyInvitationCode,
                                  tooltip: 'Salin Kode',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Daftar Anggota
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Anggota Tim',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final isCurrentUser = member.userId == widget.currentUserId;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            member.name ?? 'User ${member.userId}',
                            style: TextStyle(
                              fontWeight: isCurrentUser
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (member.email != null)
                                Text(member.email!),
                              Text(
                                member.role == 'leader' ? 'Leader' : 'Member',
                                style: TextStyle(
                                  color: member.role == 'leader'
                                      ? Colors.blue
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: isCurrentUser
                              ? const Chip(label: Text('Anda'))
                              : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
} 