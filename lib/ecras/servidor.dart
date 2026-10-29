// Painel "Servidor": estado dos serviços, Tdarr, legendas e o que aconteceu hoje.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/servidor.dart';
import '../servicos/painel.dart';
import 'comum.dart';

final _painelProvider = Provider.autoDispose((ref) => PainelApi(exigirServidor(ref)));
final _estadosProvider = FutureProvider.autoDispose((ref) => ref.watch(_painelProvider).estados());
final _tdarrProvider = FutureProvider.autoDispose((ref) => ref.watch(_painelProvider).tdarr());
final _legendasProvider = FutureProvider.autoDispose((ref) => ref.watch(_painelProvider).legendasEmFalta());
final _hojeProvider = FutureProvider.autoDispose((ref) => ref.watch(_painelProvider).hoje());

class EcraServidor extends ConsumerWidget {
  const EcraServidor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(servidorProvider) == null) return const MensagemErro('Sem ligação ao servidor.');
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_estadosProvider);
        ref.invalidate(_tdarrProvider);
        ref.invalidate(_legendasProvider);
        ref.invalidate(_hojeProvider);
      },
      child: ListView(padding: const EdgeInsets.all(8), children: [
        _Cartao(
          titulo: '📰 Últimas 24 horas',
          filho: Assincrono(
            valor: ref.watch(_hojeProvider),
            construir: (h) => Text('📺 ${h.episodios} episódio(s) novo(s)\n'
                '🎬 ${h.filmes} filme(s) novo(s)\n'
                '⬇️ ${formatarBytes(h.descarregadoBytes)} descarregados nesta sessão do qBittorrent'),
          ),
        ),
        _Cartao(
          titulo: '🩺 Serviços',
          filho: Assincrono(
            valor: ref.watch(_estadosProvider),
            construir: (m) {
              final mal = m.entries.where((e) => !e.value).map((e) => nomesServicos[e.key] ?? e.key).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mal.isEmpty ? '✅ Está tudo a funcionar (${m.length} serviços).' : '⚠️ Sem resposta: ${mal.join(', ')}'),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in m.entries)
                    Chip(
                      avatar: Icon(e.value ? Icons.check_circle : Icons.error, color: e.value ? Colors.green : Colors.red, size: 18),
                      label: Text(nomesServicos[e.key] ?? e.key, style: const TextStyle(fontSize: 12)),
                    ),
                ]),
              ]);
            },
          ),
        ),
        _Cartao(
          titulo: '🎞️ Conversão (Tdarr)',
          filho: Assincrono(
            valor: ref.watch(_tdarrProvider),
            construir: (t) => Text(t == null
                ? 'Tdarr não configurado.'
                : t.aDormir
                    ? '😴 A dormir. Converte só das 01h às 07h para não aquecer o servidor.'
                    : '✅ ${t.convertidos} convertido(s) · ❌ ${t.erros} com erro\n'
                        '⏳ ${t.fila} na fila\n'
                        '💾 Espaço poupado: ≈ ${t.poupadoGb.toStringAsFixed(1).replaceAll('.', ',')} GB'),
          ),
        ),
        _Cartao(
          titulo: '💬 Legendas (Bazarr)',
          filho: Assincrono(
            valor: ref.watch(_legendasProvider),
            construir: (l) => Text(l == null
                ? 'Bazarr não configurado.'
                : 'Em falta: ${l.episodios} episódio(s) e ${l.filmes} filme(s).\nO Bazarr vai buscando sozinho, aos poucos.'),
          ),
        ),
      ]),
    );
  }
}

class _Cartao extends StatelessWidget {
  final String titulo;
  final Widget filho;
  const _Cartao({required this.titulo, required this.filho});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            filho,
          ]),
        ),
      );
}
