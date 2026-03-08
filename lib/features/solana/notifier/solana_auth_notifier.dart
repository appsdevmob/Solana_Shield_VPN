import 'package:hiddify/features/solana/service/solana_auth_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Провайдер экземпляра SolanaAuthService
final solanaAuthServiceProvider = Provider<SolanaAuthService>((ref) {
  return SolanaAuthService.instance;
});

/// Провайдер статуса авторизации Solana
final solanaIsAuthenticatedProvider = StateProvider<bool>((ref) {
  return ref.read(solanaAuthServiceProvider).isAuthenticated;
});

/// Провайдер адреса кошелька
final solanaWalletAddressProvider = Provider<String?>((ref) {
  // Подписываемся на изменение статуса аутентификации
  ref.watch(solanaIsAuthenticatedProvider);
  return ref.read(solanaAuthServiceProvider).walletAddress;
});
