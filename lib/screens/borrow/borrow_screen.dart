import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../services/database/database_service.dart';
import '../../providers/library_provider.dart';
import '../barcode_scanner/barcode_scanner_page.dart';
import '../../constants/colors.dart';

/// Kitap ödünç verme ekranı - Wizard tarzı arayüz
class BorrowScreen extends StatefulWidget {
  // Wizard adımları - static erişim için
  static const int BOOK_SELECTION = 0;
  static const int STUDENT_SELECTION = 1;
  static const int CONFIRMATION = 2;

  final String? initialBarcode;
  final String? initialStudentNumber;
  final int? initialStudentId;
  final int? initialStep;

  const BorrowScreen({
    super.key,
    this.initialBarcode,
    this.initialStudentNumber,
    this.initialStudentId,
    this.initialStep,
  });

  @override
  State<BorrowScreen> createState() => _BorrowScreenState();
}

class _BorrowScreenState extends State<BorrowScreen> {
  // Wizard adımları
  static const int BOOK_SELECTION = 0;
  static const int STUDENT_SELECTION = 1;
  static const int CONFIRMATION = 2;

  late int _currentStep;

  Student? selectedStudent;
  Book? selectedBook;
  late DatabaseService _databaseService;
  late Future<List<Student>> _studentsFuture;
  late Future<List<Book>> _availableBooksFuture;
  bool _isProcessing = false;

  // Arama filtreleri için
  String _studentSearchQuery = '';
  String _bookSearchQuery = '';

  // Filtrelenmiş listeleri tutan değişkenler
  List<Student> _filteredStudents = [];
  List<Book> _filteredBooks = [];

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshData();

    // Varsayılan adımı ayarla
    _currentStep = widget.initialStep ?? BOOK_SELECTION;

