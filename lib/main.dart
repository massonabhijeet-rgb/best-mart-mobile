import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/notifications_service.dart';
import 'services/socket_service.dart';
import 'providers/active_order_provider.dart';
import 'providers/home_provider.dart';
import 'providers/shop_status_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/cart_provider.dart';
import 'screens/customer/root_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.init();
  unawaited(NotificationsService.instance.init().then((_) {
    if (auth.isLoggedIn) {
      NotificationsService.instance.registerForUser();
    }
  }));
  SocketService.instance.connect();
  final shopStatus = ShopStatusProvider();
  unawaited(shopStatus.init());
  final activeOrders = ActiveOrderProvider();
  if (auth.isLoggedIn) {
    unawaited(activeOrders.load());
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider.value(value: shopStatus),
        ChangeNotifierProvider.value(value: activeOrders),
      ],
      child: const BestMartApp(),
    ),
  );
}

class BestMartApp extends StatefulWidget {
  const BestMartApp({super.key});

  @override
  State<BestMartApp> createState() => _BestMartAppState();
}

class _BestMartAppState extends State<BestMartApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-attempt push registration when the app returns to foreground —
  // catches the case where the user opened iOS Settings, flipped
  // notifications back ON, then came back without a cold restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        NotificationsService.instance.registerForUser();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BestMart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!auth.isLoggedIn) return const LoginScreen();
    return const RootShell();
  }
}
