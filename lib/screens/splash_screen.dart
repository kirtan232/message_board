import 'package:flutter/material.dart';

/// Shows a branded splash while [initialize] runs (Firebase startup).
///
/// The future is created once in [initState] so widget rebuilds never restart
/// initialization. If it fails, a retry screen is shown instead of crashing.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.initialize,
    required this.onReady,
    this.minimumDuration = const Duration(milliseconds: 1500),
  });

  /// The startup work to run, e.g. `Firebase.initializeApp(...)`.
  final Future<void> Function() initialize;

  /// Builds the first real screen once [initialize] completes.
  final WidgetBuilder onReady;

  /// Keeps the splash visible long enough to be seen, even on fast devices.
  final Duration minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _runStartup();
  }

  Future<void> _runStartup() async {
    await Future.wait([
      widget.initialize(),
      Future<void>.delayed(widget.minimumDuration),
    ]);
  }

  void _retry() {
    setState(() {
      _startup = _runStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _StartupError(onRetry: _retry);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashView();
        }
        return widget.onReady(context);
      },
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.tertiary],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.forum_rounded,
                  size: 72,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Message Board',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chatboards for the new age',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connecting to Firebase…',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Firebase could not start.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
