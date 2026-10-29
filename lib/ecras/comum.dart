// Componentes partilhados pelos ecrãs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ligacao.dart';
import '../core/servidor.dart';
import '../servicos/seerr.dart';

class IndicadorLigacao extends ConsumerWidget {
  const IndicadorLigacao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(ligacaoProvider);
    final (texto, cor) = switch (l.modo) {
      ModoLigacao.casa => ('🏠 Em casa', Colors.green),
      ModoLigacao.tailscale => ('🌐 Tailscale', Colors.blue),
      ModoLigacao.aVerificar => ('⏳ A ligar…', Colors.grey),
      ModoLigacao.semLigacao => ('❌ Sem ligação', Colors.red),
    };
    return ActionChip(
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      side: BorderSide(color: cor),
      onPressed: () => ref.read(ligacaoProvider.notifier).verificar(),
      tooltip: 'Verificar a ligação outra vez',
    );
  }
}

/// Mostra um AsyncValue: carregar → dados → erro simples com "Tentar outra vez".
class Assincrono<T> extends StatelessWidget {
  final AsyncValue<T> valor;
  final Widget Function(T dados) construir;
  final VoidCallback? repetir;
  const Assincrono({super.key, required this.valor, required this.construir, this.repetir});

  @override
  Widget build(BuildContext context) => valor.when(
        data: construir,
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (e, _) => MensagemErro(mensagemErro(e), repetir: repetir),
      );
}

class MensagemErro extends StatelessWidget {
  final String texto;
  final VoidCallback? repetir;
  const MensagemErro(this.texto, {super.key, this.repetir});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 40),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center),
            if (repetir != null) TextButton(onPressed: repetir, child: const Text('Tentar outra vez')),
          ]),
        ),
      );
}

class Poster extends StatelessWidget {
  final String? url;
  final double largura;
  const Poster(this.url, {super.key, this.largura = 120});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: largura,
          height: largura * 1.5,
          child: url == null
              ? Container(color: Colors.white10, child: const Icon(Icons.movie, size: 36))
              : Image.network(url!, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: Colors.white10, child: const Icon(Icons.broken_image))),
        ),
      );
}

/// Selo "✅ Já tens" / "⏳ Pedido" / "◐ Parcial".
Widget? seloEstado(EstadoMedia e) {
  final (t, c) = switch (e) {
    EstadoMedia.disponivel => ('✅ Já tens', Colors.green),
    EstadoMedia.parcial => ('◐ Parcial', Colors.orange),
    EstadoMedia.pedido => ('⏳ Pedido', Colors.blue),
    EstadoMedia.nenhum => ('', Colors.transparent),
  };
  if (t.isEmpty) return null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
  );
}

String formatarBytes(num? b) {
  if (b == null) return '—';
  const u = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i < 2 ? 0 : 1).replaceAll('.', ',')} ${u[i]}';
}

String formatarData(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  final hh = d.hour.toString().padLeft(2, '0'), mm = d.minute.toString().padLeft(2, '0');
  return '${dias[d.weekday - 1]} ${d.day}/${d.month} $hh:$mm';
}

void avisar(BuildContext context, String texto) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
