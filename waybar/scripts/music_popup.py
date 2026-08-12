#!/usr/bin/env python3
"""
Popup de música para Waybar/Hyprland.
Mostra capa, título, artista e letra sincronizada do player MPRIS ativo.
"""

import json
import os
import re
import subprocess
import sys
import textwrap
import time
import urllib.parse
from pathlib import Path

import requests
from PySide6.QtCore import QEvent, QEasingCurve, QPropertyAnimation, Qt, QThread, QTimer, Signal
from ytmusicapi import YTMusic
from PySide6.QtGui import QFont, QIcon, QImage, QKeyEvent, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QPushButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

CACHE_DIR = Path.home() / ".cache" / "music-popup"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
STATE_FILE = CACHE_DIR / "state.json"

# Ajuste fino de sincronia da letra (segundos).
# Negativo adianta a letra, positivo atrasa. Padrão: 0.0
LYRICS_OFFSET = 0.0


def run(args):
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=5
        ).stdout.strip()
    except Exception:
        return ""


def get_player_list():
    out = run(["playerctl", "-l"])
    return [p for p in out.splitlines() if p.strip()] if out else []


def get_metadata(key, player=None):
    cmd = ["playerctl", "metadata"]
    if player:
        cmd.extend(["-p", player])
    cmd.append(key)
    return run(cmd)


def get_position(player=None):
    cmd = ["playerctl", "position"]
    if player:
        cmd.extend(["-p", player])
    try:
        return float(run(cmd))
    except ValueError:
        return 0.0


def get_status(player=None):
    cmd = ["playerctl", "status"]
    if player:
        cmd.extend(["-p", player])
    return run(cmd)


def get_active_player():
    players = get_player_list()
    for p in players:
        if get_status(p) in ("Playing", "Paused"):
            return p
    return players[0] if players else None


def parse_lrc(lrc_text: str):
    """Parseia texto LRC em lista de (tempo, texto)."""
    entries = []
    for raw_line in lrc_text.strip().splitlines():
        line = raw_line.strip()
        if not line:
            continue

        # Tags de tempo no início: [mm:ss.xx]
        tags = []
        rest = line
        while True:
            m = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\]\s*", rest)
            if not m:
                break
            minutes = int(m.group(1))
            seconds = float(m.group(2))
            tags.append(minutes * 60 + seconds)
            rest = rest[m.end() :]

        if not tags:
            continue

        # Verifica se há timestamps por palavra: <mm:ss.xx> palavra
        word_matches = re.findall(r"<(\d+):(\d+(?:\.\d+)?)>\s*([^<]*)", rest)
        if word_matches:
            for wm, ws, word in word_matches:
                time = int(wm) * 60 + float(ws)
                entries.append((time, word.strip()))
        else:
            text = rest.strip()
            for t in tags:
                entries.append((t, text))

    entries.sort(key=lambda x: x[0])
    return entries


