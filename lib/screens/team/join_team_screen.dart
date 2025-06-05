import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../../services/team_service.dart';
import '../../appwrite_config.dart';

class JoinTeamScreen extends StatefulWidget {
  final String userId;

  const JoinTeamScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _JoinTeamScreenState createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invitationCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _invitationCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinTeam() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = TeamService(
        Databases(AppwriteConfig.client),
      );

      await teamService.joinTeam(
        widget.userId,
        _invitationCodeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil bergabung dengan tim!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal bergabung dengan tim: ${e.toString()}')),
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
        title: const Text('Bergabung dengan Tim'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _invitationCodeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Undangan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kode undangan tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _joinTeam,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Bergabung dengan Tim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 