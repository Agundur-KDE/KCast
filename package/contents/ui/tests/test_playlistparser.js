// Run: node package/contents/ui/tests/test_playlistparser.js
const assert = require("assert");
const { parseM3U, formatDuration, baseName } = require("../playlistparser.js");

// Real playlist: #EXTINF entries -> a queue of tracks
{
    const text = [
        "#EXTM3U",
        "#EXTINF:125,Intro Song",
        "/home/user/Music/intro.mp3",
        "#EXTINF:-1,Live Stream (unknown length)",
        "https://example.com/stream.mp3",
        "no-extinf-before-this-one.mp4"
    ].join("\n");

    const result = parseM3U(text);
    assert.strictEqual(result.kind, "playlist");
    assert.strictEqual(result.entries.length, 3);
    assert.strictEqual(result.entries[0].title, "Intro Song");
    assert.strictEqual(result.entries[0].duration, "2:05");
    assert.strictEqual(result.entries[1].title, "Live Stream (unknown length)");
    assert.strictEqual(result.entries[1].duration, "");
    assert.strictEqual(result.entries[2].title, "no-extinf-before-this-one.mp4");
}

// HLS manifest: must NOT be treated as a playlist, despite same extension
{
    const text = [
        "#EXTM3U",
        "#EXT-X-STREAM-INF:BANDWIDTH=1280000",
        "chunklist_720p.m3u8"
    ].join("\n");

    const result = parseM3U(text);
    assert.strictEqual(result.kind, "hls");
    assert.strictEqual(result.entries.length, 0);
}

// Live-stream variant marker (#EXT-X-TARGETDURATION) also counts as HLS
{
    const text = ["#EXTM3U", "#EXT-X-TARGETDURATION:6", "segment1.ts"].join("\n");
    assert.strictEqual(parseM3U(text).kind, "hls");
}

// Empty / garbage input
assert.strictEqual(parseM3U("").kind, "empty");
assert.strictEqual(parseM3U("#EXTM3U\n").kind, "empty");
assert.strictEqual(parseM3U(null).kind, "empty");

// Helpers
assert.strictEqual(formatDuration(65), "1:05");
assert.strictEqual(baseName("https://x.com/path/My%20Song.mp3?x=1"), "My Song.mp3");

console.log("playlistparser: all assertions passed");
