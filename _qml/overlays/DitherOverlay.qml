import QtQuick
import ".."

/// Reusable Bayer-dithered backdrop for overlay windows.
///
/// Draws an 8x8 Bayer-ordered dither pattern that tiles to fill the parent.
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

    // ── Standard 8x8 Bayer matrix (flat, normalized to [0,1)) ────────

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

    // ── Off-screen canvas generates the 8x8 tile ─────────────────────

    Canvas {
        id: ditherCanvas
        width: 8
        height: 8
        visible: false

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 8, 8);

            const c = root.baseColor.toString();
            const thresh = root._threshold;
            const M = root._bayer;

            for (let y = 0; y < 8; y++) {
                for (let x = 0; x < 8; x++) {
                    if (M[y * 8 + x] / 64.0 >= thresh) {
                        ctx.fillStyle = c;
                        ctx.fillRect(x, y, 1, 1);
                    }
                }
            }
        }

        onPainted: ditherImage.source = ditherCanvas.toDataURL()
    }

    // ── Tiled image fills the overlay area ────────────────────────────

    Image {
        id: ditherImage
        anchors.fill: parent
        fillMode: Image.Tile
        smooth: false
    }

    // ── Debounced repaint avoids recursion during init ────────────────

    Timer {
        id: repaintTimer
        interval: 0
        repeat: false
        onTriggered: ditherCanvas.requestPaint()
    }

    onBaseColorChanged: repaintTimer.restart()
    onDensityChanged: repaintTimer.restart()
    Component.onCompleted: repaintTimer.restart()
}
