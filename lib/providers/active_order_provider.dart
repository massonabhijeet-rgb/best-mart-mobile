import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/socket_service.dart';

/// Single source of truth for the customer's currently-in-progress orders.
/// Used by the floating ribbon above the bottom nav to surface a "track
/// order" affordance whenever there's an undelivered order, and to hide
/// the ribbon the moment the rider marks the order delivered (server
/// pushes `order_updated` over WebSocket → we apply it locally).
class ActiveOrderProvider extends ChangeNotifier {
  List<Order> _orders = const [];
  StreamSubscription<Order>? _updatedSub;
  StreamSubscription<Order>? _newSub;
  bool _loading = false;
  bool _wsAttached = false;

  /// Tracks (publicId, status) pairs the user has explicitly dismissed via
  /// the ribbon's close button. Keying on status (not just publicId) means a
  /// status advance — say `confirmed` → `out_for_delivery` — re-surfaces the
  /// ribbon, so the user doesn't miss the moment the rider is on the way
  /// just because they dismissed the earlier "confirmed" pill.
  final Set<String> _dismissedKeys = <String>{};

  static bool _isInProgress(Order o) =>
      o.status != 'delivered' && o.status != 'cancelled';

  String _key(Order o) => '${o.publicId}|${o.status}';

  /// Most-recent first, so the ribbon (which shows one at a time) always
  /// points at the freshest active order. Dismissed keys are filtered out.
  List<Order> get inProgress {
    final filtered = _orders
        .where(_isInProgress)
        .where((o) => !_dismissedKeys.contains(_key(o)))
        .toList()
      ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
    return filtered;
  }

  bool get hasActive => inProgress.isNotEmpty;

  /// Hides the ribbon for the given order at its current status. The next
  /// status update re-keys it (different `_key`) and the ribbon comes back.
  void dismiss(String publicId) {
    for (final o in _orders) {
      if (o.publicId == publicId) {
        _dismissedKeys.add(_key(o));
        notifyListeners();
        return;
      }
    }
  }

  /// Pulls the user's order list from the server. Safe to call before
  /// login — it just no-ops on auth failure. Idempotent: attaches the
  /// WebSocket listeners exactly once, on first successful load.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      _orders = await ApiService.getMyOrders();
      notifyListeners();
    } catch (_) {
      // Auth not ready / network blip — ribbon stays hidden, retry
      // happens via socket events or a manual reload.
    } finally {
      _loading = false;
    }

    if (!_wsAttached) {
      _updatedSub = SocketService.instance.onOrderUpdated.listen(_apply);
      _newSub = SocketService.instance.onNewOrder.listen(_apply);
      _wsAttached = true;
    }
  }

  /// Replaces or prepends an order in the local cache. Order pushes from
  /// the server cover both new orders and status updates on existing ones.
  void _apply(Order updated) {
    final idx = _orders.indexWhere((o) => o.publicId == updated.publicId);
    if (idx == -1) {
      _orders = [updated, ..._orders];
    } else {
      final next = [..._orders];
      next[idx] = updated;
      _orders = next;
    }
    notifyListeners();
  }

  /// Called on logout — strips orders so the next user doesn't briefly
  /// see the previous account's ribbon.
  void clear() {
    _orders = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _updatedSub?.cancel();
    _newSub?.cancel();
    super.dispose();
  }
}
