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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isPremium': isPremium,
      'premiumExpiryDate': premiumExpiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isAdmin': isAdmin,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing date: $e');
          return null;
        }
      }
      return null;
    }

    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Tanpa Nama',
      email: map['email'] ?? '',
      isPremium: map['isPremium'] ?? false,
      premiumExpiryDate: parseDateTime(map['premiumExpiryDate']),
      createdAt: parseDateTime(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      isAdmin: map['isAdmin'] ?? false,
    );
  }
} 