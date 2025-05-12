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

  /// Dışarıdan kitap ekleme dialogunu barkod ile açmak için static fonksiyon
  static Future<void> showAddBookDialogWithBarcode(
      BuildContext context, String barcode) async {
    // BookScreen'in state'ine erişmek için bir GlobalKey kullanılabilir veya
    // doğrudan fonksiyonu burada tanımlayabiliriz. Ancak _showAddBookWithBarcode private olduğu için,
    // fonksiyonu buraya taşıyoruz.
    final formKey = GlobalKey<FormState>();
    String title = '';
    String author = '';
    String isbn = '';

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
                autofocus: true,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Yazar'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Yazar boş olamaz' : null,
                onSaved: (value) => author = value ?? '',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Barkod: $barcode',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                  final dbService =
                      Provider.of<DatabaseService>(context, listen: false);
                  final book = Book(
                    title: title,
                    author: author,
                    isbn: isbn,
                    barcode: barcode,
                  );
                  await dbService.insertBook(book);
                  // Kitaplar ekranı açıksa yenileme yapılabilir
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title başarıyla eklendi'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kitap eklenirken bir hata oluştu: $e'),
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
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

class _BookScreenState extends State<BookScreen> {
  late Future<List<Book>> _booksFuture;
  late DatabaseService _databaseService;
  final _barcodeScannerService = BarcodeScannerService();
  String _searchQuery = '';
  String _filterStatus = 'Tümü'; // 'Tümü', 'Mevcut', 'Ödünç Verildi'

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

  List<Book> _filterBooks(List<Book> books) {
    var filteredBooks = books;

    // Önce durum filtresini uygula
    if (_filterStatus != 'Tümü') {
      filteredBooks = filteredBooks.where((book) {
        if (_filterStatus == 'Mevcut') {
          return book.isAvailable;
        } else {
          return !book.isAvailable;
        }
      }).toList();
    }

    // Sonra arama filtresini uygula
    if (_searchQuery.isNotEmpty) {
      filteredBooks = filteredBooks.where((book) {
        final title = book.title.toLowerCase();
        final author = book.author.toLowerCase();
        final isbn = book.isbn.toLowerCase();
        final barcode = book.barcode.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) ||
            author.contains(query) ||
            isbn.contains(query) ||
            barcode.contains(query);
      }).toList();
    }

    return filteredBooks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Kitap ara...',
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
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ToggleButtons(
                    isSelected: [
                      _filterStatus == 'Tümü',
                      _filterStatus == 'Mevcut',
                      _filterStatus == 'Ödünç Verildi',
                    ],
                    onPressed: (index) {
                      setState(() {
                        switch (index) {
                          case 0:
                            _filterStatus = 'Tümü';
                            break;
                          case 1:
                            _filterStatus = 'Mevcut';
                            break;
                          case 2:
                            _filterStatus = 'Ödünç Verildi';
                            break;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    selectedBorderColor: const Color(0xFF04BF61),
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF04BF61),
                    color: Colors.black,
                    borderColor: Colors.grey,
                    children: const [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Tümü', textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Mevcut', textAlign: TextAlign.center),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Ödünç Verildi',
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Book>>(
              future: _booksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final books = snapshot.data ?? [];
                final filteredBooks = _filterBooks(books);

                if (filteredBooks.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Henüz kitap kaydı bulunmamaktadır.'
                          : 'Arama sonucu bulunamadı.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    return Dismissible(
                      key: Key(book.id.toString()),
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
                          _showEditBookDialog(context, book);
                          return false;
                        } else {
                          // Silme işlemi
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Kitabı Sil'),
                                content: Text(
                                    '${book.title} kitabını silmek istediğinize emin misiniz?'),
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
                            await _databaseService.deleteBook(book.id!);
                            _refreshBooks();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${book.title} başarıyla silindi'),
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
                                    'Kitap silinirken bir hata oluştu: $e'),
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
                            child: Icon(Icons.book),
                          ),
                          title: Text(book.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(book.author),
                              Text('ISBN: ${book.isbn}'),
                              Text('Barkod: ${book.barcode}'),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  book.isAvailable ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              book.isAvailable ? 'Mevcut' : 'Ödünç Verildi',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
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
    final TextEditingController barcodeController = TextEditingController();

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
                initialValue: isbn,
                onSaved: (value) => isbn = value ?? '',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Barkod'),
                      controller: barcodeController,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Barkod boş olamaz' : null,
                      onSaved: (value) => barcode = value ?? '',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      // Tarama ekranını aç
                      Navigator.pop(context);
                      _scanBarcodeAndAddBook();
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
                    SnackBar(
                      content: Text('$title başarıyla eklendi'),
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
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kitap eklenirken bir hata oluştu: $e'),
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
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcodeAndAddBook() async {
    try {
      final scannedBarcode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerPage(),
        ),
      );

      if (scannedBarcode == null || scannedBarcode.isEmpty) {
        // Tarama iptal edildi veya başarısız oldu
        _showAddBookDialog(context);
        return;
      }

      // Barkodu sistemde kontrol et
      final existingBook =
          await _databaseService.getBookByBarcode(scannedBarcode);

      if (existingBook != null) {
        // Kitap zaten var, kullanıcıya bildir
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bu barkoda sahip bir kitap zaten sistemde mevcut: ${existingBook.title}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        _showAddBookDialog(context);
      } else {
        // Kitap yok, yeni kitap ekleme formunu göster
        _showAddBookWithBarcode(context, scannedBarcode);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barkod tarama işlemi sırasında bir hata oluştu: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      _showAddBookDialog(context);
    }
  }

  Future<void> _showAddBookWithBarcode(
      BuildContext context, String barcode) async {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String author = '';
    String isbn = '';

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
                autofocus: true,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Yazar'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Yazar boş olamaz' : null,
                onSaved: (value) => author = value ?? '',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Barkod: $barcode',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
                    SnackBar(
                      content: Text('$title başarıyla eklendi'),
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
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kitap eklenirken bir hata oluştu: $e'),
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
            child: const Text('Ekle'),
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
    final TextEditingController barcodeController =
        TextEditingController(text: barcode);

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
                onSaved: (value) => isbn = value ?? '',
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Barkod'),
                      controller: barcodeController,
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Barkod boş olamaz' : null,
                      onSaved: (value) => barcode = value ?? '',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      // Mevcut dialogu kapat
                      Navigator.pop(context);

                      // Barkod tarayıcıyı aç
                      final scannedBarcode = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BarcodeScannerPage(),
                        ),
                      );

                      if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
                        // Tarama başarılı, editDialog'u yeniden aç ve barkodu güncelle
                        barcode = scannedBarcode;
                        _showEditBookDialogWithBarcode(context, book, barcode);
                      } else {
                        // Tarama başarısız, dialogu tekrar aç
                        _showEditBookDialog(context, book);
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

  // Taranan barkod ile düzenleme dialogunu yeniden aç
  Future<void> _showEditBookDialogWithBarcode(
      BuildContext context, Book book, String newBarcode) async {
    final formKey = GlobalKey<FormState>();
    String title = book.title;
    String author = book.author;
    String isbn = book.isbn;
    String barcode = newBarcode;

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
                onSaved: (value) => isbn = value ?? '',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Barkod: $barcode',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
