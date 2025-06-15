import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/user_service.dart';
import '../../services/auth_services.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({Key? key}) : super(key: key);

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLoadingAdmins = false;
  List<Map<String, dynamic>> _adminList = [];
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
    _loadAdminList();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _checkSuperAdminStatus() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null && currentUser.email == 'admin@cleanhnote.com') {
        setState(() {
          _isSuperAdmin = true;
        });
      } else {
        // Jika bukan super admin, kembali ke halaman sebelumnya
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda tidak memiliki akses ke halaman ini'),
              backgroundColor: Colors.red,
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAdminList() async {
    setState(() {
      _isLoadingAdmins = true;
    });

    try {
      final admins = await _userService.getAdminList();
      setState(() {
        _adminList = admins;
        _isLoadingAdmins = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat daftar admin: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoadingAdmins = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label berhasil disalin ke clipboard'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _setAdminStatus(String userId, bool isAdmin) async {
    // Cek apakah pengguna adalah super admin
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya admin utama yang dapat mengubah status admin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan User ID terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      final success = await _userService.setAdminStatus(
        userId, 
        isAdmin,
        currentUserEmail: currentUser?.email,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAdmin ? 'Berhasil menjadikan admin' : 'Berhasil mencabut hak admin'),
              backgroundColor: Colors.green,
            ),
          );
          _userIdController.clear();
          _loadAdminList(); // Refresh daftar admin
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengubah status admin'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAdminList,
            tooltip: 'Refresh daftar admin',
          ),
        ],
      ),
      body: !_isSuperAdmin
          ? const Center(
              child: Text(
                'Anda tidak memiliki akses ke halaman ini.\nHalaman ini hanya untuk admin utama (admin@cleanhnote.com).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kelola Admin',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tambah/Hapus Admin',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _userIdController,
                                    decoration: const InputDecoration(
                                      labelText: 'User ID',
                                      border: OutlineInputBorder(),
                                      hintText: 'Masukkan ID pengguna',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.paste),
                                  tooltip: 'Paste dari clipboard',
                                  onPressed: () async {
                                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (data != null && data.text != null) {
                                      _userIdController.text = data.text!;
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : () => _setAdminStatus(_userIdController.text, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Jadikan Admin'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : () => _setAdminStatus(_userIdController.text, false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text('Cabut Hak Admin'),
                                  ),
                                ),
                              ],
                            ),
                            if (_isLoading)
                              const Padding(
                                padding: EdgeInsets.only(top: 16.0),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Daftar Admin',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_isLoadingAdmins)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_adminList.isEmpty && !_isLoadingAdmins)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text('Tidak ada admin yang ditemukan'),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _adminList.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final admin = _adminList[index];
                                  final bool isSuperAdmin = admin['email'] == 'admin@cleanhnote.com';
                                  
                                  return ListTile(
                                    title: Text(admin['name'] ?? 'Unknown'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(admin['email'] ?? 'No Email'),
                                        if (isSuperAdmin)
                                          const Text(
                                            'Super Admin',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        Row(
                                          children: [
                                            const Text(
                                              'ID: ',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                admin['id'] ?? '',
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.copy, size: 16),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Salin ID',
                                              onPressed: () => _copyToClipboard(admin['id'] ?? '', 'ID Admin'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: isSuperAdmin
                                        ? const Icon(Icons.shield, color: Colors.red)
                                        : IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Cabut hak admin',
                                            onPressed: () => _setAdminStatus(admin['id'] ?? '', false),
                                          ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Petunjuk',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('1. Masukkan ID pengguna yang ingin dijadikan admin'),
                            Text('2. Klik "Jadikan Admin" untuk memberikan hak akses admin'),
                            Text('3. Klik "Cabut Hak Admin" untuk menghapus hak akses admin'),
                            SizedBox(height: 8),
                            Text('Catatan: User ID dapat dilihat di database "users"'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Kembali ke Dashboard'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 