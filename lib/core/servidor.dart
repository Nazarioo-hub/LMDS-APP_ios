// Acesso central aos serviços: junta a configuração do QR com o endereço ativo
// (casa ou Tailscale) e cria um cliente HTTP por serviço, já autenticado.
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../servicos/arr.dart';
import '../servicos/qbit.dart';
import '../servicos/seerr.dart';
import 'armazenamento.dart';
import 'config.dart';
import 'ligacao.dart';

class Servidor {
  final ServidorCfg cfg;
  final String host;
  final _dios = <String, Dio>{};

  Servidor(this.cfg, this.host);

  bool tem(String s) => cfg.tem(s);
  String base(String s) => 'http://$host:${cfg.servicos[s]!.porta}';

  Dio dio(String s) => _dios.putIfAbsent(s, () {
        final sc = cfg.servicos[s]!;
        final h = <String, String>{'Accept': 'application/json'};
        switch (s) {
          case 'seerr' || 'sonarr' || 'radarr' || 'prowlarr' || 'chaptarr':
            h['X-Api-Key'] = sc.apiKey ?? '';
          case 'bazarr':
            h['X-API-KEY'] = sc.apiKey ?? '';
          case 'tdarr':
            h['x-api-key'] = sc.apiKey ?? '';
          case 'jellyfin':
            h['X-Emby-Token'] = sc.apiKey ?? '';
          case 'plex':
            h['X-Plex-Token'] = sc.token ?? '';
        }
        return Dio(BaseOptions(
          baseUrl: base(s),
          headers: h,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 20),
        ));
      });

  late final SeerrApi seerr = SeerrApi(dio('seerr'));
  late final ArrApi sonarr = ArrApi(dio('sonarr'), ArrTipo.sonarr);
  late final ArrApi radarr = ArrApi(dio('radarr'), ArrTipo.radarr);
  late final QbitApi qbit = QbitApi(base('qbittorrent'), cfg.servicos['qbittorrent']!);

  ArrApi arr(ArrTipo t) => t == ArrTipo.sonarr ? sonarr : radarr;
}

/// null enquanto não há configuração ou ligação.
final servidorProvider = Provider<Servidor?>((ref) {
  final cfg = ref.watch(configProvider).valueOrNull;
  final l = ref.watch(ligacaoProvider);
  if (cfg == null || l.host == null) return null;
  return Servidor(cfg, l.host!);
});

/// Para os ecrãs: devolve o servidor ou lança um erro legível.
Servidor exigirServidor(Ref ref) {
  final s = ref.watch(servidorProvider);
  if (s == null) throw const SemLigacao();
  return s;
}

class SemLigacao implements Exception {
  const SemLigacao();
  @override
  String toString() => 'Sem ligação ao servidor.';
}

/// Converte erros técnicos em mensagens simples.
String mensagemErro(Object e) {
  if (e is SemLigacao) return e.toString();
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout:
        return 'O serviço demorou demasiado a responder (pode estar a dormir).';
      case DioExceptionType.connectionError:
        return 'Não consegui ligar ao serviço.';
      default:
        final c = e.response?.statusCode;
        if (c == 401 || c == 403) return 'Acesso recusado (chave ou login errado).';
        if (c != null) return 'O serviço respondeu com erro $c.';
    }
  }
  return e.toString();
}
