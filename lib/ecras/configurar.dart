// Primeira utilização: ler o QR privado do servidor e escrever o PIN.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/armazenamento.dart';
import '../core/config.dart';
import '../core/qr.dart';

class EcraBoasVindas extends StatelessWidget {
  const EcraBoasVindas({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.dns_rounded, size: 72),
              const SizedBox(height: 16),
              Text('LMDS', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              const Text(
                'Liga a app ao teu servidor.\n\n'
                '1. No Telegram, escreve /app ao bot do servidor.\n'
                '2. Lê aqui o QR que ele envia.\n'
                '3. Escreve o PIN de 6 dígitos que vem na mensagem seguinte.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.push('/ler-qr'),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Ler QR do servidor'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _colar(context),
                child: const Text('Colar o código do QR à mão'),
              ),
            ]),
          ),
        ),
      );

  Future<void> _colar(BuildContext context) async {
    final c = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código do QR'),
        content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: 'lmds1:…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Continuar')),
        ],
      ),
    );
    if (texto != null && texto.trim().isNotEmpty && context.mounted) {
      await pedirPinEGuardar(context, texto.trim());
    }
  }
}

class EcraLerQr extends StatefulWidget {
  const EcraLerQr({super.key});
  @override
  State<EcraLerQr> createState() => _EcraLerQrState();
}

class _EcraLerQrState extends State<EcraLerQr> {
  final _camara = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _lido = false;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ler QR do servidor')),
        body: MobileScanner(
          controller: _camara,
          onDetect: (captura) async {
            final v = captura.barcodes.firstOrNull?.rawValue;
            if (_lido || v == null || !v.startsWith(prefixoQr)) return;
            _lido = true;
            await _camara.stop();
            if (!context.mounted) return;
            final ok = await pedirPinEGuardar(context, v);
            if (!ok && mounted) {
              _lido = false;
              await _camara.start();
            }
          },
        ),
      );
}

/// Pede o PIN, decifra o QR e guarda a configuração. Devolve true se correu bem.
Future<bool> pedirPinEGuardar(BuildContext context, String texto) async {
  final c = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('PIN do QR'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        obscureText: true,
        decoration: const InputDecoration(hintText: '6 dígitos'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Ligar')),
      ],
    ),
  );
  if (pin == null || !context.mounted) return false;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('A abrir o QR…')])),
  );
  try {
    final json = await decifrarQr(texto, pin.trim());
    final cfg = ServidorCfg.fromJson(json);
    if (!context.mounted) return false;
    await ProviderScope.containerOf(context, listen: false).read(configProvider.notifier).guardar(cfg);
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    context.go('/');
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is QrInvalido ? e.motivo : 'Não consegui ler o QR: $e')));
    return false;
  }
}
