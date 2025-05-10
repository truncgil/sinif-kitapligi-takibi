import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../models/student.dart';
import '../../models/book.dart';
import '../../models/borrow_record.dart';

/// Veritabanı işlemlerini yöneten servis sınıfı
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Veritabanını başlatır ve gerekli tabloları oluşturur
  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      // Web platformu için SQLite FFI Web kullanımı
      var factory = databaseFactoryFfiWeb;
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
    // Öğrenci tablosu
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        studentNumber TEXT NOT NULL UNIQUE,
        className TEXT NOT NULL
      )
    ''');

    // Kitap tablosu
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
  }

  // Öğrenci işlemleri
  Future<int> insertStudent(Student student) async {
    final db = await database;
    return await db.insert('students', student.toMap());
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

  // Kitap işlemleri
  Future<int> insertBook(Book book) async {
    final db = await database;
    return await db.insert('books', book.toMap());
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
}
