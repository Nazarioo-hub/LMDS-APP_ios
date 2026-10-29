// qBittorrent: lista de torrents, velocidades e ações.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/servidor.dart';
import '../servicos/qbit.dart';
import 'comum.dart';

typedef _Dados = ({List<Json> torrents, Json transferencia, bool limite});

final _qbitProvider = FutureProvider.autoDispose<_Dados>((ref) async {
  final q = exigirServidor(ref).qbit;
  final r = await Future.wait([q.torrents(), q.transferencia(), q.limiteAlternativo()]);
  // atualiza sozinho a cada 4 s enquanto o ecrã está aberto
  final t = Timer(const Duration(seconds: 4), ref.invalidateSelf);
  ref.onDispose(t.cancel);
  return (torrents: r[0] as List<Json>, transferencia: r[1] as Json, limite: r[2] as bool);
});

const _estados = {
  'downloading': '⬇️ A descarregar',
  'forcedDL': '⬇️ A descarregar',
  'metaDL': '🔍 A obter dados',
  'stalledDL': '⏸️ Sem fontes',
  'queuedDL': '⏳ Na fila',
  'pausedDL': '⏸️ Em pausa',
  'stoppedDL': '⏸️ Em pausa',
  'uploading': '⬆️ A partilhar',
  'stalledUP': '✅ Terminado',
  'queuedUP': '✅ Terminado',
  'pausedUP': '✅ Terminado',
  'stoppedUP': '✅ Terminado',
  'forcedUP': '⬆️ A partilhar',
  'checkingDL': '🔄 A verificar',
  'checkingUP': '🔄 A verificar',
  'error': '❌ Erro',
  'missingFiles': '❌ Ficheiros em falta',
};

class EcraDownloads extends ConsumerWidget {
  const EcraDownloads({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_qbitProvider);
    // durante a atualização automática mantém os dados anteriores no ecrã
    final dados = v.valueOrNull;
    if (dados == null) {
      return Assincrono(valor: v, repetir: () => ref.invalidate(_qbitProvider), construir: (_) => const SizedBox.shrink());
    }
    final tr = dados.transferencia;
    return Column(children: [
      Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text('⬇️ ${formatarBytes(tr['dl_info_speed'] as num?)}/s   ⬆️ ${formatarBytes(tr['up_info_speed'] as num?)}/s\n'
                  'Sessão: ⬇️ ${formatarBytes(tr['dl_info_data'] as num?)} · ⬆️ ${formatarBytes(tr['up_info_data'] as num?)}'),
            ),
            Column(children: [
              Switch(
                value: dados.limite,
                onChanged: (_) async {
                  await ref.read(servidorProvider)?.qbit.alternarLimite();
                  ref.invalidate(_qbitProvider);
                },
              ),
              const Text('🐢 Limite', style: TextStyle(fontSize: 11)),
            ]),
          ]),
        ),
      ),
      Expanded(
        child: dados.torrents.isEmpty
            ? const Center(child: Text('Sem torrents.'))
            : ListView.builder(
                itemCount: dados.torrents.length,
                itemBuilder: (_, i) => _Torrent(dados.torrents[i]),
              ),
      ),
    ]);
  }
}

class _Torrent extends ConsumerWidget {
  final Json t;
  const _Torrent(this.t);

  bool get _parado => (t['state'] as String).startsWith('paused') || (t['state'] as String).startsWith('stopped');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = (t['progress'] as num?)?.toDouble() ?? 0;
    final eta = (t['eta'] as num?)?.toInt() ?? 0;
    return ListTile(
      onTap: () => _acoes(context, ref),
      title: Text(t['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 4),
        LinearProgressIndicator(value: p),
        const SizedBox(height: 4),
        Text([
          _estados[t['state']] ?? t['state'],
          '${(p * 100).toStringAsFixed(0)}%',
          formatarBytes(t['size'] as num?),
          if ((t['dlspeed'] as num? ?? 0) > 0) '⬇️ ${formatarBytes(t['dlspeed'] as num?)}/s',
          if (p < 1 && eta > 0 && eta < 8640000) 'faltam ${_tempo(eta)}',
        ].join(' · ')),
      ]),
    );
  }

  static String _tempo(int s) => s >= 3600 ? '${s ~/ 3600} h ${(s % 3600) ~/ 60} min' : '${s ~/ 60} min';

  void _acoes(BuildContext context, WidgetRef ref) => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(t['name'] as String, maxLines: 2)),
            ListTile(
              leading: Icon(_parado ? Icons.play_arrow : Icons.pause),
              title: Text(_parado ? 'Retomar' : 'Pausar'),
              onTap: () => _fazer(ctx, ref, (q) => _parado ? q.retomar(t['hash'] as String) : q.pausar(t['hash'] as String)),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remover torrent'),
              subtitle: const Text('Os ficheiros já descarregados ficam'),
              onTap: () => _fazer(ctx, ref, (q) => q.remover(t['hash'] as String)),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Remover torrent e ficheiros'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (d) => AlertDialog(
                    title: const Text('Apagar também os ficheiros?'),
                    content: const Text('Isto apaga o que foi descarregado e não dá para desfazer.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Não')),
                      FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Sim, apagar')),
                    ],
                  ),
                );
                if (ok == true && ctx.mounted) await _fazer(ctx, ref, (q) => q.remover(t['hash'] as String, ficheiros: true));
              },
            ),
          ]),
        ),
      );

  Future<void> _fazer(BuildContext ctx, WidgetRef ref, Future<void> Function(QbitApi q) f) async {
    Navigator.pop(ctx);
    final s = ref.read(servidorProvider);
    if (s == null) return;
    try {
      await f(s.qbit);
    } catch (e) {
      if (ctx.mounted) avisar(ctx, '❌ ${mensagemErro(e)}');
    }
    ref.invalidate(_qbitProvider);
  }
}
