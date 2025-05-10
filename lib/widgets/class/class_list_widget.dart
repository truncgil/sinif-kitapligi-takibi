import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database/database_service.dart';
import '../../screens/class/class_students_screen.dart';

class ClassListWidget extends StatelessWidget {
  const ClassListWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _getUniqueClasses(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final classes = snapshot.data ?? [];

        if (classes.isEmpty) {
          return const Center(
            child: Text('Henüz sınıf bulunmamaktadır.'),
          );
        }

        return ListView.builder(
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final className = classes[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.school),
                ),
                title: Text(className),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ClassStudentsScreen(className: className),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<List<String>> _getUniqueClasses(BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final db = await dbService.database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT DISTINCT className FROM students ORDER BY className',
    );
    return result.map((row) => row['className'] as String).toList();
  }
}
