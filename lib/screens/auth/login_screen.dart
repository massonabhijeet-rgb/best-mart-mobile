import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api.dart';
import '../../services/auth_provider.dart';
import '../../theme/tokens.dart';

// Flip to `true` once the MSG91 OTP backend is live and the template is
// approved. The phone tab stays visible while disabled so users discover
// it's coming — the form is just replaced with a "coming soon" placeholder.
const bool _kPhoneLoginEnabled = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // Email is the default (index 0) until phone OTP is live.
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Container(
                  height: 64,
                  width: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: AppRadius.brLg,
                  ),
                  child: const Icon(
                    Icons.shopping_basket_rounded,
                    color: AppColors.brandBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('BestMart',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text('Delivery in 15 minutes',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.brLg,
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: AppShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0),
                        child: Text('Sign in',
                            style:
                                Theme.of(context).textTheme.headlineSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, 4, AppSpacing.xl, AppSpacing.md),
                        child: Text(
                          'Sign in with your email to continue.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TabBar(
                        controller: _tab,
                        labelColor: AppColors.brandBlue,
                        unselectedLabelColor: AppColors.inkFaint,
                        indicatorColor: AppColors.brandBlue,
                        tabs: [
                          const Tab(text: 'Email'),
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Phone'),
                                if (!_kPhoneLoginEnabled) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.inkFaint
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Soon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkFaint,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 380,
                        child: TabBarView(
                          controller: _tab,
                          children: const [
                            _EmailTab(),
                            _PhoneTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneTab extends StatefulWidget {
  const _PhoneTab();
  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _busy = false;
  String _error = '';
  String? _requestId;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final res = await ApiService.sendOtp(phone);
      if (!mounted) return;
      setState(() => _requestId = res['requestId'] as String);
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Enter the OTP we sent you');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await context.read<AuthProvider>().loginWithOtp(
            phone: phone,
            otp: otp,
            requestId: _requestId!,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_kPhoneLoginEnabled) {
      return const _PhoneComingSoon();
    }
    final hasRequest = _requestId != null;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            enabled: !hasRequest,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              prefixText: '+91  ',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
            ),
          ),
          if (hasRequest) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: AppRadius.brSm,
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _busy ? null : (hasRequest ? _verifyOtp : _sendOtp),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(hasRequest ? 'Verify & continue' : 'Send OTP'),
          ),
          if (hasRequest) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _requestId = null;
                            _otpCtrl.clear();
                            _error = '';
                            _resendTimer?.cancel();
                            _resendIn = 0;
                          });
                        },
                  child: const Text('Change number'),
                ),
                TextButton(
                  onPressed: (_busy || _resendIn > 0) ? null : _sendOtp,
                  child: Text(_resendIn > 0
                      ? 'Resend in ${_resendIn}s'
                      : 'Resend OTP'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmailTab extends StatefulWidget {
  const _EmailTab();
  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _emailCtrl = TextEditingController(text: 'admin@bestmart.local');
  final _passCtrl = TextEditingController(text: 'BestMart123!');
  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await context.read<AuthProvider>().login(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.inkFaint,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: AppRadius.brSm,
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _loading ? null : _doLogin,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

class _PhoneComingSoon extends StatelessWidget {
  const _PhoneComingSoon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            width: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.inkFaint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.lock_clock_outlined,
              color: AppColors.inkFaint,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Phone login coming soon',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'We\'re setting up OTP delivery. For now, please sign in with '
            'your email and password on the other tab.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkFaint,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () {
              DefaultTabController.maybeOf(context)?.animateTo(0);
              final state = context
                  .findAncestorStateOfType<_LoginScreenState>();
              state?._tab.animateTo(0);
            },
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Use email instead'),
          ),
        ],
      ),
    );
  }
}
