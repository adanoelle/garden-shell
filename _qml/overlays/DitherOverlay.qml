import QtQuick
import ".."

/// Reusable Bayer-dithered backdrop for overlay windows.
///
/// Generates an 8x8 Bayer-ordered dither tile as a PNG data URL (no Canvas,
/// which has re-entrant paint issues in Qt6). The tile is tiled via Image
/// fillMode to cover the full overlay area.
///
/// Three density presets control how much of the base color shows through:
///   "dense" — ~88% fill (default, for launcher/switcher)
///   "light" — ~50% fill
///   "lock"  — ~3% fill (nearly transparent, for lock screen)
Item {
    id: root
    anchors.fill: parent

    /// Density preset: "dense", "light", or "lock".
    property string density: "dense"

    /// Base fill color (transparent pixels show through to whatever is behind).
    property color baseColor: Theme.baseDeep

    // ── Threshold for density presets ─────────────────────────────────

    readonly property real _threshold: {
        switch (root.density) {
        case "light": return 0.50;
        case "lock":  return 0.975;
        default:      return 0.12;  // dense
        }
    }

    // ── Standard 8x8 Bayer matrix (flat) ─────────────────────────────

    // prettier-ignore
    readonly property var _bayer: [
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21
    ]

    // ── Tiled image fills the overlay area ────────────────────────────

    Image {
        id: ditherImage
        anchors.fill: parent
        fillMode: Image.Tile
        smooth: false
    }

    // ── Regenerate tile when color or density changes ─────────────────

    onBaseColorChanged: _rebuild()
    onDensityChanged: _rebuild()
    Component.onCompleted: _rebuild()

    function _rebuild() {
        ditherImage.source = _generatePngDataUrl();
    }

    // ── Pure-JS PNG generator (avoids Qt6 Canvas re-entrant paint) ────

    function _generatePngDataUrl(): string {
        const c = root.baseColor;
        const r = Math.round(c.r * 255);
        const g = Math.round(c.g * 255);
        const b = Math.round(c.b * 255);
        const thresh = root._threshold;
        const M = root._bayer;

        // Build filtered RGBA rows: 8 rows × (1 filter byte + 8×4 pixel bytes)
        const raw = [];
        for (let y = 0; y < 8; y++) {
            raw.push(0); // filter: None
            for (let x = 0; x < 8; x++) {
                if (M[y * 8 + x] / 64.0 >= thresh) {
                    raw.push(r, g, b, 255);
                } else {
                    raw.push(0, 0, 0, 0);
                }
            }
        }

        // Assemble PNG: signature + IHDR + IDAT + IEND
        const sig = [137, 80, 78, 71, 13, 10, 26, 10];
        const ihdr = _chunk("IHDR", [0,0,0,8, 0,0,0,8, 8, 6, 0, 0, 0]);
        const idat = _chunk("IDAT", _zlibStored(raw));
        const iend = _chunk("IEND", []);

        const png = sig.concat(ihdr, idat, iend);

        // Base64-encode directly from byte array (Qt.btoa corrupts bytes > 127).
        return "data:image/png;base64," + _base64(png);
    }

    // ── Base64 encoder operating on integer arrays ──────────────────────

    readonly property string _b64chars:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    function _base64(bytes: var): string {
        const lut = root._b64chars;
        let out = "";
        const len = bytes.length;
        let i = 0;
        for (; i + 2 < len; i += 3) {
            const n = (bytes[i] << 16) | (bytes[i+1] << 8) | bytes[i+2];
            out += lut[(n >> 18) & 63] + lut[(n >> 12) & 63]
                 + lut[(n >>  6) & 63] + lut[n & 63];
        }
        if (i < len) {
            const r = len - i;
            if (r === 1) {
                const n = bytes[i] << 16;
                out += lut[(n >> 18) & 63] + lut[(n >> 12) & 63] + "==";
            } else {
                const n = (bytes[i] << 16) | (bytes[i+1] << 8);
                out += lut[(n >> 18) & 63] + lut[(n >> 12) & 63]
                     + lut[(n >>  6) & 63] + "=";
            }
        }
        return out;
    }

    // ── PNG helpers ───────────────────────────────────────────────────

    function _chunk(type: string, data: var): var {
        const t = [type.charCodeAt(0), type.charCodeAt(1),
                   type.charCodeAt(2), type.charCodeAt(3)];
        const crcIn = t.concat(data);
        return _u32be(data.length).concat(t, data, _u32be(_crc32(crcIn)));
    }

    function _zlibStored(raw: var): var {
        // zlib header: CMF=0x78 (deflate, 32K window), FLG=0x01 (FCHECK=1)
        const len = raw.length;
        return [0x78, 0x01,
                0x01,                                // BFINAL=1, BTYPE=stored
                len & 0xFF, (len >> 8) & 0xFF,       // LEN  (little-endian)
                ~len & 0xFF, (~len >> 8) & 0xFF]     // NLEN (little-endian)
               .concat(raw, _u32be(_adler32(raw)));
    }

    function _u32be(v: int): var {
        return [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
    }

    function _crc32(data: var): int {
        let c = 0xFFFFFFFF;
        for (let i = 0; i < data.length; i++) {
            c ^= data[i];
            for (let j = 0; j < 8; j++) c = (c >>> 1) ^ (c & 1 ? 0xEDB88320 : 0);
        }
        return (c ^ 0xFFFFFFFF) >>> 0;
    }

    function _adler32(data: var): int {
        let a = 1, b = 0;
        for (let i = 0; i < data.length; i++) {
            a = (a + data[i]) % 65521;
            b = (b + a) % 65521;
        }
        return ((b << 16) | a) >>> 0;
    }
}
