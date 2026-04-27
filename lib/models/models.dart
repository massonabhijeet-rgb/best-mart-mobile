class User {
  final int id;
  final String uid;
  final String email;
  final String role;
  final String companyId;
  final String companyName;
  final String? fullName;
  final String? phone;

  User({
    required this.id,
    required this.uid,
    required this.email,
    required this.role,
    required this.companyId,
    required this.companyName,
    this.fullName,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        uid: j['uid'],
        email: j['email'],
        role: j['role'],
        companyId: j['companyId'].toString(),
        companyName: j['companyName'],
        fullName: j['fullName'],
        phone: j['phone'],
      );
}

class OrderItem {
  final int id;
  final int? productId;
  final String productName;
  final String unitLabel;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final String? rejectedAt;
  final String? rejectionReason;

  OrderItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.unitLabel,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    this.rejectedAt,
    this.rejectionReason,
  });

  bool get isRejected => rejectedAt != null;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'],
        productId: (j['productId'] as num?)?.toInt(),
        productName: j['productName'],
        unitLabel: j['unitLabel'],
        quantity: j['quantity'],
        unitPriceCents: j['unitPriceCents'],
        lineTotalCents: j['lineTotalCents'],
        rejectedAt: j['rejectedAt'],
        rejectionReason: j['rejectionReason'],
      );
}

class Order {
  final int id;
  final String publicId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String deliveryAddress;
  final String? deliveryNotes;
  final String? deliverySlot;
  final String paymentMethod;
  final int subtotalCents;
  final int deliveryFeeCents;
  final int totalCents;
  final String status;
  final String? assignedRider;
  final int? assignedRiderUserId;
  final String? assignedRiderPhone;
  // 1-5 stars given by the customer post-delivery; null until rated.
  final int? riderRating;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? cancellationReason;
  final String? deliveryOtp;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String paymentStatus;
  // Cached driving route from rider's last "significant move" to the delivery
  // address. Server fetches this from Google once per ~500m of rider drift, so
  // customer tracking never calls the Directions API itself.
  final String? routePolyline;
  final int? routeDurationSec;
  final int? routeDistanceM;
  final String createdDate;
  final String updatedDate;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.publicId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.deliveryAddress,
    this.deliveryNotes,
    this.deliverySlot,
    required this.paymentMethod,
    required this.subtotalCents,
    required this.deliveryFeeCents,
    required this.totalCents,
    required this.status,
    this.assignedRider,
    this.assignedRiderUserId,
    this.assignedRiderPhone,
    this.riderRating,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.cancellationReason,
    this.deliveryOtp,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.paymentStatus = 'pending',
    this.routePolyline,
    this.routeDurationSec,
    this.routeDistanceM,
    required this.createdDate,
    required this.updatedDate,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        publicId: j['publicId'],
        customerName: j['customerName'],
        customerPhone: j['customerPhone'],
        customerEmail: j['customerEmail'],
        deliveryAddress: j['deliveryAddress'],
        deliveryNotes: j['deliveryNotes'],
        deliverySlot: j['deliverySlot'],
        paymentMethod: j['paymentMethod'],
        subtotalCents: j['subtotalCents'],
        deliveryFeeCents: j['deliveryFeeCents'],
        totalCents: j['totalCents'],
        status: j['status'],
        assignedRider: j['assignedRider'],
        assignedRiderUserId: j['assignedRiderUserId'],
        assignedRiderPhone: j['assignedRiderPhone'],
        riderRating: (j['riderRating'] as num?)?.toInt(),
        deliveryLatitude: (j['deliveryLatitude'] as num?)?.toDouble(),
        deliveryLongitude: (j['deliveryLongitude'] as num?)?.toDouble(),
        cancellationReason: j['cancellationReason'] as String?,
        deliveryOtp: j['deliveryOtp'] as String?,
        razorpayOrderId: j['razorpayOrderId'] as String?,
        razorpayPaymentId: j['razorpayPaymentId'] as String?,
        paymentStatus: (j['paymentStatus'] as String?) ?? 'pending',
        routePolyline: j['routePolyline'] as String?,
        routeDurationSec: (j['routeDurationSec'] as num?)?.toInt(),
        routeDistanceM: (j['routeDistanceM'] as num?)?.toInt(),
        createdDate: j['createdDate'],
        updatedDate: j['updatedDate'],
        items: (j['items'] as List).map((i) => OrderItem.fromJson(i)).toList(),
      );

  Order copyWith({String? status, String? assignedRider, int? assignedRiderUserId}) => Order(
        id: id,
        publicId: publicId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        deliveryAddress: deliveryAddress,
        deliveryNotes: deliveryNotes,
        deliverySlot: deliverySlot,
        paymentMethod: paymentMethod,
        subtotalCents: subtotalCents,
        deliveryFeeCents: deliveryFeeCents,
        totalCents: totalCents,
        status: status ?? this.status,
        assignedRider: assignedRider ?? this.assignedRider,
        assignedRiderUserId: assignedRiderUserId ?? this.assignedRiderUserId,
        assignedRiderPhone: assignedRiderPhone,
        riderRating: riderRating,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        cancellationReason: cancellationReason,
        deliveryOtp: deliveryOtp,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        paymentStatus: paymentStatus,
        routePolyline: routePolyline,
        routeDurationSec: routeDurationSec,
        routeDistanceM: routeDistanceM,
        createdDate: createdDate,
        updatedDate: updatedDate,
        items: items,
      );

  /// Optimistic local-only update used right after the customer submits a
  /// rating, so the rate-rider card flips to its "thanks" state without
  /// waiting for the next WS broadcast / refetch.
  Order copyWithRiderRating(int rating) => Order(
        id: id,
        publicId: publicId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        deliveryAddress: deliveryAddress,
        deliveryNotes: deliveryNotes,
        deliverySlot: deliverySlot,
        paymentMethod: paymentMethod,
        subtotalCents: subtotalCents,
        deliveryFeeCents: deliveryFeeCents,
        totalCents: totalCents,
        status: status,
        assignedRider: assignedRider,
        assignedRiderUserId: assignedRiderUserId,
        assignedRiderPhone: assignedRiderPhone,
        riderRating: rating,
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
        cancellationReason: cancellationReason,
        deliveryOtp: deliveryOtp,
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        paymentStatus: paymentStatus,
        routePolyline: routePolyline,
        routeDurationSec: routeDurationSec,
        routeDistanceM: routeDistanceM,
        createdDate: createdDate,
        updatedDate: updatedDate,
        items: items,
      );
}

