import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/borrow_record.dart';
import '../../models/book.dart';
import '../../services/database/database_service.dart';

class StudentDetailScreen extends StatelessWidget {
  final Student student;

  const StudentDetailScreen({Key? key, required this.student})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${student.name} ${student.surname}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getBorrowHistory(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final borrowHistory = snapshot.data ?? [];

          return ListView.builder(
            itemCount: borrowHistory.length,
            itemBuilder: (context, index) {
              final record = borrowHistory[index];
              final book = record['book'] as Book;
              final borrowRecord = record['borrowRecord'] as BorrowRecord;

              return ListTile(
                title: Text(book.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yazar: ${book.author}'),
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
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getBorrowHistory(
      BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final records = await dbService.getBorrowRecordsByStudent(student.id!);

    List<Map<String, dynamic>> history = [];
    for (var record in records) {
      final book = await dbService.getBookById(record.bookId);
      if (book != null) {
        history.add({
          'book': book,
          'borrowRecord': record,
        });
      }
    }

    return history;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
