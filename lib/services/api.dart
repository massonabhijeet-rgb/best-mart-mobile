import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const String kBaseUrl = 'https://bestmart-delivery-app-production.up.railway.app/api';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static String? _token;

  static Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  static Future<void> setToken(String t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', t);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final t = await token;
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<dynamic> _req(String method, String path,
      {Map<String, dynamic>? body, bool auth = false}) async {
    final uri = Uri.parse('$kBaseUrl$path');
    final headers = await _headers(auth: auth);
    http.Response res;
    switch (method) {
      case 'POST':
        res = await http.post(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'PATCH':
        res = await http.patch(uri, headers: headers, body: jsonEncode(body));
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: headers);
        break;
      default:
        res = await http.get(uri, headers: headers);
    }
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Request failed');
    }
    return data;
  }

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _req('POST', '/auth/login', body: {'email': email, 'password': password});
    await setToken(data['token']);
    return data;
  }

  static Future<Map<String, dynamic>> signup(String email, String password) async {
    final data = await _req('POST', '/auth/signup', body: {'email': email, 'password': password});
    await setToken(data['token']);
    return data;
  }

  static Future<void> deleteAccount() async {
    await _req('DELETE', '/auth/me', auth: true);
  }

  // OTP login
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final data = await _req('POST', '/auth/otp/send', body: {'phone': phone});
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    required String requestId,
  }) async {
    final data = await _req('POST', '/auth/otp/verify', body: {
      'phone': phone,
      'otp': otp,
      'requestId': requestId,
    });
    await setToken(data['token']);
    return data;
  }

  // Devices (push notification tokens)
  static Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _req('POST', '/devices',
        body: {'token': token, 'platform': platform}, auth: true);
  }

  static Future<void> unregisterDevice(String token) async {
    await _req('DELETE', '/devices/$token', auth: true);
  }

  // Products & Categories
  static Future<List<Product>> getProducts() async {
    final data = await _req('GET', '/products');
    return (data['products'] as List).map((p) => Product.fromJson(p)).toList();
  }

  static Future<ProductPage> getProductsPage({
    int page = 1,
    int pageSize = 20,
    int? categoryId,
    String? search,
    String? brand,
    bool? onOffer,
  }) async {
    final qp = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
    };
    if (categoryId != null) qp['categoryId'] = '$categoryId';
    if (search != null && search.isNotEmpty) qp['q'] = search;
    if (brand != null && brand.isNotEmpty) qp['brand'] = brand;
    if (onOffer == true) qp['onOffer'] = 'true';
    final query = Uri(queryParameters: qp).query;
    final data = await _req('GET', '/products/page?$query');
    return ProductPage.fromJson(data);
  }

  static Future<HomeRails> getHomeRails() async {
    final data = await _req('GET', '/products/home-rails');
    return HomeRails.fromJson(data);
  }

  static Future<StorefrontSpotlight> getSpotlight({String? mood}) async {
    final qs = (mood != null && mood.isNotEmpty)
        ? '?mood=${Uri.encodeComponent(mood)}'
        : '';
    final data = await _req('GET', '/products/spotlight$qs');
    return StorefrontSpotlight.fromJson(data);
  }

  static Future<List<Category>> getCategories() async {
    final data = await _req('GET', '/categories');
    return (data['categories'] as List).map((c) => Category.fromJson(c)).toList();
  }

  static Future<List<TempCategory>> getTempCategories({String? mood}) async {
    final qs = (mood != null && mood.isNotEmpty)
        ? '?mood=${Uri.encodeComponent(mood)}'
        : '';
    final data = await _req('GET', '/categories/temporary$qs');
    return ((data['tempCategories'] ?? []) as List)
        .map((c) => TempCategory.fromJson(c))
        .toList();
  }

  static Future<Campaign?> getActiveCampaign() async {
    final data = await _req('GET', '/campaigns/active');
    final raw = data['campaign'];
    if (raw == null) return null;
    return Campaign.fromJson(raw as Map<String, dynamic>);
  }

  static Future<List<Brand>> getBrands() async {
    final data = await _req('GET', '/brands');
    return ((data['brands'] ?? []) as List)
        .map((b) => Brand.fromJson(b))
        .toList();
  }

  static Future<List<Product>> getProductVariants(String uniqueId) async {
    final data = await _req('GET', '/products/$uniqueId/variants');
    return ((data['variants'] ?? []) as List)
        .map((p) => Product.fromJson(p))
        .toList();
  }

  static Future<List<SavedAddress>> getAddresses() async {
    final data = await _req('GET', '/auth/addresses', auth: true);
    return ((data['addresses'] ?? []) as List)
        .map((a) => SavedAddress.fromJson(a))
        .toList();
  }

  // Coupons
  static Future<List<Coupon>> getPublicCoupons() async {
    final data = await _req('GET', '/coupons/public');
    return ((data['coupons'] ?? []) as List)
        .map((c) => Coupon.fromJson(c))
        .toList();
  }

  // Filtered to coupons the signed-in user can still apply (excludes codes
  // where they've hit the per-user cap). Falls back to public if anonymous.
  static Future<List<Coupon>> getAvailableCoupons() async {
    final data = await _req('GET', '/coupons/available', auth: true);
    return ((data['coupons'] ?? []) as List)
        .map((c) => Coupon.fromJson(c))
        .toList();
  }

  static Future<CouponPreview> previewCoupon(
      String code, int subtotalCents) async {
    final data = await _req('POST', '/coupons/preview',
        body: {'code': code, 'subtotalCents': subtotalCents});
    return CouponPreview.fromJson(data);
  }

  // Orders
  static Future<Order> createOrder(Map<String, dynamic> payload) async {
    final data = await _req('POST', '/orders', body: payload, auth: true);
    return Order.fromJson(data['order']);
  }

  static Future<Order> trackOrder(String publicId) async {
    final data = await _req('GET', '/orders/track/$publicId');
    return Order.fromJson(data['order']);
  }

  static Future<List<Order>> getMyOrders() async {
    final data = await _req('GET', '/orders/my-orders', auth: true);
    return ((data['orders'] ?? []) as List)
        .map((o) => Order.fromJson(o))
        .toList();
  }

  static Future<Order> cancelOrder(String publicId) async {
    final data = await _req('POST', '/orders/$publicId/cancel');
    return Order.fromJson(data['order']);
  }

  // Payments (Razorpay)
  static Future<Map<String, dynamic>> getPaymentConfig() async {
    final data = await _req('GET', '/payments/config');
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> createPaymentIntent(int amountCents) async {
    final data = await _req('POST', '/payments/create-order',
        body: {'amountCents': amountCents}, auth: true);
    return Map<String, dynamic>.from(data);
  }

  // Ask the server to mint a Razorpay UPI intent URL that launches PhonePe /
  // GPay / Paytm directly with the amount pre-filled. Returns
  // {intentUrl, paymentId}.
  static Future<Map<String, dynamic>> createUpiIntent({
    required String razorpayOrderId,
    required int amountCents,
    required String upiApp,
    String? contact,
    String? email,
  }) async {
    final data = await _req(
      'POST',
      '/payments/upi-intent',
      body: {
        'razorpayOrderId': razorpayOrderId,
        'amountCents': amountCents,
        'upiApp': upiApp,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      auth: true,
    );
    return Map<String, dynamic>.from(data);
  }

}
