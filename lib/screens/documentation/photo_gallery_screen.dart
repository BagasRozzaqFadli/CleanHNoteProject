import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/documentation_service.dart';
import '../../services/premium_service.dart';
import '../../services/team_service.dart';
import '../../models/documentation_model.dart';
import '../../models/team_model.dart';
import 'photo_detail_screen.dart';
import 'photo_upload_screen.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final String userId;
  
  const PhotoGalleryScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  bool _isLoading = false;
  String? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    _loadDocumentations();
  }

  Future<void> _loadDocumentations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documentationService = Provider.of<DocumentationService>(context, listen: false);
      
      if (_selectedTeamId != null) {
        await documentationService.loadTeamDocumentations(_selectedTeamId!);
      } else {
        await documentationService.loadUserDocumentations();
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
    final documentationService = Provider.of<DocumentationService>(context);
    final teamService = Provider.of<TeamService>(context);
    final isPremium = premiumService.isPremium;
    final documentations = documentationService.documentations;
    final teams = teamService.teams;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri Dokumentasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocumentations,
          ),
        ],
      ),
      body: !isPremium
          ? _buildPremiumPrompt()
          : Column(
              children: [
                if (teams.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildTeamDropdown(teams),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : documentations.isEmpty
                          ? _buildEmptyState()
                          : _buildGallery(documentations),
                ),
              ],
            ),
      floatingActionButton: isPremium
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhotoUploadScreen(),
                  ),
                ).then((_) => _loadDocumentations());
              },
              child: const Icon(Icons.add_a_photo),
            )
          : null,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Dokumentasi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Anda belum memiliki dokumentasi foto. Tambahkan dokumentasi baru untuk mulai mencatat progres Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhotoUploadScreen(),
                  ),
                ).then((_) => _loadDocumentations());
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Tambah Dokumentasi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDropdown(List<TeamModel> teams) {
    return DropdownButtonFormField<String?>(
      decoration: const InputDecoration(
        labelText: 'Filter Tim',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.filter_list),
      ),
      value: _selectedTeamId,
      hint: const Text('Semua Dokumentasi'),
      onChanged: (value) {
        setState(() {
          _selectedTeamId = value;
        });
        _loadDocumentations();
      },
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Semua Dokumentasi'),
        ),
        ...teams.map((team) {
          return DropdownMenuItem<String?>(
            value: team.id,
            child: Text(team.name),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildGallery(List<DocumentationModel> documentations) {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: documentations.length,
      itemBuilder: (context, index) {
        final documentation = documentations[index];
        return _buildGalleryItem(documentation);
      },
    );
  }

  Widget _buildGalleryItem(DocumentationModel documentation) {
    final documentationService = Provider.of<DocumentationService>(context, listen: false);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoDetailScreen(documentation: documentation),
          ),
        ).then((_) => _loadDocumentations());
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FutureBuilder<String>(
                future: documentationService.getImageUrl(documentation.beforeImage),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  }
                  
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          );
                        },
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Before',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentation.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(documentation.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 