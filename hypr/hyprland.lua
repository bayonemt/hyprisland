-- ================================================================
-- hyprland.lua — migrado do seu hyprland.conf (hyprlang) antigo
-- para a sintaxe Lua do Hyprland 0.55+.
--
-- ANTES DE USAR:
-- 1) Faça backup do hyprland.conf atual (não precisa apagar, ele
--    simplesmente passa a ser ignorado assim que este arquivo
--    existir em ~/.config/hypr/hyprland.lua).
-- 2) A troca de hyprland.conf -> hyprland.lua só é detectada no
--    START do Hyprland, então após criar este arquivo você precisa
--    reiniciar a sessão do Hyprland (logout/login), não basta
--    hyprctl reload.
-- 3) Depois do restart inicial, qualquer edição neste arquivo já
--    recarrega sozinha ao salvar.
-- 4) Se algo sair muito errado e as teclas pararem de responder,
--    o Hyprland tem binds de emergência fixos: SUPER+Q abre um
--    terminal, SUPER+R abre um launcher, SUPER+M fecha o Hyprland.
--    Use isso pra editar o arquivo e corrigir se precisar.
--
-- Fonte oficial: https://wiki.hypr.land/Configuring/
-- ================================================================

local mod = "SUPER"

-- ----------------------------------------------------------------
-- Variáveis de ambiente (drivers NVIDIA / Vulkan)
-- ATENÇÃO: essas variáveis controlam driver de GPU (LIBVA, GBM,
-- GLX, WLR_RENDERER). O wiki do Arch recomenda NÃO colocar esse
-- tipo de variável no hyprland.lua e sim num arquivo de ambiente
-- carregado antes do Hyprland iniciar (ex: ~/.config/uwsm/env-hyprland
-- se você usa uwsm, ou o método equivalente que seu Fedora/spin usa
-- pra exportar variáveis antes da sessão gráfica subir). Deixei o
-- hl.env() abaixo como equivalente direto, mas se a tela renderizar
-- errado com NVIDIA depois da migração, esse é o primeiro lugar
-- pra desconfiar.
-- ----------------------------------------------------------------
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER", "vulkan")

-- ----------------------------------------------------------------
-- Configurações gerais (input / decoration)
-- ----------------------------------------------------------------
hl.config({
  input = {
    kb_layout = "br",
    kb_variant = "abnt2",
  },
  decoration = {
    rounding = 10,
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
    },
  },
})

-- ----------------------------------------------------------------
-- Apps ao iniciar (exec-once)
-- ----------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("~/.config/hypr/scripts/toggle-music-popup.sh --start-hidden")
  hl.exec_cmd("~/.config/hypr/scripts/toggle-calendar-popup.sh --start-hidden")
  hl.exec_cmd("mako")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("swww-daemon --format xrgb")
  hl.exec_cmd("/usr/libexec/kf6/polkit-kde-authentication-agent-1")
  -- hl.exec_cmd("hyprpaper") -- estava comentado no config original
end)

-- ----------------------------------------------------------------
-- Keybinds
-- ----------------------------------------------------------------

-- terminal
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("kitty"))

-- fechar janela
hl.bind(mod .. " + Q", hl.dsp.window.close())

-- launcher
hl.bind(mod .. " + D", hl.dsp.exec_cmd("wofi --show drun"))

-- mover janela ativa entre workspaces
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ workspace = "+1" }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ workspace = "-1" }))

-- mover entre janelas
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next())
-- (no original os dois binds chamavam o mesmo cyclenext sem direção,
-- então mantive igual aqui; se quiser que SHIFT+TAB cicle pro lado
-- contrário, me avisa que eu ajusto)

-- tela cheia (modo "maximizado", mantém barras)
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- minimizar todas as janelas do workspace atual (mostrar área de trabalho) / restaurar
hl.bind(mod .. " + down", hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize-all.sh hide"))
hl.bind(mod .. " + up", hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize-all.sh show"))

-- explorador de arquivos
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))

