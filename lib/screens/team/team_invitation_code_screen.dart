import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/team_service.dart';

class TeamInvitationCodeScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const TeamInvitationCodeScreen({
    Key? key,
    required this.teamId,
    required this.teamName,
  }) : super(key: key);

  @override
  State<TeamInvitationCodeScreen> createState() => _TeamInvitationCodeScreenState();
}

class _TeamInvitationCodeScreenState extends State<TeamInvitationCodeScreen> {
  bool _isLoading = true;
  String _invitationCode = '';
  bool _regenerating = false;

  @override
  void initState() {
    super.initState();
    _loadInvitationCode();
  }

  Future<void> _loadInvitationCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final code = await teamService.getTeamInvitationCode(widget.teamId);
      
      setState(() {
        _isLoading = false;
        _invitationCode = code ?? 'Kode tidak tersedia';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _invitationCode = 'Error: $e';
      });
    }
  }

  Future<void> _regenerateCode() async {
    setState(() {
      _regenerating = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final newCode = await teamService.regenerateInvitationCode(widget.teamId);
      
      setState(() {
        _regenerating = false;
        if (newCode != null) {
          _invitationCode = newCode;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kode undangan baru berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuat kode undangan baru'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _regenerating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _invitationCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode undangan disalin ke clipboard'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kode Undangan ${widget.teamName}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Bagikan kode undangan ini kepada anggota tim:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _invitationCode,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: _copyToClipboard,
                          tooltip: 'Salin kode',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _regenerating ? null : _regenerateCode,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Buat Kode Baru'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Catatan: Membuat kode baru akan membuat kode lama tidak berfungsi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
