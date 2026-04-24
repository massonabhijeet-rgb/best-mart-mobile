import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/socket_service.dart';

class ShopStatusProvider extends ChangeNotifier {
  ShopStatus _status = ShopStatus.open();
  StreamSubscription<ShopStatus>? _sub;
  bool _loaded = false;

  ShopStatus get status => _status;
  bool get isOpen => _status.shopOpen;
  bool get isClosed => !_status.shopOpen;
  String get closedMessage => _status.shopClosedMessage;
  bool get isLoaded => _loaded;

  Future<void> init() async {
    _status = await ApiService.getShopStatus();
    _loaded = true;
    notifyListeners();
    _sub?.cancel();
    _sub = SocketService.instance.onShopStatusChanged.listen((next) {
      _status = next;
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    _status = await ApiService.getShopStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
