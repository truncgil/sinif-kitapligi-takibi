import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/borrow_record.dart';
import '../../models/student.dart';
import '../../models/book.dart';
import '../../services/database/database_service.dart';
import '../../constants/colors.dart';

/// Ödünç alma geçmişi ekranı
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DatabaseService _databaseService;
  late Future<List<BorrowRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshRecords();
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = _databaseService.getAllBorrowRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        title: const Text(
          'Geçmiş',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<BorrowRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return const Center(
              child: Text('Henüz ödünç alma kaydı bulunmamaktadır.'),
            );
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return FutureBuilder<Map<String, dynamic>>(
                future: _getRecordDetails(record),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }

                  final details = snapshot.data!;
                  final student = details['student'] as Student;
                  final book = details['book'] as Book;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: ListTile(
                      title: Text(book.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Öğrenci: ${student.name} ${student.surname}'),
                          Text(
                            'Veriliş Tarihi: ${_formatDate(record.borrowDate)}',
                          ),
                          if (record.returnDate != null)
                            Text(
                              'İade Tarihi: ${_formatDate(record.returnDate!)}',
                            ),
                        ],
                      ),
                      trailing: record.isReturned
                          ? const Chip(
                              label: Text('İade Edildi'),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white),
                            )
                          : TextButton(
                              onPressed: () async {
                                final updatedRecord = BorrowRecord(
                                  id: record.id,
                                  studentId: record.studentId,
                                  bookId: record.bookId,
                                  borrowDate: record.borrowDate,
                                  returnDate: DateTime.now(),
                                  isReturned: true,
                                );

                                await _databaseService
                                    .updateBorrowRecord(updatedRecord);
                                await _databaseService.updateBookAvailability(
                                    record.bookId, true);
                                _refreshRecords();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Kitap başarıyla iade edildi.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text('İade Et'),
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getRecordDetails(BorrowRecord record) async {
    final student = await _databaseService.getStudentById(record.studentId);
    final book = await _databaseService.getBookById(record.bookId);

    if (student == null || book == null) {
      throw Exception('Kayıt detayları bulunamadı');
    }

    return {
      'student': student,
      'book': book,
    };
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm').format(date);
  }
}
