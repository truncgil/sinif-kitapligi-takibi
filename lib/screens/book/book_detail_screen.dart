import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/student.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';

class BookDetailScreen extends StatelessWidget {
  final Book book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
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
              final student = record['student'] as Student;
              final borrowRecord = record['borrowRecord'] as BorrowRecord;

              return ListTile(
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
