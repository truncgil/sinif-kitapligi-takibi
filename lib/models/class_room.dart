/// Sınıf modeli
class ClassRoom {
  final int? id;
  final String name;
  final String? description;

  ClassRoom({
    this.id,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory ClassRoom.fromMap(Map<String, dynamic> map) {
    return ClassRoom(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }
}
