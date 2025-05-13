import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database/database_service.dart';
import '../services/purchase_service.dart';

class BookLimitProvider with ChangeNotifier {
  final PurchaseService _purchaseService;
  final DatabaseService _databaseService;
  bool _isUnlimited = false;
  int _bookCount = 0;
  static const int _freeBookLimit = 20;

  BookLimitProvider(this._purchaseService, this._databaseService) {
    _initialize();
  }

  Future<void> _initialize() async {
    _isUnlimited = await _purchaseService.isUnlimitedBooksPurchased();
    await _updateBookCount();
    notifyListeners();
  }

  Future<void> _updateBookCount() async {
    final books = await _databaseService.getAllBooks();
    _bookCount = books.length;
  }

  bool get canAddMoreBooks => _isUnlimited || _bookCount < _freeBookLimit;

  Future<bool> purchaseUnlimitedBooks() async {
    final success = await _purchaseService.purchaseUnlimitedBooks();
    if (success) {
      _isUnlimited = true;
      notifyListeners();
    }
    return success;
  }

  Future<void> incrementBookCount() async {
    if (!canAddMoreBooks) {
      throw Exception(
          'Kitap ekleme limitine ulaşıldı. Sınırsız kitap eklemek için satın alma yapın.');
    }
    _bookCount++;
    notifyListeners();
  }

  void decrementBookCount() {
    if (_bookCount > 0) {
      _bookCount--;
      notifyListeners();
    }
  }

  int get remainingFreeBooks => _freeBookLimit - _bookCount;
  bool get isUnlimited => _isUnlimited;
  int get currentBookCount => _bookCount;
}
