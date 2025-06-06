import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';
import '../../models/class_room.dart';

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
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
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

    if (kIsWeb) {
      // Web platformu için SQLite FFI Web kullanımı
      var factory = _databaseFactory ?? databaseFactoryFfiWeb;
      _database = await factory.openDatabase(
        'library.db',
        options: OpenDatabaseOptions(
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
          },
        ),
      );
    } else {
      // Mobil platformlar için normal SQLite kullanımı
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'library.db');

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
        },
      );
    }
  }
}
