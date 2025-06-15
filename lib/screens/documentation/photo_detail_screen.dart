import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/documentation_model.dart';
import '../../services/documentation_service.dart';
import '../../services/team_service.dart';

class PhotoDetailScreen extends StatefulWidget {
  final DocumentationModel documentation;

  const PhotoDetailScreen({
    Key? key,
    required this.documentation,
  }) : super(key: key);

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  bool _isLoading = false;
  String? _beforeImageUrl;
  String? _afterImageUrl;
  String? _teamName;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadTeamInfo();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final documentationService = Provider.of<DocumentationService>(context, listen: false);
      
      final beforeUrl = await documentationService.getImageUrl(widget.documentation.beforeImage);
      final afterUrl = await documentationService.getImageUrl(widget.documentation.afterImage);

      if (mounted) {
        setState(() {
          _beforeImageUrl = beforeUrl;
          _afterImageUrl = afterUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading images: $e'),
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

  Future<void> _loadTeamInfo() async {
    if (widget.documentation.teamId == null) return;

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final teams = teamService.teams;
      final team = teams.firstWhere(
        (team) => team.id == widget.documentation.teamId,
        orElse: () => throw Exception('Team not found'),
      );

      if (mounted) {
        setState(() {
          _teamName = team.name;
        });
      }
    } catch (e) {
      // Team not found or error, just continue without team name
    }
  }

  Future<void> _deleteDocumentation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dokumentasi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus dokumentasi ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final documentationService = Provider.of<DocumentationService>(context, listen: false);
      final success = await documentationService.deleteDocumentation(widget.documentation.id);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dokumentasi berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus dokumentasi'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Dokumentasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteDocumentation,
            tooltip: 'Hapus Dokumentasi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageComparison(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.documentation.description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_teamName != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.group, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Tim: $_teamName',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              'Tanggal: ${_formatDate(widget.documentation.createdAt)}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImageComparison() {
    if (_beforeImageUrl == null || _afterImageUrl == null) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 400,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'SEBELUM'),
                Tab(text: 'SESUDAH'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildImageView(_beforeImageUrl!, 'Sebelum'),
                  _buildImageView(_afterImageUrl!, 'Sesudah'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageView(String imageUrl, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 48),
                    SizedBox(height: 8),
                    Text('Gagal memuat gambar'),
                  ],
                ),
              );
            },
          ),
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
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 