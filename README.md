# hyprisland

Meu setup pessoal de Hyprland + Waybar, construído em torno de um popup customizado feito em [Quickshell](https://quickshell.org/) que começou como um widget de "tocando agora" e virou um pequeno hub de central de controle com três abas:

- **Música** — player MPRIS (capa, título/artista, barra de progresso, shuffle/anterior/play-pause/próxima/loop), lê qualquer player que estiver ativo via `Quickshell.Services.Mpris`.
- **Notificações** — histórico de notificações do `mako`, com remoção individual e "limpar tudo" (o mako não tem comando nativo de "apagar do histórico", então os ids removidos são rastreados num pequeno arquivo local).
- **Ajustes** — quick settings: slider de volume + mute, mute do microfone, e um toggle de "não perturbar" que ativa um modo do `mako`.

É aberto clicando no iconezinho de nota na barra do waybar (módulo `custom/music-popup`), que alterna um arquivo de flag que um processo persistente do Quickshell fica monitorando.

## Estrutura

Isso espelha o `~/.config/`, então cada pasta de primeiro nível aqui corresponde 1:1 a uma pasta lá:

```
waybar/       -> ~/.config/waybar
quickshell/   -> ~/.config/quickshell
hypr/         -> ~/.config/hypr
mako/         -> ~/.config/mako
```

### `quickshell/qs-music-popup/`

O widget hub em si:

- `Main.qml` — a `FloatingWindow`, monitora um arquivo de flag `/tmp/qs-music-popup-visible` pra mostrar/esconder.
- `HubPopup.qml` — a barra de abas (Música / Notif. / Ajustes) + container de tamanho fixo pra aba que estiver ativa.
- `MusicPopup.qml` — a aba do player MPRIS.
- `NotificationsPanel.qml` — a aba de histórico de notificações.
- `QuickSettingsPanel.qml` — a aba de quick settings.

Alternado via `hypr/scripts/toggle-music-popup.sh`, iniciado junto com o Hyprland (`exec-once` no `hyprland.conf`) com `--start-hidden`.

**Nota sobre o tamanho da janela:** o popup tem tamanho *fixo* (`380x270`, definido via `windowrulev2 = size ...` no `hyprland.conf`/`hyprland.lua`), não é dimensionado dinamicamente a partir do conteúdo do QML. Tentei deixar o `implicitHeight` do Quickshell controlar o tamanho real da janela e não foi confiável nesse setup de Hyprland — a superfície ao vivo não redimensionava de forma consistente depois que a janela já tinha sido mapeada. Se for reaproveitar isso e o conteúdo das suas abas for mais alto/baixo, você vai precisar recalcular e ajustar esse tamanho fixo.

### `quickshell/qs-calendar-popup/`

Um popup pequeno parecido, mostrando um calendário, com o mesmo padrão de alternar via arquivo de flag.

### Não incluído: `qs-wallpaper-picker`

O `hyprland.conf` tem regras de janela pra um título `wallpaper-picker`, que vêm do [magetsu002/qs-wallpaper-picker](https://github.com/magetsu002/qs-wallpaper-picker) — um projeto de Quickshell de terceiros que eu uso, não é código meu, então não foi duplicado aqui. Pegue no repositório original se quiser usar.

## Dependências

- [Hyprland](https://hyprland.org/)
- [Waybar](https://github.com/Alexays/Waybar)
- [Quickshell](https://quickshell.org/)
- [mako](https://github.com/emersion/mako) (notificações)
- `pactl` (PipeWire-Pulse) pros controles de volume/microfone na aba Ajustes
- `playerctl` (usado pelos scripts mais antigos em `waybar/scripts/*.py`/`.sh` — a aba de música do Quickshell em si conversa direto com o MPRIS e não precisa disso)
- `python3` + `requests` se quiser o `waybar/scripts/music_popup.py` legado (popup GTK/PySide6 com letra sincronizada, substituído pelo hub em Quickshell, mantido só de referência)

## Instalando

Faça backup dos seus configs atuais primeiro, depois crie os symlinks (ou copie) cada pasta:

```sh
ln -s ~/hyprisland/waybar ~/.config/waybar
ln -s ~/hyprisland/quickshell ~/.config/quickshell
ln -s ~/hyprisland/hypr ~/.config/hypr
ln -s ~/hyprisland/mako ~/.config/mako
```

Recarregue o Hyprland (`hyprctl reload`) e reinicie o Waybar/mako. Ajuste as posições/tamanhos fixos de janela em `hypr/hyprland.conf` (regras `move`/`size`) pro seu próprio layout de monitor.

## Pontas soltas conhecidas

- `waybar/config.jsonc` define módulos `cpu`, `memory`, `temperature`, `network` e `battery` que não estão conectados em `modules-left/center/right` no momento — deixados aí de referência/reaproveitamento.
- `waybar/scripts/music-popup.py`, `music_popup.py`, `music.sh`, `music-waybar.py` são as versões anteriores ao Quickshell do widget de música (bash/playerctl, depois um popup GTK em PySide6 com letra sincronizada). Substituídos por `quickshell/qs-music-popup/`, mantidos só de referência.
- Essa máquina não tem adaptador de wifi/bluetooth nem brilho de tela controlável, então a aba Ajustes intencionalmente não tem esses toggles — adicione você mesmo se seu hardware tiver isso (`nmcli`, `bluetoothctl`, `brightnessctl`/`ddcutil`).
