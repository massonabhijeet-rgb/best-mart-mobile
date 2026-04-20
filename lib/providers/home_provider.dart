import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../services/api.dart';

enum LoadState { idle, loading, ready, error }

class HomeProvider extends ChangeNotifier {
  LoadState _state = LoadState.idle;
  String _error = '';
  HomeRails? _rails;
  List<Category> _categories = [];
  List<Coupon> _coupons = [];
  StorefrontSpotlight? _spotlight;
  List<TempCategory> _tempCategories = [];
  List<Brand> _brands = [];
  Campaign? _activeCampaign;

  String _search = '';
  int? _categoryId;
  String? _brand;

  List<Product> _gridProducts = [];
  int _page = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _firstGridLoaded = false;

  LoadState get state => _state;
  String get error => _error;
  HomeRails? get rails => _rails;
  List<Category> get categories => _categories;
  List<Coupon> get coupons => _coupons;
  StorefrontSpotlight? get spotlight => _spotlight;
  List<TempCategory> get tempCategories => _tempCategories;
  List<Brand> get brands => _brands;
  Campaign? get activeCampaign => _activeCampaign;
  void consumeActiveCampaign() {
    if (_activeCampaign == null) return;
    _activeCampaign = null;
    notifyListeners();
  }

  String get search => _search;
  int? get categoryId => _categoryId;
  String? get brand => _brand;
  bool get isFiltered =>
      _search.isNotEmpty || _categoryId != null || _brand != null;

  List<Product> get gridProducts => _gridProducts;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  bool get firstGridLoaded => _firstGridLoaded;

  Future<void> loadHome() async {
    _state = LoadState.loading;
    _error = '';
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiService.getHomeRails(),
        ApiService.getCategories(),
        ApiService.getPublicCoupons(),
        ApiService.getSpotlight().catchError((_) => StorefrontSpotlight(
              offerProducts: const [],
              dailyEssentials: const [],
              moodPicks: const [],
            )),
        ApiService.getTempCategories().catchError((_) => <TempCategory>[]),
        ApiService.getBrands().catchError((_) => <Brand>[]),
        ApiService.getActiveCampaign().catchError((_) => null),
      ]);
      final rawRails = results[0] as HomeRails;
      _rails = HomeRails(
        bestsellers: _sortedByStock(rawRails.bestsellers),
        categoryRails: rawRails.categoryRails
            .map((r) => CategoryRail(
                  id: r.id,
                  name: r.name,
                  imageUrl: r.imageUrl,
                  products: _sortedByStock(r.products),
                ))
            .toList(),
      );
      _categories = results[1] as List<Category>;
      _coupons = results[2] as List<Coupon>;
      final spot = results[3] as StorefrontSpotlight;
      _spotlight = StorefrontSpotlight(
        offerProducts: _sortedByStock(spot.offerProducts),
        dailyEssentials: _sortedByStock(spot.dailyEssentials),
        moodPicks: _sortedByStock(spot.moodPicks),
      );
      _tempCategories = (results[4] as List<TempCategory>)
          .map((tc) => TempCategory(
                id: tc.id,
                autoKey: tc.autoKey,
                name: tc.name,
                theme: tc.theme,
                keywords: tc.keywords,
                priority: tc.priority,
                products: _sortedByStock(tc.products),
              ))
          .toList();
      _brands = results[5] as List<Brand>;
      _activeCampaign = results[6] as Campaign?;
      _state = LoadState.ready;
      notifyListeners();
      await _resetGrid();
    } catch (e) {
      _state = LoadState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setSearch(String value) async {
    if (_search == value) return;
    _search = value;
    await _resetGrid();
  }

  Future<void> setCategory(int? id) async {
    if (_categoryId == id) return;
    _categoryId = id;
    await _resetGrid();
  }

  Future<void> setBrand(String? brand) async {
    if (_brand == brand) return;
    _brand = brand;
    await _resetGrid();
  }

  Future<void> clearFilters() async {
    final changed = _search.isNotEmpty || _categoryId != null || _brand != null;
    _search = '';
    _categoryId = null;
    _brand = null;
    if (changed) await _resetGrid();
  }

  Future<void> _resetGrid() async {
    _gridProducts = [];
    _page = 1;
    _hasMore = true;
    _firstGridLoaded = false;
    notifyListeners();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await ApiService.getProductsPage(
        page: _page,
        pageSize: _pageSize,
        categoryId: _categoryId,
        search: _search,
        brand: _brand,
      );
      _gridProducts.addAll(_sortedByStock(page.products));
      _hasMore = page.hasMore;
      _page += 1;
      _firstGridLoaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadHome();
  }

  static List<Product> _sortedByStock(List<Product> items) {
    final copy = List<Product>.from(items);
    copy.sort((a, b) => _stockRank(a).compareTo(_stockRank(b)));
    return copy;
  }

  static int _stockRank(Product p) {
    if (p.stockQuantity <= 0) return 2;
    if (p.stockQuantity <= 5) return 1;
    return 0;
  }
}
