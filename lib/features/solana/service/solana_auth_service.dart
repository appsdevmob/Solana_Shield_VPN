import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

// ---------------------------------------------------------------------------
// Persistence keys
// ---------------------------------------------------------------------------
const _kWalletAddress = 'solana_wallet_address';
const _kAuthToken = 'solana_auth_token';
const _kPublicKeyBytes = 'solana_pubkey_bytes';

// ---------------------------------------------------------------------------
// Singleton factory — real wallet on Android, mock elsewhere
// ---------------------------------------------------------------------------
final SolanaAuthService _singletonInstance = kIsWeb ? SolanaAuthServiceMock.instance : SolanaAuthServiceReal.instance;

/// Shared interface for Solana wallet authentication.
abstract class SolanaAuthService {
  static SolanaAuthService get instance => _singletonInstance;

  String? get walletAddress;
  String? get authToken;
  bool get isAuthenticated;
  bool get isWalletConnected;

  Future<String> connectWallet();
  Future<String> signMessage(String message);
  Future<String> connectAndSign(String message);
  Future<Uint8List> signTransaction(Uint8List transaction);
  Future<void> logout();
  Future<bool> validateToken();
  Future<String> refreshToken();
  Future<double> getBalance();
  Future<Map<String, dynamic>> getWalletInfo();
  Future<bool> isWalletAvailable();

  /// Restore session from SharedPreferences (called at startup).
  Future<void> restoreSession();
}

// ---------------------------------------------------------------------------
// Real implementation — official solana_mobile_client MWA
// ---------------------------------------------------------------------------
class SolanaAuthServiceReal extends SolanaAuthService {
  SolanaAuthServiceReal._();
  static final SolanaAuthServiceReal instance = SolanaAuthServiceReal._();

  AuthorizationResult? _authorizationResult;
  String? _cachedWalletAddress;
  String? _cachedAuthToken;

  static final Uri _identityUri = Uri.parse('https://vpn-solana.app');
  static final Uri _iconUri = Uri.parse('favicon.ico');
  static const String _identityName = 'VPN Solana';
  static const String _cluster = 'mainnet-beta';

  @override
  String? get walletAddress =>
      _cachedWalletAddress ??
      (_authorizationResult?.publicKey != null ? Ed25519HDPublicKey(_authorizationResult!.publicKey).toBase58() : null);

  @override
  String? get authToken => _authorizationResult?.authToken ?? _cachedAuthToken;

  @override
  bool get isAuthenticated => walletAddress != null && authToken != null;

  @override
  bool get isWalletConnected => walletAddress != null;

