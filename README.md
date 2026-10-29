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

A configuração está em [`codemagic.yaml`](codemagic.yaml), com os workflows `ios-sidestore` e `android-apk`. Para os usar: entrar em [codemagic.io](https://codemagic.io) com a conta GitHub, **Add application** → `LMDS-APP_ios` → **codemagic.yaml** → **Start new build**.

### Instalar com o SideStore

O `.ipa` do workflow `ios-sidestore` fica nos artefactos do build do Codemagic. Passa-o para o iPhone (Ficheiros/AirDrop) e abre-o no SideStore → **My Apps → +**. O SideStore assina-o com o teu Apple ID; com Apple ID grátis a app tem de ser renovada no SideStore a cada 7 dias e só podes ter 3 apps ativas.

### Notas

- O `NSAllowsArbitraryLoads` está ativo porque a app fala com o servidor por HTTP na rede local.
- O APK Android está assinado com a chave de debug. Serve para instalar à mão, não para a Play Store.
