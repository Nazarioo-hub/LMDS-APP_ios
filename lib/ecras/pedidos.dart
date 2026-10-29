// Pedidos do Seerr, com aprovar/recusar os pendentes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/servidor.dart';
import '../servicos/seerr.dart';
import 'comum.dart';

final _pedidosProvider = FutureProvider.autoDispose((ref) => exigirServidor(ref).seerr.pedidos());

// título e poster de cada pedido (o Seerr só devolve o id do TMDB)
final _infoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, (String, int)>(
    (ref, a) => exigirServidor(ref).seerr.detalhe(a.$1, a.$2));

const _estadoPedido = {1: '⏳ À espera de aprovação', 2: '✅ Aprovado', 3: '🚫 Recusado', 4: '❌ Falhou', 5: '✅ Concluído'};

class EcraPedidos extends ConsumerWidget {
  const EcraPedidos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_pedidosProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_pedidosProvider),
      child: Assincrono(
        valor: v,
        repetir: () => ref.invalidate(_pedidosProvider),
        construir: (l) => l.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Ainda não há pedidos.'))])
            : ListView.separated(
                itemCount: l.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _Pedido(l[i]),
              ),
      ),
    );
  }
}

class _Pedido extends ConsumerWidget {
  final Map<String, dynamic> p;
  const _Pedido(this.p);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = (p['media'] as Map).cast<String, dynamic>();
    final tipo = (media['mediaType'] ?? p['type']) as String;
    final tmdb = (media['tmdbId'] as num).toInt();
    final info = ref.watch(_infoProvider((tipo, tmdb))).valueOrNull;
    final estado = (p['status'] as num).toInt();
    final disponivel = estadoDe(media) == EstadoMedia.disponivel;
    final quem = ((p['requestedBy'] as Map?)?['displayName'] ?? '') as String;
    return ListTile(
      onTap: () => context.push('/detalhe/$tipo/$tmdb'),
      leading: Poster(posterUrl(info?['posterPath'] as String?, largura: 154), largura: 44),
      title: Text((info?['title'] ?? info?['name'] ?? '…') as String),
      subtitle: Text([
        disponivel ? '📺 Disponível' : (_estadoPedido[estado] ?? '?'),
        if (p['is4k'] == true) '4K',
        if (quem.isNotEmpty) quem,
        formatarData(p['createdAt'] as String?),
      ].join(' · ')),
      trailing: estado == 1
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check, color: Colors.green), tooltip: 'Aprovar', onPressed: () => _agir(context, ref, true)),
              IconButton(icon: const Icon(Icons.close, color: Colors.red), tooltip: 'Recusar', onPressed: () => _agir(context, ref, false)),
            ])
          : null,
    );
  }

  Future<void> _agir(BuildContext context, WidgetRef ref, bool aprovar) async {
    final s = ref.read(servidorProvider);
    if (s == null) return;
    final id = (p['id'] as num).toInt();
    try {
      aprovar ? await s.seerr.aprovar(id) : await s.seerr.recusar(id);
      if (context.mounted) avisar(context, aprovar ? '✅ Aprovado.' : '🚫 Recusado.');
      ref.invalidate(_pedidosProvider);
    } catch (e) {
      if (context.mounted) avisar(context, '❌ ${mensagemErro(e)}');
    }
  }
}
