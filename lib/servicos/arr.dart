// Sonarr e Radarr (/api/v3): biblioteca, calendário, fila, histórico, procurar.
import 'package:dio/dio.dart';

enum ArrTipo { sonarr, radarr }

typedef Json = Map<String, dynamic>;

List<Json> _maps(dynamic l) => (l as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();

class ArrApi {
  final Dio _d;
  final ArrTipo tipo;
  ArrApi(this._d, this.tipo);

  bool get series => tipo == ArrTipo.sonarr;

  Future<List<Json>> biblioteca() async {
    final r = await _d.get(series ? '/api/v3/series' : '/api/v3/movie');
    final l = _maps(r.data)..sort((a, b) => (a['sortTitle'] ?? a['title']).toString().compareTo((b['sortTitle'] ?? b['title']).toString()));
    return l;
  }

  Future<List<Json>> calendario({int dias = 14}) async {
    final hoje = DateTime.now().toUtc();
    final r = await _d.get('/api/v3/calendar', queryParameters: {
      'start': hoje.toIso8601String(),
      'end': hoje.add(Duration(days: dias)).toIso8601String(),
      if (series) 'includeSeries': true,
    });
    return _maps(r.data);
  }

  Future<List<Json>> fila() async {
    final r = await _d.get('/api/v3/queue', queryParameters: {
      'pageSize': 50,
      if (series) 'includeSeries': true,
      if (series) 'includeEpisode': true,
      if (!series) 'includeMovie': true,
    });
    return _maps((r.data as Map)['records']);
  }

  Future<List<Json>> historico({int quantos = 30}) async {
    final r = await _d.get('/api/v3/history', queryParameters: {
      'pageSize': quantos,
      'sortKey': 'date',
      'sortDirection': 'descending',
      if (series) 'includeSeries': true,
      if (series) 'includeEpisode': true,
      if (!series) 'includeMovie': true,
    });
    return _maps((r.data as Map)['records']);
  }

  /// Importados (descarregados e copiados para a biblioteca) desde [desde].
  Future<int> importadosDesde(DateTime desde) async {
    final r = await _d.get('/api/v3/history/since', queryParameters: {
      'date': desde.toUtc().toIso8601String(),
      'eventType': 3, // downloadFolderImported
    });
    return (r.data as List).length;
  }

  Future<void> procurar(int id) => _d.post('/api/v3/command',
      data: series ? {'name': 'SeriesSearch', 'seriesId': id} : {'name': 'MoviesSearch', 'movieIds': [id]});
}

String? posterArr(Json item) {
  final imgs = (item['images'] as List? ?? []).cast<Map>();
  for (final i in imgs) {
    if (i['coverType'] == 'poster') return (i['remoteUrl'] ?? i['url']) as String?;
  }
  return null;
}
