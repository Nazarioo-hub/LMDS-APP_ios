# LMDS App

App Flutter (iOS e Android) para gerir o servidor LMDS.

- Bundle ID iOS: `pt.lmds.lmdsApp.antoniopedro`
- Application ID Android: `pt.lmds.lmds_app`
- Flutter 3.41.7 (Dart 3.11.5), iOS mínimo 13.0

## Desenvolvimento

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Codemagic

A configuração está em [`codemagic.yaml`](codemagic.yaml) e tem três workflows:

| Workflow | O que faz | Precisa de |
|---|---|---|
| `ios-testflight` | IPA assinado, enviado para o TestFlight | Conta Apple Developer paga |
| `ios-sem-assinatura` | IPA sem assinatura, para instalar com Sideloadly/AltStore | Nada |
| `android-apk` | APK de release para instalar à mão | Nada |

Os três começam à mão (botão **Start new build** no Codemagic). O número de build é o `$BUILD_NUMBER` do Codemagic, que sobe sozinho em cada build.

### 1. Ligar o repositório

1. Entrar em [codemagic.io](https://codemagic.io) com a conta GitHub `Nazarioo-hub`.
2. **Add application** → GitHub → `LMDS-APP_ios` → tipo **Flutter App** → escolher **codemagic.yaml**.

A partir daqui `ios-sem-assinatura` e `android-apk` já funcionam.

### 2. Só para o TestFlight

**No Apple Developer / App Store Connect**

1. Em [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list), registar o App ID `pt.lmds.lmdsApp.antoniopedro` (se ainda não existir). As capacidades por omissão chegam.
2. Em [App Store Connect → Apps](https://appstoreconnect.apple.com/apps), **+ → New App**, iOS, com esse Bundle ID.
3. Em **Users and Access → Integrations → App Store Connect API**, gerar uma chave com acesso **App Manager**. Guardar o **Issuer ID**, o **Key ID** e o ficheiro `.p8` (só se pode descarregar uma vez).

**No Codemagic**

1. **Team settings → Team integrations → Developer Portal → Connect**. Nome da chave: `LMDS ASC` (tem de ser exatamente este, é o que o `codemagic.yaml` usa). Colar o Issuer ID e o Key ID e carregar o `.p8`.
2. **Team settings → codemagic.yaml settings → Code signing identities**:
   - **iOS certificates** → **Generate certificate** → tipo **Apple Distribution**, usando a chave `LMDS ASC`. Guardar a password que o Codemagic mostrar.
   - **iOS provisioning profiles** → **Fetch profiles** (ou criar um perfil *App Store* para `pt.lmds.lmdsApp.antoniopedro` no portal da Apple e depois fazer fetch).
3. Correr o workflow **iOS → TestFlight**. Quando a Apple acabar de processar o build (uns 10–30 min), aparece no TestFlight.

### Instalar o IPA sem assinatura

O `.ipa` do workflow `ios-sem-assinatura` fica nos artefactos do build. Instala-se com [Sideloadly](https://sideloadly.io) ou [AltStore](https://altstore.io), que o assinam com o teu Apple ID. Com Apple ID grátis a app expira ao fim de 7 dias e tem de ser reinstalada.

### Notas

- O `Info.plist` declara `ITSAppUsesNonExemptEncryption = false` para o TestFlight não pedir a declaração de exportação em cada build. A app só usa algoritmos padrão (via `cryptography` e HTTPS); se isso mudar, rever esta chave.
- O `NSAllowsArbitraryLoads` está ativo porque a app fala com o servidor por HTTP na rede local. Para o TestFlight não há problema; para a App Store pública a Apple pode pedir justificação.
- O APK Android está assinado com a chave de debug. Serve para instalar à mão, não para a Play Store.
