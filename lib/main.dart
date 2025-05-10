import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/home/home_screen.dart';
import 'screens/student/student_screen.dart';
import 'screens/book/book_screen.dart';
import 'screens/borrow/borrow_screen.dart';
import 'screens/history/history_screen.dart';
import 'services/database/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<DatabaseService>(
      create: (_) => DatabaseService(),
      child: MaterialApp(
        title: 'Sınıf Kitaplığı',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/students': (context) => const StudentScreen(),
          '/books': (context) => const BookScreen(),
          '/borrow': (context) => const BorrowScreen(),
          '/history': (context) => const HistoryScreen(),
        },
      ),
    );
  }
}
