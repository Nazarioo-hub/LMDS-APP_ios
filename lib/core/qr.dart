// QR privado do LMDS: `lmds1:<base64url(salt16 | nonce12 | cifrado+tag16)>`
// AES-256-GCM com chave PBKDF2-HMAC-SHA256(PIN, salt, 200000 iterações, 32 bytes).
// Especificação completa em app/QR-FORMATO.md.
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const prefixoQr = 'lmds1:';
const _iteracoes = 200000;

class QrInvalido implements Exception {
  final String motivo;
  QrInvalido(this.motivo);
  @override
  String toString() => motivo;
}

Future<SecretKey> _chave(String pin, List<int> salt) => Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iteracoes,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);

/// Decifra o texto lido do QR com o PIN e devolve o JSON da configuração.
Future<Map<String, dynamic>> decifrarQr(String texto, String pin) async {
  texto = texto.trim();
  if (!texto.startsWith(prefixoQr)) {
    throw QrInvalido('Este QR não é de um servidor LMDS.');
  }
  final List<int> bytes;
  try {
    bytes = base64Url.decode(base64Url.normalize(texto.substring(prefixoQr.length)));
  } on FormatException {
    throw QrInvalido('QR danificado.');
  }
  if (bytes.length < 16 + 12 + 16 + 1) throw QrInvalido('QR incompleto.');
  final salt = bytes.sublist(0, 16);
  final nonce = bytes.sublist(16, 28);
  final cifrado = bytes.sublist(28, bytes.length - 16);
  final tag = bytes.sublist(bytes.length - 16);
  try {
    final claro = await AesGcm.with256bits().decrypt(
      SecretBox(cifrado, nonce: nonce, mac: Mac(tag)),
      secretKey: await _chave(pin, salt),
    );
    return (jsonDecode(utf8.decode(claro)) as Map).cast<String, dynamic>();
  } on SecretBoxAuthenticationError {
    throw QrInvalido('PIN errado.');
  }
}

/// Cifra uma configuração no formato do QR (usado nos testes e em ferramentas).
Future<String> cifrarQr(Map<String, dynamic> json, String pin, {List<int>? salt, List<int>? nonce}) async {
  final r = Random.secure();
  salt ??= List.generate(16, (_) => r.nextInt(256));
  nonce ??= List.generate(12, (_) => r.nextInt(256));
  final caixa = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(json)),
    secretKey: await _chave(pin, salt),
    nonce: nonce,
  );
  final tudo = [...salt, ...nonce, ...caixa.cipherText, ...caixa.mac.bytes];
  return prefixoQr + base64Url.encode(tudo).replaceAll('=', '');
}
