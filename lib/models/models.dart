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
  final String productName;
  final String unitLabel;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;

  OrderItem({
    required this.id,
    required this.productName,
    required this.unitLabel,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: j['id'],
        productName: j['productName'],
        unitLabel: j['unitLabel'],
        quantity: j['quantity'],
        unitPriceCents: j['unitPriceCents'],
        lineTotalCents: j['lineTotalCents'],
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
  final double? deliveryLatitude;
  final double? deliveryLongitude;
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
    this.deliveryLatitude,
    this.deliveryLongitude,
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
        deliveryLatitude: (j['deliveryLatitude'] as num?)?.toDouble(),
        deliveryLongitude: (j['deliveryLongitude'] as num?)?.toDouble(),
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
        deliveryLatitude: deliveryLatitude,
        deliveryLongitude: deliveryLongitude,
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
        categoryName: j['categoryName'],
      );
}

class Category {
  final int id;
  final String name;
  final int productCount;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.productCount,
    this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'],
        name: j['name'],
        productCount: j['productCount'] ?? 0,
        imageUrl: j['imageUrl'],
      );
}

class Campaign {
  final int id;
  final String title;
  final String? imageUrl;
  final int? categoryId;
  final String? categorySlug;
  final String? categoryName;
  final bool isActive;

  Campaign({
    required this.id,
    required this.title,
    this.imageUrl,
    this.categoryId,
    this.categorySlug,
    this.categoryName,
    required this.isActive,
  });

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'],
        title: (j['title'] ?? '').toString(),
        imageUrl: j['imageUrl'],
        categoryId: j['categoryId'],
        categorySlug: j['categorySlug'],
        categoryName: j['categoryName'],
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

  HomeRails({required this.bestsellers, required this.categoryRails});

  factory HomeRails.fromJson(Map<String, dynamic> j) => HomeRails(
        bestsellers: ((j['bestsellers'] ?? []) as List)
            .map((p) => Product.fromJson(p))
            .toList(),
        categoryRails: ((j['categoryRails'] ?? []) as List)
            .map((r) => CategoryRail.fromJson(r))
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
