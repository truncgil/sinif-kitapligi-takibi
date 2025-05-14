import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static const String _unlimitedBooksKey = 'unlimited_books_purchased';
  static const String _productId =
      'unlimited_books'; // App Store ve Play Store'da tanımlanacak ürün ID'si

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SharedPreferences _prefs;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isProcessing = false;
  Completer<bool>? _purchaseCompleter;

  PurchaseService(this._prefs) {
    _initializePurchaseListener();
    _checkExistingPurchase(); // Uygulama başlatıldığında mevcut satın almaları kontrol et
  }

  void _initializePurchaseListener() {
    _subscription = _inAppPurchase.purchaseStream.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        print('Satın alma dinleyici hatası: $error');
        _isProcessing = false;
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
      },
    );
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isProcessing = true;
        print('Satın alma işlemi bekliyor...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _isProcessing = false;
        print('Satın alma hatası: ${purchaseDetails.error}');
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _isProcessing = false;
        await _savePurchaseStatus(true);
        print('Satın alma başarılı!');
        _purchaseCompleter?.complete(true);
        _purchaseCompleter = null;
      }
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  Future<bool> isUnlimitedBooksPurchased() async {
    return _prefs.getBool(_unlimitedBooksKey) ?? false;
  }

  Future<void> checkPurchaseStatus() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      print('Satın alma servisi kullanılamıyor');
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Satın almaları geri yükleme hatası: $e');
    }
  }

  Future<void> _savePurchaseStatus(bool purchased) async {
    await _prefs.setBool(_unlimitedBooksKey, purchased);
  }

  Future<bool> purchaseUnlimitedBooks() async {
    // Önce mevcut satın almayı kontrol et
    final bool isPurchased = await isUnlimitedBooksPurchased();
    if (isPurchased) {
      print('Bu ürün zaten satın alınmış');
      return true;
    }

    if (_isProcessing) {
      print('Zaten bir satın alma işlemi devam ediyor');
      return false;
    }

    if (_purchaseCompleter != null) {
      print('Önceki satın alma işlemi henüz tamamlanmadı');
      return false;
    }

    _purchaseCompleter = Completer<bool>();

    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        print('Satın alma servisi kullanılamıyor');
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
        return false;
      }

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails({_productId});

      if (response.notFoundIDs.isNotEmpty) {
        print('Ürün bulunamadı: ${response.notFoundIDs}');
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
        return false;
      }

      if (response.productDetails.isEmpty) {
        print('Ürün detayları alınamadı');
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
        return false;
      }

      final ProductDetails productDetails = response.productDetails.first;

      // Test ortamı kontrolü
      if (productDetails.id.contains('test')) {
        print('Test ürünü tespit edildi');
        // Test ortamında ek güvenlik kontrolleri
        await Future.delayed(
            Duration(seconds: 1)); // Test ortamında minimum bekleme süresi
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
      );

      _isProcessing = true;
      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        _isProcessing = false;
        print('Satın alma başlatılamadı');
        _purchaseCompleter?.complete(false);
        _purchaseCompleter = null;
        return false;
      }

      // Satın alma işleminin tamamlanmasını bekle
      return await _purchaseCompleter!.future;
    } catch (e) {
      _isProcessing = false;
      print('Satın alma hatası: $e');
      _purchaseCompleter?.complete(false);
      _purchaseCompleter = null;
      return false;
    }
  }

  Future<void> _checkExistingPurchase() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) return;

      // Mevcut satın almaları kontrol et
      final bool isPurchased = await isUnlimitedBooksPurchased();
      if (isPurchased) {
        print('Daha önce yapılmış satın alma tespit edildi');
        await _savePurchaseStatus(true);
        return;
      }

      // Satın almaları geri yükle
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Mevcut satın alma kontrolü hatası: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _purchaseCompleter?.complete(false);
    _purchaseCompleter = null;
  }
}
