import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../providers/library_provider.dart';
import '../barcode_scanner/barcode_scanner_page.dart';
import '../../constants/colors.dart';

/// Kitap ödünç verme ekranı
class BorrowScreen extends StatefulWidget {
  final String? initialBarcode;

  const BorrowScreen({
    super.key,
    this.initialBarcode,
  });

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  Student? selectedStudent;
  Book? selectedBook;
  late DatabaseService _databaseService;
  late Future<List<Student>> _studentsFuture;
  late Future<List<Book>> _availableBooksFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshData();

    // Eğer başlangıç barkodu varsa, o kitabı seç
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _loadBookByBarcode(widget.initialBarcode!);
    }
  }

  void _refreshData() {
    setState(() {
      _studentsFuture = _databaseService.getAllStudents();
      _availableBooksFuture = _databaseService.getAllBooks().then((books) {
        final availableBooks = books.where((book) => book.isAvailable).toList();
        if (selectedBook != null &&
            !availableBooks.any((b) => b.id == selectedBook!.id)) {
          availableBooks.add(selectedBook!);
        }
        return availableBooks;
      });
    });
  }

  Future<void> _loadBookByBarcode(String barcode) async {
    try {
      final book = await _databaseService.getBookByBarcode(barcode);
      if (book != null) {
        setState(() {
          selectedBook = book;
        });

        // Kitap listesini güncelle
        _availableBooksFuture = _databaseService.getAllBooks().then((books) {
          final availableBooks =
              books.where((book) => book.isAvailable).toList();
          if (!availableBooks.any((b) => b.barcode == selectedBook!.barcode)) {
            availableBooks.add(selectedBook!);
          }
          return availableBooks;
        });
      } else {
        if (!mounted) return;
        _showErrorMessage('Kitap bulunamadı');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Kitap yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerPage(),
        ),
      );

      if (result != null && result is String) {
        await _loadBookByBarcode(result);
      }

      // Barkod tarayıcıdan döndükten sonra verileri yeniliyoruz
      _refreshData();
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
        backgroundColor: const Color(0xFF04BF61),
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
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        title: const Text(
          'Kitap Ödünç Ver',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Color(0xFF04BF61),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Öğrenci Seç',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Student>>(
                      future: _studentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF04BF61),
                            ),
                          ));
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

                        // Seçilen öğrenci listede yoksa, null yap
                        if (selectedStudent != null) {
                          bool studentInList = false;
                          for (var student in students) {
                            if (student.id == selectedStudent!.id) {
                              studentInList = true;
                              break;
                            }
                          }

                          if (!studentInList) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                selectedStudent = null;
                              });
                            });
                          }
                        }

                        return DropdownButtonFormField<Student>(
                          value: selectedStudent,
                          decoration: const InputDecoration(
                            labelText: 'Öğrenci Seçin',
                            border: OutlineInputBorder(),
                          ),
                          items: students.map((student) {
                            return DropdownMenuItem<Student>(
                              value: student,
                              child: Text(
                                  '${student.name} ${student.surname} - ${student.className}'),
                            );
                          }).toList(),
                          onChanged: (Student? value) {
                            setState(() {
                              selectedStudent = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Lütfen bir öğrenci seçin' : null,
                          isExpanded: true,
                          selectedItemBuilder: (BuildContext context) {
                            return students.map<Widget>((Student student) {
                              return Text(
                                '${student.name} ${student.surname} - ${student.className}',
                                style: const TextStyle(
                                  color: Color(0xFF04BF61),
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.book,
                                color: Color(0xFF04BF61),
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Kitap Seç',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _scanBarcode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF04BF61),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                          label: const Text('Barkod Okut',
                              style: TextStyle(fontSize: 14)),
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
                              child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF04BF61),
                            ),
                          ));
                        }

                        if (snapshot.hasError) {
                          return Center(child: Text('Hata: ${snapshot.error}'));
                        }

                        final books = snapshot.data ?? [];

                        if (books.isEmpty) {
                          return const Center(
                            child: Text('Mevcut kitap bulunmamaktadır.'),
                          );
                        }

                        return DropdownButtonFormField<Book>(
                          value: selectedBook,
                          decoration: const InputDecoration(
                            labelText: 'Kitap Seçin',
                            border: OutlineInputBorder(),
                          ),
                          items: books.map((book) {
                            return DropdownMenuItem<Book>(
                              value: book,
                              child: Text('${book.title} - ${book.author}'),
                            );
                          }).toList(),
                          onChanged: (Book? value) {
                            setState(() {
                              selectedBook = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Lütfen bir kitap seçin' : null,
                          isExpanded: true,
                          selectedItemBuilder: (BuildContext context) {
                            return books.map<Widget>((Book book) {
                              return Text(
                                '${book.title} - ${book.author}',
                                style: const TextStyle(
                                  color: Color(0xFF04BF61),
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
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
                backgroundColor: const Color(0xFF04BF61),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.done,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ödünç Ver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
