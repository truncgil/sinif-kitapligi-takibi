import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_room.dart';
import '../../services/database/database_service.dart';
import '../../screens/student/student_screen.dart';
import '../../constants/colors.dart';

/// Sınıf işlemleri ekranı
class ClassRoomScreen extends StatefulWidget {
  const ClassRoomScreen({super.key});

  @override
  State<ClassRoomScreen> createState() => _ClassRoomScreenState();
}

class _ClassRoomScreenState extends State<ClassRoomScreen> {
  late Future<List<ClassRoom>> _classRoomsFuture;
  late DatabaseService _databaseService;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshClassRooms();
  }

  void _refreshClassRooms() {
    setState(() {
      _classRoomsFuture = _databaseService.getAllClassRooms();
    });
  }

  List<ClassRoom> _filterClassRooms(List<ClassRoom> classRooms) {
    if (_searchQuery.isEmpty) return classRooms;

    return classRooms.where((classRoom) {
      final name = classRoom.name.toLowerCase();
      final description = (classRoom.description ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.classRoom,
        centerTitle: true,
        title: const Text(
          'Sınıflar',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Sınıf Ara...',
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
            child: FutureBuilder<List<ClassRoom>>(
              future: _classRoomsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final classRooms = snapshot.data ?? [];
                final filteredClassRooms = _filterClassRooms(classRooms);

                if (filteredClassRooms.isEmpty) {
                  return const Center(
                    child: Text('Arama kriterlerine uygun sınıf bulunamadı.'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredClassRooms.length,
                  itemBuilder: (context, index) {
                    final classRoom = filteredClassRooms[index];
                    return Dismissible(
                      key: Key(classRoom.id.toString()),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      secondaryBackground: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.endToStart) {
                          // Düzenleme işlemi
                          _showEditClassRoomDialog(context, classRoom);
                          return false;
                        } else {
                          // Silme işlemi
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Sınıf Silme'),
                                content: Text(
                                    '${classRoom.name} sınıfını silmek istediğinize emin misiniz?'),
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
                            await _databaseService
                                .deleteClassRoom(classRoom.id!);
                            _refreshClassRooms();
                            if (!mounted) return;
                            _showSuccessMessage(
                                '${classRoom.name} sınıfı başarıyla silindi.');
                          } catch (e) {
                            if (!mounted) return;
                            _showErrorMessage(
                                'Sınıf silinirken bir hata oluştu: $e');
                          }
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.class_),
                          ),
                          title: Text(classRoom.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(classRoom.description ?? ''),
                              FutureBuilder<int>(
                                future: _databaseService
                                    .getStudentCountByClassRoom(classRoom.name),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Text('Yükleniyor...');
                                  }
                                  final count = snapshot.data ?? 0;
                                  return Text(
                                    '$count Öğrenci',
                                    style: TextStyle(
                                      color:
                                          count > 0 ? Colors.blue : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentScreen(classRoom: classRoom),
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
        onPressed: () => _showAddClassRoomDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddClassRoomDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    String description = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Sınıf Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Sınıf Adı'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Sınıf adı boş olamaz' : null,
                onSaved: (value) => name = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Açıklama'),
                onSaved: (value) => description = value ?? '',
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
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();
                try {
                  final classRoom = ClassRoom(
                    name: name,
                    description: description,
                  );
                  await _databaseService.insertClassRoom(classRoom);
                  _refreshClassRooms();

                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSuccessMessage('Sınıf başarıyla eklendi.');
                } catch (e) {
                  _showErrorMessage('Sınıf eklenirken bir hata oluştu: $e');
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditClassRoomDialog(
      BuildContext context, ClassRoom classRoom) async {
    final formKey = GlobalKey<FormState>();
    String name = classRoom.name;
    String description = classRoom.description ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınıf Düzenle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Sınıf Adı'),
                initialValue: name,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Sınıf adı boş olamaz' : null,
                onSaved: (value) => name = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Açıklama'),
                initialValue: description,
                onSaved: (value) => description = value ?? '',
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
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();

                try {
                  final updatedClassRoom = ClassRoom(
                    id: classRoom.id,
                    name: name,
                    description: description,
                  );

                  await _databaseService.updateClassRoom(updatedClassRoom);
                  _refreshClassRooms();

                  if (!mounted) return;
                  Navigator.pop(context);
                  _showSuccessMessage('Sınıf başarıyla güncellendi.');
                } catch (e) {
                  _showErrorMessage('Sınıf güncellenirken bir hata oluştu: $e');
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
