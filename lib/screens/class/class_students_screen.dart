import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../services/database/database_service.dart';
import '../student/student_detail_screen.dart';
import '../../constants/colors.dart';

class ClassStudentsScreen extends StatelessWidget {
  final String className;

  const ClassStudentsScreen({Key? key, required this.className})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        title: Text(
          '$className Öğrencileri',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Student>>(
        future: _getStudentsByClass(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return const Center(
              child: Text('Bu sınıfta henüz öğrenci bulunmamaktadır.'),
            );
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('${student.name} ${student.surname}'),
                subtitle: Text('Öğrenci No: ${student.studentNumber}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          StudentDetailScreen(student: student),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Student>> _getStudentsByClass(BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    return dbService.getStudentsByClass(className);
  }
}
