import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../services/barcode_scanner/barcode_scanner_service.dart';
import '../../providers/library_provider.dart';

/// Kitap ödünç verme ekranı
class BorrowScreen extends StatefulWidget {
  const BorrowScreen({super.key});

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  Student? selectedStudent;
  Book? selectedBook;
  final _barcodeScannerService = BarcodeScannerService();
  late DatabaseService _databaseService;
  late Future<List<Student>> _studentsFuture;
  late Future<List<Book>> _availableBooksFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _studentsFuture = _databaseService.getAllStudents();
      _availableBooksFuture = _databaseService.getAllBooks();
    });
  }

  Future<void> _scanBarcode() async {
    try {
      final barcode = await _barcodeScannerService.scanBarcode();
      if (barcode.isNotEmpty) {
        final book = await _databaseService.getBookByBarcode(barcode);
        if (book != null && book.isAvailable) {
          setState(() {
            selectedBook = book;
          });
        } else {
          if (!mounted) return;
          _showErrorMessage(
            book == null
                ? 'Kitap bulunamadı'
                : 'Bu kitap şu anda ödünç verilmiş durumda',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Barkod okuma işlemi başarısız oldu: $e');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _borrowBook() async {
    if (selectedStudent == null || selectedBook == null) {
      _showErrorMessage('Lütfen öğrenci ve kitap seçin');
      return;
    }

    try {
      final borrowRecord = BorrowRecord(
        studentId: selectedStudent!.id!,
        bookId: selectedBook!.id!,
        borrowDate: DateTime.now(),
      );

      await _databaseService.insertBorrowRecord(borrowRecord);
      await _databaseService.updateBookAvailability(selectedBook!.id!, false);

      // Önce navigasyonu yap, sonra provider'ı güncelle
      if (!mounted) return;
      Navigator.pop(context);

      // Provider'ı güncelle
      if (!mounted) return;
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      await provider.refreshBorrowedBooks();

      if (!mounted) return;
      _showSuccessMessage('Kitap başarıyla ödünç verildi');
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Kitap ödünç verme işlemi başarısız oldu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitap Ödünç Ver'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Öğrenci Seç',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Student>>(
                      future: _studentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        final students = snapshot.data ?? [];

                        if (students.isEmpty) {
                          return const Center(
                            child: Text('Henüz öğrenci kaydı bulunmamaktadır.'),
                          );
                        }

                        return DropdownButtonFormField<Student>(
                          value: selectedStudent,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Öğrenci seçin',
                          ),
                          items: students.map((student) {
                            return DropdownMenuItem(
                              value: student,
                              child: Text(
                                '${student.name} ${student.surname} (${student.className})',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedStudent = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kitap Seç',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _scanBarcode,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Barkod Okut'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Book>>(
                      future: _availableBooksFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        final books = snapshot.data
                                ?.where((book) => book.isAvailable)
                                .toList() ??
                            [];

                        if (books.isEmpty) {
                          return const Center(
                            child: Text(
                                'Ödünç verilebilecek kitap bulunmamaktadır.'),
                          );
                        }

                        return DropdownButtonFormField<Book>(
                          value: selectedBook,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Kitap seçin',
                          ),
                          items: books.map((book) {
                            return DropdownMenuItem(
                              value: book,
                              child: Text('${book.title} (${book.author})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBook = value;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: selectedStudent != null && selectedBook != null
                  ? _borrowBook
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Ödünç Ver',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
