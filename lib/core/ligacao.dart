// Escolha automática do endereço: primeiro a rede de casa, depois o Tailscale.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'armazenamento.dart';
import 'config.dart';

enum ModoLigacao { aVerificar, casa, tailscale, semLigacao }

class EstadoLigacao {
  final ModoLigacao modo;
  final String? host;
  const EstadoLigacao(this.modo, this.host);
}

/// Responde true se houver um servidor HTTP a responder em host:porta.
typedef Sonda = Future<bool> Function(String host, int porta, Duration limite);

Future<bool> sondaHttp(String host, int porta, Duration limite) async {
  final dio = Dio(BaseOptions(connectTimeout: limite, receiveTimeout: limite, validateStatus: (_) => true));
  try {
    await dio.get('http://$host:$porta/');
    return true; // qualquer resposta HTTP serve: o servidor está lá
  } catch (_) {
    return false;
  } finally {
    dio.close(force: true);
  }
}

/// Casa (1,5 s) → Tailscale por IP → Tailscale por nome (MagicDNS).
Future<EstadoLigacao> escolherLigacao(ServidorCfg cfg, Sonda sonda) async {
  final porta = cfg.portaSonda;
  if (await sonda(cfg.lan, porta, const Duration(milliseconds: 1500))) {
    return EstadoLigacao(ModoLigacao.casa, cfg.lan);
  }
  for (final h in [cfg.tailscale, if (cfg.tailscaleNome != null) cfg.tailscaleNome!]) {
    if (await sonda(h, porta, const Duration(seconds: 4))) {
      return EstadoLigacao(ModoLigacao.tailscale, h);
    }
  }
  return const EstadoLigacao(ModoLigacao.semLigacao, null);
}

final ligacaoProvider = NotifierProvider<LigacaoNotifier, EstadoLigacao>(LigacaoNotifier.new);

class LigacaoNotifier extends Notifier<EstadoLigacao> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _aVerificar = false;

  @override
  EstadoLigacao build() {
    final cfg = ref.watch(configProvider).valueOrNull;
    _sub?.cancel();
    if (cfg == null) return const EstadoLigacao(ModoLigacao.semLigacao, null);
    // quando a rede muda (Wi-Fi ↔ dados), volta a escolher o endereço
    _sub = Connectivity().onConnectivityChanged.listen((_) => verificar());
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(verificar);
    return const EstadoLigacao(ModoLigacao.aVerificar, null);
  }

  Future<void> verificar() async {
    final cfg = ref.read(configProvider).valueOrNull;
    if (cfg == null || _aVerificar) return;
    _aVerificar = true;
    try {
      state = EstadoLigacao(ModoLigacao.aVerificar, state.host);
      state = await escolherLigacao(cfg, sondaHttp);
    } finally {
      _aVerificar = false;
    }
  }
}
