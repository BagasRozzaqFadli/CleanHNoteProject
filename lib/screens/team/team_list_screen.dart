import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import '../../models/team.dart';
import '../../services/team_service.dart';
import '../../services/user_service.dart';
import '../../appwrite_config.dart';
import 'create_team_screen.dart';
import 'join_team_screen.dart';
import 'team_detail_screen.dart';
import 'package:flutter/rendering.dart';

class TeamListScreen extends StatefulWidget {
  final String userId;

  const TeamListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _TeamListScreenState createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  late final TeamService _teamService;
  late final UserService _userService;
  List<Team> _teams = [];
  Map<String, String> _leaderNames = {}; // Menyimpan nama leader untuk setiap tim
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _teamService = TeamService(Databases(AppwriteConfig.client));
    _userService = UserService(Databases(AppwriteConfig.client));
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final joinedTeams = await _teamService.getJoinedTeams(widget.userId);
      final ownedTeams = await _teamService.getTeamsByLeader(widget.userId);
      
      // Menggabungkan dan menghilangkan duplikat
      final allTeams = {...joinedTeams, ...ownedTeams}.toList();
      
      // Load nama leader untuk setiap tim
      Map<String, String> leaderNames = {};
      for (var team in allTeams) {
        try {
          final leader = await _userService.getUser(team.leaderId);
          leaderNames[team.id] = leader.name;
        } catch (e) {
          leaderNames[team.id] = 'Unknown Leader';
        }
      }

      if (mounted) {
        setState(() {
          _teams = allTeams;
          _leaderNames = leaderNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat tim: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToCreateTeam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTeamScreen(userId: widget.userId),
      ),
    );

    if (result == true) {
      _loadTeams();
    }
  }

  Future<void> _navigateToJoinTeam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JoinTeamScreen(userId: widget.userId),
      ),
    );

    if (result == true) {
      _loadTeams();
    }
  }

  Future<void> _navigateToTeamDetail(Team team) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailScreen(
          team: team,
          currentUserId: widget.userId,
        ),
      ),
    );

    if (result == true) {
      _loadTeams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Anda belum memiliki tim',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _navigateToCreateTeam,
                        child: const Text('Buat Tim Baru'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _navigateToJoinTeam,
                        child: const Text('Bergabung dengan Tim'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeams,
                  child: ListView.builder(
                    itemCount: _teams.length,
                    itemBuilder: (context, index) {
                      final team = _teams[index];
                      final isLeader = team.leaderId == widget.userId;
                      final leaderName = _leaderNames[team.id] ?? 'Unknown Leader';
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(team.teamName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isLeader ? 'Leader' : 'Member'),
                              Text(
                                'Leader: $leaderName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLeader)
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                      text: team.invitationCode,
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kode undangan berhasil disalin'),
                                      ),
                                    );
                                  },
                                  tooltip: 'Salin Kode Undangan',
                                ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () => _navigateToTeamDetail(team),
                                tooltip: 'Lihat Detail',
                              ),
                            ],
                          ),
                          onTap: () => _navigateToTeamDetail(team),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _teams.isNotEmpty
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'joinTeam',
                  onPressed: _navigateToJoinTeam,
                  child: const Icon(Icons.group_add),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'createTeam',
                  onPressed: _navigateToCreateTeam,
                  child: const Icon(Icons.add),
                ),
              ],
            )
          : null,
    );
  }
} 