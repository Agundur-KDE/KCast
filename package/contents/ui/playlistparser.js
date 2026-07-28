// Plain JS on purpose (no .pragma library, no QML APIs) so this file is
// importable both from QML ("import "playlistparser.js" as Parser") and
// runnable standalone under Node for the self-check in
// tests/test_playlistparser.js.

function formatDuration(totalSeconds) {
    var s = Math.max(0, Math.round(totalSeconds));
    var m = Math.floor(s / 60);
    var r = s % 60;
    return m + ":" + (r < 10 ? "0" : "") + r;
}

function baseName(url) {
    var withoutQuery = url.split("?")[0];
    var parts = withoutQuery.split("/");
    return decodeURIComponent(parts[parts.length - 1] || url);
}

// Distinguishes a real M3U/M3U8 *playlist* (list of media entries, #EXTINF
// tags) from an HLS *stream manifest* (#EXT-X-STREAM-INF / #EXT-X-TARGETDURATION),
// which despite the same file extension is a single stream URL, not a queue.
function parseM3U(text) {
    if (!text || typeof text !== "string")
        return { kind: "empty", entries: [] };

    var lines = text.split(/\r?\n/);
    var isHls = false;
    var entries = [];
    var pendingTitle = null;
    var pendingDuration = null;

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.length === 0)
            continue;

        if (line.indexOf("#EXT-X-STREAM-INF") === 0 || line.indexOf("#EXT-X-TARGETDURATION") === 0) {
            isHls = true;
            continue;
        }

        if (line.indexOf("#EXTINF") === 0) {
            var rest = line.substring("#EXTINF:".length);
            var comma = rest.indexOf(",");
            var durationPart = comma >= 0 ? rest.substring(0, comma) : rest;
            pendingTitle = comma >= 0 ? rest.substring(comma + 1).trim() : null;
            var durationSeconds = parseFloat(durationPart);
            pendingDuration = isNaN(durationSeconds) || durationSeconds < 0 ? null : durationSeconds;
            continue;
        }

        if (line.indexOf("#") === 0)
            continue;

        entries.push({
            url: line,
            title: pendingTitle || baseName(line),
            duration: pendingDuration !== null ? formatDuration(pendingDuration) : ""
        });
        pendingTitle = null;
        pendingDuration = null;
    }

    if (isHls)
        return { kind: "hls", entries: [] };

    return { kind: entries.length > 0 ? "playlist" : "empty", entries: entries };
}

// Node-testability guard: harmless in QML, where `module` is undefined.
if (typeof module !== "undefined")
    module.exports = { parseM3U: parseM3U, formatDuration: formatDuration, baseName: baseName };
