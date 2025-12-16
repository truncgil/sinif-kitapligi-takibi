import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/borrow_record.dart';
import '../../models/book.dart';
import '../../services/database/database_service.dart';
import '../../constants/colors.dart';
import '../barcode_scanner/barcode_scanner_page.dart';
import '../borrow/borrow_screen.dart';
import '../book/book_detail_screen.dart';
import '../../widgets/common/toast_message.dart';
import '../../services/export/excel_export_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late DatabaseService _databaseService;
  late Future<List<BorrowRecord>> _borrowRecordsFuture;
  late Future<int> _totalBorrowCountFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _loadBorrowRecords();
  }

  void _loadBorrowRecords() {
    setState(() {
      _borrowRecordsFuture =
          _databaseService.getBorrowRecordsByStudent(widget.student.id!);
      _totalBorrowCountFuture =
          _databaseService.getTotalBorrowCountByStudent(widget.student.id!);
    });
  }

  Future<void> _exportStudentData() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final exportService = ExcelExportService(dbService);
      
      final studentName = '${widget.student.name} ${widget.student.surname}';
      await exportService.exportStudentData(widget.student.id!, studentName);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      _showSuccessMessage('Öğrenci verileri Excel dosyası olarak hazırlandı.');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showErrorMessage('Hata: $e');
    }
  }

  /// Barkod tarayıcıyı açar ve sonucu işler
  Future<void> _scanBarcodeAndBorrow() async {
    try {
      final barcode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerPage(),
        ),
      );

      if (barcode != null && barcode is String && barcode.isNotEmpty) {
        final book = await _databaseService.getBookByBarcode(barcode);

        if (book != null) {
          if (!book.isAvailable) {
            _showErrorMessage('Bu kitap şu anda mevcut değil');
            return;
          }

          // Ödünç verme ekranına git, kitap ve öğrenci seçili olarak
          if (!mounted) return;

          // Öğrenci bilgisini aktarıyoruz
          final student = widget.student;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BorrowScreen(
                initialBarcode: barcode,
                initialStudentNumber: student.studentNumber,
                // Öğrenciyi kimliğiyle birlikte geçiriyoruz
                initialStudentId: student.id,
                initialStep: BorrowScreen.CONFIRMATION,
              ),
            ),
          ).then((_) => _loadBorrowRecords());
        } else {
          if (!mounted) return;
          _showErrorMessage('Kitap bulunamadı');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('İşlem sırasında bir hata oluştu: $e');
    }
  }

  /// Kitap seçerek ödünç verme ekranına gider
  void _navigateToBorrowScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BorrowScreen(
          initialStudentNumber: widget.student.studentNumber,
          initialStep: BorrowScreen.BOOK_SELECTION,
        ),
      ),
    ).then((_) => _loadBorrowRecords());
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
        title: Text(
          '${widget.student.name} ${widget.student.surname}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _exportStudentData,
            icon: const Icon(Icons.file_download),
            tooltip: 'Excel\'e Aktar',
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Öğrenci Bilgileri',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Ad Soyad',
                      '${widget.student.name} ${widget.student.surname}'),
                  _buildInfoRow('Öğrenci No', widget.student.studentNumber),
                  _buildInfoRow('Sınıf', widget.student.className),
                  FutureBuilder<int>(
                    future: _totalBorrowCountFuture,
                    builder: (context, snapshot) {
                      return _buildInfoRow(
                        'Toplam Kitap',
                        snapshot.hasData ? '${snapshot.data}' : '-',
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanBarcodeAndBorrow,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Barkod Okutarak\nÖdünç Ver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToBorrowScreen,
                          icon: const Icon(Icons.book),
                          label: const Text('Kitap Seçerek\nÖdünç Ver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF04BF61),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<BorrowRecord>>(
              future: _borrowRecordsFuture,
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
                    child:
                        Text('Henüz kitap ödünç alma kaydı bulunmamaktadır.'),
                  );
                }

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return FutureBuilder<Book?>(
                      future: _databaseService.getBookById(record.bookId),
                      builder: (context, bookSnapshot) {
                        if (bookSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final book = bookSnapshot.data;
                        if (book == null) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BookDetailScreen(book: book),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.book),
                              ),
                              title: Text(book.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(book.author),
                                  Text(
                                    'Ödünç Alınma: ${_formatDate(record.borrowDate)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (record.returnDate != null)
                                    Text(
                                      'İade: ${_formatDate(record.returnDate!)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: record.isReturned
                                      ? Colors.green
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  record.isReturned
                                      ? 'İade Edildi'
                                      : 'Ödünç Alındı',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
