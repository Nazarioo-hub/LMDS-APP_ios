// Catálogo (via Seerr): a estrear, estreados, populares, tendência; filtros por streaming e género.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/servidor.dart';
import '../servicos/seerr.dart';
import 'comum.dart';

typedef ArgsSeccao = ({String tipo, Seccao seccao, int? fornecedor, int? genero});

final _seccaoProvider = FutureProvider.autoDispose.family<List<ItemCatalogo>, ArgsSeccao>((ref, a) =>
    exigirServidor(ref).seerr.descobrir(a.tipo, a.seccao, fornecedor: a.fornecedor, genero: a.genero));

/// Os serviços de streaming que interessam, pela ordem dos chips.
const _streaming = <(String, bool Function(String))>[
  ('Netflix', _eNetflix),
  ('Disney+', _eDisney),
  ('HBO Max', _eHbo),
  ('Prime Video', _ePrime),
  ('Apple TV+', _eApple),
  ('SkyShowtime', _eSky),
];
bool _eNetflix(String n) => n == 'netflix';
bool _eDisney(String n) => n.contains('disney');
bool _eHbo(String n) => n == 'hbo max' || n == 'max';
bool _ePrime(String n) => n == 'amazon prime video';
bool _eApple(String n) => n == 'apple tv' || n == 'apple tv+' || n == 'apple tv plus';
bool _eSky(String n) => n.contains('skyshowtime');

final _fornecedoresProvider = FutureProvider.autoDispose.family<List<(String, int)>, String>((ref, tipo) async {
  final todos = await exigirServidor(ref).seerr.fornecedores(tipo);
  final res = <(String, int)>[];
  for (final (nome, e) in _streaming) {
    final f = todos.where((p) => e((p['name'] as String).toLowerCase())).toList()
      ..sort((a, b) => ((a['displayPriority'] as num?) ?? 99).compareTo((b['displayPriority'] as num?) ?? 99));
    if (f.isNotEmpty) res.add((nome, (f.first['id'] as num).toInt()));
  }
  return res;
});

final _generosProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
    (ref, tipo) => exigirServidor(ref).seerr.generos(tipo));

class EcraCatalogo extends StatelessWidget {
  const EcraCatalogo({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          Row(children: [
            const Expanded(child: TabBar(tabs: [Tab(text: 'Filmes'), Tab(text: 'Séries')])),
            IconButton(icon: const Icon(Icons.search), tooltip: 'Pesquisar', onPressed: () => context.push('/pesquisa')),
          ]),
          const Expanded(child: TabBarView(children: [_Lista(tipo: 'movie'), _Lista(tipo: 'tv')])),
        ]),
      );
}

class _Lista extends ConsumerStatefulWidget {
  final String tipo;
  const _Lista({required this.tipo});
  @override
  ConsumerState<_Lista> createState() => _ListaState();
}

class _ListaState extends ConsumerState<_Lista> with AutomaticKeepAliveClientMixin {
  int? _fornecedor;
  Map<String, dynamic>? _genero;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final forn = ref.watch(_fornecedoresProvider(widget.tipo));
    final gen = ref.watch(_generosProvider(widget.tipo));
    final seccoes = <(String, Seccao)>[
      ('A estrear', Seccao.aEstrear),
      ('Estreados recentemente', Seccao.recentes),
      ('Populares', Seccao.populares),
      if (_fornecedor == null && _genero == null) ('Em tendência', Seccao.tendencia),
    ];
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_seccaoProvider),
      child: ListView(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(label: const Text('Todos'), selected: _fornecedor == null, onSelected: (_) => setState(() => _fornecedor = null)),
            ),
            ...(forn.valueOrNull ?? const []).map((f) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ChoiceChip(
                    label: Text(f.$1),
                    selected: _fornecedor == f.$2,
                    onSelected: (s) => setState(() => _fornecedor = s ? f.$2 : null),
                  ),
                )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(Icons.category_outlined, size: 18),
            const SizedBox(width: 6),
            DropdownButton<int?>(
              value: (_genero?['id'] as num?)?.toInt(),
              hint: const Text('Todos os géneros'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos os géneros')),
                ...(gen.valueOrNull ?? const []).map((g) => DropdownMenuItem<int?>(value: (g['id'] as num).toInt(), child: Text(g['name'] as String))),
              ],
              onChanged: (id) => setState(() => _genero = id == null ? null : gen.valueOrNull!.firstWhere((g) => g['id'] == id)),
            ),
          ]),
        ),
        for (final (titulo, s) in seccoes)
          _Seccao(titulo: titulo, args: (tipo: widget.tipo, seccao: s, fornecedor: _fornecedor, genero: (_genero?['id'] as num?)?.toInt())),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Seccao extends ConsumerWidget {
  final String titulo;
  final ArgsSeccao args;
  const _Seccao({required this.titulo, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_seccaoProvider(args));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
      ),
      SizedBox(
        height: 228,
        child: Assincrono(
          valor: v,
          repetir: () => ref.invalidate(_seccaoProvider(args)),
          construir: (itens) => itens.isEmpty
              ? const Center(child: Text('Nada por aqui.'))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: itens.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => CartaoCatalogo(itens[i]),
                ),
        ),
      ),
    ]);
  }
}

