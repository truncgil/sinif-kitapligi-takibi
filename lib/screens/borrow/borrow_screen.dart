import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../services/barcode_scanner/barcode_scanner_service.dart';

/// Kitap ödünç verme ekranı
class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  Student? selectedStudent;
  Book? selectedBook;
  final barcodeScannerService = BarcodeScannerService();
  late DatabaseService _databaseService;
  late Future<List<Student>> _studentsFuture;
  late Future<List<Book>> _booksFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _studentsFuture = _databaseService.getAllStudents();
      _booksFuture = _databaseService.getAllBooks();
      selectedStudent = null;
      selectedBook = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitap Ödünç Ver'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Öğrenci seçimi
            FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final students = snapshot.data ?? [];

                return DropdownButtonFormField<Student>(
                  decoration: const InputDecoration(
                    labelText: 'Öğrenci Seçin',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedStudent,
                  items: students.map((student) {
                    return DropdownMenuItem<Student>(
                      value: student,
                      child: Text('${student.name} ${student.surname}'),
                    );
                  }).toList(),
                  onChanged: (Student? value) {
                    setState(() {
                      selectedStudent = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16.0),
            // Kitap seçimi
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Book>>(
                    future: _booksFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      final availableBooks = (snapshot.data ?? [])
                          .where((book) => book.isAvailable)
                          .toList();

                      return DropdownButtonFormField<Book>(
                        decoration: const InputDecoration(
                          labelText: 'Kitap Seçin',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedBook,
                        items: availableBooks.map((book) {
                          return DropdownMenuItem<Book>(
                            value: book,
                            child: Text(book.title),
                          );
                        }).toList(),
                        onChanged: (Book? value) {
                          setState(() {
                            selectedBook = value;
                          });
                        },
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final barcode = await barcodeScannerService.scanBarcode();
                    if (barcode.isNotEmpty) {
                      final book =
                          await _databaseService.getBookByBarcode(barcode);
                      if (book != null && book.isAvailable) {
                        setState(() {
                          selectedBook = book;
                        });
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Kitap bulunamadı veya ödünç verilmiş.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: selectedStudent != null && selectedBook != null
                  ? () async {
                      final borrowRecord = BorrowRecord(
                        studentId: selectedStudent!.id!,
                        bookId: selectedBook!.id!,
                        borrowDate: DateTime.now(),
                      );

                      await _databaseService.insertBorrowRecord(borrowRecord);
                      await _databaseService.updateBookAvailability(
                          selectedBook!.id!, false);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kitap başarıyla ödünç verildi.'),
                        ),
                      );

                      _refreshData();
                    }
                  : null,
              child: const Text('Ödünç Ver'),
            ),
          ],
        ),
      ),
    );
  }
}
