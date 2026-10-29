// Estrutura principal: barra de topo com o indicador de ligação e navegação em baixo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/armazenamento.dart';
import '../core/ligacao.dart';
import 'biblioteca.dart';
import 'catalogo.dart';
import 'comum.dart';
import 'configurar.dart';
import 'downloads.dart';
import 'pedidos.dart';
import 'servidor.dart';

/// Decide o primeiro ecrã: configurar (sem QR lido) ou a app.
class Portao extends ConsumerWidget {
  const Portao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(configProvider).when(
        data: (cfg) => cfg == null ? const EcraBoasVindas() : const EcraInicio(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => const EcraBoasVindas(),
      );
}

class EcraInicio extends ConsumerStatefulWidget {
  const EcraInicio({super.key});
  @override
  ConsumerState<EcraInicio> createState() => _EcraInicioState();
}

class _EcraInicioState extends ConsumerState<EcraInicio> {
  int _i = 0;

  static const _ecras = <Widget>[EcraCatalogo(), EcraPedidos(), EcraBiblioteca(), EcraDownloads(), EcraServidor()];

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(configProvider).valueOrNull;
    final l = ref.watch(ligacaoProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(cfg?.nome ?? 'LMDS'),
        actions: [
          const IndicadorLigacao(),
          PopupMenuButton<String>(
            onSelected: (o) => o == 'esquecer' ? _esquecer() : ref.read(ligacaoProvider.notifier).verificar(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'verificar', child: Text('Verificar ligação')),
              PopupMenuItem(value: 'esquecer', child: Text('Esquecer servidor')),
            ],
          ),
        ],
      ),
      body: l.modo == ModoLigacao.semLigacao
          ? MensagemErro(
              'Não encontro o servidor em casa nem pelo Tailscale.\nConfirma que o Tailscale está ligado neste telemóvel.',
              repetir: () => ref.read(ligacaoProvider.notifier).verificar(),
            )
          : l.host == null
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _i, children: _ecras),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Biblioteca'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: 'Downloads'),
          NavigationDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: 'Servidor'),
        ],
      ),
    );
  }

  Future<void> _esquecer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Esquecer este servidor?'),
        content: const Text('A app apaga as chaves guardadas. Para voltar a ligar, lê outra vez o QR (/app no Telegram).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Esquecer')),
        ],
      ),
    );
    if (ok == true) await ref.read(configProvider.notifier).esquecer();
  }
}
