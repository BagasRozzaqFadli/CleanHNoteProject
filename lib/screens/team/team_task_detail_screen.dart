import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/team_service.dart';


class TeamTaskDetailScreen extends StatefulWidget {
  final String taskId;
  final String teamId;
  final bool isLeader;

  const TeamTaskDetailScreen({
    super.key,
    required this.taskId,
    required this.teamId,
    required this.isLeader,
  });

  @override
  State<TeamTaskDetailScreen> createState() => _TeamTaskDetailScreenState();
}

class _TeamTaskDetailScreenState extends State<TeamTaskDetailScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  Map<String, dynamic>? _task;
  String? _currentUserId;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTaskDetail();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      _currentUserId = teamService.currentUserId;
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadTaskDetail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final task = await teamService.getTaskById(widget.taskId);
      
      setState(() {
        _task = task;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading task detail: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat detail tugas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaskStatus(String newStatus) async {
    if (_task == null) return;

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      await teamService.updateTaskStatus(widget.taskId, newStatus);
      
      setState(() {
        _task!['status'] = newStatus;
        if (newStatus == 'completed') {
          _task!['completed_at'] = DateTime.now().toUtc().toIso8601String();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status tugas berhasil diupdate'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengupdate status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadCompletionProof() async {
    if (_selectedImage == null || _task == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      final success = await teamService.uploadTaskCompletionProof(
        widget.taskId, 
        _selectedImage!.path
      );
      
      if (success && mounted) {
        setState(() {
          _task!['status'] = 'completed';
          _task!['completed_at'] = DateTime.now().toUtc().toIso8601String();
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bukti penyelesaian berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload task to get updated data
        _loadTaskDetail();
      } else if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengunggah bukti penyelesaian'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading completion proof: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengunggah bukti: $e'),
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
        title: const Text('Detail Tugas'),
        actions: [
          if (_task != null && (_isAssignedToMe() || widget.isLeader))
            PopupMenuButton<String>(
              onSelected: _updateTaskStatus,
              itemBuilder: (context) => [
                if (_task!['status'] != 'in_progress')
                  const PopupMenuItem(
                    value: 'in_progress',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Mulai Kerjakan'),
                      ],
                    ),
                  ),
                if (_task!['status'] != 'completed')
                  const PopupMenuItem(
                    value: 'completed',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Tandai Selesai'),
                      ],
                    ),
                  ),
                if (widget.isLeader && _task!['status'] != 'cancelled')
                  const PopupMenuItem(
                    value: 'cancelled',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Batalkan Tugas'),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(
                  child: Text(
                    'Tugas tidak ditemukan',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : _buildTaskDetail(),
    );
  }

  bool _isAssignedToMe() {
    return _task != null && _task!['assigned_to'] == _currentUserId;
  }

  Widget _buildTaskDetail() {
    final task = _task!;
    final dueDate = DateTime.parse(task['due_date']);
    final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'completed';
    final status = task['status'] ?? 'pending';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Selesai';
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Sedang Dikerjakan';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Dibatalkan';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
        statusText = 'Tertunda';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            color: statusColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Tugas',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title and Description
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? 'Tugas Tanpa Judul',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (task['description'] != null && task['description'].isNotEmpty)
                    Text(
                      task['description'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Task Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Tugas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Tenggat Waktu',
                    DateFormat('dd MMMM yyyy').format(dueDate),
                    isOverdue ? Colors.red : null,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<String>(
                    future: _getAssignedUserName(task['assigned_to']),
                    builder: (context, snapshot) {
                      return _buildInfoRow(
                        Icons.person,
                        'Ditugaskan Kepada',
                        snapshot.data ?? 'Loading...',
                        Colors.blue,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<String>(
                    future: _getCreatedByUserName(task['created_by']),
                    builder: (context, snapshot) {
                      return _buildInfoRow(
                        Icons.person_add,
                        'Dibuat Oleh',
                        snapshot.data ?? 'Loading...',
                        Colors.purple,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Tanggal Dibuat',
                    DateFormat('dd MMMM yyyy HH:mm').format(DateTime.parse(task['created_at'])),
                  ),
                  if (task['completed_at'] != null) ...[  
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.check_circle,
                      'Tanggal Selesai',
                      DateFormat('dd MMMM yyyy HH:mm').format(DateTime.parse(task['completed_at'])),
                      Colors.green,
                    ),
                  ],
                  if (task['completion_proof'] != null) ...[  
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.image,
                      'Bukti Penyelesaian',
                      'Tersedia',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Image.network(
                          task['completion_proof'],
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text('Gagal memuat gambar'),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Upload Proof Section
          if (_isAssignedToMe() && (status == 'in_progress' || status == 'pending') && task['completion_proof'] == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unggah Bukti Penyelesaian',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null) ...[  
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: Image.file(_selectedImage!),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pilih Gambar'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Ambil Foto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImage != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadCompletionProof,
                          icon: _isUploading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload),
                          label: Text(_isUploading ? 'Mengunggah...' : 'Unggah Bukti'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Action Buttons
          if (_isAssignedToMe() || widget.isLeader)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aksi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (status != 'completed' && status != 'cancelled')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateTaskStatus('completed'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Tandai Selesai'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    if (status == 'pending' && _isAssignedToMe())
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateTaskStatus('in_progress'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Mulai Kerjakan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? valueColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<String> _getAssignedUserName(String userId) async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      return await teamService.getUserName(userId);
    } catch (e) {
      debugPrint('Error getting assigned user name: $e');
      return 'Unknown User';
    }
  }

  Future<String> _getCreatedByUserName(String userId) async {
    try {
      final teamService = Provider.of<TeamService>(context, listen: false);
      return await teamService.getUserName(userId);
    } catch (e) {
      debugPrint('Error getting created by user name: $e');
      return 'Unknown User';
    }
  }
}
