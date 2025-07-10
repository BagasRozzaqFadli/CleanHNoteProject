import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumUpgradeDialog extends StatefulWidget {
  final String? selectedPeriod;
  
  const PremiumUpgradeDialog({
    Key? key,
    this.selectedPeriod,
  }) : super(key: key);

  @override
  State<PremiumUpgradeDialog> createState() => _PremiumUpgradeDialogState();
}

class _PremiumUpgradeDialogState extends State<PremiumUpgradeDialog> {
  String? _selectedPeriod;
  String? _selectedPaymentMethod;
  final List<String> _paymentMethods = ['Online Payment', 'Hubungi Admin'];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.selectedPeriod;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Text('Upgrade ke Premium'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dapatkan akses ke semua fitur premium:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildFeatureItem(Icons.people, 'Manajemen tim dan kolaborasi'),
            _buildFeatureItem(Icons.assignment_turned_in, 'Penugasan tugas ke anggota tim'),
            _buildFeatureItem(Icons.photo_library, 'Upload foto dan lampiran'),
            _buildFeatureItem(Icons.bar_chart, 'Laporan dan analitik lengkap'),
            _buildFeatureItem(Icons.notifications_active, 'Notifikasi lanjutan'),
            SizedBox(height: 16),
            Text(
              'Pilih Paket Premium:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildPricingItem('1 Bulan', 'Rp 50.000', 
              isSelected: _selectedPeriod == '1 Bulan', 
              isBestValue: false,
              onTap: () => setState(() => _selectedPeriod = '1 Bulan')),
            _buildPricingItem('3 Bulan', 'Rp 135.000', 
              isSelected: _selectedPeriod == '3 Bulan', 
              isBestValue: true,
              onTap: () => setState(() => _selectedPeriod = '3 Bulan')),
            _buildPricingItem('12 Bulan', 'Rp 480.000', 
              isSelected: _selectedPeriod == '12 Bulan', 
              isBestValue: false,
              onTap: () => setState(() => _selectedPeriod = '12 Bulan')),
            SizedBox(height: 16),
            Text(
              'Pilih Metode Pembayaran:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildPaymentMethodSelector(),
            SizedBox(height: 16),
            if (_selectedPaymentMethod == 'Hubungi Admin') ...[
              Text(
                'Kontak Admin:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () => _launchEmail('admin@cleanhnote.com'),
                child: Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'admin@cleanhnote.com',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4),
              InkWell(
                onTap: () => _launchPhone('+6281234567890'),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '+62 812 3456 7890',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedPaymentMethod == 'Online Payment') ...[
              Text(
                'Pilih Metode Pembayaran Online:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              _buildOnlinePaymentOptions(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Tutup'),
        ),
        if (_selectedPeriod != null && _selectedPaymentMethod != null)
          ElevatedButton(
            onPressed: () => _handlePaymentAction(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: Text(_selectedPaymentMethod == 'Online Payment' ? 'Lanjutkan Pembayaran' : 'Hubungi Admin'),
          ),
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      children: _paymentMethods.map((method) => 
        RadioListTile<String>(
          title: Text(method),
          value: method,
          groupValue: _selectedPaymentMethod,
          activeColor: Colors.amber,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value;
            });
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ).toList(),
    );
  }

  Widget _buildOnlinePaymentOptions() {
    return Column(
      children: [
        _buildPaymentOption('QRIS', 'assets/images/qris.png'),
        _buildPaymentOption('Bank Transfer', 'assets/images/bank.png'),
        _buildPaymentOption('E-Wallet', 'assets/images/ewallet.png'),
      ],
    );
  }

  Widget _buildPaymentOption(String name, String iconPath) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            name == 'QRIS' ? Icons.qr_code : 
            name == 'Bank Transfer' ? Icons.account_balance : 
            Icons.account_balance_wallet,
          ),
        ),
      ),
      title: Text(name),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: () {
        Navigator.pop(context);
        _showPaymentConfirmation(name);
      },
    );
  }

  void _showPaymentConfirmation(String paymentMethod) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda akan melakukan pembayaran dengan:'),
            SizedBox(height: 8),
            Text('• Paket: $_selectedPeriod', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Metode: $paymentMethod', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Total pembayaran: ${_getPriceForPeriod(_selectedPeriod)}'),
            SizedBox(height: 8),
            Text('Silakan lanjutkan ke halaman pembayaran untuk menyelesaikan transaksi.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPaymentSuccessDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Pembayaran Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Terima kasih telah berlangganan CleanHNote Premium!'),
            SizedBox(height: 8),
            Text('Akun Anda telah diupgrade ke Premium untuk $_selectedPeriod.'),
            SizedBox(height: 16),
            Text('Nikmati semua fitur premium yang tersedia.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handlePaymentAction() {
    if (_selectedPaymentMethod == 'Online Payment') {
      Navigator.pop(context);
      _showPaymentMethodSelection();
    } else {
      _launchEmail('admin@cleanhnote.com', 
          subject: 'Berlangganan Premium CleanHNote${_selectedPeriod != null ? ' - Paket $_selectedPeriod' : ''}');
    }
  }

  void _showPaymentMethodSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Metode Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPaymentOption('QRIS', 'assets/images/qris.png'),
            _buildPaymentOption('Bank Transfer', 'assets/images/bank.png'),
            _buildPaymentOption('E-Wallet', 'assets/images/ewallet.png'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
        ],
      ),
    );
  }

  String _getPriceForPeriod(String? period) {
    switch (period) {
      case '1 Bulan':
        return 'Rp 50.000';
      case '3 Bulan':
        return 'Rp 135.000';
      case '12 Bulan':
        return 'Rp 480.000';
      default:
        return 'Rp 0';
    }
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildPricingItem(String period, String price, {
    bool isBestValue = false, 
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.amber.withOpacity(0.3) 
              : (isBestValue ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Colors.amber, width: 2)
              : (isBestValue ? Border.all(color: Colors.amber) : null),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.amber, size: 18),
                    if (isSelected)
                      SizedBox(width: 8),
                    Text(period, style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: (isSelected || isBestValue) ? Colors.amber.shade800 : null,
                      ),
                    ),
                    if (isBestValue) ...[
                  SizedBox(width: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'BEST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: subject != null ? 'subject=${Uri.encodeComponent(subject)}' : null,
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );
    
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}