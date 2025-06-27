import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_intent/receive_intent.dart' as receive_intent;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/student/student_screen.dart';
import 'screens/book/book_screen.dart';
import 'screens/borrow/borrow_screen.dart';
import 'screens/history/history_screen.dart';
import 'services/database/database_service.dart';
import 'services/backup/backup_service.dart';
import 'services/purchase_service.dart';
import 'providers/library_provider.dart';
import 'providers/book_limit_provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

// Uygulama çapında anahtar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Debug loglaması için
void logDebug(String message) {
  debugPrint('🚀 LibroLog Debug: $message');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logDebug('LibroLog uygulaması başlatılıyor...');

  if (kIsWeb) {
    // Web için SQLite'ı yapılandır
    // Web platformunda sqflite için FFI Web bağlantı noktasını kullan
    var factory = databaseFactoryFfiWeb;
    // Initialize database with this factory
    DatabaseService().setDatabaseFactory(factory);
    logDebug('Web platformu için SQLite yapılandırıldı');
  } else {
    logDebug(
        'Mobil platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final purchaseService = PurchaseService(prefs);
    final backupService = BackupService();

    // Veritabanını sıfırlamak yerine varolan veritabanını kullan
    logDebug('Veritabanı başlatılıyor...');
    final databaseService = DatabaseService();
    await databaseService.initialize();
    logDebug('Veritabanı başarıyla başlatıldı');

    // Satın alma sistemini yapılandır (iOS için kritik)
    if (!kIsWeb && Platform.isIOS) {
      logDebug('iOS için satın alma sistemi yapılandırılıyor...');
      try {
        // iOS için AppStore konfigürasyonu
        final iosPlatform = InAppPurchase.instance
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

        await iosPlatform.setDelegate(ExamplePaymentQueueDelegate());
        logDebug('iOS ödeme delegasyonu başarıyla ayarlandı');
      } catch (e) {
        logDebug('iOS satın alma yapılandırması hatası: $e');
      }
    }

    runApp(
      MultiProvider(
        providers: [
          Provider<DatabaseService>(
            create: (_) => databaseService,
          ),
          Provider<PurchaseService>(
            create: (_) => purchaseService,
          ),
          Provider<BackupService>(
            create: (_) => backupService,
          ),
          ChangeNotifierProvider(
            create: (context) => LibraryProvider(databaseService),
          ),
          ChangeNotifierProvider(
            create: (context) =>
                BookLimitProvider(purchaseService, databaseService),
          ),
        ],
        child: const MyApp(),
      ),
    );

    logDebug('Uygulama başlatıldı ve hazır');
  } catch (e) {
    logDebug('Uygulama başlatılırken hata oluştu: $e');
    logDebug('Hata stack trace: ${StackTrace.current}');
    // Hataya rağmen uygulamayı çalıştırmaya çalış
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
              'Uygulama başlatılırken bir hata oluştu. Lütfen tekrar deneyin.'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibroLog',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF04BF61),
          primary: const Color(0xFF04BF61),
        ),
        useMaterial3: true,
      ),
      home: const AppStartWidget(),
      routes: {
        '/students': (context) => const StudentScreen(),
        '/books': (context) => const BookScreen(),
        '/borrow': (context) => const BorrowScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

/// Uygulama başlangıç ekranından ana ekrana animasyonlu geçiş sağlar
class AppStartWidget extends StatefulWidget {
  const AppStartWidget({super.key});

  @override
  State<AppStartWidget> createState() => _AppStartWidgetState();
}

class _AppStartWidgetState extends State<AppStartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String? _receivedFilePath;
  bool _intentInitialized = false;
  bool _hasProcessedIntent = false;
  bool _navigatedToHome = false;

  @override
  void initState() {
    super.initState();
    logDebug('AppStartWidget initState başladı');

    // Animasyon denetleyicisini oluştur
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Yavaş başlayıp hızlanan ve yavaşlayan bir animasyon eğrisi
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );

    // Animasyonu başlat
    _controller.forward();

    // Uygulama çalıştırılmadan önce gelen intent'i kontrol et
    _initReceiveIntent();

    // 2 saniye sonra ana ekrana geçiş yap
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        logDebug('Ana ekrana geçiliyor...');
        setState(() {
          _navigatedToHome = true;
        });

        Navigator.of(context)
            .pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              var begin = const Offset(0.0, 0.0);
              var end = Offset.zero;
              var curve = Curves.ease;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        )
            .then((_) {
          logDebug('Ana ekrana geçiş tamamlandı');

          // Ana ekrana geçtikten sonra intent'i işle
          if (_receivedFilePath != null && !_hasProcessedIntent) {
            logDebug(
                'Ana ekrana geçiş sonrası intent işleniyor: $_receivedFilePath');
            Future.delayed(const Duration(seconds: 1), () {
              _processBackupFile(_receivedFilePath!);
            });
          }
        });
      }
    });
  }

  Future<void> _initReceiveIntent() async {
    if (kIsWeb) return;
    logDebug('Intent dinleme başlatılıyor...');

    try {
      // Intent dinleyicisi için daha fazla loglama ekleyelim
      logDebug('Intent dinleyici başlatılmadan önce kontroller yapılıyor');
      logDebug('Uygulama platform: ${Platform.operatingSystem}');

      // Uygulama belge dizinini oluştur (WhatsApp paylaşımları için yedekleri kaydedebilmek için)
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final importDir = Directory('${documentsDir.path}/imports');
        if (!await importDir.exists()) {
          await importDir.create(recursive: true);
          logDebug('İçe aktarma dizini oluşturuldu: ${importDir.path}');
        }
      } catch (e) {
        logDebug('İçe aktarma dizini oluşturulurken hata: $e');
      }

      // Başlangıçta uygulama açılırken intent'i kontrol et
      final receivedIntent =
          await receive_intent.ReceiveIntent.getInitialIntent();

      logDebug(
          'Başlangıç intent kontrolü tamamlandı. Sonuç: ${receivedIntent != null ? "Var" : "Yok"}');

      if (receivedIntent != null) {
        logDebug('Başlangıç intent alındı: ${receivedIntent.data}');
        logDebug('Başlangıç intent action: ${receivedIntent.action}');
        logDebug('Başlangıç intent kategorileri: ${receivedIntent.categories}');

        if (receivedIntent.data != null) {
          logDebug('Başlangıç intent işleniyor...');
          _handleReceivedIntent(receivedIntent);
        }
      }

      // Intent dinleyicisi ekle - canlı akış için
      logDebug('Intent stream dinleyicisi ekleniyor...');

      receive_intent.ReceiveIntent.receivedIntentStream.listen(
        (intent) {
          logDebug('Stream üzerinden intent alındı: ${intent?.action}');
          logDebug('Intent detayları: data=${intent?.data}');

          if (intent != null && intent.data != null) {
            logDebug('Intent veri içeriyor, işleniyor...');
            _handleReceivedIntent(intent);
          } else {
            logDebug('Intent boş veya veri içermiyor, işlem yapılmıyor');
          }
        },
        onError: (error) {
          logDebug('Intent alınırken hata: $error');
          logDebug('Hata stack trace: ${StackTrace.current}');
        },
        onDone: () {
          logDebug('Intent stream tamamlandı');
        },
        cancelOnError: false,
      );

      setState(() {
        _intentInitialized = true;
      });

      logDebug('Intent dinleyici başarıyla başlatıldı');
      // İntent işleme hazır durumda olduğunu bildirelim
      Future.delayed(const Duration(milliseconds: 200), () {
        logDebug('Intent işleme sistemi hazır');
      });
    } catch (e) {
      logDebug('Intent dinleme başlatılamadı: $e');
      logDebug('Hata stack trace: ${StackTrace.current}');
    }
  }

  void _handleReceivedIntent(receive_intent.Intent intent) {
    logDebug('_handleReceivedIntent çağrıldı');
    logDebug('Intent action: ${intent.action}');
    logDebug('Intent categories: ${intent.categories}');

    final uri = intent.data;
    if (uri == null) {
      logDebug('Intent URI null, işlem yapılmıyor');
      return;
    }

    final filePath = uri.toString();
    logDebug('Alınan intent yolu: $filePath');

    // Extra detayları logla
    if (intent.extra != null) {
      intent.extra!.forEach((key, value) {
        logDebug('Intent extra - $key: $value');
      });
    }

    // Content URI kontrolü
    if (filePath.startsWith('content://')) {
      logDebug('Content URI tespit edildi: $filePath');
      _showErrorMessage(
          'Dosya paylaşımı desteklenmiyor. Lütfen uygulama içinden yedek oluşturun.');
      return;
    }

    // Normal dosya işleme mantığı
    bool isDbFile = filePath.toLowerCase().endsWith('.db');
    if (isDbFile) {
      logDebug('DB dosyası algılandı: $filePath');
      final normalizedPath = _normalizeFilePath(filePath);
      setState(() {
        _receivedFilePath = normalizedPath;
        _hasProcessedIntent = false;
      });

      if (_navigatedToHome) {
        Future.delayed(const Duration(seconds: 1), () {
          _processBackupFile(normalizedPath);
        });
      }
    } else {
      logDebug('Alınan dosya .db değil veya desteklenmiyor: $filePath');
      _showErrorMessage('Lütfen geçerli bir yedek dosyası (.db) seçin.');
    }
  }

  Future<void> _processWhatsAppFile(String contentUri) async {
    logDebug('WhatsApp dosyası işleniyor: $contentUri');

    try {
      // Belge dizinine erişim
      final documentsDir = await getApplicationDocumentsDirectory();
      final importDir = Directory('${documentsDir.path}/imports');
      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }

      // Geçici dosya oluştur
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${importDir.path}/whatsapp_import_$timestamp.db');

      // Content URI'dan dosyayı kopyala
      final sourceFile = File.fromUri(Uri.parse(contentUri));
      if (await sourceFile.exists()) {
        await sourceFile.copy(tempFile.path);
        logDebug('WhatsApp dosyası başarıyla kopyalandı: ${tempFile.path}');

        setState(() {
          _receivedFilePath = tempFile.path;
          _hasProcessedIntent = false;
        });

        if (_navigatedToHome) {
          Future.delayed(const Duration(seconds: 1), () {
            _processBackupFile(tempFile.path);
          });
        }
      } else {
        logDebug('WhatsApp dosyası bulunamadı');
        _showErrorMessage('Dosya bulunamadı. Lütfen dosyayı tekrar paylaşın.');
      }
    } catch (e) {
      logDebug('WhatsApp dosyası işlenirken hata: $e');
      _showErrorMessage('Dosya işlenemedi. Lütfen dosyayı tekrar paylaşın.');
    }
  }

  // Dosya yollarını normalize etme yardımcı metodu
  String _normalizeFilePath(String filePath) {
    String normalizedPath = filePath;

    // file:// protokolünü kaldır
    if (normalizedPath.startsWith('file://')) {
      normalizedPath = normalizedPath.substring(7);
      logDebug('file:// protokolü kaldırıldı: $normalizedPath');
    }

    // URL decode işlemi
    try {
      normalizedPath = Uri.decodeFull(normalizedPath);
      logDebug('URI decode edildi: $normalizedPath');
    } catch (e) {
      logDebug('URI decode hatası: $e');
    }

    return normalizedPath;
  }

  void _processBackupFile(String filePath) async {
    logDebug('_processBackupFile başladı. Yol: $filePath');

    if (!mounted) {
      logDebug('Widget artık mounted değil, işlem iptal edildi');
      return;
    }

    setState(() {
      _hasProcessedIntent = true;
    });

    logDebug('Dosya işleme başlıyor: $filePath');

    try {
      // Dosya varlık kontrolü
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        logDebug('Dosya bulunamadı: $filePath');
        _showErrorMessage(
            'Dosya bulunamadı. Lütfen uygulama içinden yedek oluşturun.');
        return;
      }

      // Yedek servisini al
      final backupService = Provider.of<BackupService>(context, listen: false);

      // Dosyayı içe aktar
      logDebug('Dosya içe aktarılıyor...');
      final success = await backupService.importBackup(filePath);

      if (success) {
        logDebug('Dosya başarıyla içe aktarıldı');

        if (!mounted) {
          logDebug('Widget artık mounted değil, işlem iptal edildi');
          return;
        }

        // Dialog'u ana ekranda göster
        WidgetsBinding.instance.addPostFrameCallback((_) {
          logDebug('Dialog gösteriliyor...');
          showDialog(
            context: navigatorKey.currentContext ?? context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Yedek Dosyası Algılandı'),
              content: Text(
                  '${path.basename(filePath)} dosyasını geri yüklemek ister misiniz?'),
              actions: [
                TextButton(
                  onPressed: () {
                    logDebug('Geri yükleme iptal edildi');
                    Navigator.of(context).pop();
                  },
                  child: const Text('İptal'),
                ),
                TextButton(
                  onPressed: () {
                    logDebug('Geri yükleme onaylandı');
                    Navigator.of(context).pop();
                    _showRestoreConfirmationDialog(context, filePath);
                  },
                  child: const Text('Geri Yükle'),
                ),
              ],
            ),
          );
        });
      } else {
        logDebug('Dosya içe aktarılamadı');
        _showErrorMessage(
            'Yedek dosyası içe aktarılamadı. Dosya geçerli bir yedek olmayabilir.');
      }
    } catch (error) {
      logDebug('Dosya işleme hatası: $error');
      logDebug('Hata stack trace: ${StackTrace.current}');
      _showErrorMessage('Yedeği işlemede hata: $error');
    }
  }

  void _showErrorMessage(String message) {
    logDebug('Hata mesajı gösteriliyor: $message');

    ScaffoldMessenger.of(navigatorKey.currentContext ?? context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRestoreConfirmationDialog(BuildContext context, String backupPath) {
    logDebug('Geri yükleme onay dialogu gösteriliyor');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedeği Geri Yükle'),
        content: const Text(
            'Bu işlem mevcut veritabanınızı yedek ile değiştirecek. Mevcut verileriniz kaybolacak. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () {
              logDebug('İkinci onay da iptal edildi');
              Navigator.of(context).pop();
            },
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              logDebug('İkinci onay da kabul edildi, geri yükleme başlıyor');
              Navigator.of(context).pop();
              _performRestore(context, backupPath);
            },
            child: const Text('Geri Yükle'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(BuildContext context, String backupPath) async {
    logDebug('Geri yükleme işlemi başlatılıyor: $backupPath');

    try {
      // Yükleme göstergesini göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final backupService = Provider.of<BackupService>(context, listen: false);
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);

      logDebug('Veritabanı geri yükleniyor...');
      final success = await backupService.restoreDatabase(backupPath);

      // Yükleme göstergesini kapat
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        logDebug('Veritabanı başarıyla geri yüklendi');

        // Veritabanı değiştiği için Provider'ı güncelle
        logDebug('Provider güncelleniyor...');
        await libraryProvider.refreshBorrowedBooks();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yedek başarıyla geri yüklendi'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Ana sayfaya yönlendir
        logDebug('Ana sayfaya yönlendiriliyor');
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        logDebug('Geri yükleme başarısız oldu');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geri yükleme başarısız oldu'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Yükleme göstergesini kapat
      logDebug('Geri yükleme hatası: $e');
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Geri yükleme sırasında hata oluştu: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    logDebug('AppStartWidget dispose');
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Image.asset(
            'assets/icons/librolog.png',
            width: 250,
          ),
        ),
      ),
    );
  }
}

// AppStore ödeme işlemleri için özel delegasyon sınıfı
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    logDebug(
        'Ödeme işlemi devam etmeli mi kontrolü: ${transaction.transactionIdentifier}');
    return true; // Tüm işlemlere devam et
  }

  @override
  bool shouldShowPriceConsent() {
    return false; // Fiyat değişikliklerinde kullanıcıya bildirim gösterme
  }
}
