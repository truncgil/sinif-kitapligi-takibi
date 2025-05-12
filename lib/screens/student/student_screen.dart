import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../models/class_room.dart';
import '../../services/database/database_service.dart';
import 'student_detail_screen.dart';
import '../../constants/colors.dart';

/// Öğrenci işlemleri ekranı
class StudentScreen extends StatefulWidget {
  final ClassRoom? classRoom;
  const StudentScreen({super.key, this.classRoom});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late Future<List<Student>> _studentsFuture;
  late DatabaseService _databaseService;
  late Future<List<ClassRoom>> _classRoomsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _searchController.text = widget.classRoom?.name ?? '';
    _searchQuery = widget.classRoom?.name ?? '';
    _refreshStudents();
    _classRoomsFuture = _databaseService.getAllClassRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshStudents() {
    setState(() {
      _studentsFuture = _databaseService.getAllStudents();
    });
  }

  List<Student> _filterStudents(List<Student> students) {
    if (_searchQuery.isEmpty) return students;

    return students.where((student) {
      final fullName = '${student.name} ${student.surname}'.toLowerCase();
      final studentNumber = student.studentNumber.toLowerCase();
      final className = student.className.toLowerCase();
      final query = _searchQuery.toLowerCase();

      return fullName.contains(query) ||
          studentNumber.contains(query) ||
          className.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        centerTitle: true,
        title: const Text(
          'Öğrenciler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Öğrenci Ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Student>>(
              future: _studentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final students = snapshot.data ?? [];
                final filteredStudents = _filterStudents(students);

                if (filteredStudents.isEmpty) {
                  return const Center(
                    child: Text('Arama kriterlerine uygun öğrenci bulunamadı.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return Dismissible(
                      key: Key(student.id.toString()),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Düzenleme işlemi
                          _showEditStudentDialog(context, student);
                          return false;
                        } else {
                          // Silme işlemi
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Öğrenci Silme'),
                                content: Text(
                                    '${student.name} ${student.surname} öğrencisini silmek istediğinize emin misiniz?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text(
                                      'Sil',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      },
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          try {
                            await _databaseService.deleteStudent(student.id!);
                            _refreshStudents();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${student.name} ${student.surname} başarıyla silindi'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Öğrenci silinirken bir hata oluştu: $e'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text('${student.name} ${student.surname}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Öğrenci No: ${student.studentNumber}'),
                              Text('Sınıf: ${student.className}'),
                            ],
                          ),
                          trailing: FutureBuilder<int>(
                            future: _databaseService
                                .getActiveBorrowCountByStudentId(student.id!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text('Yükleniyor...');
                              }
                              final count = snapshot.data ?? 0;
                              return Text(
                                '$count Kitap',
                                style: TextStyle(
                                  color: count > 0 ? Colors.blue : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentDetailScreen(student: student),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
}
