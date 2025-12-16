import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../database/database_service.dart';

class ExcelExportService {
  final DatabaseService _databaseService;

  ExcelExportService(this._databaseService);

  Future<void> exportAllData() async {
    try {
      // 1. Verileri al
      final data = await _databaseService.getAllBorrowingHistoryForExport();

      if (data.isEmpty) {
        throw Exception('Dışa aktarılacak veri bulunamadı.');
      }

      // 2. Excel dosyası oluştur
      var excel = Excel.createExcel();

      // Varsayılan sayfayı al veya oluştur
      String sheetName = 'Librolog Kaytları';
      Sheet sheetObject = excel[sheetName];

      // Varsayılan "Sheet1" varsa adını değiştirelim veya silelim
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // 3. Başlıkları ekle
      List<String> headers = [
        'Öğrenci Adı',
        'Öğrenci Soyadı',
        'Öğrenci No',
        'Sınıf',
        'Kitap Adı',
        'Yazar',
        'Barkod',
        'Ödünç Alma Tarihi',
        'İade Tarihi',
        'Durum'
      ];

      // Başlık stilini ayarla (isteğe bağlı, kütüphane desteğine göre)
      // Şimdilik sadece veriyi yazıyoruz.
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // 4. Verileri ekle
      for (var row in data) {
        final borrowDateStr = row['borrowDate'] as String;
        final returnDateStr = row['returnDate'] as String?;
        final isReturned = row['isReturned'] == 1;

        final borrowDate = DateTime.parse(borrowDateStr);
        final formattedBorrowDate =
            DateFormat('dd.MM.yyyy HH:mm').format(borrowDate);

        String formattedReturnDate = '-';
        if (returnDateStr != null) {
          final returnDate = DateTime.parse(returnDateStr);
          formattedReturnDate =
              DateFormat('dd.MM.yyyy HH:mm').format(returnDate);
        }

        List<CellValue> excelRow = [
          TextCellValue(row['name'] as String),
          TextCellValue(row['surname'] as String),
          TextCellValue(row['studentNumber'] as String),
          TextCellValue(row['className'] as String),
          TextCellValue(row['title'] as String),
          TextCellValue(row['author'] as String),
          TextCellValue(row['barcode'] as String),
          TextCellValue(formattedBorrowDate),
          TextCellValue(formattedReturnDate),
          TextCellValue(isReturned ? 'İade Edildi' : 'Ödünç Alındı'),
        ];

        sheetObject.appendRow(excelRow);
      }

      // Otomatik sütun genişliği için basit bir ayar (manuel)
      // Excel paketi otomatik genişlik konusunda bazen sınırlı olabilir
      for (int i = 0; i < headers.length; i++) {
        sheetObject.setColumnWidth(i, 20.0);
      }

      // 5. Dosyayı kaydet
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Truncgil_Librolog_$dateStr.xlsx';
      final path = '${directory.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Excel dosyası oluşturulamadı.');
      }

      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      // 6. Dosyayı paylaş
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Librolog Kaytları Excel Dosyası',
      );
    } catch (e) {
      rethrow;
    }
  }
}
