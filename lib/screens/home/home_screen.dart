import 'package:flutter/material.dart';
import '../student/student_screen.dart';
import '../book/book_screen.dart';
import '../history/history_screen.dart';
import '../class_room/class_room_screen.dart';
import '../statistics/statistics_screen.dart';
import '../borrow/borrow_screen.dart';
import '../../models/book.dart';
import '../../services/database/database_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/library_provider.dart';

/// Ana ekran
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kitap Takibi',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _MenuCard(
                      title: 'Ödünç Ver',
                      icon: Icons.add_box,
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BorrowScreen()),
                      ),
                    ),
                    _MenuCard(
                      title: 'Sınıflar',
                      icon: Icons.class_,
                      color: Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClassRoomScreen()),
                      ),
                    ),
                    _MenuCard(
                      title: 'Öğrenciler',
                      icon: Icons.people,
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StudentScreen()),
                      ),
                    ),
                    _MenuCard(
                      title: 'Kitaplar',
                      icon: Icons.book,
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BookScreen()),
                      ),
                    ),
                    _MenuCard(
                      title: 'Geçmiş',
                      icon: Icons.history,
                      color: Colors.brown,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()),
                      ),
                    ),
                    _MenuCard(
                      title: 'İstatistik',
                      icon: Icons.bar_chart,
                      color: Colors.red,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StatisticsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Şu An Okunan Kitaplar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const _CurrentlyReadingBooks(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentlyReadingBooks extends StatefulWidget {
  const _CurrentlyReadingBooks();

  @override
  State<_CurrentlyReadingBooks> createState() => _CurrentlyReadingBooksState();
}

class _CurrentlyReadingBooksState extends State<_CurrentlyReadingBooks> {
  @override
  void initState() {
    super.initState();
    // Post frame callback ile veri yükleme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBorrowedBooks();
    });
  }

  Future<void> _loadBorrowedBooks() async {
    if (!mounted) return;
    final provider = Provider.of<LibraryProvider>(context, listen: false);
    await provider.refreshBorrowedBooks();
  }

  String _formatDuration(DateTime borrowDate) {
    final now = DateTime.now();
    final difference = now.difference(borrowDate);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat';
    } else {
      return '${difference.inMinutes} dakika';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final books = provider.borrowedBooks;

        if (books.isEmpty) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('Şu an okunan kitap bulunmamaktadır.'),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index]['book'] as Book;
            final borrowDate = books[index]['borrowDate'] as DateTime;
            final studentName = books[index]['studentName'] as String;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.book),
                ),
                title: Text(book.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Öğrenci: $studentName'),
                    Text('Okuma süresi: ${_formatDuration(borrowDate)}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
