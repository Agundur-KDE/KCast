import pychromecast
import time

# Testmedien-Datei
media_url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
media_url = "blob:https://streamup.ws/172b4eca-e6ff-467f-bc0f-f38af3f81ef6"

content_type = "video/mp4"

print("Suche Chromecasts...")
chromecasts, browser = pychromecast.get_chromecasts()

if not chromecasts:
    print("Keine Chromecasts gefunden")
    exit(1)

cast = chromecasts[0]
print(f"Verbinde mit Chromecast ({cast})...")

# Verbinden
cast.wait()

# Explizit die Default Media Receiver App starten
cast.start_app('CC1AD845')  # Default Media Receiver App ID

# Kurz warten, bis die App gestartet ist
time.sleep(2)

# Media Controller verwenden
mc = cast.media_controller

# Video abspielen
print(f"Starte Video...")
mc.play_media(media_url, content_type)
print("Video wird geladen...")

# Status-Updates anzeigen
for _ in range(10):  # 10 Status-Updates
    status = mc.status
    if status:
        print(f"Status: {status.player_state}")
    else:
        print("Kein Status verfügbar")
    time.sleep(1)

print("Video sollte jetzt laufen. Drücke Strg+C zum Beenden.")
try:
    while True:
        time.sleep(5)
        status = mc.status
        if status:
            print(f"Status: {status.player_state}")
except KeyboardInterrupt:
    print("Beende...")
finally:
    # Sauber aufräumen
    cast.disconnect()
    browser.stop_discovery()
    print("Fertig.")