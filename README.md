# Controle RC Shell

Site em Flutter Web para controlar os carrinhos de controle remoto Bluetooth da
promoção da Shell (coleção Shell Motorsport / Racing Legends) direto do
navegador, via **Web Bluetooth**.

## Requisitos

- **Google Chrome** ou **Microsoft Edge** (Android, Windows, macOS, Linux/ChromeOS).
  Safari/iPhone **não** suportam Web Bluetooth.
- O site precisa ser servido por **HTTPS** (ou `localhost`).
- Feche o app oficial da Shell no celular antes: o carrinho só aceita uma conexão.

## Rodando

```bash
flutter pub get
flutter run -d chrome
```

Build para publicar (ex.: GitHub Pages, Firebase Hosting, Netlify):

```bash
flutter build web --release --no-web-resources-cdn
```

O resultado fica em `build/web/`.

## Como usar

1. Ligue o carrinho.
2. Clique em **Conectar** e escolha o dispositivo (normalmente `SL-...`).
3. Segure as setas para andar/virar. **Turbo** funciona enquanto pressionado; **Farol** liga/desliga.
4. No computador: `W A S D` ou setas, `Shift` = turbo, `L` = farol.

## Protocolo (engenharia reversa da comunidade)

| Item | Valor |
|---|---|
| Serviço | `0000fff0-0000-1000-8000-00805f9b34fb` |
| Característica de controle | `d44bc439-abfd-45a2-b575-925416129600` |
| Comando (16 bytes, antes de criptografar) | `00 'C' 'T' 'L' frente ré esq dir farol turbo 00 00 00 00 00 00` |
| Criptografia | AES-128-ECB, chave `34522a5b7a6e492c08090a9d8d2a23f8` |

Os comandos são reenviados a cada 50 ms enquanto conectado (ver
`lib/src/car_connection.dart`). Toda a lógica do protocolo está em
`lib/src/shell_protocol.dart` — se algum modelo se comportar diferente
(ex.: farol invertido), é lá que se ajusta.

## Publicação

Cada push na `main` builda e publica no GitHub Pages
(`.github/workflows/deploy.yml`). Na primeira vez, ative em
**Settings → Pages → Source: GitHub Actions**. O site fica em
`https://diegodio.github.io/controleRC/` (HTTPS, exigido pelo Web Bluetooth).
