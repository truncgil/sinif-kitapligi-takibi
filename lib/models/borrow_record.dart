/// Ödünç alma kayıtlarını tutan model sınıfı
class BorrowRecord {
  final int? id;
  final int studentId;
  final int bookId;
  final DateTime borrowDate;
  final DateTime? returnDate;
  final bool isReturned;

  BorrowRecord({
    this.id,
    required this.studentId,
    required this.bookId,
    required this.borrowDate,
    this.returnDate,
    this.isReturned = false,
  });

  /// Ödünç alma kaydını Map formatına dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'bookId': bookId,
      'borrowDate': borrowDate.toIso8601String(),
      'returnDate': returnDate?.toIso8601String(),
      'isReturned': isReturned ? 1 : 0,
    };
  }

  /// Map formatındaki veriden Ödünç alma kaydı nesnesi oluşturur
  factory BorrowRecord.fromMap(Map<String, dynamic> map) {
    return BorrowRecord(
      id: map['id'] as int?,
      studentId: map['studentId'] as int,
      bookId: map['bookId'] as int,
      borrowDate: DateTime.parse(map['borrowDate'] as String),
      returnDate: map['returnDate'] != null
          ? DateTime.parse(map['returnDate'] as String)
          : null,
      isReturned: (map['isReturned'] as int) == 1,
    );
  }
}