class CartaoCatalogo extends StatelessWidget {
  final ItemCatalogo item;
  final double largura;
  const CartaoCatalogo(this.item, {super.key, this.largura = 120});

  @override
  Widget build(BuildContext context) {
    final selo = seloEstado(item.estado);
    return InkWell(
      onTap: () => context.push('/detalhe/${item.tipo}/${item.id}'),
      child: SizedBox(
        width: largura,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Poster(posterUrl(item.poster), largura: largura),
            if (selo != null) Positioned(left: 4, top: 4, child: selo),
          ]),
          const SizedBox(height: 4),
          Text(item.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          if (item.ano != null) Text(item.ano!, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      ),
    );
  }
}

// ---------- Pesquisa ----------

class EcraPesquisa extends ConsumerStatefulWidget {
  const EcraPesquisa({super.key});
  @override
  ConsumerState<EcraPesquisa> createState() => _EcraPesquisaState();
}

class _EcraPesquisaState extends ConsumerState<EcraPesquisa> {
  Future<List<ItemCatalogo>>? _res;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Filme ou série…', border: InputBorder.none),
            onSubmitted: (t) {
              final s = ref.read(servidorProvider);
              if (s != null && t.trim().isNotEmpty) setState(() => _res = s.seerr.pesquisar(t.trim()));
            },
          ),
        ),
        body: _res == null
            ? const Center(child: Text('Escreve o nome e carrega em pesquisar.'))
            : FutureBuilder<List<ItemCatalogo>>(
                future: _res,
                builder: (_, snap) {
                  if (snap.hasError) return MensagemErro(mensagemErro(snap.error!));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final l = snap.data!;
                  if (l.isEmpty) return const Center(child: Text('Sem resultados.'));
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisExtent: 230, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: l.length,
                    itemBuilder: (_, i) => CartaoCatalogo(l[i], largura: 120),
                  );
                },
              ),
      );
}

// ---------- Detalhe ----------

final _detalheProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, (String, int)>(
    (ref, a) => exigirServidor(ref).seerr.detalhe(a.$1, a.$2));

class EcraDetalhe extends ConsumerWidget {
  final String tipo;
  final int id;
  const EcraDetalhe({super.key, required this.tipo, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_detalheProvider((tipo, id)));
    return Scaffold(
      appBar: AppBar(),
      body: Assincrono(
        valor: v,
        repetir: () => ref.invalidate(_detalheProvider((tipo, id))),
        construir: (d) => _corpo(context, ref, d),
      ),
    );
  }

