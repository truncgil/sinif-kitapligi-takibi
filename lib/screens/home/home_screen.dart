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
import '../barcode_scanner/barcode_scanner_page.dart';
import '../../constants/colors.dart';

/// Ana ekran
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Image.asset(
                    'assets/icons/edubook.png',
                    width: MediaQuery.of(context).size.width > 600
                        ? 280
                        : MediaQuery.of(context).size.width * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                _buildMenuButtons(context),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.auto_stories,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Şu An Okunan Kitaplar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _CurrentlyReadingBooks(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final scannedBarcode = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
          );
          if (context.mounted) {
            final provider =
                Provider.of<LibraryProvider>(context, listen: false);
            await provider.refreshBorrowedBooks();
          }
          if (scannedBarcode != null &&
              scannedBarcode is String &&
              scannedBarcode.isNotEmpty) {
            final dbService =
                Provider.of<DatabaseService>(context, listen: false);
            final existingBook =
                await dbService.getBookByBarcode(scannedBarcode);
            if (existingBook == null) {
              await BookScreen.showAddBookDialogWithBarcode(
                  context, scannedBarcode);
            }
          }
        },
        backgroundColor: theme.colorScheme.primary,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Barkod Okut', style: TextStyle(color: Colors.white)),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMenuButtons(BuildContext context) {
    final theme = Theme.of(context);

    final menuItems = [
      {
        'title': 'Ödünç Ver',
        'icon': Icons.add_box,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BorrowScreen()),
            ),
      },
      {
        'title': 'Sınıflar',
        'icon': Icons.class_,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClassRoomScreen()),
            ),
      },
      {
        'title': 'Öğrenciler',
        'icon': Icons.people,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentScreen()),
            ),
      },
      {
        'title': 'Kitaplar',
        'icon': Icons.book,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookScreen()),
            ),
      },
      {
        'title': 'Geçmiş',
        'icon': Icons.history,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
      },
      {
        'title': 'İstatistik',
        'icon': Icons.bar_chart,
        'color': theme.colorScheme.primary,
        'onTap': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        return _FlatMenuButton(
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: item['onTap'] as VoidCallback,
        );
      },
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

class _FlatMenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FlatMenuButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
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
    final theme = Theme.of(context);

    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final books = provider.borrowedBooks;

        if (books.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Şu an okunan kitap bulunmamaktadır.',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
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
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(
                    Icons.book,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  book.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'Öğrenci: $studentName',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      'Okuma süresi: ${_formatDuration(borrowDate)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
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
