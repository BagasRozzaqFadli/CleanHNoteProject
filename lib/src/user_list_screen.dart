import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final bool isPremium;
  final DateTime? premiumExpiryDate;
  final DateTime createdAt;
  final bool isAdmin;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.isPremium = false,
    this.premiumExpiryDate,
    required this.createdAt,
    this.isAdmin = false,
  });
}

class UserService {
  Future<List<UserModel>> getAllUsers() async {
    // Dummy implementation
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<bool> activatePremium(String userId, int months) async {
    // Dummy implementation
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat daftar pengguna: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
      return;
    }

    final query = _searchQuery.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.id.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID berhasil disalin'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pengguna'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari Pengguna',
                hintText: 'Masukkan nama, email, atau ID',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _filterUsers();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterUsers();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text('Tidak ada pengguna yang ditemukan'),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserListItem(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListItem(UserModel user) {
    final bool isPremium = user.isPremium;
    final bool isExpired = user.isPremium && user.premiumExpiryDate != null && 
                          user.premiumExpiryDate!.isBefore(DateTime.now());
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPremium ? (isExpired ? Colors.orange : Colors.green) : Colors.grey,
          child: Icon(
            isPremium ? Icons.star : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
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
                    user.id,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyToClipboard(user.id),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPremium
                    ? (isExpired ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2))
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPremium
                    ? (isExpired ? 'Premium (Expired)' : 'Premium')
                    : 'Free',
                style: TextStyle(
                  fontSize: 12,
                  color: isPremium
                      ? (isExpired ? Colors.orange : Colors.green)
                      : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {
            _showUserOptions(user);
          },
        ),
      ),
    );
  }

  void _showUserOptions(UserModel user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Detail Pengguna'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserDetails(user);
                },
              ),
              if (!user.isPremium)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text('Aktifkan Premium'),
                  onTap: () {
                    Navigator.pop(context);
                    _activatePremium(user);
                  },
                ),
              if (user.isPremium)
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Perpanjang Premium'),
                  onTap: () {
                    Navigator.pop(context);
                    _activatePremium(user);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Detail Pengguna'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Nama', user.name),
              _buildDetailRow('Email', user.email),
              _buildDetailRow('ID', user.id),
              _buildDetailRow('Status', user.isPremium ? 'Premium' : 'Free'),
              if (user.isPremium && user.premiumExpiryDate != null)
                _buildDetailRow(
                  'Tanggal Berakhir',
                  '${user.premiumExpiryDate!.day}/${user.premiumExpiryDate!.month}/${user.premiumExpiryDate!.year}',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _activatePremium(UserModel user) {
    int selectedMonths = 1;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${user.isPremium ? 'Perpanjang' : 'Aktifkan'} Premium'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pengguna: ${user.name}'),
                  const SizedBox(height: 16),
                  const Text('Pilih Durasi:'),
                  DropdownButton<int>(
                    value: selectedMonths,
                    onChanged: (value) {
                      setState(() {
                        selectedMonths = value!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 1,
                        child: Text('1 Bulan - Rp 50.000'),
                      ),
                      DropdownMenuItem(
                        value: 6,
                        child: Text('6 Bulan - Rp 270.000 (Hemat 10%)'),
                      ),
                      DropdownMenuItem(
                        value: 12,
                        child: Text('12 Bulan - Rp 480.000 (Hemat 20%)'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });
                    
                    try {
                      final success = await _userService.activatePremium(user.id, selectedMonths);
                      
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Premium berhasil diaktifkan untuk ${user.name}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadUsers(); // Refresh daftar
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gagal mengaktifkan premium'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
                  child: const Text('Aktifkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
} 