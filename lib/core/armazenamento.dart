import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';

/// Guarda a configuração do servidor no armazenamento seguro do telemóvel
/// (Keystore no Android, Keychain no iOS).
class Armazenamento {
  static const _chave = 'lmds_servidor';
  final FlutterSecureStorage _s;
  Armazenamento([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();

  Future<ServidorCfg?> ler() async {
    final t = await _s.read(key: _chave);
    if (t == null) return null;
    return ServidorCfg.fromJson((jsonDecode(t) as Map).cast<String, dynamic>());
  }

  Future<void> guardar(ServidorCfg c) => _s.write(key: _chave, value: jsonEncode(c.toJson()));
  Future<void> apagar() => _s.delete(key: _chave);
}

final configProvider = AsyncNotifierProvider<ConfigNotifier, ServidorCfg?>(ConfigNotifier.new);

class ConfigNotifier extends AsyncNotifier<ServidorCfg?> {
  final _arm = Armazenamento();

  @override
  Future<ServidorCfg?> build() => _arm.ler();

  Future<void> guardar(ServidorCfg c) async {
    await _arm.guardar(c);
    state = AsyncData(c);
  }

  Future<void> esquecer() async {
    await _arm.apagar();
    state = const AsyncData(null);
  }
}
