import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/premium_service.dart';
import 'payment_status_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, dynamic> paymentMethod;

  const PaymentConfirmationScreen({
    Key? key,
    required this.plan,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  File? _proofImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  String? _paymentId;
  bool _isCreatingPayment = true;

  // Informasi rekening untuk transfer bank
  final Map<String, String> _bankAccounts = {
    'bank_transfer': 'Bank BCA: 1234567890 a.n. CleanHNote',
    'e_wallet': 'DANA/OVO/GoPay: 081234567890',
    'qris': 'Silakan scan kode QRIS di bawah ini',
    'virtual_account': 'VA akan dikirim melalui email',
    'credit_card': 'Anda akan diarahkan ke halaman pembayaran',
  };

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  Future<void> _createPayment() async {
    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final paymentId = await premiumService.createPayment(
        widget.plan['price'].toDouble(),
        widget.paymentMethod['id'],
      );
      
      if (mounted) {
        setState(() {
          _paymentId = paymentId;
          _isCreatingPayment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreatingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreatingPayment) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Konfirmasi Pembayaran'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mempersiapkan pembayaran...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konfirmasi Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPaymentInstructions(),
              const SizedBox(height: 24),
              if (widget.paymentMethod['id'] == 'qris') _buildQRCode(),
              if (widget.paymentMethod['id'] != 'credit_card') ...[
                const Text(
                  'Upload Bukti Pembayaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildImageUploader(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _uploadProofAndConfirm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isUploading
                            ? const CircularProgressIndicator()
                            : const Text(
                                'Konfirmasi Pembayaran',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _redirectToPaymentGateway,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Lanjutkan ke Pembayaran',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Instruksi Pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInstructionRow('Metode', widget.paymentMethod['name']),
          const SizedBox(height: 8),
          _buildInstructionRow(
            'Jumlah',
            'Rp ${_formatPrice(widget.plan['price'])}',
          ),
          const SizedBox(height: 8),
          _buildInstructionRow(
            'Rekening/Tujuan',
            _bankAccounts[widget.paymentMethod['id']]!,
          ),
          const SizedBox(height: 16),
          const Text(
            'Catatan:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '- Pembayaran akan diverifikasi dalam 1x24 jam',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          const Text(
            '- Pastikan nominal transfer sesuai dengan jumlah di atas',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildQRCode() {
    return Column(
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('QR Code Placeholder'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildImageUploader() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _proofImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _proofImage!,
                  fit: BoxFit.cover,
                ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text('Klik untuk upload bukti pembayaran'),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _proofImage = File(image.path);
      });
    }
  }

  Future<void> _uploadProofAndConfirm() async {
    if (_proofImage == null && widget.paymentMethod['id'] != 'credit_card') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan upload bukti pembayaran terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      
      bool success = false;
      
      if (_proofImage != null && _paymentId != null) {
        success = await premiumService.uploadPaymentProof(
          _paymentId!,
          _proofImage!.path,
        );
      }

      if (!mounted) return;

      if (success || widget.paymentMethod['id'] == 'credit_card') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentStatusScreen(
              paymentId: _paymentId!,
              amount: widget.plan['price'].toDouble(),
              months: widget.plan['months'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengupload bukti pembayaran'),
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
          _isUploading = false;
        });
      }
    }
  }

  void _redirectToPaymentGateway() {
    if (_paymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan, silakan coba lagi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Implementasi untuk redirect ke payment gateway
    // Untuk saat ini, kita langsung arahkan ke halaman status
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentStatusScreen(
          paymentId: _paymentId!,
          amount: widget.plan['price'].toDouble(),
          months: widget.plan['months'],
        ),
      ),
    );
  }
  
  String _formatPrice(num price) {
    String priceStr = price.toString();
    String result = '';
    int count = 0;

    for (int i = priceStr.length - 1; i >= 0; i--) {
      result = priceStr[i] + result;
      count++;
      if (count % 3 == 0 && i > 0) {
        result = '.$result';
      }
    }

    return result;
  }
} 