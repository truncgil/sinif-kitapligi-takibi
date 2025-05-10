import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/class_room.dart';
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
  late Future<List<ClassRoom>> _classRoomsFuture;

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshStudents();
    _classRoomsFuture = _databaseService.getAllClassRooms();
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
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(student.studentNumber),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditStudentDialog(context, student),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () =>
                          _showDeleteStudentDialog(context, student),
                    ),
                  ],
                ),
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
    String? selectedClassName;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Öğrenci Ekle'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
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
                FutureBuilder<List<ClassRoom>>(
                  future: _classRoomsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Hata: ${snapshot.error}');
                    }

                    final classRooms = snapshot.data ?? [];

                    if (classRooms.isEmpty) {
                      return const Text('Önce sınıf eklemelisiniz!');
                    }

                    final uniqueClassNames =
                        classRooms.map((c) => c.name).toSet().toList();

                    if (selectedClassName == null &&
                        uniqueClassNames.isNotEmpty) {
                      selectedClassName = uniqueClassNames[0];
                    }

                    if (!uniqueClassNames.contains(selectedClassName)) {
                      selectedClassName = uniqueClassNames[0];
                    }

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Sınıf'),
                      value: selectedClassName,
                      items: uniqueClassNames.map((className) {
                        return DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClassName = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Lütfen bir sınıf seçin' : null,
                    );
                  },
                ),
              ],
            ),
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
                  className: selectedClassName!,
                );
                _databaseService.insertStudent(student).then((_) {
                  _refreshStudents();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Öğrenci başarıyla eklendi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                });
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditStudentDialog(
      BuildContext context, Student student) async {
    final formKey = GlobalKey<FormState>();
    String name = student.name;
    String surname = student.surname;
    String studentNumber = student.studentNumber;
    String? selectedClassName = student.className;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenci Düzenle'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Ad'),
                  initialValue: name,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Ad boş olamaz' : null,
                  onSaved: (value) => name = value ?? '',
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Soyad'),
                  initialValue: surname,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Soyad boş olamaz' : null,
                  onSaved: (value) => surname = value ?? '',
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Öğrenci Numarası'),
                  initialValue: studentNumber,
                  validator: (value) => value?.isEmpty ?? true
                      ? 'Öğrenci numarası boş olamaz'
                      : null,
                  onSaved: (value) => studentNumber = value ?? '',
                ),
                FutureBuilder<List<ClassRoom>>(
                  future: _classRoomsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    if (snapshot.hasError) {
                      return Text('Hata: ${snapshot.error}');
                    }

                    final classRooms = snapshot.data ?? [];

                    if (classRooms.isEmpty) {
                      return const Text('Önce sınıf eklemelisiniz!');
                    }

                    final uniqueClassNames =
                        classRooms.map((c) => c.name).toSet().toList();

                    if (selectedClassName == null &&
                        uniqueClassNames.isNotEmpty) {
                      selectedClassName = uniqueClassNames[0];
                    }

                    if (!uniqueClassNames.contains(selectedClassName)) {
                      selectedClassName = uniqueClassNames[0];
                    }

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Sınıf'),
                      value: selectedClassName,
                      items: uniqueClassNames.map((className) {
                        return DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClassName = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Lütfen bir sınıf seçin' : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();

                try {
                  final updatedStudent = Student(
                    id: student.id,
                    name: name,
                    surname: surname,
                    studentNumber: studentNumber,
                    className: selectedClassName!,
                  );

                  await _databaseService.updateStudent(updatedStudent);
                  _refreshStudents();

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Öğrenci başarıyla güncellendi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Öğrenci güncellenirken bir hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteStudentDialog(
      BuildContext context, Student student) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğrenci Silme'),
        content: Text(
            '${student.name} ${student.surname} öğrencisini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _databaseService.deleteStudent(student.id!);
                _refreshStudents();

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Öğrenci başarıyla silindi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Öğrenci silinirken bir hata oluştu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