class Product {
  final int id;
  final String uniqueId;
  final String name;
  final String unitLabel;
  final String? description;
  final int priceCents;
  final int? originalPriceCents;
  final int stockQuantity;
  final bool isActive;
  final bool isOnOffer;
  final String? imageUrl;
  final String? badge;
  final int? categoryId;
  final String? categoryName;

  Product({
    required this.id,
    required this.uniqueId,
    required this.name,
    required this.unitLabel,
    this.description,
    required this.priceCents,
    this.originalPriceCents,
    required this.stockQuantity,
    required this.isActive,
    required this.isOnOffer,
    this.imageUrl,
    this.badge,
    this.categoryId,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        uniqueId: j['uniqueId'],
        name: j['name'],
        unitLabel: j['unitLabel'],
        description: j['description'],
        priceCents: j['priceCents'],
        originalPriceCents: j['originalPriceCents'],
        stockQuantity: j['stockQuantity'],
        isActive: j['isActive'],
        isOnOffer: j['isOnOffer'] ?? false,
        imageUrl: j['imageUrl'],
        badge: j['badge'],
        categoryId: (j['categoryId'] as num?)?.toInt(),
        categoryName: j['categoryName'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uniqueId': uniqueId,
        'name': name,
        'unitLabel': unitLabel,
        'description': description,
        'priceCents': priceCents,
        'originalPriceCents': originalPriceCents,
        'stockQuantity': stockQuantity,
        'isActive': isActive,
        'isOnOffer': isOnOffer,
        'imageUrl': imageUrl,
        'badge': badge,
        'categoryName': categoryName,
      };
}

class Category {
  final int id;
  final String name;
  final int productCount;
  final String? imageUrl;
  final int? parentId;

  Category({
    required this.id,
    required this.name,
    required this.productCount,
    this.imageUrl,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        productCount: j['productCount'] ?? 0,
        imageUrl: j['imageUrl'],
        parentId: (j['parentId'] as num?)?.toInt(),
      );
}

class CampaignCategoryRef {
  final int id;
  final String slug;
  final String name;

  CampaignCategoryRef({required this.id, required this.slug, required this.name});

  factory CampaignCategoryRef.fromJson(Map<String, dynamic> j) => CampaignCategoryRef(
        id: j['id'] as int,
        slug: (j['slug'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
}

class Campaign {
  final int id;
  final String title;
  final String? imageUrl;
  final List<int> categoryIds;
  final List<CampaignCategoryRef> categories;
  final bool isActive;

  Campaign({
    required this.id,
    required this.title,
    this.imageUrl,
    this.categoryIds = const [],
    this.categories = const [],
    required this.isActive,
  });

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'],
        title: (j['title'] ?? '').toString(),
        imageUrl: j['imageUrl'],
        categoryIds: (j['categoryIds'] as List?)
                ?.map((v) => (v as num).toInt())
                .toList() ??
            const [],
        categories: (j['categories'] as List?)
                ?.map((v) => CampaignCategoryRef.fromJson(v as Map<String, dynamic>))
                .toList() ??
            const [],
        isActive: j['isActive'] ?? false,
      );
}

class CategoryRail {
  final int id;
  final String name;
  final String? imageUrl;
  final List<Product> products;

  CategoryRail({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.products,
  });

  factory CategoryRail.fromJson(Map<String, dynamic> j) => CategoryRail(
        id: j['id'],
        name: j['name'] ?? '',
        imageUrl: j['imageUrl'],
        products: ((j['products'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
      );
}

class HomeRails {
  final List<Product> bestsellers;
  final List<CategoryRail> categoryRails;
  // Personalised rail derived from the signed-in user's recent search
  // history. Empty for anonymous users or users without recent signal —
  // UI hides the rail when empty.
  final List<Product> pickedForYou;

  HomeRails({
    required this.bestsellers,
    required this.categoryRails,
    this.pickedForYou = const [],
  });

  factory HomeRails.fromJson(Map<String, dynamic> j) => HomeRails(
        bestsellers: ((j['bestsellers'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
        categoryRails: ((j['categoryRails'] ?? []) as List)
            .map((r) => CategoryRail.fromJson(r))
            .toList(),
        pickedForYou: ((j['pickedForYou'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
      );
}

class ProductPage {
  final List<Product> products;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  ProductPage({
    required this.products,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory ProductPage.fromJson(Map<String, dynamic> j) => ProductPage(
        products: ((j['products'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
        total: j['total'] ?? 0,
        page: j['page'] ?? 1,
        pageSize: j['pageSize'] ?? 20,
        hasMore: j['hasMore'] ?? false,
      );
}

class Coupon {
  final String code;
  final String? description;
  final String discountType;
  final num discountValue;
  final int? maxDiscountCents;
  final int? minSubtotalCents;
  final String? validUntil;

  Coupon({
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.maxDiscountCents,
    this.minSubtotalCents,
    this.validUntil,
  });

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        code: j['code'] ?? '',
        description: j['description'],
        discountType: j['discountType'] ?? 'percent',
        discountValue: j['discountValue'] ?? 0,
        maxDiscountCents: j['maxDiscountCents'],
        minSubtotalCents: j['minSubtotalCents'],
        validUntil: j['validUntil'],
      );
}

class CouponPreview {
  final String code;
  final String? description;
  final int discountCents;
  final String discountType;
  final num discountValue;

  CouponPreview({
    required this.code,
    this.description,
    required this.discountCents,
    required this.discountType,
    required this.discountValue,
  });

  factory CouponPreview.fromJson(Map<String, dynamic> j) => CouponPreview(
        code: j['code'] ?? '',
        description: j['description'],
        discountCents: j['discountCents'] ?? 0,
        discountType: j['discountType'] ?? 'percent',
        discountValue: j['discountValue'] ?? 0,
      );
}

class StorefrontSpotlight {
  final List<Product> offerProducts;
  final List<Product> dailyEssentials;
  final List<Product> moodPicks;

  StorefrontSpotlight({
    required this.offerProducts,
    required this.dailyEssentials,
    required this.moodPicks,
  });

  factory StorefrontSpotlight.fromJson(Map<String, dynamic> j) =>
      StorefrontSpotlight(
        offerProducts: ((j['offerProducts'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
        dailyEssentials: ((j['dailyEssentials'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
        moodPicks: ((j['moodPicks'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
      );
}

class TempCategory {
  final int id;
  final String autoKey;
  final String name;
  final String theme;
  final List<String> keywords;
  final int priority;
  final List<Product> products;

  TempCategory({
    required this.id,
    required this.autoKey,
    required this.name,
    required this.theme,
    required this.keywords,
    required this.priority,
    required this.products,
  });

  factory TempCategory.fromJson(Map<String, dynamic> j) => TempCategory(
        id: j['id'] ?? 0,
        autoKey: j['autoKey'] ?? '',
        name: j['name'] ?? '',
        theme: j['theme'] ?? '',
        keywords:
            ((j['keywords'] ?? []) as List).map((e) => e.toString()).toList(),
        priority: j['priority'] ?? 0,
        products: ((j['products'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
      );
}

class Brand {
  final int id;
  final String name;
  final String slug;
  final int productCount;

  Brand({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
  });

  factory Brand.fromJson(Map<String, dynamic> j) => Brand(
        id: j['id'] ?? 0,
        name: j['name'] ?? '',
        slug: j['slug'] ?? '',
        productCount: j['productCount'] ?? 0,
      );
}

class SavedAddress {
  final int id;
  final String fullName;
  final String phone;
  final String deliveryAddress;
  final String? deliveryNotes;
  final double? latitude;
  final double? longitude;
  final int useCount;

  SavedAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.deliveryAddress,
    this.deliveryNotes,
    this.latitude,
    this.longitude,
    required this.useCount,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: j['id'] ?? 0,
        fullName: j['fullName'] ?? '',
        phone: j['phone'] ?? '',
        deliveryAddress: j['deliveryAddress'] ?? '',
        deliveryNotes: j['deliveryNotes'],
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        useCount: j['useCount'] ?? 0,
      );
}

class RiderLocation {
  final int riderId;
  final String? riderName;
  final double latitude;
  final double longitude;
  final String updatedAt;

  RiderLocation({
    required this.riderId,
    this.riderName,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory RiderLocation.fromJson(Map<String, dynamic> j) => RiderLocation(
        riderId: j['riderId'],
        riderName: j['riderName'],
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        updatedAt: j['updatedAt'],
      );
}

class ShopStatus {
  final bool shopOpen;
  final String shopClosedMessage;

  const ShopStatus({
    required this.shopOpen,
    required this.shopClosedMessage,
  });

  factory ShopStatus.open() => const ShopStatus(
        shopOpen: true,
        shopClosedMessage: '',
      );

  factory ShopStatus.fromJson(Map<String, dynamic> j) => ShopStatus(
        shopOpen: (j['shopOpen'] as bool?) ?? true,
        shopClosedMessage:
            (j['shopClosedMessage'] as String?) ??
                "We're closed right now. Come back tomorrow!",
      );
}

// ─── Themed pages ────────────────────────────────────────────────────────
//
// Editorial seasonal landing pages — each surfaces as a tab in the
// storefront's top icon row and opens a dedicated screen with a hero
// banner + tile grid. Tiles deep-link into a category, a search query,
// or a hand-curated set of product ids.

enum ThemedPageTileLinkType { category, search, productIds, unknown }

ThemedPageTileLinkType _parseTileLinkType(String? raw) {
  switch (raw) {
    case 'category':
      return ThemedPageTileLinkType.category;
    case 'search':
      return ThemedPageTileLinkType.search;
    case 'product_ids':
      return ThemedPageTileLinkType.productIds;
    default:
      return ThemedPageTileLinkType.unknown;
  }
}

class ThemedPageTile {
  final int id;
  final String label;
  final String? sublabel;
  final String? imageUrl;
  final String? bgColor;
  final ThemedPageTileLinkType linkType;
  final int? linkCategoryId;
  final String? linkSearchQuery;
  final List<int>? linkProductIds;
  final int sortOrder;

  const ThemedPageTile({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.imageUrl,
    required this.bgColor,
    required this.linkType,
    required this.linkCategoryId,
    required this.linkSearchQuery,
    required this.linkProductIds,
    required this.sortOrder,
  });

  factory ThemedPageTile.fromJson(Map<String, dynamic> j) {
    final ids = j['linkProductIds'];
    return ThemedPageTile(
      id: j['id'] ?? 0,
      label: j['label'] ?? '',
      sublabel: j['sublabel'] as String?,
      imageUrl: j['imageUrl'] as String?,
      bgColor: j['bgColor'] as String?,
      linkType: _parseTileLinkType(j['linkType'] as String?),
      linkCategoryId: j['linkCategoryId'] as int?,
      linkSearchQuery: j['linkSearchQuery'] as String?,
      linkProductIds:
          ids is List ? ids.map((e) => (e as num).toInt()).toList() : null,
      sortOrder: j['sortOrder'] ?? 0,
    );
  }
}

class ThemedPage {
  final int id;
  final String slug;
  final String title;
  final String? subtitle;
  final String? navIconUrl;
  final String? heroImageUrl;
  final String? themeColor;
  final bool isActive;
  final int sortOrder;
  final List<ThemedPageTile> tiles;

  const ThemedPage({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.navIconUrl,
    required this.heroImageUrl,
    required this.themeColor,
    required this.isActive,
    required this.sortOrder,
    required this.tiles,
  });

  factory ThemedPage.fromJson(Map<String, dynamic> j) => ThemedPage(
        id: j['id'] ?? 0,
        slug: j['slug'] ?? '',
        title: j['title'] ?? '',
        subtitle: j['subtitle'] as String?,
        navIconUrl: j['navIconUrl'] as String?,
        heroImageUrl: j['heroImageUrl'] as String?,
        themeColor: j['themeColor'] as String?,
        isActive: (j['isActive'] as bool?) ?? true,
        sortOrder: j['sortOrder'] ?? 0,
        tiles: ((j['tiles'] ?? []) as List)
            .map((t) => ThemedPageTile.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
