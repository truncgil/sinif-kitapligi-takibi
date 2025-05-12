import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/student.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../constants/colors.dart';

/// Kitap detay ekranı
class BookDetailScreen extends StatelessWidget {
  final Book book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

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
      ),
      body: Column(
        children: [
          _BookHeader(book: book),
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
                  return Center(child: Text('Hata: {snapshot.error}'));
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
    );
  }

  /// Kitabın ödünç alınma geçmişini getirir
  Future<List<Map<String, dynamic>>> _getBorrowHistory(
      BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final records = await dbService.getBorrowRecordsByBook(book.id!);

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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
