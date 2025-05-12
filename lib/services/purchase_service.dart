import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  static const String _unlimitedBooksKey = 'unlimited_books_purchased';
  static const String _productId =
      'unlimited_books'; // App Store ve Play Store'da tanımlanacak ürün ID'si

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final SharedPreferences _prefs;

  PurchaseService(this._prefs);

  Future<bool> isUnlimitedBooksPurchased() async {
    return _prefs.getBool(_unlimitedBooksKey) ?? false;
  }

  Future<void> checkPurchaseStatus() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) return;

    // Satın almaları geri yükle
    await _inAppPurchase.restorePurchases();
  }

  Future<void> _savePurchaseStatus(bool purchased) async {
    await _prefs.setBool(_unlimitedBooksKey, purchased);
  }

  Future<bool> purchaseUnlimitedBooks() async {
    try {
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails({_productId});

      if (response.notFoundIDs.isNotEmpty) {
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: response.productDetails.first,
      );

      final bool success =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (success) {
        await _savePurchaseStatus(true);
        return true;
      }

      return false;
    } catch (e) {
      print('Satın alma hatası: $e');
      return false;
    }
  }
}