-- print
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- tela de bloqueio (no original isso rodava "hyprctl dispatch exit",
-- ou seja, na prática fechava o Hyprland em vez de bloquear a tela —
-- mantive o comportamento original com o dispatcher nativo de saída)
hl.bind(mod .. " + L", hl.dsp.exit())

-- arrastar/redimensionar janelas com o mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- mostrar área de trabalho
hl.bind(mod .. " + B", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + SHIFT + B", hl.dsp.focus({ workspace = "previous" }))

-- abrir apps
hl.bind("CTRL + F1", hl.dsp.exec_cmd("DiscordCanary --enable-features=UseOzonePlatform --ozone-platform=wayland"))
hl.bind("CTRL + F2", hl.dsp.exec_cmd("firefox"))

-- controlar volume pela rodinha do teclado
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))

-- definir wallpaper
hl.bind(mod .. " + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-selector-quickshell.sh"))

-- fechar app à força
-- (no original estava "SUPER_SHIFT" com underline, que não é uma
-- combinação de mod válida — deve ter ficado sem funcionar. Ajustei
-- para SUPER + SHIFT, que era claramente a intenção)
hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/superkill.sh"))

-- opções de energia
hl.bind(mod .. " + ESCAPE", hl.dsp.exec_cmd("wlogout"))

-- histórico da área de transferência
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- teste
hl.bind(mod .. " + F12", hl.dsp.exec_cmd("notify-send TESTE"))

-- ----------------------------------------------------------------
-- Window rules
-- ----------------------------------------------------------------

-- Music popup (Quickshell qs-music-popup)
-- 270 = 41 (tab bar) + 207 (altura real medida do conteúdo da aba de Música)
-- + folga. O Quickshell não redimensiona essa janela ao vivo nesse setup,
-- então o tamanho tem que já vir certo daqui.
hl.window_rule({
  name = "music-popup",
  match = { title = "^(music-popup)$" },
  float = true,
  size = "380 270",
  move = "770 54",
  pin = true,
  border_size = 0,
  no_shadow = true,
  rounding = 20,
  no_blur = true,
  opaque = true,
})

-- Calendar popup (Quickshell qs-calendar-popup)
hl.window_rule({
  name = "calendar-popup",
  match = { title = "^(calendar-popup)$" },
  float = true,
  size = "300 336",
  move = "810 54",
  pin = true,
  border_size = 0,
  no_shadow = true,
  rounding = 20,
  no_blur = true,
  opaque = true,
})

-- Wallpaper selector (Quickshell qs-wallpaper-picker), com classe
hl.window_rule({
  name = "wallpaper-picker-quickshell",
  match = { class = "^(quickshell)$", title = "^(wallpaper-picker)$" },
  float = true,
  center = true,
  pin = true,
  border_size = 0,
  no_shadow = true,
  rounding = 20,
  no_blur = true,
  opaque = true,
})

-- Wallpaper selector - fallback (caso class/title sejam diferentes)
hl.window_rule({
  name = "wallpaper-picker-fallback",
  match = { title = "^(wallpaper-picker)$" },
  float = true,
  center = true,
  pin = true,
  border_size = 0,
  no_shadow = true,
  rounding = 20,
  no_blur = true,
  opaque = true,
})

-- Waypaper
hl.window_rule({
  name = "waypaper",
  match = { class = "^(waypaper)$" },
  float = true,
  size = "850 520",
  center = true,
  pin = true,
  border_size = 0,
  no_shadow = true,
  rounding = 20,
})

-- WayDroid - corrige offset de mouse/input
hl.window_rule({
  name = "waydroid",
  match = { class = "^(Waydroid)$" },
  float = true,
  size = "576 1024",
  center = true,
  pin = true,
  border_size = 0,
  no_shadow = true,
  no_blur = true,
  opaque = true,
  rounding = 0,
  no_max_size = true,
  suppress_event = "maximize fullscreen",
})
