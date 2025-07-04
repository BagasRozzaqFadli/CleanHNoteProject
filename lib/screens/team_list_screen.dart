import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/premium_service.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';
import 'team/create_team_screen.dart';
import 'team/team_detail_screen.dart';
import 'team/join_team_screen.dart';

class TeamListScreen extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const TeamListScreen({
    Key? key,
    required this.userId,
    required this.isPremium,
  }) : super(key: key);

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.loadUserTeams();
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
  }

  @override
  Widget build(BuildContext context) {
    final premiumService = Provider.of<PremiumService>(context);
    final teamService = Provider.of<TeamService>(context);
    final teams = teamService.teams;
    final isPremium = Provider.of<TeamListScreen>(context).isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tim Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : teams.isEmpty
              ? _buildEmptyState(isPremium)
              : _buildTeamList(teams),
      floatingActionButton: _buildFloatingActionButton(isPremium),
    );
  }

  Widget _buildEmptyState(bool isPremium) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Tim',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPremium
                  ? 'Anda belum memiliki atau bergabung dengan tim apapun. Buat tim baru atau bergabung dengan tim yang sudah ada.'
                  : 'Fitur ini hanya tersedia untuk pengguna premium. Upgrade akun Anda untuk membuat tim atau bergabung dengan tim yang sudah ada.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (isPremium) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateTeamScreen(),
                    ),
                  ).then((_) => _loadTeams());
                },
                icon: const Icon(Icons.add),
                label: const Text('Buat Tim Baru'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JoinTeamScreen(),
                    ),
                  ).then((_) => _loadTeams());
                },
                icon: const Icon(Icons.login),
                label: const Text('Gabung Tim'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ] else
              ElevatedButton(
                onPressed: () {
                  // Navigate to premium plans screen
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const PremiumPlansScreen(),
                  //   ),
                  // );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Upgrade ke Premium',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamList(List<TeamModel> teams) {
    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final team = teams[index];
          final isCreator = team.createdBy == Provider.of<TeamService>(context).currentUserId;
          
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16.0),
              leading: CircleAvatar(
                backgroundColor: isCreator ? Colors.blue : Colors.grey,
                child: Icon(
                  isCreator ? Icons.star : Icons.group,
                  color: Colors.white,
                ),
              ),
              title: Text(
                team.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    team.description.isNotEmpty ? team.description : 'Tidak ada deskripsi',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${team.members.length} anggota',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamDetailScreen(team: team),
                  ),
                ).then((_) => _loadTeams());
              },
            ),
          );
        },
      ),
    );
  }

  Widget? _buildFloatingActionButton(bool isPremium) {
    if (!isPremium) return null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'join_team',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const JoinTeamScreen(),
              ),
            ).then((_) => _loadTeams());
          },
          backgroundColor: Colors.green,
          child: const Icon(Icons.login),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'create_team',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateTeamScreen(),
              ),
            ).then((_) => _loadTeams());
          },
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
