import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database/database_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('İstatistikler'),
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
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getStatistics(DatabaseService dbService) async {
    final totalBooks = await dbService.getAllBooks();
    final totalStudents = await dbService.getAllStudents();
    final borrowedBooks = await dbService.getCurrentlyBorrowedBooks();
    final totalClasses = await dbService.getAllClassRooms();

    return {
      'totalBooks': totalBooks.length,
      'totalStudents': totalStudents.length,
      'borrowedBooks': borrowedBooks.length,
      'totalClasses': totalClasses.length,
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
