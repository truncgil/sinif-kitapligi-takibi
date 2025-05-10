import 'package:flutter/material.dart';

/// Ana ekran widget'ı
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınıf Kitaplığı'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        children: [
          _buildMenuCard(
            context,
            'Öğrenciler',
            Icons.people,
            () => Navigator.pushNamed(context, '/students'),
          ),
          _buildMenuCard(
            context,
            'Kitaplar',
            Icons.book,
            () => Navigator.pushNamed(context, '/books'),
          ),
          _buildMenuCard(
            context,
            'Ödünç Ver',
            Icons.assignment_turned_in,
            () => Navigator.pushNamed(context, '/borrow'),
          ),
          _buildMenuCard(
            context,
            'Geçmiş',
            Icons.history,
            () => Navigator.pushNamed(context, '/history'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4.0,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48.0,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
