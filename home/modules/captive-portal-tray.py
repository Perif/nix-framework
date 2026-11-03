#!/usr/bin/env python3
"""KDE StatusNotifier menu for the temporary captive-portal service."""

import subprocess
import sys

from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QColor, QIcon, QPainter, QPainterPath, QPen, QPixmap
from PyQt6.QtWidgets import QApplication, QMenu, QSystemTrayIcon


UNIT = "captive-portal-mode.service"


def state_icon(active: bool) -> QIcon:
    """Draw a compact shield badge instead of reusing the normal Wi-Fi icon."""
    pixmap = QPixmap(32, 32)
    pixmap.fill(QColor("transparent"))
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)

    shield = QPainterPath()
    shield.moveTo(16, 3)
    shield.lineTo(27, 7)
    shield.lineTo(25, 19)
    shield.cubicTo(24, 25, 20, 28, 16, 30)
    shield.cubicTo(12, 28, 8, 25, 7, 19)
    shield.lineTo(5, 7)
    shield.closeSubpath()
    painter.setPen(QPen(QColor("#5e6773") if not active else QColor("#b56a00"), 1.5))
    painter.setBrush(QColor("#8b95a1") if not active else QColor("#f0a000"))
    painter.drawPath(shield)

    painter.setPen(QPen(QColor("white"), 2.5))
    painter.drawLine(12, 16, 20, 16)
    painter.drawLine(16, 12, 16, 20)
    painter.end()
    return QIcon(pixmap)


def is_active() -> bool:
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", UNIT], check=False
    ).returncode == 0


def manage(action: str) -> None:
    # systemd forwards this request to Plasma's Polkit agent. The agent uses
    # polkit-1 PAM, where fprintd is enabled declaratively.
    subprocess.Popen(["systemctl", action, UNIT])


def main() -> int:
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    tray = QSystemTrayIcon(state_icon(False))
    menu = QMenu()
    status = menu.addAction("")
    status.setEnabled(False)
    menu.addSeparator()
    start = menu.addAction("Start captive portal mode")
    stop = menu.addAction("Stop captive portal mode")
    menu.addSeparator()
    quit_action = menu.addAction("Quit captive portal control")
    tray.setContextMenu(menu)

    def refresh() -> None:
        active = is_active()
        status.setText(
            "Captive portal mode: active" if active else "Captive portal mode: off"
        )
        start.setEnabled(not active)
        stop.setEnabled(active)
        tray.setIcon(state_icon(active))
        tray.setToolTip(status.text())

    def start_mode() -> None:
        manage("start")
        QTimer.singleShot(1200, refresh)

    def stop_mode() -> None:
        manage("stop")
        QTimer.singleShot(1200, refresh)

    start.triggered.connect(start_mode)
    stop.triggered.connect(stop_mode)
    quit_action.triggered.connect(app.quit)
    refresh()
    tray.show()

    timer = QTimer(tray)
    timer.timeout.connect(refresh)
    timer.start(5000)
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
