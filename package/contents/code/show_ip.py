#!/usr/bin/env python3

import socket

def get_local_ip():
    """
    Gibt die IP-Adresse der aktiven Netzwerkverbindung zurück.
    Funktioniert ohne Internetzugang.
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Verbindung wird nicht wirklich aufgebaut – dient nur zur IP-Erkennung
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception as e:
        print("⚠️ Fehler bei IP-Ermittlung:", e)
        return "127.0.0.1"
    finally:
        s.close()

if __name__ == "__main__":
    ip = get_local_ip()
    print("📡 Lokale IP-Adresse ist:", ip)

    url = f"http://{ip}:8000/{'filename'}"

    print(url)