  Widget _corpo(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
    final titulo = (d['title'] ?? d['name'] ?? '?') as String;
    final data = (d['releaseDate'] ?? d['firstAirDate']) as String?;
    final estado = estadoDe((d['mediaInfo'] as Map?)?.cast<String, dynamic>());
    final generos = ((d['genres'] as List?) ?? []).map((g) => (g as Map)['name']).join(' · ');
    final elenco = (((d['credits'] as Map?)?['cast'] as List?) ?? []).take(12).map((c) => (c as Map)['name'] as String).toList();
    final ondeVer = (((d['watchProviders'] as List?) ?? []).cast<Map>().where((w) => w['iso_3166_1'] == regiao).firstOrNull?['flatrate'] as List?)
            ?.map((f) => (f as Map)['name'] as String)
            .toList() ??
        const <String>[];
    final duracao = d['runtime'] as num?;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Poster(posterUrl(d['posterPath'] as String?), largura: 130),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text([
              if (data != null && data.length >= 4) data.substring(0, 4),
              if (duracao != null && duracao > 0) '${duracao.toInt()} min',
              if (tipo == 'tv' && d['numberOfSeasons'] != null) '${d['numberOfSeasons']} temporada(s)',
            ].join(' · ')),
            const SizedBox(height: 4),
            Text(generos, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            if (seloEstado(estado) != null) seloEstado(estado)!,
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      if (estado == EstadoMedia.disponivel)
        const ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Já está na tua biblioteca.'))
      else
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _pedir(context, ref, d, false),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar (1080p)'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => _pedir(context, ref, d, true), child: const Text('4K')),
        ]),
      const SizedBox(height: 16),
      if ((d['overview'] as String?)?.isNotEmpty ?? false) Text(d['overview'] as String),
      const SizedBox(height: 16),
      if (ondeVer.isNotEmpty) ...[
        Text('Onde ver em Portugal', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: ondeVer.map((n) => Chip(label: Text(n))).toList()),
        const SizedBox(height: 16),
      ],
      if (elenco.isNotEmpty) ...[
        Text('Elenco', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(elenco.join(', ')),
      ],
    ]);
  }

  Future<void> _pedir(BuildContext context, WidgetRef ref, Map<String, dynamic> d, bool quatroK) async {
    final s = ref.read(servidorProvider);
    if (s == null) return;
    List<int>? temporadas;
    if (tipo == 'tv') {
      final todas = ((d['seasons'] as List?) ?? [])
          .cast<Map>()
          .map((x) => (x['seasonNumber'] as num).toInt())
          .where((n) => n > 0)
          .toList();
      final escolha = await showDialog<List<int>?>(context: context, builder: (_) => _EscolherTemporadas(todas));
      if (escolha == null) return; // cancelou
      temporadas = escolha.length == todas.length ? null : escolha;
    }
    try {
      await s.seerr.pedir(tipo, id, quatroK: quatroK, temporadas: temporadas);
      if (context.mounted) avisar(context, quatroK ? '✅ Pedido em 4K enviado.' : '✅ Adicionado. Vai começar a descarregar.');
      ref.invalidate(_detalheProvider((tipo, id)));
    } catch (e) {
      if (context.mounted) avisar(context, '❌ ${mensagemErro(e)}');
    }
  }
}

class _EscolherTemporadas extends StatefulWidget {
  final List<int> todas;
  const _EscolherTemporadas(this.todas);
  @override
  State<_EscolherTemporadas> createState() => _EscolherTemporadasState();
}

class _EscolherTemporadasState extends State<_EscolherTemporadas> {
  late final Set<int> _sel = widget.todas.toSet();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Que temporadas?'),
        content: SizedBox(
          width: 300,
          child: ListView(shrinkWrap: true, children: [
            CheckboxListTile(
              title: const Text('Todas'),
              value: _sel.length == widget.todas.length,
              onChanged: (v) => setState(() => v == true ? _sel.addAll(widget.todas) : _sel.clear()),
            ),
            for (final n in widget.todas)
              CheckboxListTile(
                title: Text('Temporada $n'),
                value: _sel.contains(n),
                onChanged: (v) => setState(() => v == true ? _sel.add(n) : _sel.remove(n)),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: _sel.isEmpty ? null : () => Navigator.pop(context, (_sel.toList()..sort())),
            child: const Text('Adicionar'),
          ),
        ],
      );
}
