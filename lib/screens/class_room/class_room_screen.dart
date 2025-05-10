import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/class_room.dart';
import '../../services/database/database_service.dart';

/// Sınıf işlemleri ekranı
class ClassRoomScreen extends StatefulWidget {
  const ClassRoomScreen({super.key});

  @override
  State<ClassRoomScreen> createState() => _ClassRoomScreenState();
}

class _ClassRoomScreenState extends State<ClassRoomScreen> {
  late Future<List<ClassRoom>> _classRoomsFuture;
  late DatabaseService _databaseService;

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
        title: const Text('Sınıflar'),
      ),
      body: FutureBuilder<List<ClassRoom>>(
        future: _classRoomsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final classRooms = snapshot.data ?? [];

          if (classRooms.isEmpty) {
            return const Center(
              child: Text('Henüz sınıf kaydı bulunmamaktadır.'),
            );
          }

          return ListView.builder(
            itemCount: classRooms.length,
            itemBuilder: (context, index) {
              final classRoom = classRooms[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.class_),
                  ),
                  title: Text(classRoom.name),
                  subtitle: Text(classRoom.description ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditClassRoomDialog(context, classRoom),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () =>
                            _showDeleteClassRoomDialog(context, classRoom),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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

  Future<void> _showDeleteClassRoomDialog(
      BuildContext context, ClassRoom classRoom) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sınıf Silme'),
        content: Text(
            '${classRoom.name} sınıfını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _databaseService.deleteClassRoom(classRoom.id!);
                _refreshClassRooms();

                if (!mounted) return;
                Navigator.pop(context);
                _showSuccessMessage('Sınıf başarıyla silindi.');
              } catch (e) {
                _showErrorMessage('Sınıf silinirken bir hata oluştu: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
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
