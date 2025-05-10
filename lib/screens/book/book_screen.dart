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
                trailing: Container(
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
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                formKey.currentState?.save();
                final book = Book(
                  title: title,
                  author: author,
                  isbn: isbn,
                  barcode: barcode,
                );
                _databaseService.insertBook(book).then((_) {
                  _refreshBooks();
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
