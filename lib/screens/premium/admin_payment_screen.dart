import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../services/premium_service.dart';
import '../../models/payment_model.dart';

class AdminPaymentScreen extends StatefulWidget {
  const AdminPaymentScreen({Key? key}) : super(key: key);

  @override
  State<AdminPaymentScreen> createState() => _AdminPaymentScreenState();
}

class _AdminPaymentScreenState extends State<AdminPaymentScreen> {
  bool _isLoading = true;
  bool _isActivating = false;
  List<PaymentModel> _pendingPayments = [];
  final TextEditingController _userIdController = TextEditingController();
  int _selectedMonths = 1; // Default 1 bulan

  final List<Map<String, dynamic>> _premiumPackages = [
    {'months': 1, 'price': 50000, 'name': '1 Bulan'},
    {'months': 6, 'price': 270000, 'name': '6 Bulan (Hemat 10%)'},
    {'months': 12, 'price': 480000, 'name': '12 Bulan (Hemat 20%)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPendingPayments();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final pendingPayments = await premiumService.getPendingPayments();
      
      setState(() {
        _pendingPayments = pendingPayments;
        _isLoading = false;
      });
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
  }

  Future<void> _verifyPayment(String paymentId) async {
    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final success = await premiumService.verifyPayment(paymentId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil diverifikasi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingPayments();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memverifikasi pembayaran'),
            backgroundColor: Colors.red,
          ),
        );
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

  Future<void> _activatePremiumDirectly() async {
    if (_userIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID harus diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isActivating = true;
    });

    final userId = _userIdController.text.trim();

    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final success = await premiumService.adminActivatePremium(userId, _selectedMonths);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status premium berhasil diaktifkan untuk $userId selama $_selectedMonths bulan'),
            backgroundColor: Colors.green,
          ),
        );
        _userIdController.clear();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengaktifkan status premium'),
            backgroundColor: Colors.red,
          ),
        );
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
          _isActivating = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Verifikasi Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDirectActivation(),
                  const SizedBox(height: 24),
                  _buildPendingPayments(),
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
    );
  }

  Widget _buildDirectActivation() {
    // Dapatkan informasi paket yang dipilih
    final selectedPackage = _premiumPackages.firstWhere(
      (package) => package['months'] == _selectedMonths,
      orElse: () => _premiumPackages[0],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aktivasi Premium Langsung',
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
            const Text(
              'Pilih Paket Premium:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedMonths,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMonths = newValue;
                      });
                    }
                  },
                  items: _premiumPackages.map<DropdownMenuItem<int>>((Map<String, dynamic> package) {
                    return DropdownMenuItem<int>(
                      value: package['months'],
                      child: Text('${package['name']} - Rp ${_formatPrice(package['price'])}'),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paket: ${selectedPackage['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Harga: Rp ${_formatPrice(selectedPackage['price'])}'),
                  const SizedBox(height: 4),
                  Text('Durasi: ${selectedPackage['months']} bulan'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isActivating ? null : _activatePremiumDirectly,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isActivating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Mengaktifkan...'),
                        ],
                      )
                    : const Text('Aktifkan Premium'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method untuk memformat harga
  String _formatPrice(num price) {
    final priceString = price.toStringAsFixed(0);
    final buffer = StringBuffer();
    
    for (int i = 0; i < priceString.length; i++) {
      if ((priceString.length - i) % 3 == 0 && i > 0) {
        buffer.write('.');
      }
      buffer.write(priceString[i]);
    }
    
    return buffer.toString();
  }

  Widget _buildPendingPayments() {
    if (_pendingPayments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Tidak ada pembayaran yang menunggu verifikasi',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pembayaran Menunggu Verifikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_pendingPayments.length, (index) {
          final payment = _pendingPayments[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'ID Pembayaran: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Text(payment.id)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyToClipboard(payment.id, 'ID Pembayaran'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'User ID: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(child: Text(payment.userId)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _copyToClipboard(payment.userId, 'User ID'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tanggal: ${payment.paymentDate}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jumlah: Rp ${payment.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Durasi: ${payment.durationMonths} bulan',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${payment.status}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _verifyPayment(payment.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Verifikasi Pembayaran'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
} 