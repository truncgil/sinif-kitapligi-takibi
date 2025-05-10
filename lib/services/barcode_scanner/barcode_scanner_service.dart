import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';

/// Barkod tarama işlemlerini yöneten servis sınıfı
class BarcodeScannerService {
  /// Barkod tarama işlemini başlatır
  Future<String> scanBarcode() async {
    try {
      final controller = MobileScannerController();
      String result = '';

      // Bu metot kullanıldığında, uygulama içinde bir kamera görünümü açılacak
      // ve kullanıcının bir barkod taraması yapması beklenecek
      // Gerçek uygulamada, bu bir widget olarak gerçekleştirilmelidir.

      // Burada basit bir şekilde MobileScanner widget'ı kullanıldığını varsayıyoruz
      // Gerçek uygulamada, bu widget bir sayfa içinde kullanılmalıdır.

      // Simülasyon amaçlı test değeri döndürülüyor
      return result.isNotEmpty ? result : '';
    } catch (e) {
      return '';
    }
  }
}

/// Barkod tarama sayfası
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  String? barcode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod Tarayıcı'),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: MobileScannerController(),
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes[0].rawValue != null) {
                  setState(() {
                    barcode = barcodes[0].rawValue;
                  });
                  Navigator.pop(context, barcode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
