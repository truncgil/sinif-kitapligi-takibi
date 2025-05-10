import 'package:flutter/material.dart';
import '../services/database/database_service.dart';

class LibraryProvider extends ChangeNotifier {
  final DatabaseService _databaseService;
  List<Map<String, dynamic>>? _borrowedBooks;
  bool _isLoading = false;

  LibraryProvider(this._databaseService) {
    // Provider oluşturulduğunda ilk verileri yükle
    refreshBorrowedBooks();
  }

  List<Map<String, dynamic>> get borrowedBooks => _borrowedBooks ?? [];
  bool get isLoading => _isLoading;

  Future<void> refreshBorrowedBooks() async {
    try {
      _isLoading = true;
      notifyListeners();

      _borrowedBooks = await _databaseService.getCurrentlyBorrowedBooks();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Ödünç alınan kitaplar yüklenirken hata: $e');
      notifyListeners();
    }
  }
}
