import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel? task;
  final String? taskId;
  final bool isPremium;

  const TaskDetailScreen({
    Key? key,
    this.task,
    this.taskId,
    required this.isPremium,
  }) : assert(task != null || taskId != null, 'Either task or taskId must be provided'),
       super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TaskModel? _task;
  bool _isLoading = false;
  bool _isLoadingTask = false;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;
  late String _executionTime;
  late TaskPriority _priority;

  @override
  void initState() {
    super.initState();
    debugPrint('TaskDetailScreen: initState called');
    if (widget.task != null) {
      debugPrint('TaskDetailScreen: Using provided task: ${widget.task!.id} - ${widget.task!.title}');
      _task = widget.task;
      _initializeControllers();
    } else if (widget.taskId != null) {
      debugPrint('TaskDetailScreen: No task provided, loading by ID: ${widget.taskId}');
      _task = null;
      _isLoadingTask = true;
      // Gunakan Future.microtask untuk memastikan context tersedia saat _loadTaskDetails dipanggil
      Future.microtask(() => _loadTaskDetails());
    } else {
      debugPrint('TaskDetailScreen: ERROR - Neither task nor taskId provided');
      _task = null;
      _isLoadingTask = false;
    }
  }

  void _initializeControllers() {
    if (_task != null) {
      _titleController = TextEditingController(text: _task!.title);
      _descriptionController = TextEditingController(text: _task!.description);
      _dueDate = _task!.dueDate;
      _executionTime = _task!.executionTime ?? '09:00';
      _priority = _task!.priority ?? TaskPriority.medium;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _dueDate = DateTime.now().add(const Duration(days: 1));
      _executionTime = '09:00';
      _priority = TaskPriority.medium;
    }
  }

  Future<void> _loadTaskDetails() async {
    if (widget.taskId == null) {
      debugPrint('TaskDetailScreen: taskId is null, skipping load');
      return;
    }
    
    debugPrint('TaskDetailScreen: Loading task details for ID: ${widget.taskId}');
    setState(() {
      _isLoadingTask = true;
    });
    
    try {
      debugPrint('TaskDetailScreen: Getting TaskService from provider');
      final taskService = Provider.of<TaskService>(context, listen: false);
      debugPrint('TaskDetailScreen: Calling getTaskById with ID: ${widget.taskId}');
      final task = await taskService.getTaskById(widget.taskId!);
      debugPrint('TaskDetailScreen: Task loaded successfully: ${task.id} - ${task.title}');
      
      setState(() {
        _task = task;
        _isLoadingTask = false;
      });
      
      debugPrint('TaskDetailScreen: Initializing controllers');
      _initializeControllers();
    } catch (e) {
      debugPrint('TaskDetailScreen: ERROR loading task details: $e');
      debugPrint('TaskDetailScreen: Error type: ${e.runtimeType}');
      if (e is Exception) {
        debugPrint('TaskDetailScreen: Exception message: ${e.toString()}');
      }
      
      setState(() {
        _isLoadingTask = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail tugas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: int.parse(_executionTime.split(':')[0]),
      minute: int.parse(_executionTime.split(':')[1]),
    );
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    
    if (picked != null) {
      setState(() {
        _executionTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _updateTask() async {
    if (!_formKey.currentState!.validate() || _task == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('=== MEMULAI UPDATE TUGAS ===');
      debugPrint('Task ID: ${_task?.id}');
      
      // Tampilkan snackbar bahwa tugas sedang diupdate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menyimpan perubahan...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      final taskService = Provider.of<TaskService>(context, listen: false);
      
      // Pertahankan status dan completedAt yang ada
      final updatedTask = _task!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        executionTime: _executionTime,
        priority: _priority,
        updatedAt: DateTime.now(),
      );

      debugPrint('Mengirim update ke TaskService...');
      final result = await taskService.updateTask(updatedTask);
      
      if (result != null) {
        debugPrint('Update berhasil dengan ID: ${result.id}');
        setState(() {
          _task = result;
          _isEditing = false;
          _isLoading = false;
        });
        
        // Tampilkan snackbar sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tugas berhasil diperbarui'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Gagal mengupdate tugas');
      }
    } catch (e) {
      debugPrint('=== ERROR SAAT UPDATE TUGAS ===');
      debugPrint('Error: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate tugas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'COBA LAGI',
              textColor: Colors.white,
              onPressed: _updateTask,
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    if (_task == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Tampilkan snackbar bahwa status sedang diubah
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mengubah status menjadi ${_getStatusName(newStatus)}...'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
      
      final taskService = Provider.of<TaskService>(context, listen: false);
      
      // Jika status berubah menjadi completed atau cancelled,
      // kita perlu mengupdate waktu penyelesaian
      DateTime? completedAt;
      if (newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) {
        completedAt = DateTime.now();
        debugPrint('Tugas ${newStatus == TaskStatus.completed ? "diselesaikan" : "dibatalkan"} pada: $completedAt');
      }
      
      final success = await taskService.updateTaskStatus(_task!.id, newStatus);
      
      if (success) {
        setState(() {
          _task = _task!.copyWith(
            status: newStatus,
            completedAt: completedAt ?? _task?.completedAt
          );
          _isLoading = false;
        });
        
        // Tampilkan snackbar sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status berhasil diubah menjadi ${_getStatusName(newStatus)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Jika tugas diselesaikan atau dibatalkan, kembali ke halaman sebelumnya setelah delay
        if ((newStatus == TaskStatus.completed || newStatus == TaskStatus.cancelled) && mounted) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop(true); // Kembali dengan hasil true untuk memicu refresh
            }
          });
        }
      } else {
        throw Exception('Gagal mengupdate status tugas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate status tugas: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'COBA LAGI',
              textColor: Colors.white,
              onPressed: () => _updateTaskStatus(newStatus),
            ),
          ),
        );
      }
    }
  }

  String _getStatusName(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'Menunggu';
      case TaskStatus.inProgress:
        return 'Dalam Proses';
      case TaskStatus.completed:
        return 'Selesai';
      case TaskStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  Future<void> _deleteTask() async {
    if (_task == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin menghapus tugas ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final taskService = Provider.of<TaskService>(context, listen: false);
      final success = await taskService.deleteTask(_task!.id);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Gagal menghapus tugas');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus tugas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTask) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Tugas'),
        ),
        body: const Center(
          child: Text('Tugas tidak ditemukan'),
        ),
      );
    }
    
    // Status color
    late Color statusColor;
    late String statusText;

    switch (_task!.status) {
      case TaskStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Menunggu';
        break;
      case TaskStatus.inProgress:
        statusColor = Colors.blue;
        statusText = 'Dalam Proses';
        break;
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusText = 'Selesai';
        break;
      case TaskStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'Dibatalkan';
        break;
    }

    // Priority color
    late Color priorityColor;
    late String priorityText;

    switch (_task!.priority) {
      case TaskPriority.low:
        priorityColor = Colors.green;
        priorityText = 'Rendah';
        break;
      case TaskPriority.medium:
        priorityColor = Colors.orange;
        priorityText = 'Sedang';
        break;
      case TaskPriority.high:
        priorityColor = Colors.red;
        priorityText = 'Tinggi';
        break;
      case null:
        priorityColor = Colors.orange;
        priorityText = 'Sedang';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tugas'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? _buildEditForm()
              : _buildTaskDetails(statusColor, statusText, priorityColor, priorityText),
    );
  }

  Widget _buildTaskDetails(Color statusColor, String statusText, Color priorityColor, String priorityText) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Prioritas: $priorityText',
                              style: TextStyle(
                                color: priorityColor,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _task!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Deskripsi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _task!.description,
                      // Mengubah overflow menjadi visible dan menghapus maxLines
                      // agar teks dapat ditampilkan sepenuhnya
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tenggat: ${DateFormat('dd MMMM yyyy').format(_task!.dueDate)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Waktu Pelaksanaan: ${_task!.executionTime ?? "09:00"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.person, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Ditugaskan kepada: ${_task!.assignedTo ?? "Tidak Ada"}',
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Dibuat: ${DateFormat('dd MMMM yyyy').format(_task!.createdAt)}',
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                    if (_task!.updatedAt != _task!.createdAt) ...[                      
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.update, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Diupdate: ${DateFormat('dd MMMM yyyy').format(_task!.updatedAt)}',
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_task!.completedAt != null) ...[                      
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Diselesaikan: ${DateFormat('dd MMMM yyyy').format(_task!.completedAt!)}',
                              style: const TextStyle(color: Colors.green),
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ubah Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                if (_task!.status != TaskStatus.pending)
                  _buildStatusButton(
                    'Menunggu',
                    Colors.orange,
                    Icons.hourglass_empty,
                    () => _updateTaskStatus(TaskStatus.pending),
                  ),
                if (_task!.status != TaskStatus.inProgress)
                  _buildStatusButton(
                    'Dalam Proses',
                    Colors.blue,
                    Icons.play_circle,
                    () => _updateTaskStatus(TaskStatus.inProgress),
                  ),
                if (_task!.status != TaskStatus.completed)
                  _buildStatusButton(
                    'Selesai',
                    Colors.green,
                    Icons.check_circle,
                    () => _updateTaskStatus(TaskStatus.completed),
                  ),
                if (_task!.status != TaskStatus.cancelled)
                  _buildStatusButton(
                    'Batalkan',
                    Colors.red,
                    Icons.cancel,
                    () => _updateTaskStatus(TaskStatus.cancelled),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: () => _confirmStatusChange(label, color, onPressed),
      icon: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        label, 
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.visible,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  Future<void> _confirmStatusChange(String statusName, Color color, VoidCallback onChangeStatus) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah Status'),
        content: Text('Apakah Anda yakin ingin mengubah status tugas menjadi "$statusName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: color,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YA'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      onChangeStatus();
    }
  }

  Widget _buildEditForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Tugas',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul tugas tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Deskripsi tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tenggat Waktu',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(_dueDate),
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectTime(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Waktu Pelaksanaan',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _executionTime,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        const Icon(Icons.access_time),
                      ],
                    ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                decoration: const InputDecoration(
                  labelText: 'Prioritas',
                  border: OutlineInputBorder(),
                ),
                value: _priority,
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem<TaskPriority>(
                    value: priority,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getPriorityColor(priority),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            priority.name,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _priority = value ?? TaskPriority.medium;
                  });
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _titleController.text = _task!.title;
                          _descriptionController.text = _task!.description;
                          _dueDate = _task!.dueDate;
                          _executionTime = _task!.executionTime ?? '09:00';
                          _priority = _task!.priority ?? TaskPriority.medium;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateTask,
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }
}