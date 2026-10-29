// Sonarr/Radarr: biblioteca, calendário, fila e histórico.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/servidor.dart';
import '../servicos/arr.dart';
import 'comum.dart';

final _bibProvider = FutureProvider.autoDispose.family((ref, ArrTipo t) => exigirServidor(ref).arr(t).biblioteca());
final _calProvider = FutureProvider.autoDispose.family((ref, ArrTipo t) => exigirServidor(ref).arr(t).calendario());
final _filaProvider = FutureProvider.autoDispose.family((ref, ArrTipo t) => exigirServidor(ref).arr(t).fila());
final _histProvider = FutureProvider.autoDispose.family((ref, ArrTipo t) => exigirServidor(ref).arr(t).historico());

class EcraBiblioteca extends StatefulWidget {
  const EcraBiblioteca({super.key});
  @override
  State<EcraBiblioteca> createState() => _EcraBibliotecaState();
}

class _EcraBibliotecaState extends State<EcraBiblioteca> {
  ArrTipo _tipo = ArrTipo.sonarr;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<ArrTipo>(
              segments: const [
                ButtonSegment(value: ArrTipo.sonarr, label: Text('Séries'), icon: Icon(Icons.tv)),
                ButtonSegment(value: ArrTipo.radarr, label: Text('Filmes'), icon: Icon(Icons.movie)),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
          ),
          const TabBar(isScrollable: true, tabs: [Tab(text: 'Biblioteca'), Tab(text: 'Calendário'), Tab(text: 'Fila'), Tab(text: 'Histórico')]),
          Expanded(
            child: TabBarView(children: [
              _Biblioteca(_tipo),
              _Calendario(_tipo),
              _Fila(_tipo),
              _Historico(_tipo),
            ]),
          ),
        ]),
      );
}

class _Biblioteca extends ConsumerStatefulWidget {
  final ArrTipo tipo;
  const _Biblioteca(this.tipo);
  @override
  ConsumerState<_Biblioteca> createState() => _BibliotecaState();
}

class _BibliotecaState extends ConsumerState<_Biblioteca> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(_bibProvider(widget.tipo));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Procurar na biblioteca', isDense: true, border: OutlineInputBorder()),
          onChanged: (t) => setState(() => _filtro = t.toLowerCase()),
        ),
      ),
      Expanded(
        child: Assincrono(
          valor: v,
          repetir: () => ref.invalidate(_bibProvider(widget.tipo)),
          construir: (todos) {
            final l = _filtro.isEmpty ? todos : todos.where((i) => (i['title'] as String).toLowerCase().contains(_filtro)).toList();
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, mainAxisExtent: 210, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: l.length,
              itemBuilder: (_, i) => InkWell(
                onTap: () => _opcoes(context, l[i]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Poster(posterArr(l[i]), largura: 110),
                  Text(l[i]['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  Text(_resumo(l[i]), style: const TextStyle(fontSize: 10, color: Colors.white60)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  String _resumo(Json i) {
    if (widget.tipo == ArrTipo.sonarr) {
      final st = (i['statistics'] as Map?) ?? const {};
      return '${st['episodeFileCount'] ?? 0}/${st['episodeCount'] ?? 0} episódios';
    }
    return i['hasFile'] == true ? '✅ No disco' : '⏳ Em falta';
  }

  void _opcoes(BuildContext context, Json item) => showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(item['title'] as String), subtitle: Text('${item['year'] ?? ''} · ${_resumo(item)}')),
            ListTile(
              leading: const Icon(Icons.manage_search),
              title: const Text('Procurar agora'),
              subtitle: const Text('Procura nos indexers o que estiver em falta'),
              onTap: () async {
                Navigator.pop(ctx);
                final s = ref.read(servidorProvider);
                if (s == null) return;
                try {
                  await s.arr(widget.tipo).procurar((item['id'] as num).toInt());
                  if (context.mounted) avisar(context, '🔎 Procura lançada.');
                } catch (e) {
                  if (context.mounted) avisar(context, '❌ ${mensagemErro(e)}');
                }
              },
            ),
          ]),
        ),
      );
}