  @override
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString(_kWalletAddress);
      final savedToken = prefs.getString(_kAuthToken);
      if (savedAddress != null && savedToken != null) {
        _cachedWalletAddress = savedAddress;
        _cachedAuthToken = savedToken;
        if (kDebugMode) print('Solana Real: session restored — $savedAddress');
      }
    } catch (e) {
      if (kDebugMode) print('Solana Real: restoreSession error: $e');
    }
  }

  Future<void> _saveSession() async {
    try {
      if (walletAddress == null || authToken == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWalletAddress, walletAddress!);
      await prefs.setString(_kAuthToken, authToken!);
      if (_authorizationResult?.publicKey != null) {
        await prefs.setString(_kPublicKeyBytes, base64Encode(_authorizationResult!.publicKey));
      }
    } catch (e) {
      if (kDebugMode) print('Solana Real: _saveSession error: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kWalletAddress);
      await prefs.remove(_kAuthToken);
      await prefs.remove(_kPublicKeyBytes);
      _cachedWalletAddress = null;
      _cachedAuthToken = null;
    } catch (_) {}
  }

  @override
  Future<bool> isWalletAvailable() async {
    try {
      return await LocalAssociationScenario.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> connectWallet() async {
    if (kDebugMode) print('Solana Real: connecting via MWA…');
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start().timeout(const Duration(seconds: 60));

      // Try reauthorize if we have a saved token
      if (_cachedAuthToken != null) {
        try {
          final reauth = await client.reauthorize(
            identityUri: _identityUri,
            iconUri: _iconUri,
            identityName: _identityName,
            authToken: _cachedAuthToken!,
          );
          if (reauth != null) {
            _authorizationResult = reauth;
            _cachedWalletAddress = Ed25519HDPublicKey(reauth.publicKey).toBase58();
            await _saveSession();
            return walletAddress!;
          }
        } catch (_) {
          // Fall through to full authorize
        }
      }

      final result = await client.authorize(
        identityUri: _identityUri,
        iconUri: _iconUri,
        identityName: _identityName,
        cluster: _cluster,
      );
      if (result == null) throw Exception('Authorization cancelled or rejected by wallet');

      _authorizationResult = result;
      _cachedWalletAddress = Ed25519HDPublicKey(result.publicKey).toBase58();
      await _saveSession();
      return walletAddress!;
    } catch (e) {
      if (kDebugMode) print('Solana Real: connectWallet error: $e');
      rethrow;
    } finally {
      await session.close();
    }
  }

  @override
  Future<String> connectAndSign(String message) async => await connectWallet();

  Future<bool> _doReauthorize(MobileWalletAdapterClient client) async {
    final token = authToken;
    if (token == null) return false;
    final result = await client.reauthorize(
      identityUri: _identityUri,
      iconUri: _iconUri,
      identityName: _identityName,
      authToken: token,
    );
    if (result != null) {
      _authorizationResult = result;
      await _saveSession();
      return true;
    }
    return false;
  }

  @override
  Future<String> signMessage(String message) async {
    if (!isAuthenticated) throw Exception('Wallet not connected');
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      if (await _doReauthorize(client)) {
        final messageBytes = Uint8List.fromList(utf8.encode(message));
        final result = await client.signMessages(
          messages: [messageBytes],
          addresses: [_authorizationResult!.publicKey],
        );
        if (result.signedMessages.isEmpty || result.signedMessages.first.signatures.isEmpty) {
          throw Exception('No signature returned');
        }
        return base64Encode(result.signedMessages.first.signatures.first);
      }
      throw Exception('Failed to reauthorize');
    } finally {
      await session.close();
    }
  }

  @override
  Future<Uint8List> signTransaction(Uint8List transaction) async {
    if (!isAuthenticated) throw Exception('Wallet not connected');
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      if (await _doReauthorize(client)) {
        final result = await client.signTransactions(transactions: [transaction]);
        if (result.signedPayloads.isEmpty) throw Exception('No signature returned');
        return result.signedPayloads.first;
      }
      throw Exception('Failed to reauthorize');
    } finally {
      await session.close();
    }
  }

  @override
  Future<void> logout() async {
    final token = authToken;
    if (token != null) {
      try {
        final session = await LocalAssociationScenario.create();
        session.startActivityForResult(null).ignore();
        try {
          final client = await session.start();
          await client.deauthorize(authToken: token);
        } finally {
          await session.close();
        }
      } catch (e) {
        if (kDebugMode) print('Solana Real: logout error: $e');
      }
    }
    _authorizationResult = null;
    await _clearSession();
  }

  @override
  Future<bool> validateToken() async => isAuthenticated;

  @override
  Future<String> refreshToken() async {
    if (!isAuthenticated) throw Exception('No auth token to refresh');
    final session = await LocalAssociationScenario.create();
    session.startActivityForResult(null).ignore();
    try {
      final client = await session.start();
      if (!await _doReauthorize(client)) {
        throw Exception('Failed to refresh token');
      }
      return authToken!;
    } finally {
      await session.close();
    }
  }

  @override
  Future<double> getBalance() async => 0.0;

  @override
  Future<Map<String, dynamic>> getWalletInfo() async => {
    'address': walletAddress,
    'balance': await getBalance(),
    'network': _cluster,
    'isMock': false,
  };
}

// ---------------------------------------------------------------------------
// Mock implementation — used on web or when no wallet is installed
// ---------------------------------------------------------------------------
class SolanaAuthServiceMock extends SolanaAuthService {
  SolanaAuthServiceMock._();
  static final SolanaAuthServiceMock instance = SolanaAuthServiceMock._();

  String? _walletAddress;
  String? _authToken;

  @override
  String? get walletAddress => _walletAddress;
  @override
  String? get authToken => _authToken;
  @override
  bool get isAuthenticated => _walletAddress != null && _authToken != null;
  @override
  bool get isWalletConnected => _walletAddress != null;

  String _makeToken() => 'sol_mock_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _walletAddress = prefs.getString(_kWalletAddress);
      _authToken = prefs.getString(_kAuthToken);
    } catch (_) {}
  }

  @override
  Future<bool> isWalletAvailable() async => true;

  @override
  Future<String> connectWallet() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    _walletAddress = '8xKtT3xMock3m2P';
    _authToken = _makeToken();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kWalletAddress, _walletAddress!);
      await prefs.setString(_kAuthToken, _authToken!);
    } catch (_) {}
    return _walletAddress!;
  }

  @override
  Future<String> signMessage(String message) async {
    if (!isAuthenticated) throw Exception('Wallet not connected');
    return base64Encode(Uint8List.fromList('mock_sig'.codeUnits));
  }

  @override
  Future<String> connectAndSign(String message) async {
    await connectWallet();
    return _walletAddress!;
  }

  @override
  Future<Uint8List> signTransaction(Uint8List transaction) async {
    if (!isAuthenticated) throw Exception('Wallet not connected');
    return Uint8List.fromList(transaction);
  }

  @override
  Future<void> logout() async {
    _walletAddress = null;
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kWalletAddress);
      await prefs.remove(_kAuthToken);
    } catch (_) {}
  }

  @override
  Future<bool> validateToken() async => _authToken != null;

  @override
  Future<String> refreshToken() async {
    _authToken = _makeToken();
    return _authToken!;
  }

  @override
  Future<double> getBalance() async => DateTime.now().millisecond / 10.0;

  @override
  Future<Map<String, dynamic>> getWalletInfo() async => {
    'address': _walletAddress,
    'balance': await getBalance(),
    'network': 'mainnet-beta',
    'isMock': true,
  };
}
