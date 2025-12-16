import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database/database_service.dart';
import '../../constants/colors.dart';
import '../../models/book.dart';

import '../../models/student.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.statistics,
        centerTitle: true,
        title: const Text(
          'İstatistikler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getStatistics(dbService),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final stats = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatisticCard(
                title: 'Toplam Kitap',
                value: stats['totalBooks']?.toString() ?? '0',
                icon: Icons.book,
                color: Colors.blue,
              ),
              _StatisticCard(
                title: 'Toplam Öğrenci',
                value: stats['totalStudents']?.toString() ?? '0',
                icon: Icons.people,
                color: Colors.green,
              ),
              _StatisticCard(
                title: 'Ödünç Verilen Kitaplar',
                value: stats['borrowedBooks']?.toString() ?? '0',
                icon: Icons.book_online,
                color: Colors.orange,
              ),
              _StatisticCard(
                title: 'Toplam Sınıf',
                value: stats['totalClasses']?.toString() ?? '0',
                icon: Icons.class_,
                color: Colors.purple,
              ),
              GestureDetector(
                onTap: () {
                  _showNeverBorrowedBooks(context, dbService);
                },
                child: _StatisticCard(
                  title: 'Hiç Okunmayan Kitaplar',
                  value: stats['neverBorrowedBooks']?.toString() ?? '0',
                  icon: Icons.menu_book,
                  color: Colors.red,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showMostBorrowedBooks(context, dbService);
                },
                child: _StatisticCard(
                  title: 'En Çok Okunan Kitaplar',
                  value: 'Liste',
                  icon: Icons.stars,
                  color: Colors.amber,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showMostReadingStudents(context, dbService);
                },
                child: _StatisticCard(
                  title: 'En Çok Okuyan Öğrenciler',
                  value: 'Liste',
                  icon: Icons.school,
                  color: Colors.teal,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showMostReadingStudentsThisMonth(context, dbService);
                },
                child: _StatisticCard(
                  title: 'Bu Ayın En Çok Okuyanları',
                  value: 'Liste',
                  icon: Icons.calendar_month,
                  color: Colors.indigo,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMostReadingStudentsThisMonth(
      BuildContext context, DatabaseService dbService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final students = await dbService.getMostReadingStudentsThisMonth();
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Bu Ayın En Çok Okuyanları',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: students.isEmpty
                      ? const Center(
                          child: Text('Bu ay henüz kitap okunmamış.'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final studentData = students[index];
                            final student = Student.fromMap(studentData);
                            final count = studentData['readCount'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    index < 3 ? Colors.amber : Colors.indigo,
                                child: Text('${index + 1}'),
                              ),
                              title: Text('${student.name} ${student.surname}'),
                              subtitle: Text(
                                  '${student.className} - ${student.studentNumber}'),
                              trailing: Chip(
                                label: Text('$count kitap'),
                                backgroundColor: Colors.indigo.shade100,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _showMostReadingStudents(
      BuildContext context, DatabaseService dbService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final students = await dbService.getMostReadingStudents();
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'En Çok Okuyan Öğrenciler (Top 10)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: students.isEmpty
                      ? const Center(
                          child: Text('Henüz hiç kitap okunmamış.'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final studentData = students[index];
                            final student = Student.fromMap(studentData);
                            final count = studentData['readCount'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    index < 3 ? Colors.amber : Colors.teal,
                                child: Text('${index + 1}'),
                              ),
                              title: Text('${student.name} ${student.surname}'),
                              subtitle: Text('${student.className} - ${student.studentNumber}'),
                              trailing: Chip(
                                label: Text('$count kitap'),
                                backgroundColor: Colors.blue.shade100,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _showMostBorrowedBooks(
      BuildContext context, DatabaseService dbService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final books = await dbService.getMostBorrowedBooks();
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'En Çok Okunan Kitaplar (Top 10)',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: books.isEmpty
                      ? const Center(
                          child: Text('Henüz hiç kitap okunmamış.'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: books.length,
                          itemBuilder: (context, index) {
                            final bookData = books[index];
                            final book = Book.fromMap(bookData);
                            final count = bookData['borrowCount'];
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: index < 3 ? Colors.amber : Colors.blue,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(book.title),
                              subtitle: Text(book.author),
                              trailing: Chip(
                                label: Text('$count kez'),
                                backgroundColor: Colors.green.shade100,
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<void> _showNeverBorrowedBooks(
      BuildContext context, DatabaseService dbService) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final books = await dbService.getNeverBorrowedBooks();
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hiç Okunmayan Kitaplar (${books.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: books.isEmpty
                      ? const Center(
                          child: Text('Tüm kitaplar en az bir kez okunmuş! 🎉'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: books.length,
                          itemBuilder: (context, index) {
                            final book = books[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Icon(Icons.book, color: Colors.white),
                              ),
                              title: Text(book.title),
                              subtitle: Text(book.author),
                              trailing: Text(book.barcode),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _getStatistics(DatabaseService dbService) async {
    final totalBooks = await dbService.getAllBooks();
    final totalStudents = await dbService.getAllStudents();
    final borrowedBooks = await dbService.getCurrentlyBorrowedBooks();
    final totalClasses = await dbService.getAllClassRooms();
    final neverBorrowedBooks = await dbService.getNeverBorrowedBooks();

    return {
      'totalBooks': totalBooks.length,
      'totalStudents': totalStudents.length,
      'borrowedBooks': borrowedBooks.length,
      'totalClasses': totalClasses.length,
      'neverBorrowedBooks': neverBorrowedBooks.length,
    };
  }
}

class _StatisticCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatisticCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