    // Eğer başlangıç barkodu varsa, o kitabı seç
    if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
      _loadBookByBarcode(widget.initialBarcode!);
    }

    // Eğer başlangıç öğrenci ID'si varsa, o öğrenciyi doğrudan seç
    if (widget.initialStudentId != null) {
      _loadStudentById(widget.initialStudentId!);
    }
    // Eğer ID yoksa ama öğrenci numarası varsa, numaraya göre yükle
    else if (widget.initialStudentNumber != null &&
        widget.initialStudentNumber!.isNotEmpty) {
      _loadStudentByNumber(widget.initialStudentNumber!);
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
        // Filtrelenmiş kitap listesini başlat
        _filteredBooks = availableBooks;
        return availableBooks;
      });

      // Filtrelenmiş öğrenci listesini başlat
      _studentsFuture.then((students) {
        _filteredStudents = students;
      });
    });
  }

  // Sonraki adıma geç
  void _nextStep() {
    if (_currentStep < CONFIRMATION) {
      setState(() {
        _currentStep++;
      });
    } else {
      _borrowBook();
    }
  }

  // Önceki adıma dön
  void _previousStep() {
    if (_currentStep > BOOK_SELECTION) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  // Mevcut adımı kontrol edip ilerleyip ilerleyemeyeceğini belirle
  bool _canProceed() {
    switch (_currentStep) {
      case BOOK_SELECTION:
        return selectedBook != null;
      case STUDENT_SELECTION:
        return selectedStudent != null;
      case CONFIRMATION:
        return !_isProcessing;
      default:
        return false;
    }
  }

  Future<void> _loadBookByBarcode(String barcode) async {
    try {
      final book = await _databaseService.getBookByBarcode(barcode);
      if (book != null) {
        if (!book.isAvailable) {
          _showErrorMessage('Bu kitap şu anda mevcut değil');
          return;
        }

        setState(() {
          selectedBook = book;
        });

        // Eğer öğrenci zaten seçiliyse, direkt olarak onay adımına geç
        if (selectedStudent != null) {
          setState(() {
            _currentStep = CONFIRMATION;
          });
        } else if (_currentStep == BOOK_SELECTION) {
          // Kitap seçimi yapıldıktan sonra öğrenci seçimine geç
          setState(() {
            _currentStep = STUDENT_SELECTION;
          });
        }
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

      if (result != null && result is String && result.isNotEmpty) {
        await _loadBookByBarcode(result);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Barkod okuma işlemi başarısız oldu: $e');
    }
  }

  Future<void> _loadStudentByNumber(String studentNumber) async {
    try {
      final students = await _databaseService.getAllStudents();
      final student = students.firstWhere(
        (s) => s.studentNumber == studentNumber,
        orElse: () => throw Exception('Öğrenci bulunamadı'),
      );

      setState(() {
        selectedStudent = student;
      });

      // Öğrenci detay ekranından gelen yönlendirmede, kitap seçimine geç
      if (_currentStep == STUDENT_SELECTION &&
          widget.initialStep == BOOK_SELECTION) {
        setState(() {
          _currentStep = BOOK_SELECTION;
        });
      }
      // Eğer kitap da seçilmişse, doğrudan onay adımına geç
      else if (selectedBook != null) {
        setState(() {
          _currentStep = CONFIRMATION;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Öğrenci yüklenirken hata oluştu: $e');
    }
  }

  // Öğrenciyi ID'ye göre yükle
  Future<void> _loadStudentById(int studentId) async {
    try {
      final students = await _databaseService.getAllStudents();
      final student = students.firstWhere(
        (s) => s.id == studentId,
        orElse: () => throw Exception('Öğrenci bulunamadı (ID: $studentId)'),
      );

      setState(() {
        selectedStudent = student;
      });

      // Eğer kitap da seçiliyse, doğrudan onay adımına geç
      if (selectedBook != null) {
        setState(() {
          _currentStep = CONFIRMATION;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Öğrenci yüklenirken hata oluştu: $e');
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

    setState(() {
      _isProcessing = true;
    });

    try {
      final borrowRecord = BorrowRecord(
        studentId: selectedStudent!.id!,
        bookId: selectedBook!.id!,
        borrowDate: DateTime.now(),
      );

      await _databaseService.insertBorrowRecord(borrowRecord);
      await _databaseService.updateBookAvailability(selectedBook!.id!, false);

      // Provider'ı güncelle
      if (!mounted) return;
      final provider = Provider.of<LibraryProvider>(context, listen: false);
      await provider.refreshBorrowedBooks();

      if (!mounted) return;
      _showSuccessMessage('Kitap başarıyla ödünç verildi');

      // Sayfayı kapat
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showErrorMessage('Kitap ödünç verme işlemi başarısız oldu: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Kitap seçim sayfası
  Widget _buildBookSelectionStep() {
    return FutureBuilder<List<Book>>(
      future: _availableBooksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF04BF61),
              ),
            ),
          );
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Kitap Seçimi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _scanBarcode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF04BF61),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Barkod Okut',
                        style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Kitap ara...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _filterBooks,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = _filteredBooks[index];
                  final bool isSelected = selectedBook?.id == book.id;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF04BF61)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedBook = book;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.book,
                                color: isSelected
                                    ? const Color(0xFF04BF61)
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isSelected
                                          ? const Color(0xFF04BF61)
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    book.author,
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF04BF61)
                                          : Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (book.barcode.isNotEmpty)
                                    Text(
                                      'Barkod: ${book.barcode}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? const Color(0xFF04BF61)
                                            : Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF04BF61),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Öğrenci seçim sayfası
  Widget _buildStudentSelectionStep() {
    return FutureBuilder<List<Student>>(
      future: _studentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF04BF61),
              ),
            ),
          );
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Öğrenci Seçimi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Öğrenci ara...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _filterStudents,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = _filteredStudents[index];
                  final bool isSelected = selectedStudent?.id == student.id;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF04BF61)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedStudent = student;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person,
                                color: isSelected
                                    ? const Color(0xFF04BF61)
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${student.name} ${student.surname}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isSelected
                                          ? const Color(0xFF04BF61)
                                          : Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Sınıf: ${student.className}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF04BF61)
                                          : Colors.grey.shade700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Numara: ${student.studentNumber}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? const Color(0xFF04BF61)
                                          : Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF04BF61),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Onay sayfası
  Widget _buildConfirmationStep() {
    if (selectedBook == null || selectedStudent == null) {
      return const Center(
        child: Text('Lütfen önce kitap ve öğrenci seçin.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ödünç Verme İşlemini Onayla',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kitap Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF04BF61),
                      ),
                    ),
                    const Divider(),
                    _buildInfoRow('Kitap Adı', selectedBook!.title),
                    _buildInfoRow('Yazar', selectedBook!.author),
                    if (selectedBook!.barcode.isNotEmpty)
                      _buildInfoRow('Barkod', selectedBook!.barcode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Öğrenci Bilgileri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF04BF61),
                      ),
                    ),
                    const Divider(),
                    _buildInfoRow('Ad Soyad',
                        '${selectedStudent!.name} ${selectedStudent!.surname}'),
                    _buildInfoRow('Sınıf', selectedStudent!.className),
                    _buildInfoRow('Öğrenci No', selectedStudent!.studentNumber),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  // 🌟 Scrollable eklendi
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İşlem Bilgileri',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF04BF61),
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow('İşlem', 'Kitap Ödünç Verme'),
                      _buildInfoRow('Tarih', _formatDate(DateTime.now())),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isProcessing)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF04BF61),
                  ),
                ),
              ),
          ],
        ),
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
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.borrow,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
      ),
      body: Column(
        children: [
          // İlerleme göstergesi
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _buildStepIndicator(BOOK_SELECTION, 'Kitap')),
                _buildStepConnector(_currentStep > BOOK_SELECTION),
                Flexible(
                    child: _buildStepIndicator(STUDENT_SELECTION, 'Öğrenci')),
                _buildStepConnector(_currentStep > STUDENT_SELECTION),
                Flexible(child: _buildStepIndicator(CONFIRMATION, 'Onay')),
              ],
            ),
          ),

          // Kontroller (Üstte)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label:
                      Text(_currentStep == BOOK_SELECTION ? 'İptal' : 'Geri'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
                ElevatedButton(
                  onPressed: _canProceed() ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF04BF61),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _getNextButtonText(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Ana içerik
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildBookSelectionStep(),
                _buildStudentSelectionStep(),
                _buildConfirmationStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case BOOK_SELECTION:
        return 'Kitap Seç';
      case STUDENT_SELECTION:
        return 'Öğrenci Seç';
      case CONFIRMATION:
        return 'Ödünç Ver';
      default:
        return 'Kitap Ödünç Ver';
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case BOOK_SELECTION:
        return 'Devam Et';
      case STUDENT_SELECTION:
        return 'Devam Et';
      case CONFIRMATION:
        return 'Ödünç Ver';
      default:
        return 'Devam Et';
    }
  }

  Widget _buildStepIndicator(int step, String label) {
    final bool isActive = _currentStep >= step;
    final bool isCurrent = _currentStep == step;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF04BF61) : Colors.grey.shade300,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: const Color(0xFF04BF61), width: 3)
                : null,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF04BF61) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      color: isActive ? const Color(0xFF04BF61) : Colors.grey.shade300,
    );
  }

  // Öğrenci araması için filtre fonksiyonu
  void _filterStudents(String query) {
    setState(() {
      _studentSearchQuery = query;
    });

    _studentsFuture.then((students) {
      setState(() {
        if (query.isEmpty) {
          _filteredStudents = students;
        } else {
          _filteredStudents = students.where((student) {
            final fullName = '${student.name} ${student.surname}'.toLowerCase();
            final studentNumber = student.studentNumber.toLowerCase();
            final className = student.className.toLowerCase();
            final searchLower = query.toLowerCase();

            return fullName.contains(searchLower) ||
                studentNumber.contains(searchLower) ||
                className.contains(searchLower);
          }).toList();
        }
      });
    });
  }

  // Kitap araması için filtre fonksiyonu
  void _filterBooks(String query) {
    setState(() {
      _bookSearchQuery = query;
    });

    _availableBooksFuture.then((books) {
      setState(() {
        if (query.isEmpty) {
          _filteredBooks = books;
        } else {
          _filteredBooks = books.where((book) {
            final title = book.title.toLowerCase();
            final author = book.author.toLowerCase();
            final barcode = book.barcode.toLowerCase();
            final searchLower = query.toLowerCase();

            return title.contains(searchLower) ||
                author.contains(searchLower) ||
                barcode.contains(searchLower);
          }).toList();
        }
      });
    });
  }
}
