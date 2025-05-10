import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../services/database/database_service.dart';

/// Öğrenci işlemleri ekranı
class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late Future<List<Student>> _studentsFuture;
  late DatabaseService _databaseService;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshStudents();
  }

  void _refreshStudents() {
    setState(() {
      _studentsFuture = _databaseService.getAllStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Öğrenciler'),
      ),
      body: FutureBuilder<List<Student>>(
        future: _studentsFuture,
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
              child: Text('Henüz öğrenci kaydı bulunmamaktadır.'),
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
                subtitle: Text('Sınıf: ${student.className}'),
                trailing: Text(student.studentNumber),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudentDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddStudentDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String surname = '';
    String studentNumber = '';
    String className = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Öğrenci Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ad boş olamaz' : null,
                onSaved: (value) => name = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Soyad'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Soyad boş olamaz' : null,
                onSaved: (value) => surname = value ?? '',
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Öğrenci Numarası'),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Öğrenci numarası boş olamaz'
                    : null,
                onSaved: (value) => studentNumber = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Sınıf'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Sınıf boş olamaz' : null,
                onSaved: (value) => className = value ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();
                final student = Student(
                  name: name,
                  surname: surname,
                  studentNumber: studentNumber,
                  className: className,
                );
                _databaseService.insertStudent(student).then((_) {
                  _refreshStudents();
                  Navigator.pop(context);
                });
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
