import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../../services/api.dart';

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        product: Product.fromJson(j['product'] as Map<String, dynamic>),
        quantity: j['quantity'] as int,
      );
}

class CartProvider extends ChangeNotifier {
  static const int deliveryFeeCents = 4900;
  static const int freeDeliveryThresholdCents = 20000;
  static const int promoThresholdCents = 50000;
  static const int promoMaxCents = 20000;

  static const String _storageKey = 'cart_items_v1';

  final Map<String, CartItem> _items = {};
  CouponPreview? _appliedCoupon;
  String _couponError = '';
  bool _applyingCoupon = false;

  CartProvider() {
    _load();
    // Drop the basket the moment the server tells us the session ended
    // (e.g. another device signed in and rotated the session_id). Without
    // this the next user who logs in sees the previous user's items
    // until they manually empty the cart.
    ApiService.onUnauthorized(_clearOnSessionEnd);
  }

  void _clearOnSessionEnd() => clear();

  @override
  void dispose() {
    ApiService.offUnauthorized(_clearOnSessionEnd);
    super.dispose();
  }

  Map<String, CartItem> get items => _items;

  int get totalItems => _items.values.fold(0, (s, i) => s + i.quantity);

  int get subtotalCents =>
      _items.values.fold(0, (s, i) => s + i.product.priceCents * i.quantity);

  int get totalCents => subtotalCents;

  int get promoDiscountCents {
    if (subtotalCents < promoThresholdCents) return 0;
    final half = subtotalCents ~/ 2;
    return half > promoMaxCents ? promoMaxCents : half;
  }

  int get couponDiscountCents => _appliedCoupon?.discountCents ?? 0;

  int get deliveryFeeCentsApplied {
    if (_items.isEmpty) return 0;
    if (subtotalCents >= freeDeliveryThresholdCents) return 0;
    return deliveryFeeCents;
  }

  int get grandTotalCents {
    final t = subtotalCents -
        promoDiscountCents -
        couponDiscountCents +
        deliveryFeeCentsApplied;
    return t < 0 ? 0 : t;
  }

  CouponPreview? get appliedCoupon => _appliedCoupon;
  String get couponError => _couponError;
  bool get applyingCoupon => _applyingCoupon;

  int quantity(String uniqueId) => _items[uniqueId]?.quantity ?? 0;

  void add(Product p) {
    if (_items.containsKey(p.uniqueId)) {
      _items[p.uniqueId]!.quantity++;
    } else {
      _items[p.uniqueId] = CartItem(product: p);
    }
    notifyListeners();
    _save();
    _revalidateCoupon();
  }

  void remove(String uniqueId) {
    if (!_items.containsKey(uniqueId)) return;
    if (_items[uniqueId]!.quantity > 1) {
      _items[uniqueId]!.quantity--;
    } else {
      _items.remove(uniqueId);
    }
    notifyListeners();
    _save();
    _revalidateCoupon();
  }

  void clear() {
    _items.clear();
    _appliedCoupon = null;
    _couponError = '';
    notifyListeners();
    _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _items.clear();
      decoded.forEach((key, value) {
        _items[key] = CartItem.fromJson(value as Map<String, dynamic>);
      });
      notifyListeners();
    } catch (_) {
      // ignore: corrupt or incompatible payload — start fresh
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_items.isEmpty) {
        await prefs.remove(_storageKey);
        return;
      }
      final encoded = jsonEncode(
        _items.map((k, v) => MapEntry(k, v.toJson())),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  Future<bool> applyCoupon(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return false;
    if (subtotalCents <= 0) {
      _couponError = 'Add items to your cart first.';
      notifyListeners();
      return false;
    }
    _applyingCoupon = true;
    _couponError = '';
    notifyListeners();
    try {
      final preview = await ApiService.previewCoupon(trimmed, subtotalCents);
      _appliedCoupon = preview;
      _couponError = '';
      return true;
    } catch (e) {
      _appliedCoupon = null;
      _couponError = e.toString();
      return false;
    } finally {
      _applyingCoupon = false;
      notifyListeners();
    }
  }

  void clearCoupon() {
    _appliedCoupon = null;
    _couponError = '';
    notifyListeners();
  }

  Future<void> _revalidateCoupon() async {
    final code = _appliedCoupon?.code;
    if (code == null) return;
    if (subtotalCents <= 0) {
      _appliedCoupon = null;
      notifyListeners();
      return;
    }
    try {
      final preview = await ApiService.previewCoupon(code, subtotalCents);
      _appliedCoupon = preview;
      notifyListeners();
    } catch (_) {
      _appliedCoupon = null;
      notifyListeners();
    }
  }

  static CartProvider of(BuildContext context) =>
      Provider.of<CartProvider>(context);
}
