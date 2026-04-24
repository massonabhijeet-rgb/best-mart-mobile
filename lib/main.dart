import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/notifications_service.dart';
import 'services/socket_service.dart';
import 'providers/home_provider.dart';
import 'providers/shop_status_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customer/storefront_screen.dart';
import 'screens/customer/cart_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthProvider();
  await auth.init();
  await NotificationsService.instance.init();
  if (auth.isLoggedIn) {
    unawaited(NotificationsService.instance.registerForUser());
  }
  SocketService.instance.connect();
  final shopStatus = ShopStatusProvider();
  unawaited(shopStatus.init());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider.value(value: shopStatus),
      ],
      child: const BestMartApp(),
    ),
  );
}

class BestMartApp extends StatelessWidget {
  const BestMartApp({super.key});

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
    return const StorefrontScreen();
  }
}
