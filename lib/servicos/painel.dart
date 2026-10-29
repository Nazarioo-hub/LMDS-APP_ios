// Dados do painel "Servidor": estado dos serviços, Tdarr, Bazarr e o que fez hoje.
import 'package:dio/dio.dart';

import '../core/servidor.dart';

class EstadoTdarr {
  final bool aDormir;
  final int fila, convertidos, erros;
  final double poupadoGb;
  const EstadoTdarr({this.aDormir = false, this.fila = 0, this.convertidos = 0, this.erros = 0, this.poupadoGb = 0});
}

class Hoje {
  final int episodios, filmes;
  final int? descarregadoBytes;
  const Hoje(this.episodios, this.filmes, this.descarregadoBytes);
}

/// Nomes amigáveis e ordem no painel.
const nomesServicos = {
  'seerr': 'Pedidos (Seerr)',
  'sonarr': 'Séries (Sonarr)',
  'radarr': 'Filmes (Radarr)',
  'qbittorrent': 'Downloads (qBittorrent)',
  'prowlarr': 'Indexers (Prowlarr)',
  'bazarr': 'Legendas (Bazarr)',
  'jellyfin': 'Jellyfin',
  'plex': 'Plex',
  'tautulli': 'Tautulli',
  'tdarr': 'Conversão (Tdarr)',
  'maintainerr': 'Limpeza (Maintainerr)',
  'chaptarr': 'Livros (Chaptarr)',
  'audiobookshelf': 'Audiolivros',
};

class PainelApi {
  final Servidor s;
  PainelApi(this.s);

  Future<Map<String, bool>> estados() async {
    final nomes = nomesServicos.keys.where(s.tem).toList();
    final r = await Future.wait(nomes.map((n) async {
      final d = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 6),
          validateStatus: (c) => c != null && c < 500));
      try {
        final caminho = n == 'plex' ? '/identity' : '/';
        await d.get('${s.base(n)}$caminho');
        return true;
      } catch (_) {
        return false;
      } finally {
        d.close(force: true);
      }
    }));
    return {for (var i = 0; i < nomes.length; i++) nomes[i]: r[i]};
  }

  Future<EstadoTdarr?> tdarr() async {
    if (!s.tem('tdarr')) return null;
    final d = s.dio('tdarr');
    Future<Map> tabela(String t, int n) async => (await d.post('/api/v2/client/status-tables',
            data: {
              'data': {'start': 0, 'pageSize': n, 'filters': [], 'sorts': [], 'opts': {'table': t}}
            },
            options: Options(receiveTimeout: const Duration(seconds: 8), sendTimeout: const Duration(seconds: 8))))
        .data as Map;
    try {
      final fila = await tabela('table1', 1);
      final ok = await tabela('table2', 500);
      final erro = await tabela('table3', 1);
      var poupado = 0.0;
      for (final f in (ok['array'] as List? ?? []).cast<Map>()) {
        final antes = (f['oldSize'] as num?)?.toDouble() ?? 0, depois = (f['newSize'] as num?)?.toDouble() ?? 0;
        if (antes > 0 && depois > 0 && antes > depois) poupado += antes - depois; // em GB
      }
      return EstadoTdarr(
        fila: (fila['totalCount'] as num?)?.toInt() ?? 0,
        convertidos: (ok['totalCount'] as num?)?.toInt() ?? 0,
        erros: (erro['totalCount'] as num?)?.toInt() ?? 0,
        poupadoGb: poupado,
      );
    } on DioException {
      // fora das 01h–07h o Tdarr está congelado e não responde
      return const EstadoTdarr(aDormir: true);
    }
  }

  Future<({int episodios, int filmes})?> legendasEmFalta() async {
    if (!s.tem('bazarr')) return null;
    final d = s.dio('bazarr');
    final e = await d.get('/api/episodes/wanted', queryParameters: {'start': 0, 'length': 1});
    final f = await d.get('/api/movies/wanted', queryParameters: {'start': 0, 'length': 1});
    return (episodios: ((e.data as Map)['total'] as num?)?.toInt() ?? 0, filmes: ((f.data as Map)['total'] as num?)?.toInt() ?? 0);
  }

  Future<Hoje> hoje() async {
    final desde = DateTime.now().subtract(const Duration(hours: 24));
    final ep = s.tem('sonarr') ? await s.sonarr.importadosDesde(desde) : 0;
    final fi = s.tem('radarr') ? await s.radarr.importadosDesde(desde) : 0;
    int? bytes;
    try {
      bytes = ((await s.qbit.transferencia())['dl_info_data'] as num?)?.toInt();
    } catch (_) {}
    return Hoje(ep, fi, bytes);
  }
}
