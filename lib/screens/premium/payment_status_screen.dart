import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/premium_service.dart';
import '../../models/payment_model.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;
  final double amount;
  final int months;

  const PaymentStatusScreen({
    Key? key,
    required this.paymentId,
    required this.amount,
    required this.months,
  }) : super(key: key);

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  PaymentModel? _payment;
  bool _isLoading = true;
  Timer? _timer;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentStatus();
    // Poll for payment status updates every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadPaymentStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaymentStatus() async {
    if (_isUpgrading) return; // Jangan reload saat sedang proses upgrade

    setState(() {
      _isLoading = true;
    });

    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      final payments = await premiumService.getUserPayments();
      
      if (payments.isEmpty) {
        throw Exception('Tidak ada data pembayaran ditemukan');
      }
      
      final payment = payments.firstWhere(
        (p) => p.id == widget.paymentId,
        orElse: () => throw Exception('Pembayaran tidak ditemukan'),
      );

      setState(() {
        _payment = payment;
        _isLoading = false;
      });

      // If payment is verified, upgrade to premium
      if (_payment?.status == 'verified' && !_isUpgrading) {
        _upgradeToPremium();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _upgradeToPremium() async {
    setState(() {
      _isUpgrading = true;
    });
    
    try {
      final premiumService = Provider.of<PremiumService>(context, listen: false);
      await premiumService.upgradeToPremium(widget.months);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun Anda berhasil diupgrade ke Premium!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupgrade akun: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpgrading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildPaymentDetails(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _payment?.status ?? 'pending';
    
    IconData icon;
    Color color;
    String statusText;
    String message;
    
    switch (status) {
      case 'verified':
        icon = Icons.check_circle;
        color = Colors.green;
        statusText = 'Terverifikasi';
        message = 'Pembayaran Anda telah diverifikasi. Akun Anda telah diupgrade ke Premium!';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        statusText = 'Ditolak';
        message = 'Pembayaran Anda ditolak. Silakan hubungi customer service kami.';
        break;
      default:
        icon = Icons.access_time;
        color = Colors.orange;
        statusText = 'Menunggu Verifikasi';
        message = 'Pembayaran Anda sedang diverifikasi. Proses ini dapat memakan waktu hingga 1x24 jam.';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 64,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          if (_isUpgrading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Mengupgrade akun Anda...'),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('ID Pembayaran', widget.paymentId),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Jumlah',
            'Rp ${_formatPrice(widget.amount)}',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Metode',
            _payment?.method ?? '-',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Tanggal',
            _payment?.createdAt.toString().substring(0, 16) ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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

  Widget _buildActionButtons() {
    final status = _payment?.status ?? 'pending';
    
    return Column(
      children: [
        if (status == 'pending')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUpgrading ? null : _loadPaymentStatus,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Refresh Status',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isUpgrading ? null : () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  String _formatPrice(double price) {
    String priceStr = price.toStringAsFixed(0);
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