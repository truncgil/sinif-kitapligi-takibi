/// Öğrenci bilgilerini tutan model sınıfı
class Student {
  final int? id;
  final String name;
  final String surname;
  final String studentNumber;
  final String className;

  Student({
    this.id,
    required this.name,
    required this.surname,
    required this.studentNumber,
    required this.className,
  });

  /// Öğrenci bilgilerini Map formatına dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'studentNumber': studentNumber,
      'className': className,
    };
  }

  /// Map formatındaki veriden Öğrenci nesnesi oluşturur
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      surname: map['surname'] as String,
      studentNumber: map['studentNumber'] as String,
      className: map['className'] as String,
    );
  }
}
