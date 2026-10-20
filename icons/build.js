// Rebuilds icons/atlas.png from the Lucide SVG set.
//
//   npm install
//   node build.js
//
// The order of the icon list below must match the Library.IconAtlas.Icons
// map in Unable.lua. Bump the atlas file name in that map after rebuilding
// so executors do not reuse a stale cached image.

const fs = require("fs");
const path = require("path");
const sharp = require("sharp");

const LucideDir = path.join(
    path.dirname(require.resolve("lucide-static/package.json")),
    "icons"
);

const OutSvgDir = path.join(__dirname, "svg");
const OutAtlas = path.join(__dirname, "atlas.png");

// logical name -> candidate file names in lucide-static
const Icons = {
    "bell": ["bell"],
    "check": ["check"],
    "chevron-down": ["chevron-down"],
    "circle": ["circle"],
    "command": ["command"],
    "copy": ["copy"],
    "download": ["download"],
    "eye": ["eye"],
    "folder": ["folder"],
    "home": ["house", "home"],
    "layers": ["layers", "layers-2"],
    "move": ["move"],
    "palette": ["palette"],
    "pencil": ["pencil"],
    "plus": ["plus"],
    "power": ["power"],
    "save": ["save"],
    "search": ["search"],
    "settings": ["settings"],
    "share-2": ["share-2", "share2"],
    "trash-2": ["trash-2", "trash2"],
    "triangle-alert": ["triangle-alert", "alert-triangle"],
    "x": ["x"],

    // menu tabs and sub tabs
    "swords": ["swords"],
    "flame": ["flame"],
    "shield-check": ["shield-check"],
    "radar": ["radar"],
    "layout-dashboard": ["layout-dashboard"],
    "shirt": ["shirt"],
    "footprints": ["footprints"],
    "globe": ["globe"],
    "map": ["map"],
    "sliders-horizontal": ["sliders-horizontal"],
    "wrench": ["wrench"]
};

const Cell = 96;
const Columns = 8;

async function main() {
    fs.mkdirSync(OutSvgDir, { recursive: true });

    const names = Object.keys(Icons);
    const tiles = [];
    const map = {};

    for (let index = 0; index < names.length; index++) {
        const name = names[index];
        let svg = null;
        let used = null;

        for (const candidate of Icons[name]) {
            const file = path.join(LucideDir, candidate + ".svg");
            if (fs.existsSync(file)) {
                svg = fs.readFileSync(file, "utf8");
                used = candidate;
                break;
            }
        }

        if (!svg) {
            console.warn("missing:", name);
            continue;
        }

        fs.writeFileSync(path.join(OutSvgDir, name + ".svg"), svg, "utf8");
        console.log(`mapped ${name} -> ${used}.svg`);

        const white = svg.replace(/currentColor/g, "#FFFFFF");
        const png = await sharp(Buffer.from(white), { density: 384 })
            .resize(Cell, Cell, {
                fit: "contain",
                background: { r: 0, g: 0, b: 0, alpha: 0 }
            })
            .png()
            .toBuffer();

        const column = index % Columns;
        const row = Math.floor(index / Columns);

        map[name] = index + 1;
        tiles.push({ input: png, left: column * Cell, top: row * Cell });
    }

    const rows = Math.ceil(names.length / Columns);

    await sharp({
        create: {
            width: Columns * Cell,
            height: rows * Cell,
            channels: 4,
            background: { r: 0, g: 0, b: 0, alpha: 0 }
        }
    })
        .composite(tiles)
        .png()
        .toFile(OutAtlas);

    console.log("\natlas:", OutAtlas, `${Columns * Cell}x${rows * Cell}`);

    const entries = Object.keys(map).map(
        (key) => `            ["${key}"] = ${map[key]},`
    );
    console.log("\nLua map:\n" + entries.join("\n"));
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
