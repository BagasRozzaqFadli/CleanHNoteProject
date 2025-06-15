class DocumentationModel {
  final String id;
  final String userId;
  final String? teamId;
  final String beforeImage;
  final String afterImage;
  final String description;
  final DateTime createdAt;

  DocumentationModel({
    required this.id,
    required this.userId,
    this.teamId,
    required this.beforeImage,
    required this.afterImage,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'teamId': teamId,
      'beforeImage': beforeImage,
      'afterImage': afterImage,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DocumentationModel.fromMap(Map<String, dynamic> map) {
    return DocumentationModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      teamId: map['teamId'],
      beforeImage: map['beforeImage'] ?? '',
      afterImage: map['afterImage'] ?? '',
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
} 