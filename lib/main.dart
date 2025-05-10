import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'screens/home/home_screen.dart';
import 'screens/student/student_screen.dart';
import 'screens/book/book_screen.dart';
import 'screens/borrow/borrow_screen.dart';
import 'screens/history/history_screen.dart';
import 'services/database/database_service.dart';
import 'providers/library_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web için SQLite'ı yapılandır
    // Web platformunda sqflite için FFI Web bağlantı noktasını kullan
    var factory = databaseFactoryFfiWeb;
    // Initialize database with this factory
    DatabaseService().setDatabaseFactory(factory);
  }

  final databaseService = DatabaseService();

  // Veritabanı tabloları değişti, bu nedenle veritabanını sıfırlıyoruz
  // NOT: Bu kodu sadece geliştirme sürecinde kullanın,
  // uygulama stabil olduktan sonra kaldırın!
  await databaseService.resetDatabase();

  // await databaseService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => databaseService,
        ),
        ChangeNotifierProvider(
          create: (context) => LibraryProvider(databaseService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitap Takibi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
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

  @override
  void initState() {
    super.initState();

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

    // 2 saniye sonra ana ekrana geçiş yap
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
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
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: Image.asset(
            'assets/icons/icon.png',
            width: 150,
            height: 150,
          ),
        ),
      ),
    );
  }
}
