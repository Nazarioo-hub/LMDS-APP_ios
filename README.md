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

## Compilar

Nada é assinado. Há duas formas de compilar, com os mesmos dois builds (IPA iOS sem assinatura e APK Android):

### GitHub Actions

O ficheiro [`.github/workflows/compilar.yml`](.github/workflows/compilar.yml) corre sozinho em cada push para o `master` (e pode ser lançado à mão em **Actions → Compilar → Run workflow**). O IPA e o APK ficam em **Artifacts**, no fundo da página de cada execução.

### Codemagic

A configuração está em [`codemagic.yaml`](codemagic.yaml), com os workflows `ios-sem-assinatura` e `android-apk`. Para os usar: entrar em [codemagic.io](https://codemagic.io) com a conta GitHub, **Add application** → `LMDS-APP_ios` → **codemagic.yaml** → **Start new build**.

### Instalar o IPA sem assinatura

O `.ipa` do workflow `ios-sem-assinatura` fica nos artefactos do build. Instala-se com [Sideloadly](https://sideloadly.io) ou [AltStore](https://altstore.io), que o assinam com o teu Apple ID. Com Apple ID grátis a app expira ao fim de 7 dias e tem de ser reinstalada.

### Notas

- O `NSAllowsArbitraryLoads` está ativo porque a app fala com o servidor por HTTP na rede local.
- O APK Android está assinado com a chave de debug. Serve para instalar à mão, não para a Play Store.
