import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safespend/core/security/app_lock_provider.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final lock = context.read<AppLockProvider>();
    await lock.load();
    if (!mounted || !lock.enabled) return;
    setState(() => _locked = true);
    await _tryDeviceUnlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final lock = context.read<AppLockProvider>();
      if (lock.enabled && mounted) setState(() => _locked = true);
    }
  }

  Future<void> _tryDeviceUnlock() async {
    if (_authenticating || !mounted) return;
    setState(() => _authenticating = true);
    final ok = await context.read<AppLockProvider>().authenticateWithDevice();
    if (mounted) {
      setState(() {
        _authenticating = false;
        if (ok) _locked = false;
      });
    }
  }

  Future<void> _submitPin(String pin) async {
    if (pin.length < 4) return;
    final ok = await context.read<AppLockProvider>().verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    if (!lock.loaded || !_locked || !lock.enabled) return widget.child;

    return _LockScreen(
      authenticating: _authenticating,
      onUnlockWithDevice: _tryDeviceUnlock,
      onSubmitPin: _submitPin,
    );
  }
}

class _LockScreen extends StatefulWidget {
  final bool authenticating;
  final VoidCallback onUnlockWithDevice;
  final ValueChanged<String> onSubmitPin;

  const _LockScreen({
    required this.authenticating,
    required this.onUnlockWithDevice,
    required this.onSubmitPin,
  });

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 58,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  'SafeSpend is locked',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your PIN to view your finances.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: widget.onSubmitPin,
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: Icon(Icons.password_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => widget.onSubmitPin(_pinController.text),
                    child: const Text('Unlock'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: widget.authenticating
                      ? null
                      : widget.onUnlockWithDevice,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(
                    widget.authenticating
                        ? 'Checking device security...'
                        : 'Use device security',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
