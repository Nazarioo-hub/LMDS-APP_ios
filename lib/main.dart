import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ecras/catalogo.dart';
import 'ecras/configurar.dart';
import 'ecras/inicio.dart';

void main() => runApp(const ProviderScope(child: AppLmds()));

final _rotas = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, _) => const Portao()),
  GoRoute(path: '/ler-qr', builder: (_, _) => const EcraLerQr()),
  GoRoute(path: '/pesquisa', builder: (_, _) => const EcraPesquisa()),
  GoRoute(
    path: '/detalhe/:tipo/:id',
    builder: (_, s) => EcraDetalhe(tipo: s.pathParameters['tipo']!, id: int.parse(s.pathParameters['id']!)),
  ),
]);

class AppLmds extends StatelessWidget {
  const AppLmds({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'LMDS',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF4F8EF7),
        ),
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF4F8EF7)),
        routerConfig: _rotas,
      );
}
