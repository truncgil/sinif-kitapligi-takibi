import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database/database_service.dart';
import '../../models/book.dart';
import '../borrow/borrow_screen.dart';

/// Barkod tarama sayfası
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  String _scanResult = '';
  bool _isScanning = true;
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty && mounted) {
      final String code = barcodes.first.rawValue ?? '';

      if (code.isEmpty) return;

      setState(() {
        _scanResult = code;
        _isScanning = false;
        _isProcessing = true;
      });

      // Tarama işlemi tamamlandığında kitap kontrolü yap
      await _processBarcode(code);
    }
  }

  Future<void> _processBarcode(String barcode) async {
    try {
      // Veritabanında kitabı ara
      final book = await _databaseService.getBookByBarcode(barcode);

      if (book == null) {
        _showMessage('Bu barkod numarasına sahip kitap bulunamadı.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      if (book.isAvailable) {
        // Kitap mevcutsa, ödünç verme ekranına gönder
        if (!mounted) return;
        // İlk olarak tarayıcıyı kapat
        Navigator.pop(context);
        // Ödünç verme ekranını aç
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BorrowScreen(initialBarcode: barcode),
          ),
        );
      } else {
        // Kitap ödünç verildiyse, iade işlemini başlat
        await _returnBook(book);
      }
    } catch (e) {
      _showMessage('İşlem sırasında bir hata oluştu: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _returnBook(Book book) async {
    try {
      // Ödünç kaydını bul
      final borrowRecord =
          await _databaseService.getActiveBorrowRecordByBookId(book.id!);

      if (borrowRecord == null) {
        _showMessage(
            'Kitap ödünç kaydı bulunamadı, ancak kitap durumu ödünç görünüyor.');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // İade işlemi için onay penceresi göster
      if (!mounted) return;

      final student =
          await _databaseService.getStudentById(borrowRecord.studentId);
      final studentName = student != null
          ? '${student.name} ${student.surname}'
          : 'Bilinmeyen öğrenci';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kitap İadesi'),
          content: Text(
              '${book.title} adlı kitap $studentName tarafından ödünç alınmış. İade etmek istiyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                setState(() {
                  _isProcessing = false;
                });
              },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await _completeReturn(borrowRecord.id!, book.id!);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF04BF61),
                foregroundColor: Colors.white,
              ),
              child: const Text('İade Et'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showMessage('İade işlemi sırasında bir hata oluştu: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeReturn(int borrowRecordId, int bookId) async {
    try {
      // İade işlemini tamamla
      await _databaseService.updateBorrowRecordAsReturned(borrowRecordId);
      await _databaseService.updateBookAvailability(bookId, true);

      if (!mounted) return;
      _showMessage('Kitap başarıyla iade edildi!', isSuccess: true);

      // Ana ekrana dön
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _showMessage('İade işlemi tamamlanırken bir hata oluştu: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showMessage(String message, {bool isSuccess = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF04BF61) : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(
              Icons.qr_code_scanner,
              color: Color(0xFF04BF61),
            ),
            SizedBox(width: 8),
            Text(
              'Barkod Okut',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Tarama hedef çerçevesi
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF04BF61),
                            width: 3.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                        ),
                        child: const Center(
                          child: Opacity(
                            opacity: 0.6,
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Color(0xFF04BF61),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Durum mesajı - üstte göster
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isScanning
                          ? 'Kitap barkodunu tarama alanına hizalayın'
                          : 'Barkod: $_scanResult',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isProcessing)
                  Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF04BF61),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'İşleniyor...',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isScanning = true;
                        _scanResult = '';
                      });
                      _controller.start();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF04BF61),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Tekrar Tara',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
