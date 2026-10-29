// Seerr (/api/v1): catálogo TMDB, pesquisa, pedidos.
import 'package:dio/dio.dart';

const regiao = 'PT';

String? posterUrl(String? caminho, {int largura = 342}) =>
    caminho == null || caminho.isEmpty ? null : 'https://image.tmdb.org/t/p/w$largura$caminho';

/// Estado do media no servidor (mediaInfo.status do Seerr).
enum EstadoMedia { nenhum, pedido, parcial, disponivel }

EstadoMedia estadoDe(Map<String, dynamic>? mediaInfo) {
  switch ((mediaInfo?['status'] as num?)?.toInt()) {
    case 5:
      return EstadoMedia.disponivel;
    case 4:
      return EstadoMedia.parcial;
    case 2 || 3:
      return EstadoMedia.pedido;
    default:
      return EstadoMedia.nenhum;
  }
}

class ItemCatalogo {
  final int id;
  final String tipo; // movie | tv
  final String titulo;
  final String? ano;
  final String? poster;
  final EstadoMedia estado;

  const ItemCatalogo(this.id, this.tipo, this.titulo, this.ano, this.poster, this.estado);

  factory ItemCatalogo.fromJson(Map<String, dynamic> j, String tipoPadrao) {
    final tipo = (j['mediaType'] as String?) ?? tipoPadrao;
    final data = (j['releaseDate'] ?? j['firstAirDate']) as String?;
    return ItemCatalogo(
      (j['id'] as num).toInt(),
      tipo,
      ((j['title'] ?? j['name']) as String?) ?? '?',
      data != null && data.length >= 4 ? data.substring(0, 4) : null,
      j['posterPath'] as String?,
      estadoDe((j['mediaInfo'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

enum Seccao { aEstrear, recentes, populares, tendencia }

class SeerrApi {
  final Dio _d;
  SeerrApi(this._d);

  static String _data(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<List<ItemCatalogo>> descobrir(String tipo, Seccao s, {int? fornecedor, int? genero, int pagina = 1}) async {
    final filme = tipo == 'movie';
    final hoje = DateTime.now();
    final q = <String, dynamic>{'page': pagina, 'sortBy': 'popularity.desc'};
    if (fornecedor != null) {
      q['watchProviders'] = fornecedor;
      q['watchRegion'] = regiao;
    }
    if (genero != null) q['genre'] = genero;
    final gte = filme ? 'primaryReleaseDateGte' : 'firstAirDateGte';
    final lte = filme ? 'primaryReleaseDateLte' : 'firstAirDateLte';
    switch (s) {
      case Seccao.aEstrear:
        q[gte] = _data(hoje);
      case Seccao.recentes:
        q[gte] = _data(hoje.subtract(const Duration(days: 90)));
        q[lte] = _data(hoje);
      case Seccao.populares:
        break;
      case Seccao.tendencia:
        if (fornecedor == null && genero == null) {
          final r = await _d.get('/api/v1/discover/trending', queryParameters: {'page': pagina});
          return _lista(r.data, tipo).where((i) => i.tipo == tipo).toList();
        }
    }
    final r = await _d.get(filme ? '/api/v1/discover/movies' : '/api/v1/discover/tv', queryParameters: q);
    return _lista(r.data, tipo);
  }

  List<ItemCatalogo> _lista(dynamic dados, String tipo) => ((dados as Map)['results'] as List)
      .cast<Map>()
      .where((j) => j['mediaType'] == null || j['mediaType'] == 'movie' || j['mediaType'] == 'tv')
      .map((j) => ItemCatalogo.fromJson(j.cast<String, dynamic>(), tipo))
      .toList();

  /// Serviços de streaming em Portugal: [{id, name, logoPath, displayPriority}]
  Future<List<Map<String, dynamic>>> fornecedores(String tipo) async {
    final r = await _d.get('/api/v1/watchproviders/${tipo == 'movie' ? 'movies' : 'tv'}',
        queryParameters: {'watchRegion': regiao});
    return (r.data as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> generos(String tipo) async {
    final r = await _d.get('/api/v1/genres/${tipo == 'movie' ? 'movie' : 'tv'}');
    return (r.data as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<ItemCatalogo>> pesquisar(String texto) async {
    final r = await _d.get('/api/v1/search', queryParameters: {'query': texto, 'page': 1});
    return _lista(r.data, 'movie');
  }

  Future<Map<String, dynamic>> detalhe(String tipo, int id) async {
    final r = await _d.get('/api/v1/${tipo == 'movie' ? 'movie' : 'tv'}/$id');
    return (r.data as Map).cast<String, dynamic>();
  }

  /// Servidor e perfil 4K (UHD/2160p) do Radarr/Sonarr ligado ao Seerr.
  Future<({int servidor, int perfil})?> perfil4k(String tipo) async {
    final app = tipo == 'movie' ? 'radarr' : 'sonarr';
    final lista = (await _d.get('/api/v1/service/$app')).data as List;
    if (lista.isEmpty) return null;
    final sid = ((lista.first as Map)['id'] as num).toInt();
    final det = (await _d.get('/api/v1/service/$app/$sid')).data as Map;
    for (final p in (det['profiles'] as List? ?? []).cast<Map>()) {
      final n = (p['name'] as String).toLowerCase();
      if (n.contains('2160') || n.contains('uhd') || n.contains('4k')) {
        return (servidor: sid, perfil: (p['id'] as num).toInt());
      }
    }
    return null;
  }

  /// Cria um pedido. Em séries, [temporadas] null = todas.
  Future<void> pedir(String tipo, int id, {bool quatroK = false, List<int>? temporadas}) async {
    final corpo = <String, dynamic>{'mediaType': tipo, 'mediaId': id};
    if (tipo == 'tv') corpo['seasons'] = temporadas ?? 'all';
    if (quatroK) {
      final p = await perfil4k(tipo);
      if (p == null) throw Exception('Não há perfil 4K configurado.');
      corpo['serverId'] = p.servidor;
      corpo['profileId'] = p.perfil;
    }
    await _d.post('/api/v1/request', data: corpo);
  }

  Future<List<Map<String, dynamic>>> pedidos() async {
    final r = await _d.get('/api/v1/request', queryParameters: {'take': 50, 'skip': 0, 'sort': 'added', 'filter': 'all'});
    return ((r.data as Map)['results'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> aprovar(int id) => _d.post('/api/v1/request/$id/approve');
  Future<void> recusar(int id) => _d.post('/api/v1/request/$id/decline');
}
