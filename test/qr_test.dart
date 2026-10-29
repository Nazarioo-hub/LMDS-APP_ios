import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lmds_app/core/config.dart';
import 'package:lmds_app/core/qr.dart';

// Vetor gerado pela implementação de referência em Python (app/ferramentas/qr_lmds.py vetor):
// configuração FALSA, PIN 123456, salt 00..0f, nonce 64..6f.
const vetor =
    'lmds1:AAECAwQFBgcICQoLDA0OD2RlZmdoaWprbG1ub11PsSP03DdDxvzurLnDutd4TOnn02KTLasmZljVgBA8GQtZqbEZ0LC_vmRBs3s6zOPizVfMO4lNYvXbR8gKCKyF6t6QqP-mrKnjEFvWPx2VX6KR7ShYLA0g5QLzFbeFRAOiBk_Z9nk3UGcLgm0apsvtgcd0xofAEB-ThP_yOobphQ1eRnCEguR9uwZ0Vie_q1GhJkne1Cj50IhMMcoRiEGqD30wVdJliAMEqEZa6GYHDbgWXyXtU0LGez3m5gKR7yC54nwAFTuM_MQRPhzDQyqo9Gt0qKfW5sP3JJ92GoQRqaVaG8xKmg2Nq2NBOxgj0zrT8nKaX_nm0CfSEZeneEYtnhgiJjaHe5RU-iRN1wV_edthoAQzGd-kcIgV_jYk5anSSgO7WWzhQiFp9gGesmtxj5lXZCSeuMbBkH7K_7mrOYvCEu3i4_tnRTWC4t1UNSUzDioRvvnkIkNkNBT16Eh9cbAsmTUSmgKaiVEnNBFo1iXFX5e7B4ZdvZt870fg5GaQE0vs2Bn51zgho8OPyv39n8BoSGzsz58iFMI07ld5m9etyInnz2eXSNlXVRv0_y8W4KATUhXlhM6_BgW37qfhlBcMkIOty0ybV6USAndn8zoeSxebQzJum_pv9Izn_3s05TRTuXVH8rAGoCivPas';

void main() {
  test('decifra o vetor de referência (Python) e lê a configuração', () async {
    final json = await decifrarQr(vetor, '123456');
    final cfg = ServidorCfg.fromJson(json);
    expect(cfg.nome, 'LMDS-teste');
    expect(cfg.lan, '192.168.1.10');
    expect(cfg.tailscale, '100.64.0.10');
    expect(cfg.tailscaleNome, 'lmds-teste');
    expect(cfg.servicos['seerr']!.porta, 5055);
    expect(cfg.servicos['seerr']!.apiKey, 'chave-falsa-seerr');
    expect(cfg.servicos['qbittorrent']!.utilizador, 'teste');
    expect(cfg.servicos['maintainerr']!.apiKey, isNull);
    expect(cfg.portaSonda, 5055);
  });

  test('PIN errado é recusado com mensagem simples', () async {
    expect(
      () => decifrarQr(vetor, '654321'),
      throwsA(isA<QrInvalido>().having((e) => e.motivo, 'motivo', 'PIN errado.')),
    );
  });

  test('QR de outra coisa é recusado', () async {
    expect(() => decifrarQr('https://exemplo.pt', '123456'), throwsA(isA<QrInvalido>()));
    expect(() => decifrarQr('lmds1:@@@', '123456'), throwsA(isA<QrInvalido>()));
  });

  // Compatibilidade com o /app do bot: LMDS_QR_SERVIDOR = QR de teste (configuração FALSA, PIN 246810)
  // gerado com mod_app.cifrar() no servidor. Só corre se a variável existir.
  test('decifra um QR gerado pelo código do servidor (mod_app.py)', () async {
    final qr = Platform.environment['LMDS_QR_SERVIDOR'];
    if (qr == null) return markTestSkipped('LMDS_QR_SERVIDOR não definido');
    final cfg = ServidorCfg.fromJson(await decifrarQr(qr, '246810'));
    expect(cfg.nome, 'LMDS-servidor-teste');
    expect(cfg.tailscaleNome, isNull);
    expect(cfg.servicos['seerr']!.porta, 5055);
  });

  test('cifrar → decifrar devolve o mesmo JSON (e a configuração sobrevive a toJson)', () async {
    final orig = ServidorCfg.fromJson(await decifrarQr(vetor, '123456')).toJson();
    final texto = await cifrarQr(orig, '000111');
    expect(texto.startsWith(prefixoQr), isTrue);
    expect(await decifrarQr(texto, '000111'), orig);
  });
}
