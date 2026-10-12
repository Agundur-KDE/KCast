// Run: node package/contents/ui/tests/test_playlistparser.js
const assert = require("assert");
const { parseM3U, formatDuration, baseName, classifyMediaUrl, mediaUrlForCasting } = require("../playlistparser.js");

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

// Signed remote master/variant manifests stay a single stream. In particular,
// they must never be sent to the local-file playlist reader after a URL drop.
assert.strictEqual(classifyMediaUrl("  https://example.com/master.m3u8?token=a+b/c==&expires=123  "), "hls");
assert.strictEqual(classifyMediaUrl("https://example.com/index-v1-a1.m3u8?token=a+b#start"), "hls");
assert.strictEqual(classifyMediaUrl("https://example.com/MASTER.M3U8"), "hls");
assert.strictEqual(classifyMediaUrl("https://example.com/master.m3u"), "hls");
assert.strictEqual(classifyMediaUrl("https://example.com/watch?next=master.m3u8"), "remote");
assert.strictEqual(classifyMediaUrl("https://example.com/movie.mp4"), "remote");
assert.strictEqual(classifyMediaUrl("https://www.youtube.com/watch?v=example"), "remote");
assert.strictEqual(classifyMediaUrl("file:///home/user/Music/playlist.m3u8"), "playlist");
assert.strictEqual(classifyMediaUrl("/home/user/Music/song.mp3"), "file");
assert.strictEqual(classifyMediaUrl("blob:https://example.com/browser-object"), "blob");
assert.strictEqual(classifyMediaUrl("  "), "empty");
assert.strictEqual(classifyMediaUrl(null), "empty");

// Player parameter lists sometimes contain the real stream as encoded mu=.
// Use synthetic tokens: real copied stream credentials must not enter Git.
const stream = "https://cdn.example.com/hls/master.m3u8?token=a+b/c==&escaped=%2B";
const encodedStream = encodeURIComponent(stream);
const parameters = "https%3A%2F%2Fexample.com%2Fembed%2Fvideo&pv=8&mu=" + encodedStream + "&pd=2";
assert.strictEqual(mediaUrlForCasting(parameters), stream);
assert.strictEqual(classifyMediaUrl(parameters), "hls");
assert.strictEqual(mediaUrlForCasting("https://example.com/player?mu=" + encodedStream + "&width=1920"), stream);
assert.strictEqual(mediaUrlForCasting("mu=" + encodedStream), stream);
assert.strictEqual(mediaUrlForCasting(encodedStream), stream);
assert.strictEqual(mediaUrlForCasting(stream), stream);
assert.strictEqual(mediaUrlForCasting(stream + "&mu=" + encodedStream), stream + "&mu=" + encodedStream);
assert.strictEqual(mediaUrlForCasting("mu=https%3A%2F%2Fexample.com%2Fnot-video.html"), "mu=https%3A%2F%2Fexample.com%2Fnot-video.html");
assert.strictEqual(mediaUrlForCasting("mu=https%3A%2F%2Fexample.com%2Fmaster.m3u8%XX"), "mu=https%3A%2F%2Fexample.com%2Fmaster.m3u8%XX");
assert.strictEqual(mediaUrlForCasting("mu=javascript%3Aalert(1)"), "mu=javascript%3Aalert(1)");

console.log("playlistparser: all assertions passed");
