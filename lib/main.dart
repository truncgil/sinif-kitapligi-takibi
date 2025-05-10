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
      home: const HomeScreen(),
      routes: {
        '/students': (context) => const StudentScreen(),
        '/books': (context) => const BookScreen(),
        '/borrow': (context) => const BorrowScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
