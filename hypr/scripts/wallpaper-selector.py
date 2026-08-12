#!/usr/bin/env python3
"""
Seletor minimalista de wallpapers.
Só mostra as thumbnails; clique aplica.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageOps
from PySide6.QtCore import QEvent, Qt, Signal
from PySide6.QtGui import QKeyEvent, QPixmap
from PySide6.QtWidgets import QGraphicsOpacityEffect
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QGridLayout,
    QLabel,
    QMainWindow,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

WALL_DIR = Path.home() / "Pictures" / "wallpapers"
CACHE_DIR = Path.home() / ".cache" / "wallpaper-selector"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
CACHE_FILE = CACHE_DIR / "thumbnails.json"

STATIC_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
ANIMATED_EXTS = {".gif"}
VIDEO_EXTS = {".mp4", ".webm", ".mov", ".mkv", ".avi"}
ALL_EXTS = STATIC_EXTS | ANIMATED_EXTS | VIDEO_EXTS

THUMB_SIZE = 170


def run(args, check=False):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=30, check=check)
    except Exception as e:
        return subprocess.CompletedProcess(args, 1, "", str(e))


def get_wallpapers():
    if not WALL_DIR.exists():
        return []
    return [f for f in sorted(WALL_DIR.iterdir()) if f.is_file() and f.suffix.lower() in ALL_EXTS]


def get_file_type(path: Path) -> str:
    ext = path.suffix.lower()
    if ext in VIDEO_EXTS:
        return "video"
    if ext in ANIMATED_EXTS:
        return "gif"
    return "static"


def cache_key(path: Path) -> str:
    stat = path.stat()
    return f"{path.stem}_{stat.st_size}_{int(stat.st_mtime)}"


def load_cache():
    try:
        return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_cache(data):
    try:
        CACHE_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


def make_thumbnail(path: Path) -> Path:
    cache = load_cache()
    key = cache_key(path)
    thumb_path = CACHE_DIR / f"{key}.png"
    if cache.get(key) == str(thumb_path) and thumb_path.exists():
        return thumb_path

    ftype = get_file_type(path)
    source = path
    if ftype == "video":
        frame_path = CACHE_DIR / f"{key}_frame.jpg"
        run([
            "ffmpeg", "-y", "-i", str(path), "-ss", "00:00:00.500",
            "-vframes", "1", "-q:v", "2", str(frame_path)
        ])
        if frame_path.exists():
            source = frame_path

    try:
        img = Image.open(source)
        img = ImageOps.exif_transpose(img)
        # Crop central quadrado
        min_dim = min(img.width, img.height)
        left = (img.width - min_dim) // 2
        top = (img.height - min_dim) // 2
        img = img.crop((left, top, left + min_dim, top + min_dim))
        img = img.resize((THUMB_SIZE, THUMB_SIZE), Image.LANCZOS)
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        img.save(thumb_path, "PNG")
    except Exception:
        canvas = Image.new("RGBA", (THUMB_SIZE, THUMB_SIZE), (20, 20, 28, 255))
        canvas.save(thumb_path, "PNG")

    cache[key] = str(thumb_path)
    save_cache(cache)
    return thumb_path


def apply_wallpaper(path: Path):
    ftype = get_file_type(path)
    run(["pkill", "mpvpaper"])

    if ftype == "video":
        result = run(["hyprctl", "monitors", "-j"])
        try:
            monitors = json.loads(result.stdout)
            monitor_names = [m.get("name") for m in monitors if m.get("name")]
        except Exception:
            monitor_names = ["HDMI-A-1"]

        for mon in monitor_names:
            subprocess.Popen(
                ["mpvpaper", "-o", "no-audio loop", mon, str(path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    else:
        subprocess.run([
            "swww", "img", str(path),
            "--transition-type", "grow",
            "--transition-duration", "0.8",
        ], check=False)


class WallpaperItem(QFrame):
    clicked = Signal(Path)

    def __init__(self, path: Path, parent=None):
        super().__init__(parent)
        self.path = path
        self.setFixedSize(THUMB_SIZE + 6, THUMB_SIZE + 6)
        self.setCursor(Qt.PointingHandCursor)
        self.selected = False
        self.setStyleSheet("""
            QFrame {
                background-color: transparent;
                border-radius: 0px;
                border: none;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(2, 2, 2, 2)

        self.image_label = QLabel()
        self.image_label.setFixedSize(THUMB_SIZE, THUMB_SIZE)
        self.image_label.setAlignment(Qt.AlignCenter)
        self.image_label.setStyleSheet("background-color: transparent; border-radius: 0px;")
        layout.addWidget(self.image_label)

        try:
            thumb_path = make_thumbnail(path)
            pixmap = QPixmap(str(thumb_path))
            scaled = pixmap.scaled(
                THUMB_SIZE, THUMB_SIZE, Qt.KeepAspectRatioByExpanding, Qt.SmoothTransformation
            )
            self.image_label.setPixmap(scaled)
        except Exception:
            pass

    def set_selected(self, selected: bool):
        self.selected = selected
        effect = QGraphicsOpacityEffect(self.image_label)
        effect.setOpacity(1.0 if selected else 0.55)
        self.image_label.setGraphicsEffect(effect)

    def mousePressEvent(self, event):
        self.clicked.emit(self.path)


class WallpaperSelector(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Wallpapers")
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)

        central = QWidget()
        central.setStyleSheet("""
            QWidget {
                background-color: rgba(20, 20, 28, 0.92);
                border-radius: 12px;
            }
        """)
        self.setCentralWidget(central)

        layout = QVBoxLayout(central)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(8)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.scroll.setStyleSheet("""
            QScrollArea { border: none; background: transparent; }
            QScrollBar:vertical { width: 5px; background: transparent; }
            QScrollBar::handle:vertical { background: #89b4fa; border-radius: 3px; }
        """)

        self.grid_widget = QWidget()
        self.grid_layout = QGridLayout(self.grid_widget)
        self.grid_layout.setSpacing(6)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.scroll.setWidget(self.grid_widget)
        layout.addWidget(self.scroll)

        self.wallpapers = get_wallpapers()
        self.items = []
        self.selected_idx = 0
        self.render_grid()
        self.position_window()
        self.update_selection()
        self.setFocusPolicy(Qt.StrongFocus)
        self.setFocus()

    def position_window(self):
        screen = QApplication.primaryScreen().availableGeometry()
        cols = min(4, len(self.wallpapers)) if len(self.wallpapers) > 0 else 1
        rows = (len(self.wallpapers) + cols - 1) // cols
        w = cols * (THUMB_SIZE + 10) + 32
        h = rows * (THUMB_SIZE + 10) + 32
        w = max(200, min(w, screen.width() - 80))
        h = max(160, min(h, screen.height() - 80))
        x = (screen.width() - w) // 2
        y = (screen.height() - h) // 2
        self.setGeometry(x, y, w, h)

    def keyPressEvent(self, event: QKeyEvent):
        key = event.key()
        if key == Qt.Key_Escape:
            self.close()
            return
        if key in (Qt.Key_Return, Qt.Key_Enter):
            if 0 <= self.selected_idx < len(self.wallpapers):
                apply_wallpaper(self.wallpapers[self.selected_idx])
            return
        if key == Qt.Key_Left:
            self.selected_idx = max(0, self.selected_idx - 1)
            self.update_selection()
            return
        if key == Qt.Key_Right:
            self.selected_idx = min(len(self.wallpapers) - 1, self.selected_idx + 1)
            self.update_selection()
            return
        if key == Qt.Key_Up:
            cols = self.grid_layout.columnCount()
            self.selected_idx = max(0, self.selected_idx - cols)
            self.update_selection()
            return
        if key == Qt.Key_Down:
            cols = self.grid_layout.columnCount()
            self.selected_idx = min(len(self.wallpapers) - 1, self.selected_idx + cols)
            self.update_selection()
            return
        super().keyPressEvent(event)

    def update_selection(self):
        for i, item in enumerate(self.items):
            item.set_selected(i == self.selected_idx)
        if 0 <= self.selected_idx < len(self.items):
            item = self.items[self.selected_idx]
            self.scroll.ensureWidgetVisible(item, 20, 20)

    def changeEvent(self, event):
        if event.type() == QEvent.WindowDeactivate:
            self.close()
        super().changeEvent(event)

    def closeEvent(self, event):
        QApplication.quit()
        super().closeEvent(event)

    def render_grid(self):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.items.clear()

        cols = min(4, len(self.wallpapers)) if len(self.wallpapers) > 0 else 1
        for i, path in enumerate(self.wallpapers):
            item = WallpaperItem(path)
            item.clicked.connect(lambda checked=False, p=path: apply_wallpaper(p))
            item.mousePressEvent = lambda event, idx=i: self.select_item(idx)
            self.grid_layout.addWidget(item, i // cols, i % cols)
            self.items.append(item)

    def select_item(self, idx: int):
        self.selected_idx = idx
        self.update_selection()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        new_cols = max(1, min(4, self.width() // (THUMB_SIZE + 16)))
        if new_cols != self.grid_layout.columnCount():
            old_idx = self.selected_idx
            self.render_grid()
            self.selected_idx = min(old_idx, len(self.items) - 1)
            self.update_selection()


LOCK_FILE = Path("/tmp/wallpaper-selector.lock")


def ensure_single_instance():
    try:
        if LOCK_FILE.exists():
            try:
                pid = int(LOCK_FILE.read_text().strip())
                # Verifica se o PID ainda existe e é um wallpaper-selector
                cmdline = Path(f"/proc/{pid}/cmdline").read_text(errors="ignore") if Path(f"/proc/{pid}").exists() else ""
                if "wallpaper-selector.py" in cmdline:
                    return False
            except (ValueError, ProcessLookupError, FileNotFoundError):
                pass
            # Lock obsoleto, remove
            try:
                LOCK_FILE.unlink()
            except FileNotFoundError:
                pass
        LOCK_FILE.write_text(str(os.getpid()))
        return True
    except Exception:
        return True


def main():
    if not ensure_single_instance():
        sys.exit(0)

    app = QApplication(sys.argv)
    app.setApplicationName("wallpaper-selector")
    app.setDesktopFileName("wallpaper-selector")
    app.setStyle("Fusion")
    selector = WallpaperSelector()
    selector.show()

    def cleanup():
        try:
            LOCK_FILE.unlink()
        except FileNotFoundError:
            pass

    app.aboutToQuit.connect(cleanup)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
