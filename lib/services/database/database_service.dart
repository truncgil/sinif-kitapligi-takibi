import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../models/class_room.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Veritabanı işlemlerini yöneten servis sınıfı
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static var _databaseFactory;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  void setDatabaseFactory(var factory) {
    _databaseFactory = factory;
  }

  /// Veritabanını sıfırlar ve yeniden oluşturur
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    if (kIsWeb) {
      var factory = _databaseFactory ?? databaseFactoryFfiWeb;
      await factory.deleteDatabase('library.db');
    } else {
      String path = join(await getDatabasesPath(), 'library.db');
      await deleteDatabase(path);
    }

    // Veritabanını yeniden başlat
    await initialize();
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Veritabanını başlatır ve gerekli tabloları oluşturur
  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Web platformu için SQLite FFI Web kullanımı
      var factory = _databaseFactory ?? databaseFactoryFfiWeb;
      return await factory.openDatabase(
        'library.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: _onCreate,
        ),
      );
    } else {
      // Mobil platformlar için normal SQLite kullanımı
      sqfliteFfiInit();
      String path = join(await getDatabasesPath(), 'library.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        studentNumber TEXT NOT NULL,
        className TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        isbn TEXT NOT NULL,
        barcode TEXT NOT NULL UNIQUE,
        isAvailable INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE borrow_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentId INTEGER NOT NULL,
        bookId INTEGER NOT NULL,
        borrowDate TEXT NOT NULL,
        returnDate TEXT,
        isReturned INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (studentId) REFERENCES students (id),
        FOREIGN KEY (bookId) REFERENCES books (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE class_rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT
      )
    ''');
  }

  // Öğrenci işlemleri
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
  }

  Future<void> deleteStudent(int id) async {
    final db = await database;
    await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStudent(Student student) async {
    final db = await database;
    await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<List<Student>> getAllStudents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('students');
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  Future<Student?> getStudentById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Student.fromMap(maps.first);
  }

  Future<List<Student>> getStudentsByClass(String className) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'students',
      where: 'className = ?',
      whereArgs: [className],
    );
    return List.generate(maps.length, (i) => Student.fromMap(maps[i]));
  }

  // Kitap işlemleri
  Future<int> insertBook(Book book) async {
    final db = await database;
    return await db.insert('books', book.toMap());
  }

  Future<void> deleteBook(int id) async {
    final db = await database;
    await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateBook(Book book) async {
    final db = await database;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<List<Book>> getAllBooks() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('books');
      return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
    } catch (e) {
      debugPrint('Kitaplar getirilirken hata: $e');
      // Hata durumunda boş liste döndür
      return <Book>[];
    }
  }

  Future<Book?> getBookByBarcode(String barcode) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<Book?> getBookById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<void> updateBookAvailability(int bookId, bool isAvailable) async {
    final db = await database;
    await db.update(
      'books',
      {'isAvailable': isAvailable ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // Ödünç alma kayıtları işlemleri
  Future<int> insertBorrowRecord(BorrowRecord record) async {
    final db = await database;
    return await db.insert('borrow_records', record.toMap());
  }

  Future<List<BorrowRecord>> getAllBorrowRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_records',
      orderBy: 'borrowDate DESC',
    );
    return List.generate(maps.length, (i) => BorrowRecord.fromMap(maps[i]));
  }

  Future<int> updateBorrowRecord(BorrowRecord record) async {
    final db = await database;
    return await db.update(
      'borrow_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<BorrowRecord>> getBorrowRecordsByStudent(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_records',
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'borrowDate DESC',
    );
    return List.generate(maps.length, (i) => BorrowRecord.fromMap(maps[i]));
  }

  Future<List<BorrowRecord>> getBorrowRecordsByBook(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_records',
      where: 'bookId = ?',
      whereArgs: [bookId],
      orderBy: 'borrowDate DESC',
    );
    return List.generate(maps.length, (i) => BorrowRecord.fromMap(maps[i]));
  }

  // Sınıf işlemleri
  Future<List<ClassRoom>> getAllClassRooms() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('class_rooms');
    return List.generate(maps.length, (i) => ClassRoom.fromMap(maps[i]));
  }

  Future<int> insertClassRoom(ClassRoom classRoom) async {
    final db = await database;
    return await db.insert('class_rooms', classRoom.toMap());
  }

  Future<void> updateClassRoom(ClassRoom classRoom) async {
    final db = await database;
    await db.update(
      'class_rooms',
      classRoom.toMap(),
      where: 'id = ?',
      whereArgs: [classRoom.id],
    );
  }

  Future<void> deleteClassRoom(int id) async {
    final db = await database;
    await db.delete(
      'class_rooms',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCurrentlyBorrowedBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> records = await db.query(
      'borrow_records',
      where: 'isReturned = ?',
      whereArgs: [0],
      orderBy: 'borrowDate DESC',
    );

    List<Map<String, dynamic>> result = [];
    for (var record in records) {
      final borrowRecord = BorrowRecord.fromMap(record);
      final book = await getBookById(borrowRecord.bookId);
      final student = await getStudentById(borrowRecord.studentId);

      if (book != null && student != null) {
        result.add({
          'book': book,
          'borrowDate': borrowRecord.borrowDate,
          'studentName': '${student.name} ${student.surname}',
        });
      }
    }

    return result;
  }

  Future<void> initialize() async {
    if (_database != null) return;

    // Veritabanının daha önce oluşturulup oluşturulmadığını kontrol et
    bool isFirstRun = false;

    if (kIsWeb) {
      // Web platformu için SQLite FFI Web kullanımı
      var factory = _databaseFactory ?? databaseFactoryFfiWeb;
      _database = await factory.openDatabase(
        'library.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (Database db, int version) async {
            isFirstRun = true;
            // Sınıflar tablosu
            await db.execute('''
              CREATE TABLE class_rooms (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                description TEXT
              )
            ''');

            // Öğrenciler tablosu
            await db.execute('''
              CREATE TABLE students (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                surname TEXT NOT NULL,
                studentNumber TEXT NOT NULL,
                className TEXT NOT NULL
              )
            ''');

            // Kitaplar tablosu
            await db.execute('''
              CREATE TABLE books (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                author TEXT NOT NULL,
                isbn TEXT NOT NULL,
                barcode TEXT NOT NULL UNIQUE,
                isAvailable INTEGER NOT NULL DEFAULT 1
              )
            ''');

            // Ödünç alma kayıtları tablosu
            await db.execute('''
              CREATE TABLE borrow_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                studentId INTEGER NOT NULL,
                bookId INTEGER NOT NULL,
                borrowDate TEXT NOT NULL,
                returnDate TEXT,
                isReturned INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (studentId) REFERENCES students (id),
                FOREIGN KEY (bookId) REFERENCES books (id)
              )
            ''');

            // Örnek verileri ekle
            await _insertDemoData(db);
          },
        ),
      );
    } else {
      // Mobil platformlar için normal SQLite kullanımı
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'library.db');

      // Veritabanının daha önce var olup olmadığını kontrol et
      bool dbExists = await databaseExists(path);
      isFirstRun = !dbExists;

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          // Sınıflar tablosu
          await db.execute('''
            CREATE TABLE class_rooms (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT
            )
          ''');

          // Öğrenciler tablosu
          await db.execute('''
            CREATE TABLE students (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              surname TEXT NOT NULL,
              studentNumber TEXT NOT NULL,
              className TEXT NOT NULL
            )
          ''');

          // Kitaplar tablosu
          await db.execute('''
            CREATE TABLE books (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              author TEXT NOT NULL,
              isbn TEXT NOT NULL,
              barcode TEXT NOT NULL UNIQUE,
              isAvailable INTEGER NOT NULL DEFAULT 1
            )
          ''');

          // Ödünç alma kayıtları tablosu
          await db.execute('''
            CREATE TABLE borrow_records (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              studentId INTEGER NOT NULL,
              bookId INTEGER NOT NULL,
              borrowDate TEXT NOT NULL,
              returnDate TEXT,
              isReturned INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (studentId) REFERENCES students (id),
              FOREIGN KEY (bookId) REFERENCES books (id)
            )
          ''');

          // Örnek verileri ekle
          await _insertDemoData(db);
        },
      );
    }
  }

  /// Örnek demo verileri ekler (sadece ilk kurulumda çalışır)
  Future<void> _insertDemoData(Database db) async {
    // Sınıfları ekle
    List<Map<String, dynamic>> classRooms = [
      {'name': '1-A', 'description': '1. Sınıf A Şubesi'},
      {'name': '2-B', 'description': '2. Sınıf B Şubesi'},
      {'name': '3-C', 'description': '3. Sınıf C Şubesi'},
      {'name': '4-A', 'description': '4. Sınıf A Şubesi'},
    ];

    for (var classRoom in classRooms) {
      await db.insert('class_rooms', classRoom);
    }

    // Öğrencileri ekle
    List<Map<String, dynamic>> students = [
      {
        'name': 'Ahmet',
        'surname': 'Yılmaz',
        'studentNumber': '1001',
        'className': '1-A'
      },
      {
        'name': 'Ayşe',
        'surname': 'Kaya',
        'studentNumber': '1002',
        'className': '1-A'
      },
      {
        'name': 'Mehmet',
        'surname': 'Demir',
        'studentNumber': '2001',
        'className': '2-B'
      },
      {
        'name': 'Zeynep',
        'surname': 'Çelik',
        'studentNumber': '2002',
        'className': '2-B'
      },
      {
        'name': 'Muhammed Reva',
        'surname': 'Tunç',
        'studentNumber': '3001',
        'className': '3-C'
      },
      {
        'name': 'Damlanur Sevgi',
        'surname': 'Tunç',
        'studentNumber': '4001',
        'className': '4-A'
      },
    ];

    for (var student in students) {
      await db.insert('students', student);
    }

    // Kitapları ekle
    List<Map<String, dynamic>> books = [
      {
        'title': 'Adobe Premiere Pro ile Montaj Teknikleri',
        'author': 'Ümit Tunç',
        'isbn': '9789750719451',
        'barcode': 'KP002432',
        'isAvailable': 1
      },
      {
        'title': 'Küçük Prens',
        'author': 'Antoine de Saint-Exupéry',
        'isbn': '9789750719981',
        'barcode': 'KP001',
        'isAvailable': 1
      },
      {
        'title': 'Şeker Portakalı',
        'author': 'Jose Mauro De Vasconcelos',
        'isbn': '9789750726477',
        'barcode': 'SP001',
        'isAvailable': 1
      },
      {
        'title': 'Küçük Kara Balık',
        'author': 'Samed Behrengi',
        'isbn': '9789944717519',
        'barcode': 'KKB001',
        'isAvailable': 1
      },
      {
        'title': 'Martı Jonathan Livingston',
        'author': 'Richard Bach',
        'isbn': '9789754587272',
        'barcode': 'MJL001',
        'isAvailable': 1
      },
      {
        'title': 'Beyaz Diş',
        'author': 'Jack London',
        'isbn': '9789750736377',
        'barcode': 'BD001',
        'isAvailable': 1
      },
      {
        'title': 'Simyacı',
        'author': 'Paulo Coelho',
        'isbn': '9789750726538',
        'barcode': 'SM001',
        'isAvailable': 1
      },
      {
        'title': 'Hayvan Çiftliği',
        'author': 'George Orwell',
        'isbn': '9789753638029',
        'barcode': 'HC001',
        'isAvailable': 1
      },
      {
        'title': 'Fareler ve İnsanlar',
        'author': 'John Steinbeck',
        'isbn': '9789753638043',
        'barcode': 'FI001',
        'isAvailable': 1
      },
    ];

    for (var book in books) {
      await db.insert('books', book);
    }
  }

  // Aktif ödünç kaydını kitap ID'sine göre getir
  Future<BorrowRecord?> getActiveBorrowRecordByBookId(int bookId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_records',
      where: 'bookId = ? AND isReturned = 0',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return BorrowRecord.fromMap(maps.first);
  }

  // Ödünç kaydını iade edildi olarak güncelle
  Future<void> updateBorrowRecordAsReturned(int borrowRecordId) async {
    final db = await database;
    await db.update(
      'borrow_records',
      {
        'returnDate': DateTime.now().toIso8601String(),
        'isReturned': 1,
      },
      where: 'id = ?',
      whereArgs: [borrowRecordId],
    );
  }

  Future<List<BorrowRecord>> getBorrowRecordsByStudentId(int studentId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'borrow_records',
      where: 'studentId = ? AND isReturned = 0',
      whereArgs: [studentId],
    );
    return List.generate(maps.length, (i) => BorrowRecord.fromMap(maps[i]));
  }

  Future<int> getActiveBorrowCountByStudentId(int studentId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM borrow_records 
      WHERE studentId = ? AND isReturned = 0
    ''', [studentId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getStudentCountByClassRoom(String className) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM students 
      WHERE className = ?
    ''', [className]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Örnek 20 kitap ekler
  Future<void> insertSampleBooks() async {
    final db = await database;
    List<Map<String, dynamic>> books = [
      {
        'title': 'Suç ve Ceza',
        'author': 'Fyodor Dostoyevski',
        'isbn': '9789750719452',
        'barcode': 'SC001',
        'isAvailable': 1
      },
      {
        'title': 'Sefiller',
        'author': 'Victor Hugo',
        'isbn': '9789750719453',
        'barcode': 'SF001',
        'isAvailable': 1
      },
      {
        'title': '1984',
        'author': 'George Orwell',
        'isbn': '9789750719454',
        'barcode': '1984001',
        'isAvailable': 1
      },
      {
        'title': 'Dönüşüm',
        'author': 'Franz Kafka',
        'isbn': '9789750719455',
        'barcode': 'DN001',
        'isAvailable': 1
      },
      {
        'title': 'Yüzüklerin Efendisi',
        'author': 'J.R.R. Tolkien',
        'isbn': '9789750719456',
        'barcode': 'YE001',
        'isAvailable': 1
      },
      {
        'title': 'Saatleri Ayarlama Enstitüsü',
        'author': 'Ahmet Hamdi Tanpınar',
        'isbn': '9789750719457',
        'barcode': 'SAE001',
        'isAvailable': 1
      },
      {
        'title': 'Tutunamayanlar',
        'author': 'Oğuz Atay',
        'isbn': '9789750719458',
        'barcode': 'TT001',
        'isAvailable': 1
      },
      {
        'title': 'Kürk Mantolu Madonna',
        'author': 'Sabahattin Ali',
        'isbn': '9789750719459',
        'barcode': 'KMM001',
        'isAvailable': 1
      },
      {
        'title': 'İnce Memed',
        'author': 'Yaşar Kemal',
        'isbn': '9789750719460',
        'barcode': 'IM001',
        'isAvailable': 1
      },
      {
        'title': 'Çalıkuşu',
        'author': 'Reşat Nuri Güntekin',
        'isbn': '9789750719461',
        'barcode': 'CK001',
        'isAvailable': 1
      },
      {
        'title': 'Fareler ve İnsanlar',
        'author': 'John Steinbeck',
        'isbn': '9789750719462',
        'barcode': 'FI002',
        'isAvailable': 1
      },
      {
        'title': 'Beyaz Diş',
        'author': 'Jack London',
        'isbn': '9789750719463',
        'barcode': 'BD002',
        'isAvailable': 1
      },
      {
        'title': 'Simyacı',
        'author': 'Paulo Coelho',
        'isbn': '9789750719464',
        'barcode': 'SM002',
        'isAvailable': 1
      },
      {
        'title': 'Küçük Prens',
        'author': 'Antoine de Saint-Exupéry',
        'isbn': '9789750719465',
        'barcode': 'KP002',
        'isAvailable': 1
      },
      {
        'title': 'Şeker Portakalı',
        'author': 'Jose Mauro De Vasconcelos',
        'isbn': '9789750719466',
        'barcode': 'SP002',
        'isAvailable': 1
      },
      {
        'title': 'Küçük Kara Balık',
        'author': 'Samed Behrengi',
        'isbn': '9789750719467',
        'barcode': 'KKB002',
        'isAvailable': 1
      },
      {
        'title': 'Martı Jonathan Livingston',
        'author': 'Richard Bach',
        'isbn': '9789750719468',
        'barcode': 'MJL002',
        'isAvailable': 1
      },
      {
        'title': 'Hayvan Çiftliği',
        'author': 'George Orwell',
        'isbn': '9789750719469',
        'barcode': 'HC002',
        'isAvailable': 1
      },
      {
        'title': 'Dönüşüm',
        'author': 'Franz Kafka',
        'isbn': '9789750719470',
        'barcode': 'DN002',
        'isAvailable': 1
      },
      {
        'title': 'Suç ve Ceza',
        'author': 'Fyodor Dostoyevski',
        'isbn': '9789750719471',
        'barcode': 'SC002',
        'isAvailable': 1
      }
    ];

    for (var book in books) {
      await db.insert('books', book);
    }
  }
}
