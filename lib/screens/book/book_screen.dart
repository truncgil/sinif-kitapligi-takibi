import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../services/database/database_service.dart';
import '../../services/barcode_scanner/barcode_scanner_service.dart';

/// Kitap işlemleri ekranı
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late Future<List<Book>> _booksFuture;
  late DatabaseService _databaseService;
  final _barcodeScannerService = BarcodeScannerService();

  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _refreshBooks();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = _databaseService.getAllBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplar'),
      ),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final books = snapshot.data ?? [];

          if (books.isEmpty) {
            return const Center(
              child: Text('Henüz kitap kaydı bulunmamaktadır.'),
            );
          }

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.book),
                ),
                title: Text(book.title),
                subtitle: Text(book.author),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: book.isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        book.isAvailable ? 'Mevcut' : 'Ödünç Verildi',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (book.isAvailable) ...[
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditBookDialog(context, book),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _showDeleteBookDialog(context, book),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBookDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddBookDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String author = '';
    String isbn = '';
    String barcode = '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Kitap Ekle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Kitap Adı'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Kitap adı boş olamaz' : null,
                onSaved: (value) => title = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Yazar'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Yazar boş olamaz' : null,
                onSaved: (value) => author = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ISBN'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'ISBN boş olamaz' : null,
                onSaved: (value) => isbn = value ?? '',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Barkod'),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Barkod boş olamaz' : null,
                      onSaved: (value) => barcode = value ?? '',
                      controller: TextEditingController(text: barcode),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final scannedBarcode =
                          await _barcodeScannerService.scanBarcode();
                      if (scannedBarcode.isNotEmpty) {
                        setState(() {
                          barcode = scannedBarcode;
                        });
                        formKey.currentState?.reset();
                      }
                    },
                  ),
                ],
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
                  // Önce barkodun benzersiz olup olmadığını kontrol et
                  final existingBook =
                      await _databaseService.getBookByBarcode(barcode);
                  if (existingBook != null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Bu barkoda sahip bir kitap zaten mevcut!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final book = Book(
                    title: title,
                    author: author,
                    isbn: isbn,
                    barcode: barcode,
                  );

                  await _databaseService.insertBook(book);
                  _refreshBooks();

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kitap başarıyla eklendi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kitap eklenirken bir hata oluştu: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteBookDialog(BuildContext context, Book book) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kitap Silme'),
        content:
            Text('${book.title} kitabını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _databaseService.deleteBook(book.id!);
                _refreshBooks();

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kitap başarıyla silindi.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kitap silinirken bir hata oluştu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sil'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBookDialog(BuildContext context, Book book) async {
    final formKey = GlobalKey<FormState>();
    String title = book.title;
    String author = book.author;
    String isbn = book.isbn;
    String barcode = book.barcode;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kitap Düzenle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Kitap Adı'),
                initialValue: title,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Kitap adı boş olamaz' : null,
                onSaved: (value) => title = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Yazar'),
                initialValue: author,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Yazar boş olamaz' : null,
                onSaved: (value) => author = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ISBN'),
                initialValue: isbn,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'ISBN boş olamaz' : null,
                onSaved: (value) => isbn = value ?? '',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Barkod'),
                      initialValue: barcode,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Barkod boş olamaz' : null,
                      onSaved: (value) => barcode = value ?? '',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final scannedBarcode =
                          await _barcodeScannerService.scanBarcode();
                      if (scannedBarcode.isNotEmpty) {
                        setState(() {
                          barcode = scannedBarcode;
                        });
                      }
                    },
                  ),
                ],
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
                  // Barkod değiştiyse kontrol et
                  if (barcode != book.barcode) {
                    final existingBook =
                        await _databaseService.getBookByBarcode(barcode);
                    if (existingBook != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Bu barkoda sahip bir kitap zaten mevcut!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  final updatedBook = Book(
                    id: book.id,
                    title: title,
                    author: author,
                    isbn: isbn,
                    barcode: barcode,
                    isAvailable: book.isAvailable,
                  );

                  await _databaseService.updateBook(updatedBook);
                  _refreshBooks();

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kitap başarıyla güncellendi.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kitap güncellenirken bir hata oluştu: $e'),
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