class _Calendario extends ConsumerWidget {
  final ArrTipo tipo;
  const _Calendario(this.tipo);

  @override
  Widget build(BuildContext context, WidgetRef ref) => Assincrono(
        valor: ref.watch(_calProvider(tipo)),
        repetir: () => ref.invalidate(_calProvider(tipo)),
        construir: (l) => l.isEmpty
            ? const Center(child: Text('Nada nos próximos 14 dias.'))
            : ListView(children: [
                for (final i in l)
                  if (tipo == ArrTipo.sonarr)
                    ListTile(
                      leading: const Icon(Icons.tv),
                      title: Text(((i['series'] as Map?)?['title'] ?? '') as String),
                      subtitle: Text('T${i['seasonNumber']}E${i['episodeNumber']} · ${i['title'] ?? ''}\n${formatarData(i['airDateUtc'] as String?)}'),
                      trailing: i['hasFile'] == true ? const Icon(Icons.check, color: Colors.green) : null,
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.movie),
                      title: Text(i['title'] as String),
                      subtitle: Text(_estreiaFilme(i)),
                      trailing: i['hasFile'] == true ? const Icon(Icons.check, color: Colors.green) : null,
                    ),
              ]),
      );

  String _estreiaFilme(Json i) {
    if (i['digitalRelease'] != null) return 'Digital: ${formatarData(i['digitalRelease'] as String)}';
    if (i['physicalRelease'] != null) return 'Físico: ${formatarData(i['physicalRelease'] as String)}';
    return 'Cinema: ${formatarData(i['inCinemas'] as String?)}';
  }
}

class _Fila extends ConsumerWidget {
  final ArrTipo tipo;
  const _Fila(this.tipo);

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_filaProvider(tipo)),
        child: Assincrono(
          valor: ref.watch(_filaProvider(tipo)),
          repetir: () => ref.invalidate(_filaProvider(tipo)),
          construir: (l) => l.isEmpty
              ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Nada a descarregar.'))])
              : ListView(children: [
                  for (final r in l)
                    ListTile(
                      title: Text((r['title'] ?? '') as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 4),
                        LinearProgressIndicator(value: _progresso(r)),
                        const SizedBox(height: 4),
                        Text('${r['status'] ?? ''} · ${r['timeleft'] ?? '—'} · ${formatarBytes(r['size'] as num?)}'),
                      ]),
                    ),
                ]),
        ),
      );

  double _progresso(Json r) {
    final t = (r['size'] as num?)?.toDouble() ?? 0, f = (r['sizeleft'] as num?)?.toDouble() ?? 0;
    return t <= 0 ? 0 : (1 - f / t).clamp(0, 1);
  }
}

class _Historico extends ConsumerWidget {
  final ArrTipo tipo;
  const _Historico(this.tipo);

  static const _eventos = {
    'grabbed': '⬇️ Encontrado',
    'downloadFolderImported': '✅ Importado',
    'downloadFailed': '❌ Falhou',
    'episodeFileDeleted': '🗑️ Apagado',
    'movieFileDeleted': '🗑️ Apagado',
    'episodeFileRenamed': '✏️ Renomeado',
    'movieFileRenamed': '✏️ Renomeado',
    'downloadIgnored': '🙈 Ignorado',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => Assincrono(
        valor: ref.watch(_histProvider(tipo)),
        repetir: () => ref.invalidate(_histProvider(tipo)),
        construir: (l) => ListView(children: [
          for (final h in l)
            ListTile(
              dense: true,
              title: Text((h['sourceTitle'] ?? '') as String, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${_eventos[h['eventType']] ?? h['eventType']} · ${formatarData(h['date'] as String?)}'),
            ),
        ]),
      );
}
