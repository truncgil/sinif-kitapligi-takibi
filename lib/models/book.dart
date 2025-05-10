/// Kitap bilgilerini tutan model sınıfı
class Book {
  final int? id;
  final String title;
  final String author;
  final String isbn;
  final String barcode;
  final bool isAvailable;

  Book({
    this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.barcode,
    this.isAvailable = true,
  });

  /// Kitap bilgilerini Map formatına dönüştürür
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'barcode': barcode,
      'isAvailable': isAvailable ? 1 : 0,
    };
  }

  /// Map formatındaki veriden Kitap nesnesi oluşturur
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String,
      isbn: map['isbn'] as String,
      barcode: map['barcode'] as String,
      isAvailable: (map['isAvailable'] as int) == 1,
    );
  }
}
