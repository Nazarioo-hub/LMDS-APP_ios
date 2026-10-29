// qBittorrent WebUI API v2, com sessão por cookie SID.
import 'package:dio/dio.dart';

import '../core/config.dart';

typedef Json = Map<String, dynamic>;

class QbitApi {
  final ServicoCfg _cfg;
  final Dio _d;
  String? _sid;

  QbitApi(String base, this._cfg)
      : _d = Dio(BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 20),
          // o qBittorrent recusa pedidos sem Referer/Origin iguais ao endereço
          headers: {'Referer': '$base/', 'Origin': base},
        ));

  Future<void> _entrar() async {
    final r = await _d.post('/api/v2/auth/login',
        data: {'username': _cfg.utilizador ?? '', 'password': _cfg.password ?? ''},
        options: Options(contentType: Headers.formUrlEncodedContentType, responseType: ResponseType.plain));
    // 4.x chama-lhe "SID"; 5.x chama-lhe "QBT_SID_<porta>"
    final cookie = (r.headers['set-cookie'] ?? const [])
        .firstWhere((c) => RegExp(r'^[A-Za-z_]*SID[A-Za-z0-9_]*=').hasMatch(c), orElse: () => '');
    if (cookie.isEmpty) throw Exception('Login no qBittorrent recusado.');
    _sid = cookie.split(';').first;
  }

  Future<Response<T>> _pedido<T>(Future<Response<T>> Function(Options o) fazer) async {
    if (_sid == null) await _entrar();
    try {
      return await fazer(Options(headers: {'Cookie': _sid}));
    } on DioException catch (e) {
      if (e.response?.statusCode != 403) rethrow;
      await _entrar(); // sessão expirou
      return fazer(Options(headers: {'Cookie': _sid}));
    }
  }

  Future<List<Json>> torrents() async {
    final r = await _pedido((o) => _d.get('/api/v2/torrents/info', queryParameters: {'sort': 'added_on', 'reverse': true}, options: o));
    return (r.data as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Json> transferencia() async {
    final r = await _pedido((o) => _d.get('/api/v2/transfer/info', options: o));
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<bool> limiteAlternativo() async {
    final r = await _pedido((o) => _d.get('/api/v2/transfer/speedLimitsMode', options: o..responseType = ResponseType.plain));
    return r.data.toString().trim() == '1';
  }

  Future<void> alternarLimite() => _pedido((o) => _d.post('/api/v2/transfer/toggleSpeedLimitsMode', options: o));

  Future<void> _acao(String nova, String antiga, Map<String, dynamic> dados) async {
    final f = FormData.fromMap(dados);
    try {
      await _pedido((o) => _d.post('/api/v2/torrents/$nova', data: f.clone(), options: o));
    } on DioException catch (e) {
      // qBittorrent 4.x usa pause/resume; o 5.x usa stop/start
      if (e.response?.statusCode != 404) rethrow;
      await _pedido((o) => _d.post('/api/v2/torrents/$antiga', data: f.clone(), options: o));
    }
  }

  Future<void> pausar(String hash) => _acao('stop', 'pause', {'hashes': hash});
  Future<void> retomar(String hash) => _acao('start', 'resume', {'hashes': hash});

  /// [ficheiros] = também apaga o que foi descarregado.
  Future<void> remover(String hash, {bool ficheiros = false}) => _pedido((o) => _d.post('/api/v2/torrents/delete',
      data: FormData.fromMap({'hashes': hash, 'deleteFiles': ficheiros.toString()}), options: o));
}