def fetch_lyrics_ytmusic(video_id: str) -> str:
    """Busca letra sincronizada diretamente do YouTube Music."""
    if not video_id:
        return ""

    try:
        yt = YTMusic()
        wp = yt.get_watch_playlist(video_id)
        browse_id = wp.get("lyrics")
        if not browse_id:
            return ""

        lyrics = yt.get_lyrics(browse_id, True)
        if not lyrics.get("hasTimestamps"):
            return ""

        lrc_lines = []
        for line in lyrics["lyrics"]:
            start_sec = line.start_time / 1000
            minutes = int(start_sec // 60)
            seconds = start_sec % 60
            lrc_lines.append(f"[{minutes:02d}:{seconds:05.2f}] {line.text}")
        return "\n".join(lrc_lines)
    except Exception:
        return ""


def fetch_lyrics(artist: str, title: str, album: str = "", duration: float = 0.0):
    """Busca letra sincronizada no LRCLIB."""
    if not artist or not title:
        return None

    cache_key = f"{artist}-{title}-{album}".lower()
    cache_key = re.sub(r"[^a-z0-9_-]+", "-", cache_key)[:80]
    cache_file = CACHE_DIR / f"{cache_key}.json"

    if cache_file.exists():
        try:
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            if data.get("syncedLyrics"):
                return data["syncedLyrics"]
        except Exception:
            pass

    params = {
        "track_name": title,
        "artist_name": artist,
    }
    if album:
        params["album_name"] = album
    if duration > 0:
        params["duration"] = round(duration)

    try:
        resp = requests.get(
            "https://api.lrclib.net/api/get",
            params=params,
            timeout=10,
        )
        if resp.status_code == 200:
            data = resp.json()
            cache_file.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            return data.get("syncedLyrics") or data.get("plainLyrics")
    except Exception:
        pass

    return None


def load_art(url: str) -> QPixmap:
    """Carrega a capa do álbum de URL local ou remota."""
    pixmap = QPixmap()
    if not url:
        return pixmap

    try:
        if url.startswith("file://"):
            path = urllib.parse.urlparse(url).path
            pixmap.load(path)
        elif url.startswith("http://") or url.startswith("https://"):
            resp = requests.get(url, timeout=10)
            if resp.status_code == 200:
                image = QImage()
                image.loadFromData(resp.content)
                pixmap = QPixmap.fromImage(image)
    except Exception:
        pass

    return pixmap


def fetch_cover_url(artist: str, title: str) -> str:
    """Busca uma capa de alta resolução no iTunes Search API."""
    if not artist or not title:
        return ""

    cache_key = re.sub(r"[^a-z0-9]+", "-", f"{artist}-{title}".lower())[:60]
    cache_file = CACHE_DIR / f"cover-{cache_key}.url"

    if cache_file.exists():
        cached = cache_file.read_text(encoding="utf-8").strip()
        if cached:
            return cached

    try:
        resp = requests.get(
            "https://itunes.apple.com/search",
            params={
                "term": f"{artist} {title}",
                "entity": "song",
                "limit": 1,
            },
            timeout=10,
        )
        data = resp.json()
        if data.get("resultCount", 0) > 0:
            url = data["results"][0].get("artworkUrl100", "")
            if url:
                url = url.replace("100x100bb", "1000x1000bb")
                cache_file.write_text(url, encoding="utf-8")
                return url
    except Exception:
        pass

    return ""


def fetch_youtube_thumbnail(video_url: str) -> str:
    """Extrai o ID do vídeo do YouTube e retorna URL da thumbnail em alta resolução."""
    if not video_url:
        return ""

    patterns = [
        r"[?&]v=([a-zA-Z0-9_-]{11})",
        r"youtu\.be/([a-zA-Z0-9_-]{11})",
        r"youtube\.com/embed/([a-zA-Z0-9_-]{11})",
        r"youtube\.com/v/([a-zA-Z0-9_-]{11})",
    ]
    video_id = ""
    for pattern in patterns:
        m = re.search(pattern, video_url)
        if m:
            video_id = m.group(1)
            break

    if not video_id:
        return ""

    # Tenta várias resoluções, da maior para a menor
    for quality in ["maxresdefault", "hqdefault", "mqdefault", "default"]:
        url = f"https://img.youtube.com/vi/{video_id}/{quality}.jpg"
        try:
            resp = requests.head(url, timeout=5, allow_redirects=True)
            if resp.status_code == 200:
                return url
        except Exception:
            pass

    return ""


def fetch_cover_from_ytdlp(video_url: str) -> str:
    """Usa yt-dlp para obter a capa em alta resolução do YouTube Music."""
    if not video_url or "music.youtube.com" not in video_url:
        return ""

    try:
        result = subprocess.run(
            ["yt-dlp", "--no-download", "--dump-json", "--no-update", video_url],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            data = json.loads(result.stdout.strip().splitlines()[0])
            # Pega a thumbnail principal (jpg, alta resolução)
            if data.get("thumbnail"):
                return data["thumbnail"]
            thumbnails = data.get("thumbnails", [])
            if thumbnails:
                best = thumbnails[-1].get("url", "")
                if best:
                    return best
    except Exception:
        pass

    return ""


class CoverLoader(QThread):
    loaded = Signal(QPixmap)

    def __init__(self, parent, mpris_url: str, artist: str, title: str, video_url: str = ""):
        super().__init__(parent)
        self.mpris_url = mpris_url
        self.artist = artist
        self.title = title
        self.video_url = video_url

    def run(self):
        pixmap = load_art(self.mpris_url)
        # Se não tem capa ou é pequena demais, tenta outras fontes
        if pixmap.isNull() or pixmap.width() < 300:
            # Primeiro: thumbnail direta do YouTube (rápida, boa qualidade)
            if "youtube.com/watch" in self.video_url or "youtu.be" in self.video_url:
                yt_url = fetch_youtube_thumbnail(self.video_url)
                if yt_url:
                    pixmap = load_art(yt_url)
        self.loaded.emit(pixmap)


class LyricsLoader(QThread):
    loaded = Signal(str)

    def __init__(self, parent, video_url: str, artist: str, title: str, album: str, duration: float):
        super().__init__(parent)
        self.video_url = video_url
        self.artist = artist
        self.title = title
        self.album = album
        self.duration = duration

    def run(self):
        lrc_text = ""
        if self.video_url and ("music.youtube.com" in self.video_url or "youtube.com" in self.video_url):
            video_id_match = re.search(r"[?&]v=([a-zA-Z0-9_-]{11})", self.video_url)
            if video_id_match:
                lrc_text = fetch_lyrics_ytmusic(video_id_match.group(1))
        if not lrc_text:
            lrc_text = fetch_lyrics(self.artist, self.title, self.album, self.duration)
        self.loaded.emit(lrc_text or "")


class LyricLine(QLabel):
    def __init__(self, text: str, parent=None):
        super().__init__(text, parent)
        self.setAlignment(Qt.AlignCenter)
        self.setWordWrap(True)
        self.setTextInteractionFlags(Qt.NoTextInteraction)
        self.base_style = """
            QLabel {
                color: #888888;
                font-size: 18px;
                padding: 4px 20px;
            }
        """
        self.active_style = """
            QLabel {
                color: #ffffff;
                font-size: 24px;
                font-weight: bold;
                padding: 8px 20px;
            }
        """
        self.setStyleSheet(self.base_style)

    def set_active(self, active: bool):
        self.setStyleSheet(self.active_style if active else self.base_style)


class MusicPopup(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Música")
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setWindowFlags(
            Qt.FramelessWindowHint
            | Qt.WindowStaysOnTopHint
            | Qt.Tool
        )

        self.player = None
        self.current_track_id = ""
        self.lyrics = []
        self.cover_url = ""
        self.duration = 0.0
        self.cover_loader = None

        # Estimativa de posição (Firefox/YouTube Music não atualiza MPRIS position direito)
        self.last_status = ""
        self.status_change_time = 0.0
        self.position_at_status_change = 0.0
        self.save_state_timer = 0.0

        # Controle de rolagem
        self.last_lyric_idx = -1
        self.scroll_anim = None

        self.build_ui()
        self.position_window()

        # Timer de atualização
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.update_state)
        self.timer.start(100)

        self.update_state()

    def build_ui(self):
        central = QWidget()
        central.setStyleSheet(
            """
            QWidget {
                background-color: rgba(20, 20, 28, 0.95);
                border-radius: 20px;
                color: #ffffff;
            }
            """
        )
        self.setCentralWidget(central)

        layout = QVBoxLayout(central)
        layout.setContentsMargins(20, 12, 20, 16)
        layout.setSpacing(6)

        # Botão de fechar
        close_btn = QPushButton("✕")
        close_btn.setFixedSize(28, 28)
        close_btn.setStyleSheet(
            """
            QPushButton {
                background-color: transparent;
                color: #888888;
                border: none;
                font-size: 16px;
                font-weight: bold;
            }
            QPushButton:hover {
                color: #ffffff;
            }
            """
        )
        close_btn.clicked.connect(self.close)
        layout.addWidget(close_btn, alignment=Qt.AlignRight)

        # Capa
        self.cover_label = QLabel()
        self.cover_label.setAlignment(Qt.AlignCenter)
        self.cover_label.setFixedSize(220, 220)
        self.cover_label.setStyleSheet(
            "background-color: rgba(255,255,255,0.05); border-radius: 16px;"
        )
        layout.addWidget(self.cover_label, alignment=Qt.AlignCenter)

        # Info
        self.title_label = QLabel("Nenhuma música tocando")
        self.title_label.setAlignment(Qt.AlignCenter)
        self.title_label.setFont(QFont("JetBrainsMono Nerd Font", 15, QFont.Bold))
        self.title_label.setStyleSheet("color: #89b4fa;")
        self.title_label.setWordWrap(True)
        layout.addWidget(self.title_label)

        self.artist_label = QLabel("")
        self.artist_label.setAlignment(Qt.AlignCenter)
        self.artist_label.setFont(QFont("JetBrainsMono Nerd Font", 12))
        self.artist_label.setStyleSheet("color: #cdd6f4;")
        self.artist_label.setWordWrap(True)
        layout.addWidget(self.artist_label)

        # Botões de controle
        controls = QHBoxLayout()
        controls.setSpacing(24)
        controls.setAlignment(Qt.AlignCenter)

        btn_style = """
            QPushButton {
                background-color: transparent;
                color: #cdd6f4;
                border: none;
                font-size: 20px;
                padding: 2px;
            }
            QPushButton:hover {
                color: #89b4fa;
            }
        """

        prev_btn = QPushButton("⏮")
        prev_btn.setStyleSheet(btn_style)
        prev_btn.setCursor(Qt.PointingHandCursor)
        prev_btn.clicked.connect(lambda: self.player_command("previous"))
        controls.addWidget(prev_btn)

        self.play_pause_btn = QPushButton("⏯")
        self.play_pause_btn.setStyleSheet(btn_style)
        self.play_pause_btn.setCursor(Qt.PointingHandCursor)
        self.play_pause_btn.clicked.connect(lambda: self.player_command("play-pause"))
        controls.addWidget(self.play_pause_btn)

        next_btn = QPushButton("⏭")
        next_btn.setStyleSheet(btn_style)
        next_btn.setCursor(Qt.PointingHandCursor)
        next_btn.clicked.connect(lambda: self.player_command("next"))
        controls.addWidget(next_btn)

        layout.addLayout(controls)

        # Letra
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.scroll.setStyleSheet(
            "QScrollArea { border: none; background: transparent; }"
        )
        # Bloqueia rolagem manual (mouse/touchpad)
        self.scroll.viewport().installEventFilter(self)

        self.lyrics_widget = QWidget()
        self.lyrics_layout = QVBoxLayout(self.lyrics_widget)
        self.lyrics_layout.setAlignment(Qt.AlignCenter)
        self.lyrics_layout.setSpacing(0)
        self.lyrics_layout.setContentsMargins(0, 0, 0, 0)
        self.scroll.setWidget(self.lyrics_widget)
        layout.addWidget(self.scroll, stretch=1)

        # Mensagem de placeholder
        self.placeholder = QLabel("Clique em uma música na barra para ver os detalhes")
        self.placeholder.setAlignment(Qt.AlignCenter)
        self.placeholder.setStyleSheet("color: #6c7086; font-size: 14px;")
        self.lyrics_layout.addWidget(self.placeholder)

    def position_window(self):
        screen = QApplication.primaryScreen().availableGeometry()
        w, h = 420, 580
        x = (screen.width() - w) // 2
        y = 45  # logo abaixo da barra superior
        self.setGeometry(x, y, w, h)

    def keyPressEvent(self, event: QKeyEvent):
        if event.key() == Qt.Key_Escape:
            self.close()
        super().keyPressEvent(event)

    def changeEvent(self, event):
        if event.type() == QEvent.WindowDeactivate:
            self.save_state()
            self.close()
        super().changeEvent(event)

    def closeEvent(self, event):
        self.save_state()
        super().closeEvent(event)

    def eventFilter(self, obj, event):
        if obj == self.scroll.viewport() and event.type() == QEvent.Wheel:
            return True  # ignora scroll manual
        return super().eventFilter(obj, event)

    def mousePressEvent(self, event):
        self._drag_pos = event.globalPosition().toPoint()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.LeftButton:
            self.move(self.pos() + event.globalPosition().toPoint() - self._drag_pos)
            self._drag_pos = event.globalPosition().toPoint()
        super().mouseMoveEvent(event)

    def load_state(self, track_id: str):
        """Recupera a última posição conhecida de uma música."""
        try:
            if not STATE_FILE.exists():
                return 0.0, ""
            data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            if data.get("track_id") != track_id:
                return 0.0, ""

            saved_time = data.get("timestamp", 0.0)
            saved_status = data.get("status", "")
            saved_pos = data.get("position", 0.0)
            elapsed = time.time() - saved_time

            if saved_status == "Playing":
                return saved_pos + elapsed, "Playing"
            return saved_pos, saved_status
        except Exception:
            return 0.0, ""

    def save_state(self):
        """Persiste a posição atual para reabrir no mesmo ponto."""
        if not self.current_track_id:
            return
        try:
            STATE_FILE.write_text(
                json.dumps(
                    {
                        "track_id": self.current_track_id,
                        "status": self.last_status,
                        "position": self.position_at_status_change
                        + (
                            time.time() - self.status_change_time
                            if self.last_status == "Playing"
                            else 0.0
                        ),
                        "timestamp": time.time(),
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
        except Exception:
            pass

    def update_state(self):
        player = get_active_player()
        if not player:
            self.title_label.setText("Nenhum player ativo")
            self.artist_label.setText("Abra o YouTube Music no Firefox")
            return

        self.player = player
        status = get_status(player)
        title = get_metadata("title", player)
        artist = get_metadata("artist", player)
        album = get_metadata("album", player)
        art_url = get_metadata("mpris:artUrl", player)
        video_url = get_metadata("xesam:url", player)

        try:
            length_us = int(get_metadata("mpris:length", player))
            self.duration = length_us / 1_000_000
        except ValueError:
            self.duration = 0.0

        track_id = f"{title}|{artist}|{album}"
        now = time.time()

        if track_id != self.current_track_id:
            self.current_track_id = track_id
            # Tenta recuperar posição salva da mesma música
            saved_pos, saved_status = self.load_state(track_id)
            self.last_status = saved_status or status
            self.status_change_time = now
            self.position_at_status_change = saved_pos
            self.load_track(title, artist, album, art_url, video_url)

        # Atualiza estimativa de posição
        if status != self.last_status:
            mpris_position = get_position(player)
            if mpris_position > 1.0:  # só confia se for maior que 1 segundo
                self.position_at_status_change = mpris_position
            elif status == "Playing" and self.last_status == "Paused":
                # Continua de onde parou
                pass
            else:
                self.position_at_status_change = 0.0
            self.status_change_time = now
            self.last_status = status

        if status == "Playing":
            position = self.position_at_status_change + (now - self.status_change_time)
        else:
            position = self.position_at_status_change

        # Evita extrapolar a duração conhecida
        if self.duration > 0 and position > self.duration:
            position = self.duration

        self.update_lyrics(position + LYRICS_OFFSET)

        # Salva estado a cada 500ms para reabrir no ponto certo
        if now - self.save_state_timer > 0.5:
            self.save_state()
            self.save_state_timer = now

    def load_cover(self, mpris_url: str, artist: str, title: str, video_url: str):
        # Carrega a capa em uma thread para não travar a abertura do popup
        self.cover_loader = CoverLoader(self, mpris_url, artist, title, video_url)
        self.cover_loader.loaded.connect(self.set_cover, Qt.QueuedConnection)
        self.cover_loader.finished.connect(self.cover_loader.deleteLater)
        self.cover_loader.start()

    def load_track(self, title: str, artist: str, album: str, art_url: str, video_url: str = ""):
        self.title_label.setText(title or "Música desconhecida")
        self.artist_label.setText(artist or "")

        # Carrega capa
        if art_url != self.cover_url:
            self.cover_url = art_url
            self.cover_label.setText("🎵")
            self.cover_label.setPixmap(QPixmap())
            self.load_cover(art_url, artist, title, video_url)

        # Limpa letra anterior
        while self.lyrics_layout.count():
            item = self.lyrics_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self.lyrics = []
        self.lyric_labels = []

        if not title or not artist:
            self.placeholder = QLabel("Sem informações suficientes para buscar a letra")
            self.placeholder.setAlignment(Qt.AlignCenter)
            self.placeholder.setStyleSheet("color: #6c7086;")
            self.lyrics_layout.addWidget(self.placeholder)
            return

        # Busca letra em background (primeiro YT Music, depois LRCLIB)
        self.lyrics_loader = LyricsLoader(self, video_url, artist, title, album, self.duration)
        self.lyrics_loader.loaded.connect(self.on_lyrics_loaded, Qt.QueuedConnection)
        self.lyrics_loader.finished.connect(self.lyrics_loader.deleteLater)
        self.lyrics_loader.start()

    def on_lyrics_loaded(self, lrc_text: str):
        # Limpa placeholder
        while self.lyrics_layout.count():
            item = self.lyrics_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self.lyrics = []
        self.lyric_labels = []

        if not lrc_text:
            self.placeholder = QLabel("Letra não encontrada")
            self.placeholder.setAlignment(Qt.AlignCenter)
            self.placeholder.setStyleSheet("color: #6c7086;")
            self.lyrics_layout.addWidget(self.placeholder)
            return

        self.lyrics = parse_lrc(lrc_text)
        if not self.lyrics:
            self.placeholder = QLabel("Letra disponível, mas não sincronizada")
            self.placeholder.setAlignment(Qt.AlignCenter)
            self.placeholder.setStyleSheet("color: #6c7086;")
            self.lyrics_layout.addWidget(self.placeholder)
            return

        for _, text in self.lyrics:
            line = LyricLine(text)
            self.lyrics_layout.addWidget(line)
            self.lyric_labels.append(line)

        # Espaçadores para centralizar
        self.lyrics_layout.addStretch()

    def set_cover(self, pixmap: QPixmap):
        if pixmap.isNull():
            self.cover_label.setText("🎵")
            return
        scaled = pixmap.scaled(
            280, 280, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation
        )
        self.cover_label.setPixmap(scaled)

    def player_command(self, command: str):
        """Envia comando playerctl para o player ativo."""
        player = self.player or get_active_player()
        cmd = ["playerctl", command]
        if player:
            cmd.extend(["-p", player])
        try:
            subprocess.run(cmd, check=False, timeout=5)
        except Exception:
            pass

    def update_lyrics(self, position: float):
        if not self.lyrics or not self.lyric_labels:
            return

        # Encontra a linha atual
        current_idx = 0
        for i, (line_time, _) in enumerate(self.lyrics):
            if line_time <= position:
                current_idx = i
            else:
                break

        for i, label in enumerate(self.lyric_labels):
            label.set_active(i == current_idx)

        # Rola suavemente apenas quando a linha ativa mudar ou na primeira vez
        if current_idx != self.last_lyric_idx:
            self.last_lyric_idx = current_idx
            if 0 <= current_idx < len(self.lyric_labels):
                label = self.lyric_labels[current_idx]
                target_y = label.geometry().center().y() - self.scroll.viewport().height() // 2
                target_y = max(0, min(target_y, self.scroll.widget().height() - self.scroll.viewport().height()))
                scrollbar = self.scroll.verticalScrollBar()

                # Só anima se a diferença for relevante
                if abs(scrollbar.value() - target_y) < 5:
                    scrollbar.setValue(target_y)
                    return

                if self.scroll_anim:
                    self.scroll_anim.stop()
                self.scroll_anim = QPropertyAnimation(scrollbar, b"value")
                self.scroll_anim.setDuration(250)
                self.scroll_anim.setStartValue(scrollbar.value())
                self.scroll_anim.setEndValue(target_y)
                self.scroll_anim.setEasingCurve(QEasingCurve.OutCubic)
                self.scroll_anim.start()


LOCK_FILE = Path("/tmp/music-popup.lock")


def ensure_single_instance():
    try:
        if LOCK_FILE.exists():
            try:
                pid = int(LOCK_FILE.read_text())
                os.kill(pid, 0)
                return False
            except (ValueError, ProcessLookupError):
                pass
        LOCK_FILE.write_text(str(os.getpid()))
        return True
    except Exception:
        return True


def main():
    if not ensure_single_instance():
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setApplicationName("music-popup")
    app.setDesktopFileName("music-popup")
    app.setStyle("Fusion")
    popup = MusicPopup()
    popup.show()

    def cleanup():
        try:
            LOCK_FILE.unlink()
        except FileNotFoundError:
            pass

    app.aboutToQuit.connect(cleanup)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
