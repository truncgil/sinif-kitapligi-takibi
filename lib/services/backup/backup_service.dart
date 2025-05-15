import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_service.dart';

/// Veritabanı yedekleme ve geri yükleme işlemlerini yöneten servis sınıfı
class BackupService {
  final DatabaseService _databaseService = DatabaseService();

  /// Yedek dizininin yolunu döndürür
  Future<String> getBackupPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${directory.path}/backups');

    // Dizin yoksa oluştur
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir.path;
  }

  /// Veritabanını belirli bir konuma yedekler
  ///
  /// [fileName] parametresi belirtilmezse, tarih ve saat bilgisi ile otomatik isim oluşturulur
  Future<String> backupDatabase({String? fileName}) async {
    try {
      if (kIsWeb) {
        throw Exception('Web platformunda yedekleme henüz desteklenmiyor.');
      }

      // Yedekleme için veritabanı dosyasının yolunu al
      final db = await _databaseService.database;

      // Veritabanını güvenli bir şekilde kapat
      await db.close();

      // Uygulama yeniden başlayana kadar bekleme
      await Future.delayed(const Duration(seconds: 3));

      // Orjinal veritabanı dosyasını bul
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'library.db'));

      if (!await dbFile.exists()) {
        throw Exception('Veritabanı dosyası bulunamadı.');
      }

      // Yedekleme için hedef dizini al
      final backupDir = await getBackupPath();

      // Yedek dosya adını oluştur
      final backupFileName = fileName ??
          'librolog_backup_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.db';
      final backupFilePath = '$backupDir/$backupFileName';

      // Veritabanı dosyasını kopyala
      await dbFile.copy(backupFilePath);

      // Veritabanını yeniden başlat
      await _databaseService.initialize();

      return backupFilePath;
    } catch (e) {
      // Hata durumunda veritabanını tekrar açmayı dene
      try {
        await Future.delayed(const Duration(seconds: 3));
        await _databaseService.initialize();
        await Future.delayed(const Duration(milliseconds: 500));

        await _databaseService.resetDatabase();
      } catch (innerError) {
        // İç hata görmezden gelinebilir
      }
      rethrow;
    }
  }

  /// Yedeği cihaz üzerinden paylaşır
  Future<void> shareBackup(String backupPath) async {
    try {
      if (kIsWeb) {
        throw Exception('Web platformunda paylaşım henüz desteklenmiyor.');
      }

      final file = File(backupPath);
      if (!await file.exists()) {
        throw Exception('Paylaşılacak yedek dosyası bulunamadı.');
      }

      final fileName = basename(backupPath);
      await Share.shareXFiles([XFile(backupPath)],
          text: 'LibroLog Veritabanı Yedeği: $fileName');
    } catch (e) {
      rethrow;
    }
  }

  /// Yedeklenmiş veritabanını geri yükler
  Future<bool> restoreDatabase(String backupFilePath) async {
    try {
      if (kIsWeb) {
        throw Exception('Web platformunda geri yükleme henüz desteklenmiyor.');
      }

      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('Yedek dosyası bulunamadı.');
      }

      // Geri yükleme için veritabanını kapat
      final db = await _databaseService.database;
      await db.close();

      // Uygulama yeniden başlayana kadar bekleme
      await Future.delayed(const Duration(milliseconds: 500));

      // Hedef veritabanı dosyasını al
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'library.db'));

      // Mevcut veritabanını yedek dosyası ile değiştir
      await backupFile.copy(dbFile.path);

      // Veritabanını tamamen kapatıp yeniden başlatmak için
      // _database değişkenini null yapmak gerekiyor
      // Veritabanı servisine doğrudan erişim olmadığı için
      // bir gecikme ekleyip initialize çağırıyoruz
      await Future.delayed(const Duration(milliseconds: 500));

      // Veritabanını yeniden başlat (tam yeniden başlatma)
      await _databaseService.resetDatabase();

      return true;
    } catch (e) {
      // Hata durumunda veritabanını tekrar açmayı dene
      try {
        await _databaseService.initialize();
      } catch (innerError) {
        // İç hata görmezden gelinebilir
      }
      rethrow;
    }
  }

  /// Mevcut tüm yedekleri listeler
  Future<List<FileSystemEntity>> listBackups() async {
    try {
      if (kIsWeb) {
        throw Exception(
            'Web platformunda yedekleri listeleme henüz desteklenmiyor.');
      }

      // Yedekleme dizinini al
      final backupDir = await getBackupPath();

      // Dizindeki tüm .db uzantılı dosyaları listele
      final entities = await Directory(backupDir).list().toList();
      return entities
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Belirtilen yedek dosyasını siler
  Future<bool> deleteBackup(String backupFilePath) async {
    try {
      final file = File(backupFilePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  /// Belirtilen konumdan yedeği içe aktarır (manuel olarak seçilen dosya)
  Future<bool> importBackup(String sourceFilePath) async {
    try {
      if (kIsWeb) {
        throw Exception('Web platformunda içe aktarma henüz desteklenmiyor.');
      }

      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('Kaynak dosya bulunamadı.');
      }

      // Dosya adını al
      final fileName = basename(sourceFilePath);

      // Hedef dizini al
      final backupDir = await getBackupPath();

      // Hedef dosya yolu
      final targetPath = '$backupDir/$fileName';

      // Dosyayı yedekleme dizinine kopyala
      await sourceFile.copy(targetPath);

      return true;
    } catch (e) {
      rethrow;
    }
  }
}
