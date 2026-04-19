import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

const String kWsUrl = 'wss://bestmart-delivery-app-production.up.railway.app/ws';

class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();
  SocketService._();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _destroyed = false;

  final _newOrderController = StreamController<Order>.broadcast();
  final _orderUpdatedController = StreamController<Order>.broadcast();
  final _riderLocationController = StreamController<RiderLocation>.broadcast();

  Stream<Order> get onNewOrder => _newOrderController.stream;
  Stream<Order> get onOrderUpdated => _orderUpdatedController.stream;
  Stream<RiderLocation> get onRiderLocation => _riderLocationController.stream;

  void connect() {
    _destroyed = false;
    _doConnect();
  }

  void _doConnect() {
    if (_destroyed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(kWsUrl));
      _channel!.stream.listen(
        (msg) {
          try {
            final data = jsonDecode(msg as String) as Map<String, dynamic>;
            final type = data['type'] as String;
            if (type == 'new_order') {
              _newOrderController.add(Order.fromJson(data['payload']));
            } else if (type == 'order_updated') {
              _orderUpdatedController.add(Order.fromJson(data['payload']));
            } else if (type == 'rider_location') {
              _riderLocationController.add(RiderLocation.fromJson(data['payload']));
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_destroyed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  void disconnect() {
    _destroyed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
