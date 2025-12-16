import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/student.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../constants/colors.dart';
import '../borrow/borrow_screen.dart';

import '../../services/export/excel_export_service.dart';
import '../../widgets/common/toast_message.dart';

/// Kitap detay ekranı
class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late DatabaseService _databaseService;
  late Book _book;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _book = widget.book;
  }

  Future<void> _exportBookData() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final exportService = ExcelExportService(dbService);
      
      await exportService.exportBookData(widget.book.id!, widget.book.title);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      _showSuccessMessage('Kitap verileri Excel dosyası olarak hazırlandı.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorMessage('Hata: $e');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    showToastMessage(context, message: message, isSuccess: false);
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showToastMessage(context, message: message, isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        title: const Text(
          'Kitap Detayları',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _exportBookData,
            icon: const Icon(Icons.file_download),
            tooltip: 'Excel\'e Aktar',
          ),
        ],
      ),
      body: Column(
        children: [
          _BookHeader(book: _book),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bu kitabı okuyan öğrenciler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getBorrowHistory(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Hata: {snapshot.error}'));
                }

                final borrowHistory = snapshot.data ?? [];

                if (borrowHistory.isEmpty) {
                  return const Center(
                    child: Text('Bu kitabı henüz kimse ödünç almamış.'),
                  );
                }

                return ListView.builder(
                  itemCount: borrowHistory.length,
                  itemBuilder: (context, index) {
                    final record = borrowHistory[index];
                    final student = record['student'] as Student;
                    final borrowRecord = record['borrowRecord'] as BorrowRecord;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text('${student.name} ${student.surname}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sınıf: ${student.className}'),
                            Text(
                                'Alınma Tarihi: ${_formatDate(borrowRecord.borrowDate)}'),
                            if (borrowRecord.returnDate != null)
                              Text(
                                  'İade Tarihi: ${_formatDate(borrowRecord.returnDate!)}'),
                          ],
                        ),
                        trailing: borrowRecord.isReturned
                            ? const Chip(label: Text('İade Edildi'))
                            : const Chip(
                                label: Text('İade Edilmedi'),
                                backgroundColor: Colors.red,
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book.isAvailable ? _borrowBook : _returnBook,
        backgroundColor: _book.isAvailable ? AppColors.primary : Colors.orange,
        label: Text(
          _book.isAvailable ? 'Ödünç Ver' : 'İade Et',
          style: const TextStyle(color: Colors.white),
        ),
        icon: Icon(
          _book.isAvailable ? Icons.bookmark_add : Icons.bookmark_remove,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Kitabın ödünç alınma geçmişini getirir
  Future<List<Map<String, dynamic>>> _getBorrowHistory(
      BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final records = await dbService.getBorrowRecordsByBook(_book.id!);

    List<Map<String, dynamic>> history = [];
    for (var record in records) {
      final student = await dbService.getStudentById(record.studentId);
      if (student != null) {
        history.add({
          'student': student,
          'borrowRecord': record,
        });
      }
    }

    return history;
  }

  /// Tarihi Türkçe formatta döndürür
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  /// Kitap ödünç verme işlemi
  Future<void> _borrowBook() async {
    // Öğrenci seçim ekranına değil, doğrudan BorrowScreen'e yönlendir
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BorrowScreen(initialBarcode: _book.barcode),
      ),
    ).then((_) {
      // Ekrana geri dönüldüğünde kitap durumunu güncellemek için kitabı tekrar yükle
      _refreshBookStatus();
    });
  }

  /// Kitap durumunu veritabanından tekrar yükler
  Future<void> _refreshBookStatus() async {
    try {
      final updatedBook = await _databaseService.getBookById(_book.id!);
      if (updatedBook != null && mounted) {
        setState(() {
          _book = updatedBook;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Kitap durumu güncellenirken hata oluştu: $e');
    }
  }

  /// Kitap iade işlemi
  Future<void> _returnBook() async {
    try {
      // Aktif ödünç kaydını bul
      final borrowRecord =
          await _databaseService.getActiveBorrowRecordByBookId(_book.id!);

      if (borrowRecord == null) {
        _showErrorMessage('Kitap ödünç kaydı bulunamadı');
        return;
      }

      // Öğrenci bilgilerini getir
      final student =
          await _databaseService.getStudentById(borrowRecord.studentId);
      final studentName = student != null
          ? '${student.name} ${student.surname}'
          : 'Bilinmeyen öğrenci';

      // Onay diyaloğu göster
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Kitap İadesi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kitap: ${_book.title}'),
                const SizedBox(height: 8),
                Text('Bu kitap $studentName tarafından ödünç alınmış.'),
                const SizedBox(height: 16),
                const Text('Kitabı iade etmek istiyor musunuz?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
                child: const Text('İade Et'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;

      // İade işlemini gerçekleştir
      await _databaseService.updateBorrowRecordAsReturned(borrowRecord.id!);
      await _databaseService.updateBookAvailability(_book.id!, true);

      // Book nesnesini güncelle
      setState(() {
        _book = _book.copyWith(isAvailable: true);
      });

      // Bildirim göster
      if (!mounted) return;
      _showSuccessMessage('Kitap başarıyla iade edildi');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('İşlem sırasında bir hata oluştu: $e');
    }
  }
}

/// Kitap detayları için üstte gösterilecek modern header widget'ı
class _BookHeader extends StatelessWidget {
  final Book book;
  const _BookHeader({required this.book});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(Icons.book, size: 40, color: colorScheme.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yazar: ${book.author}',
                  style: TextStyle(
                      fontSize: 16, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'ISBN: ${book.isbn}',
                  style: TextStyle(
                      fontSize: 15, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Barkod: ${book.barcode}',
                  style: TextStyle(
                      fontSize: 15, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      book.isAvailable ? Icons.check_circle : Icons.cancel,
                      color: book.isAvailable
                          ? colorScheme.primary
                          : colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      book.isAvailable ? 'Mevcut' : 'Ödünç Verildi',
                      style: TextStyle(
                        color: book.isAvailable
                            ? colorScheme.primary
                            : colorScheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
