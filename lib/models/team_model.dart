class TeamModel {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final List<String> members;
  final int maxMembers;
  final DateTime createdAt;

  TeamModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
    this.maxMembers = 50,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'maxMembers': maxMembers,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TeamModel.fromMap(Map<String, dynamic> map) {
    return TeamModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      maxMembers: map['maxMembers']?.toInt() ?? 50,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
  
  factory TeamModel.empty() {
    return TeamModel(
      id: '',
      name: '',
      description: '',
      createdBy: '',
      members: [],
      maxMembers: 50,
      createdAt: DateTime.now(),
    );
  }
}