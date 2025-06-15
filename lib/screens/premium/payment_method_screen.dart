import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/premium_service.dart';
import 'payment_confirmation_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final Map<String, dynamic> plan;

  const PaymentMethodScreen({
    Key? key,
    required this.plan,
  }) : super(key: key);

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String _selectedMethod = 'bank_transfer';

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'bank_transfer',
      'name': 'Transfer Bank',
      'icon': Icons.account_balance,
      'description': 'BCA, BRI, Mandiri, BNI',
    },
    {
      'id': 'e_wallet',
      'name': 'E-Wallet',
      'icon': Icons.account_balance_wallet,
      'description': 'GoPay, OVO, DANA, LinkAja',
    },
    {
      'id': 'qris',
      'name': 'QRIS',
      'icon': Icons.qr_code,
      'description': 'Scan untuk pembayaran instan',
    },
    {
      'id': 'virtual_account',
      'name': 'Virtual Account',
      'icon': Icons.credit_card,
      'description': 'BCA, BRI, Mandiri, BNI',
    },
    {
      'id': 'credit_card',
      'name': 'Kartu Kredit',
      'icon': Icons.payment,
      'description': 'Visa, Mastercard, JCB',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metode Pembayaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(),
                  const SizedBox(height: 24),
                  const Text(
                    'Pilih Metode Pembayaran',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodList(),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildOrderItem(
              'Paket',
              widget.plan['name'],
            ),
            const SizedBox(height: 8),
            _buildOrderItem(
              'Durasi',
              '${widget.plan['months']} bulan',
            ),
            const Divider(),
            _buildOrderItem(
              'Total',
              'Rp ${_formatPrice(widget.plan['price'])}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _paymentMethods.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        final isSelected = _selectedMethod == method['id'];

        return RadioListTile<String>(
          title: Row(
            children: [
              Icon(method['icon']),
              const SizedBox(width: 12),
              Text(
                method['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          subtitle: Text(method['description']),
          value: method['id'],
          groupValue: _selectedMethod,
          onChanged: (value) {
            setState(() {
              _selectedMethod = value!;
            });
          },
          activeColor: Theme.of(context).primaryColor,
          selected: isSelected,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Kembali'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Dapatkan metode pembayaran yang dipilih
                final selectedMethod = _paymentMethods.firstWhere(
                  (method) => method['id'] == _selectedMethod,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentConfirmationScreen(
                      plan: widget.plan,
                      paymentMethod: selectedMethod,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Lanjutkan'),
            ),
          ),
        ],
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