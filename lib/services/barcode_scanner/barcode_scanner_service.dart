import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';

/// Barkod tarama işlemlerini yöneten servis sınıfı
class BarcodeScannerService {
  /// Barkod tarama işlemini başlatır
  Future<String> scanBarcode() async {
    try {
      String barcode = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'İptal',
        true,
        ScanMode.BARCODE,
      );
      return barcode != '-1' ? barcode : '';
    } catch (e) {
      return '';
    }
  }
}
