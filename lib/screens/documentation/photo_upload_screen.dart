import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/documentation_service.dart';
import '../../services/premium_service.dart';
import '../../services/team_service.dart';
import '../../models/team_model.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({Key? key}) : super(key: key);

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  File? _beforeImage;
  File? _afterImage;
  String? _selectedTeamId;
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isBefore) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documentationService = Provider.of<DocumentationService>(context, listen: false);
      final image = await documentationService.pickImage();

      if (image != null) {
        setState(() {
          if (isBefore) {
            _beforeImage = image;
          } else {
            _afterImage = image;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
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

  Future<void> _uploadDocumentation() async {
    if (!_formKey.currentState!.validate() || _beforeImage == null || _afterImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap pilih foto sebelum dan sesudah'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final documentationService = Provider.of<DocumentationService>(context, listen: false);
      final documentation = await documentationService.createDocumentation(
        description: _descriptionController.text.trim(),
        beforeImage: _beforeImage!,
        afterImage: _afterImage!,
        teamId: _selectedTeamId,
      );

      if (!mounted) return;

      if (documentation != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumentasi berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengunggah dokumentasi'),
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

  @override
  Widget build(BuildContext context) {
    final premiumService = Provider.of<PremiumService>(context);
    final teamService = Provider.of<TeamService>(context);
    final isPremium = premiumService.isPremium;
    final teams = teamService.teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Dokumentasi Foto'),
      ),
      body: !isPremium
          ? _buildPremiumPrompt()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upload Foto Dokumentasi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (teams.isNotEmpty) ...[
                            _buildTeamDropdown(teams),
                            const SizedBox(height: 16),
                          ],
                          _buildImageUploadSection(
                            title: 'Foto Sebelum',
                            image: _beforeImage,
                            onTap: () => _pickImage(true),
                          ),
                          const SizedBox(height: 16),
                          _buildImageUploadSection(
                            title: 'Foto Sesudah',
                            image: _afterImage,
                            onTap: () => _pickImage(false),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Deskripsi tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _uploadDocumentation,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'Upload Dokumentasi',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildPremiumPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Fitur Premium',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fitur dokumentasi foto hanya tersedia untuk pengguna premium. Upgrade akun Anda untuk menggunakan fitur ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
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

  Widget _buildTeamDropdown(List<TeamModel> teams) {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Tim (Opsional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.group),
      ),
      value: _selectedTeamId,
      hint: const Text('Pilih tim (opsional)'),
      onChanged: (value) {
        setState(() {
          _selectedTeamId = value;
        });
      },
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Pribadi (tanpa tim)'),
        ),
        ...teams.map((team) {
          return DropdownMenuItem<String>(
            value: team.id,
            child: Text(team.name),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildImageUploadSection({
    required String title,
    required File? image,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text('Klik untuk memilih foto'),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
} 