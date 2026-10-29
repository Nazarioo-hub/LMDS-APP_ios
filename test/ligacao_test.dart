import 'package:flutter_test/flutter_test.dart';
import 'package:lmds_app/core/config.dart';
import 'package:lmds_app/core/ligacao.dart';

const cfg = ServidorCfg(
  versao: 1,
  nome: 'teste',
  lan: '192.168.1.10',
  tailscale: '100.64.0.10',
  tailscaleNome: 'lmds-teste',
  servicos: {'seerr': ServicoCfg(porta: 5055)},
);

/// Sonda falsa: só "responde" nos hosts indicados e regista as tentativas.
Sonda sondaFalsa(Set<String> vivos, List<String> tentativas) => (host, porta, limite) async {
      tentativas.add('$host:$porta@${limite.inMilliseconds}');
      return vivos.contains(host);
    };

void main() {
  test('em casa usa a LAN e não tenta o Tailscale', () async {
    final t = <String>[];
    final e = await escolherLigacao(cfg, sondaFalsa({'192.168.1.10', '100.64.0.10'}, t));
    expect(e.modo, ModoLigacao.casa);
    expect(e.host, '192.168.1.10');
    expect(t, ['192.168.1.10:5055@1500']);
  });

  test('fora de casa passa para o Tailscale por IP', () async {
    final t = <String>[];
    final e = await escolherLigacao(cfg, sondaFalsa({'100.64.0.10'}, t));
    expect(e.modo, ModoLigacao.tailscale);
    expect(e.host, '100.64.0.10');
    expect(t.length, 2);
  });

  test('se o IP do Tailscale falhar, tenta o nome (MagicDNS)', () async {
    final e = await escolherLigacao(cfg, sondaFalsa({'lmds-teste'}, []));
    expect(e.modo, ModoLigacao.tailscale);
    expect(e.host, 'lmds-teste');
  });

  test('sem nada a responder fica "sem ligação"', () async {
    final e = await escolherLigacao(cfg, sondaFalsa({}, []));
    expect(e.modo, ModoLigacao.semLigacao);
    expect(e.host, isNull);
  });
}
