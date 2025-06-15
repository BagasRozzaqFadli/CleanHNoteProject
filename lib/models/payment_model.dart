class PaymentModel {
  final String id;
  final String userId;
  final double amount;
  final String method;
  final String status; // pending, verified, rejected
  final String? proofImage;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime? verifiedAt;
  final int durationMonths; // Durasi langganan dalam bulan

  PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    this.proofImage,
    this.verifiedBy,
    required this.createdAt,
    this.verifiedAt,
    this.durationMonths = 1,
  });

  // Getter untuk format tanggal pembayaran yang lebih mudah dibaca
  String get paymentDate {
    return "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'method': method,
      'status': status,
      'proofImage': proofImage,
      'verifiedBy': verifiedBy,
      'createdAt': createdAt.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'durationMonths': durationMonths,
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] ?? map['\$id'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] is String) 
          ? double.tryParse(map['amount'] as String) ?? 0.0 
          : (map['amount']?.toDouble() ?? 0.0),
      method: map['method'] ?? '',
      status: map['payment_status'] ?? map['status'] ?? 'pending',
      proofImage: map['payment_proof'] ?? map['proofImage'],
      verifiedBy: map['verifiedBy'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'] as String) 
          : DateTime.now(),
      verifiedAt: map['verifiedAt'] != null
          ? DateTime.parse(map['verifiedAt'] as String)
          : null,
      durationMonths: map['durationMonths'] ?? 1,
    );
  }
} 