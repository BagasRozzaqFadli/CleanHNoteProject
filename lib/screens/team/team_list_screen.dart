import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/premium_service.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';
import 'create_team_screen.dart';
import 'team_detail_screen.dart';

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

  Future<void> _navigateToJoinTeam() async {
    // Navigasi ke halaman join tim dan tunggu hasilnya
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Gabung Tim'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildJoinTeamContent(),
          ),
        ),
      ),
    );
    
    if (result == true) {
      _loadTeams(); // Refresh tim jika berhasil join
    }
  }

  Widget _buildJoinTeamContent() {
    final _formKey = GlobalKey<FormState>();
    final _codeController = TextEditingController();
    bool _isLoading = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        Future<void> _joinTeam() async {
          if (!_formKey.currentState!.validate()) return;

          setState(() {
            _isLoading = true;
          });

          try {
            final teamService = Provider.of<TeamService>(context, listen: false);
            final success = await teamService.joinTeamWithCode(
              _codeController.text.trim().toUpperCase(),
            );

            if (!mounted) return;

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Berhasil bergabung dengan tim'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.pop(context, true); // Return success = true
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gagal bergabung dengan tim. Kode undangan tidak valid atau Anda sudah menjadi anggota tim.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          } finally {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
        }
        
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gabung dengan Tim',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan kode undangan untuk bergabung dengan tim.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Undangan',
                  hintText: 'Masukkan kode undangan 6 karakter',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kode undangan tidak boleh kosong';
                  }
                  if (value.trim().length != 6) {
                    return 'Kode undangan harus 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinTeam,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Gabung Tim',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Catatan: Semua pengguna (free plan dan premium) dapat bergabung dengan tim yang sudah ada menggunakan kode undangan.',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final premiumService = Provider.of<PremiumService>(context);
    final teamService = Provider.of<TeamService>(context);
    final teams = teamService.teams;
    final isPremium = premiumService.isPremium;

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
              : _buildTeamList(teams, isPremium),
      floatingActionButton: isPremium
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateTeamScreen(),
                  ),
                ).then((_) => _loadTeams());
              },
              child: const Icon(Icons.add),
              tooltip: 'Buat Tim Baru',
            )
          : FloatingActionButton(
              onPressed: _navigateToJoinTeam,
              child: const Icon(Icons.group_add),
              tooltip: 'Gabung Tim',
            ),
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
            const Text(
              'Anda belum memiliki atau bergabung dengan tim apapun.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (isPremium)
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
            ElevatedButton.icon(
              onPressed: _navigateToJoinTeam,
              icon: const Icon(Icons.group_add),
              label: const Text('Gabung dengan Tim'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Colors.blue,
              ),
            ),
            if (!isPremium) ...[
              const SizedBox(height: 24),
              const Text(
                'Upgrade ke premium untuk membuat tim Anda sendiri',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  // Navigate to premium plans screen
                },
                child: const Text('Upgrade ke Premium'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamList(List<TeamModel> teams, bool isPremium) {
    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: teams.length + (isPremium ? 2 : 1), // +1 for buttons
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                if (isPremium)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ElevatedButton.icon(
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _navigateToJoinTeam,
                    icon: const Icon(Icons.group_add),
                    label: const Text('Gabung dengan Tim'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            );
          }
          
          final adjustedIndex = isPremium ? index - 2 : index - 1;
          
          // Tambahkan pengecekan untuk memastikan adjustedIndex valid
          if (adjustedIndex < 0 || adjustedIndex >= teams.length) {
            return const SizedBox(); // Return widget kosong jika indeks tidak valid
          }
          
          final team = teams[adjustedIndex];
          return _buildTeamCard(team);
        },
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    final bool isCreator = team.createdBy == widget.userId;
    final teamService = Provider.of<TeamService>(context, listen: false);
    
    return FutureBuilder<String>(
      future: teamService.getUserName(team.createdBy),
      builder: (context, snapshot) {
        final creatorName = snapshot.data ?? 'Memuat...';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamDetailScreen(
                    team: team,
                    isLeader: isCreator,
                  ),
                ),
              ).then((_) => _loadTeams());
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isCreator)
                        Chip(
                          label: const Text('Pembuat'),
                          backgroundColor: Colors.green.shade100,
                          labelStyle: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Dibuat oleh: $creatorName',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (team.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      team.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: teamService.getTeamMembersWithNames(team.id),
                        builder: (context, snapshot) {
                          final int memberCount = snapshot.data?.length ?? 0;
                          return Text(
                            '$memberCount anggota',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          );
                        },
                      ),
                      Text(
                        'Dibuat: ${_formatDate(team.createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 