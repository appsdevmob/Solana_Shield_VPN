import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/solana/notifier/solana_auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum _AuthState { idle, loading, error }

/// Интегрирован в GoRouter оригинального Solana Shield VPN.
class SolanaAuthPage extends ConsumerStatefulWidget {
  const SolanaAuthPage({super.key});

  @override
  ConsumerState<SolanaAuthPage> createState() => _SolanaAuthPageState();
}

class _SolanaAuthPageState extends ConsumerState<SolanaAuthPage> {
  _AuthState _authState = _AuthState.idle;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    setState(() {
      _authState = _AuthState.loading;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(solanaAuthServiceProvider);
      await authService.connectAndSign('VPN Solana Auth ${DateTime.now().millisecondsSinceEpoch}');

      if (mounted) {
        // Обновляем статус аутентификации → redirect перенаправит на /home
        ref.read(solanaIsAuthenticatedProvider.notifier).state = true;
        context.goNamed('home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _authState = _AuthState.error;
          _errorMessage = _friendlyError(e.toString(), ref.read(translationsProvider).requireValue);
        });
      }
    }
  }
  String _friendlyError(String raw, TranslationsEn t) {
    if (raw.contains('cancelled') || raw.contains('cancel')) {
      return t.solanaAuth.errors.cancelled;
    }
    if (raw.contains('timeout') || raw.contains('Timeout')) {
      return t.solanaAuth.errors.timeout;
    }
    if (raw.contains('available') || raw.contains('Available')) {
      return t.solanaAuth.errors.notFound;
    }
    if (raw.contains('channel-error')) {
      return t.solanaAuth.errors.channelError;
    }
    return '${t.solanaAuth.errors.rawPrefix}$raw';
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, const Color(0xFF0D0E1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildHeader(theme, colorScheme, t),
                const Spacer(flex: 2),
                _buildLoginButton(theme, colorScheme, t),
                const SizedBox(height: 20),
                _buildInfoCard(theme, colorScheme, t),
                if (_authState == _AuthState.error) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(theme, colorScheme, t),
                ],
                const Spacer(),
                Text(
                  t.solanaAuth.title,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, TranslationsEn t) {
    return Column(
      children: [
        // Animated logo ring
        _GlowLogo(colorScheme: cs)
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.7, 0.7), duration: 700.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),
        Text(
          t.solanaAuth.title,
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const SizedBox(height: 10),
        Text(
          t.solanaAuth.subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 350.ms, duration: 500.ms),
      ],
    );
  }

  Widget _buildLoginButton(ThemeData theme, ColorScheme cs, TranslationsEn t) {
    switch (_authState) {
      case _AuthState.loading:
        return _SolanaAuthButton(
          label: t.solanaAuth.connecting,
          subtitle: t.solanaAuth.openWallet,
          isLoading: true,
          onPressed: () {},
          colorScheme: cs,
        ).animate().fadeIn(duration: 300.ms);

      case _AuthState.error:
        return _SolanaAuthButton(
          label: t.solanaAuth.tryAgain,
          onPressed: _handleLogin,
          colorScheme: cs,
        ).animate().fadeIn(duration: 300.ms).shake(hz: 3, offset: const Offset(4, 0));

      case _AuthState.idle:
        return _SolanaAuthButton(
          label: t.solanaAuth.loginWithSolana,
          subtitle: t.solanaAuth.supportedWallets,
          onPressed: _handleLogin,
          colorScheme: cs,
        ).animate().fadeIn(delay: 500.ms, duration: 500.ms).slideY(begin: 0.4, duration: 500.ms);
    }
  }

  Widget _buildInfoCard(ThemeData theme, ColorScheme cs, TranslationsEn t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                t.solanaAuth.infoCard,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7), height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 650.ms, duration: 500.ms);
  }

  Widget _buildErrorMessage(ThemeData theme, ColorScheme cs, TranslationsEn t) {
    return Card(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? t.solanaAuth.errors.unknown,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).shake(hz: 2, offset: const Offset(3, 0));
  }
}

// ── Private sub-widgets ─────────────────────────────────────

class _SolanaAuthButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool isLoading;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  const _SolanaAuthButton({
    required this.label,
    this.subtitle,
    this.isLoading = false,
    required this.onPressed,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: subtitle != null ? 72 : 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
      ),
    );
  }
}

class _GlowLogo extends StatefulWidget {
  final ColorScheme colorScheme;
  const _GlowLogo({required this.colorScheme});

  @override
  State<_GlowLogo> createState() => _GlowLogoState();
}

class _GlowLogoState extends State<_GlowLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              startAngle: _ctrl.value * 6.28,
              colors: [cs.primary, cs.secondary, cs.tertiary, cs.primary],
            ),
            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: -4)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, shape: BoxShape.circle),
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.5), blurRadius: 20)],
                ),
                child: const Center(child: Icon(Icons.vpn_lock_rounded, size: 46, color: Colors.white)),
              ),
            ),
          ),
        );
      },
    );
  }
}
