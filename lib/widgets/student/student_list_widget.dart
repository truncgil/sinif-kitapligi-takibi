import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../screens/student/student_detail_screen.dart';

class StudentListWidget extends StatelessWidget {
  final List<Student> students;

  const StudentListWidget({Key? key, required this.students}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return const Center(
        child: Text('Henüz öğrenci bulunmamaktadır.'),
      );
    }

    return ListView.builder(
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text('${student.name} ${student.surname}'),
            subtitle: Text(
                'Sınıf: ${student.className} - No: ${student.studentNumber}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentDetailScreen(student: student),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
