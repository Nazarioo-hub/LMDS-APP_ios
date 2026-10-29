// Modelo da configuração de um servidor LMDS, tal como vem no QR privado.
// Nada disto está embutido na app: cada pessoa lê o QR do seu próprio servidor.

class ServicoCfg {
  final int porta;
  final String? apiKey;
  final String? utilizador;
  final String? password;
  final String? token;

  const ServicoCfg({required this.porta, this.apiKey, this.utilizador, this.password, this.token});

  factory ServicoCfg.fromJson(Map<String, dynamic> j) => ServicoCfg(
        porta: (j['porta'] as num).toInt(),
        apiKey: j['api_key'] as String?,
        utilizador: j['utilizador'] as String?,
        password: j['password'] as String?,
        token: j['token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'porta': porta,
        if (apiKey != null) 'api_key': apiKey,
        if (utilizador != null) 'utilizador': utilizador,
        if (password != null) 'password': password,
        if (token != null) 'token': token,
      };
}

class ServidorCfg {
  final int versao;
  final String nome;
  final String lan;
  final String tailscale;
  final String? tailscaleNome;
  final Map<String, ServicoCfg> servicos;

  const ServidorCfg({
    required this.versao,
    required this.nome,
    required this.lan,
    required this.tailscale,
    this.tailscaleNome,
    required this.servicos,
  });

  factory ServidorCfg.fromJson(Map<String, dynamic> j) {
    final end = (j['enderecos'] as Map).cast<String, dynamic>();
    final sv = (j['servicos'] as Map).cast<String, dynamic>();
    return ServidorCfg(
      versao: (j['v'] as num?)?.toInt() ?? 1,
      nome: (j['nome'] as String?) ?? 'LMDS',
      lan: end['lan'] as String,
      tailscale: end['tailscale'] as String,
      tailscaleNome: end['tailscale_nome'] as String?,
      servicos: sv.map((k, v) => MapEntry(k, ServicoCfg.fromJson((v as Map).cast<String, dynamic>()))),
    );
  }

  Map<String, dynamic> toJson() => {
        'v': versao,
        'nome': nome,
        'enderecos': {'lan': lan, 'tailscale': tailscale, if (tailscaleNome != null) 'tailscale_nome': tailscaleNome},
        'servicos': servicos.map((k, v) => MapEntry(k, v.toJson())),
      };

  bool tem(String servico) => servicos.containsKey(servico);

  /// Porta usada para testar se o servidor responde (o Seerr é o coração da app).
  int get portaSonda => servicos['seerr']?.porta ?? servicos.values.first.porta;
}
