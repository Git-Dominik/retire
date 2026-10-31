---
name: doors-asset-guide
description: Build props, furniture, fixtures and set pieces in the Roblox "Doors" art style in Blender (via MCP) with a Studio hand-off: new in-style originals, or faithful replicas of a supplied target reference. Use for any Doors-style 3D asset request, especially when reference screenshots are supplied.
---

# Doors Asset Guide v24 (v23 + design methods from a reference hotel set; supersedes v20-v23)

**For:** Claude in Blender via MCP. **Scope:** any object type; method + part grammar, no object recipes. Two reference modes: STYLE (default, new original) or TARGET (replicate; 3.3). `examples/` and `LEARNINGS.md` unchanged from v20; the toolkit needs the v22 helpers (Sec 14).
**From v21:** reference table (0), instance-aware budgets (9.1), looser ornament/color rules (3, 5), part types array, panel, drapery, upholstery, cornice, sheet, glass, mechanism (11), optional texture tier (5.2).
**From v24:** design methods and their reasons (Sec 10); value-region mesh split and saturation by area (5); `Sand` for cloth (5); overlay pattern tier (5.3); two-layer lights (8); measured furniture sizes (7); helper and collision parts (9.2).
**From v22:** target mode with measure-and-overlay (3.3), swan-neck curves (4.3), four-question chamfer test and sharp connectors (4.5), hollow light shells (11), `reference_mode` / `curve_plan` / `hollow` spec fields.
**Confidence:** style traits come from in-game screenshots. Sizes, Material choices, value and saturation ranges and light settings in Sec 7, 8 and 10 were measured from a reference set in Studio; budgets are still estimates. Verified/unverified facts: `LEARNINGS.md`.
**Setting:** `TEXTURE_MODE = off` (default: flat color + built-in Material). `overlay` (5.3) adds faint tiled pattern textures in Studio; `on` (5.2) adds full color maps. Switch only if the user says so. Per reference: `reference_mode = style` unless the user says replicate/match (3.3).

---

## 0. Process (in order)

Read only this guide and files it names. Build from scratch; no marketplace models.
1. **Receipt.** Start the FIRST reply with `Guide v24 read`. If you cannot state "v24", you are reading an old copy: stop and say so.
2. **Classify references** (if supplied). Mark each image `style` or `target` (3.3); if unclear, ask. Then one table row per image: `object | unique parts | repeats (count x unit) | color regions | surface source (Material / pattern / texture / geometry) | recognition features | hero part | est. tris`. Say which surfaces you cannot identify. Target rows also carry the 3.3 measurements.
3. **Interpret** in one line (canonical form; ask if ambiguous). No reference or a style reference: build a NEW design. Target reference: replicate it (3.3).
4. **Spec** (Sec 12) per object, then **wait for approval** unless told to build directly.
5. **Build** part by part with the toolkit and Sec 11. Report real `tk.stats()`.
6. **Review** in the Sec 8 rig (never gray Solid). Orbit 4 sides + above, zoom every joint, compare with reference crops at the same scale and check density matches (same kinds of repeats and small accents, +/-30%). Target: run the 3.3 overlay loop until it matches.
7. **Audit:** `tk.audit_mesh`, `audit_connections`, `audit_clipping`, `audit_style`, then Sec 13 honestly; list failures.
8. **Hand off** (9.6).

**Precedence (high to low):** 1) hard constraints (Roblox Materials only unless `TEXTURE_MODE` is `overlay` (5.3) or `on` (5.2); crisp default, <=1 soft part; curves from facets; light housings hollow; tech limits; true scale; no gore) 2) a TARGET reference (if it has no collar, boss or switch, add none; it outranks the detail plan and every default below) 3) recognition + joinery 4) reference density 5) simplicity (large faces plain) 6) controlled wonk 7) palette/polish. If a request conflicts with a hard constraint, follow the constraint and state the deviation.

---

## 1. Style DNA

1. **Crisp chamfered low-poly.** Flat facets, real corners, at most one 45-degree chamfer strip. Smoothness is made from sharp blocks; curves are chains of chunky straight segments with visible joints.
2. **Octagon for round bodies, hexagon for bars** (arms, hooks, handles, rings, rods). No other counts.
3. **Material gives surface, geometry gives silhouette** (patterns only via 5.2 or the faint 5.3 overlay).
4. **Warm light vs dark void.** Small bright warm emitters; the rest in shadow. Horror from contrast, not gore.
5. **Readable interactables:** one saturated accent against a muted scene.
6. **Chunky toy proportions.** Handles, knobs, legs, feet thicker than real life.
7. **Machined = exact; hand-made = slightly wonky** (wax, cloth, paper, books, drapery, rough wood).
8. **Mundane props in wrong places.**

Style mode, vary freely: object, silhouette, composition, color combos inside biome ranges, counts, layout, wonk seed. Keep: shape language, budgets, naming, hand-off. Pass the "same world, different object" test. Target mode: vary only color, seed and tiny proportions.

---

## 2. Design procedure

Name + canonical form + biome -> 2-4 recognition features (gray silhouette test) -> size by analogy (Sec 7) -> parts typed from Sec 11 (list repeats as arrays) -> joints + detail plan (11.1-11.2) -> tier per part (4.2) -> split by Material -> Material + flat color per region -> budget -> vary -> build.

---

## 3. Detail calibration

**Simple, never featureless.** Remove micro-detail; keep structural and chunky repeated detail.
- **Banned:** engraving, stitching, filigree, medallions, tassels, ribbons, tall thin finials, individually modeled realistic leaves.
- **Allowed:** studs, buttons, trim strips, inset panels, tiebacks, ticks, keys, book bands, clips, handles. Condition: chunky (>= ~4% of object size), low-relief or flat-faced, purposeful or repeated.
- **Unique parts:** small 5-12, medium 8-20, hero 15-35. **Repeats** are declared as arrays and do not count toward this cap.
- **Large faces, backs, undersides stay plain.**
- **Recognition features (2-4):** ask what it DOES, what a child would draw first, what survives in gray. Test: nameable without its label; not a pile of tiny parts.

| Failure | Fix |
|---|---|
| Over-detailed (micro-detail, terraced profiles) | Delete micro-detail, merge parts |
| Under-built (blob + bar, no collars, no operating detail, no repeats the object needs) | Run 11.2; add arrays |
| Badly joined (floating, crossing, short) | 11.1 |
| Featureless | Restore recognition features |
| Softened (round corners, smooth tubes) | Facets (4.3) |
| Wonk mix-up | Machined exact, hand-made wonky |
| Pipe-elbow arm (single 90-degree kink) | Swan-neck chain (4.3) |
| Closed or solid shade/hood/bowl; bulb outside its shade | Hollow two-wall shell, light inside (Sec 11) |
| Target simplified (elbow for a curve, plain block for a detailed part) | Rebuild the hard shape (3.3) |

**Checkable geometry:** chamfer = 1 flat 45-degree segment, ~12% of smallest dimension, clamped 0.03-0.08 studs; base <= 2 levels; solid objects stay solid (shallow trays/wells OK) EXCEPT shells that house something (shades, hoods, cups, bowls, lamp heads, cloches), which are hollow (Sec 11); overhang <= 5% (cornice <= 8%); plan corners real; every facet turn >= 30 degrees (45/90 ideal); <= 6 segments per half circle; <= 8 sides. A straight gable (two planes) may be any angle; it is not a curve.

### 3.3 Reference modes (mark each image in the spec)
**STYLE (default).** Take detail level, shape language, value/color logic and finish; never layout, counts, text, colors, accent placement or a feature combination. If the result could be mistaken for the reference, vary it.
**TARGET.** Triggered by "replicate", "recreate", "match", "like this", "supposed to be", or naming the image as the shape to build. The shape IS the requirement: reproduce silhouette and construction faithfully; do not simplify.
1. **Analyse first:** (a) parts and proportions, (b) every curve's segment count and joint angles, (c) which edges are sharp or chamfered, (d) joints and connectors, (e) what the target does NOT have (no boss, switch or extra ring: add none).
2. **Measure, do not eyeball:** take the largest part (plate, body) as the ruler; read every other size as a ratio of it; measure each segment's angle and relative length; count facets; convert to studs with the ruler's Sec 7 size.
3. **Build to the analysis, then compare:** Blender viewport screenshot at the target's angle (orthographic side view for a side target). Check every segment angle within ~10 degrees, every length/size within ~15%, and the silhouette (arm rise, bend positions, head size vs plate). Fix and re-compare until it matches; one pass is not enough.
4. Never replace a curved member with an elbow, a sweeping arm with a straight bar, or a detailed part with a plain block because the real shape is hard: building the hard shape is the job.
5. Never copy label text or logos. If the target is another game's proprietary asset, remind the user once that near-copies are for study and reference, not for shipping.

---

## 4. Shape language

**4.1 Silhouette.** Chunky, slightly oversized, readable at 20 studs. Mirror machined pairs/sets.

**4.2 Tiers.**
| Tier | Parts | Rules |
|---|---|---|
| CRISP (default) | plates, frames, posts, legs, bodies, arms, trays, doors, shelves, hardware, round-looking functional parts | Flat-shaded, hard corners, 8-sided max, sharp or 1 chamfer, no bevel/subsurf/smooth/weighted normals |
| HAND-MADE | wax, cloth, drapery, books, paper, sacks, rope, rough wood | Faceted, flat-shaded, controlled wonk (4.4) |
| ORGANIC | foliage, soil, rubble, rock | Irregular flat facets (4.7) |
| SOFT (<=1, 2 with reason) | the one focal dome/bulb whose smooth curve IS its recognition feature | 4-5 even rings, clean revolution, no wonk; neighbors crisp |

Attention test: soft only if the curve is the recognition feature AND the eye goes there first. When unsure, use a faceted curve.

**4.3 Curves from facets (swan-neck, not pipe-elbow).** Joints 30-45 degrees (never < 30); a 90-degree bend takes >= 3 joints; half circle <= 6 segments; ring 8. A long straight run is ONE segment. A curved arm that leaves a plate, rises, hooks over and drops takes 5-10 segments: short straight stub out of its collar, long confident sweep, several 30-45 degree joints for the hook, short finishing run. Vary segment lengths (equal tiny segments look soft; a few huge ones look blocky). Mitred planar joints, hex section (`tk.turtle` + `tk.tube(..., sides=6)`), thickness ~0.1-0.25 of length. Rigid right-angle frames (furniture, racks) may use 90-degree joints; curved members may not. Plates stay plates. Arches (alcoves, pediment tops, chair backs) are 3-6 facets with a thick frame. Record each curve in `curve_plan`. Worked example: `gen_wall_light_hood`.

**4.4 Wonk (hand-made only).** Lean 2-4 degrees; uneven taper 10-20%; uneven top; vertex jitter <= 5% of radius; at most one local feature; seated flat; flat-shaded; vary seed per instance. `tk.wonky(m, tags, lean, taper, jitter, top_tilt, seed)`; add tag to `organic_tags` in `audit_mesh`.

**4.5 Edges and sections (decide per part; state `edge:` in spec).** SHARP is the default; a chamfer (ONE flat 45-degree strip, ~12% of smallest dimension, 0.03-0.08 studs) must be earned. **Chamfer test: ALL FOUR yes, else SHARP.** (1) Mass or plate, not a connector or small fitting (collars, bosses, sockets, ferrules, clamps, brackets, hinges, hubs, bolts, knobs < 0.3, switches, handles, stems, rings are NOT masses). (2) Thick: smallest dimension >= 0.3 (plate or shelf >= 0.25). (3) Edge is outside and visible: not at a seam, not where another part enters, leaves or sits, not on a back, bottom or hidden side. (4) Wide enough that the cut reads at normal distance.

| Part role | Edges |
|---|---|
| Connector (collar, boss, socket, ferrule, clamp, hub, bracket, hinge, bolt head: anything a bar/arm/stem enters or leaves) | SHARP plain prism (8-sided lathe or box), FLAT top and bottom; no chamfer ring, step ring or rounded top |
| Thin stock (plank, board, rail, slat, flat bar, panel, trim, rim, brim, flange; < 0.25-0.3 thick) | SHARP |
| Cap on a post | flat underside; chamfer TOP edge only |
| Post, leg, beam (chunky) | vertical edges chamfered, ends FLAT where a cap/joint sits (`tk.slab` + `tk.cut_rect`) |
| Box body, crate, chest, counter, seat, cushion | chamfer exposed edges |
| Shelf top, tabletop, thick slab (>= 0.3) | chamfer exposed outer edges |
| Backplate / wall plate (>= 0.25) | chamfer FRONT edge only; sharp if thinner |
| Round body (lathe) | 45/90-degree profile turns; no extra chamfer rings |
| Hand-made, organic (books, drapery, paper, foliage) | no chamfers (4.4 / 4.7) |
| Array units (keys, studs, ticks) | SHARP (small fittings) |
| Panel inset (Sec 11) | the 45-degree bevel is structural, not an edge chamfer |

**Seams first:** where parts meet face to face (cap on post, lid on body, arm into collar, part against wall) both edges are SHARP and flat so they seat; a chamfered or stepped top under an arm leaves a groove. Repeated thin pieces stay sharp however large the group. `tk.edge_style(dims, role)` and `tk.auto_box` encode the thin-stock rule.
- **Sections:** round body = octagon; bar/arm/handle/ring = hexagon; blocky furniture post = box.
- **Thin-stock exception:** mullions, pendulum/platen rods and similar sticks < ~0.15 studs may be flat rectangular strips or small hex rods, sharp-edged, still buried at joints.

**4.6 Shading.** Flat everywhere; smooth only a declared soft tag (`to_blender(..., smooth_tags=...)`).

**4.7 Organic masses.** Tapered, widest at 30-45% height, ragged mixed-size facets, 30-50 folded blades, chunky leaning stems; no flowers/fruit unless asked; < 600 tris per potted object; contents always visible.

**4.8 Architecture and furniture trim.** Wainscot, crown, baseboards, door frames, beams, and furniture cornices/pediments are 2-3 step profiles. Archways are faceted chains with chunky corner blocks.

---

## 5. Materials and color

Only built-in `Enum.Material` (set in Studio) + flat vertex color (baked in FBX, attribute `Col`). One Material per mesh. Forbidden when `TEXTURE_MODE=off`: custom textures, `SurfaceAppearance`, `MaterialVariant`, decals, gradient/painted vertex colors. Emissive = `Neon` + light. Signage/text added in Studio.

| Part | Material | Notes |
|---|---|---|
| Metal | `Metal` (`DiamondPlate` Mines) | muted bronze/steel |
| Wood | `Wood` / `WoodPlanks` | warm browns; see grain below |
| Cloth, upholstery, drapery, bedding | `Sand` | soft matte grain (10.7) |
| Rugs, carpet | `Fabric` | knit reads as carpet |
| Books | `Sand` / `Concrete` | covers; page blocks lighter cream |
| Paper, canvas | `Sand` / `Concrete` | cream |
| Plastic/dials/keys | `Plastic` / `SmoothPlastic` | matte |
| Wax/clay | `SmoothPlastic` / `Plastic` | cream/ochre |
| Soil / foliage | `Ground` / `LeafyGrass` | dark grey-brown / olive |
| Stone/walls | `Slate`, `Concrete`, `Brick`, `Plaster`, ... | per biome |
| Glass | `Glass` | Transparency set in Studio (~0.5-0.7), flat tint |
| Emissive | `Neon` | small, bright |

**Color discipline.** Muted, earthy; saturation by area (10.4): large masses ~15-25%, walls/upholstery ~30-40%, small repeats up to ~50% (judge under warm light; pick slightly less orange than wanted). Furniture wood stays dark (value ~25-45%) so lights and pale hardware pop. 2-3 value steps per part group, split as meshes by value region (10.1): frame/plinth darkest, body mid, recessed back or inner panel lightest. Accent hardware by value (pale, near-neutral), not by a new hue (10.5). Unique features: <= 4 colors and <= 1 accent. **Repeats** (books, keys, studs, pleats) may draw from a declared palette of <= 6 colors, assigned per instance. No pure black/white (`#1A1A1A`-`#F0E8D8`). Wear = value differences only. **One mesh per color region**, color set as `Part.Color` by the apply script (10.2); that is how the reference set is built. Vertex color is only a fallback.

**Grain direction.** Model long members as separate pieces along their long axis (posts vertical, shelves horizontal, rails along length, arch facets along each facet). Check grain in Studio; swap Material if it reads wrong. With textures on, use 5.2 UV rules.

Starter palette (+/-10%): terracotta `#A8503C`, brick `#8E4636`, olive `#6B6A38`, dusty plum `#7A5A78`, ochre `#C8803C`, cream `#E3B88A`, warm tan metal `#9A7B5A`, dark base `#3A2D28`. Glows: cyan `#8FE4FF`, green `#5CFF6E`, warm `#FFD58A`.

### 5.2 Texture tier (only if `TEXTURE_MODE=on`; unverified in Studio)
- Patterns the references use: harlequin diamonds (wallpaper, upholstery), stripes (curtains, book bands), directional wood grain, fabric/paper speckle.
- Generate tileable `ColorMap` PNGs procedurally (Python/numpy), <= 512 px, one small atlas per object, consistent texel density, muted values, no baked lighting or gradients beyond the pattern.
- UVs: U runs along the part's long axis; no stretched or mirrored seams on visible faces.
- Use `SurfaceAppearance.ColorMap` only; keep the vertex color as a tint; list every texture in the spec. Images must be uploaded to Roblox; write asset-ID placeholders in the manifest.
- Geometry still carries silhouette: do not replace structural detail (keys, studs, panels) with texture.

### 5.3 Overlay tier (only if `TEXTURE_MODE=overlay`)
The reference set's method (10.6): flat base color plus a faint tiled `Texture` instance added in Studio, no UV work.
- Use it for wallpaper, upholstery, rugs and tufting only; hard surfaces stay plain.
- `Texture.Transparency` 0.85-0.97, `Color3` near the base hue (lighter or darker by one value step); tile size scaled to the face (wall ~3 x 2 studs, cushion ~0.6-1.5).
- One motif per biome, shared by wall and upholstery (harlequin Manor, chevron or stripe for floors).
- The apply script adds the Texture to the named faces; list the texture asset IDs (placeholders until uploaded) in the manifest.

---

## 6. Biomes

**Manor** (candle-lit, uncanny): plum/green harlequin wallpaper `#6A3A5C` (pattern `#7E4A6E`); dark wainscot `#4A3024`-`#6B4533`; floor `#5A3524`; upholstery warm `#A67658` / cool `#7C6C9C`; frame orange `#E8873C`; wax `#F5D9A8`; glow `#FFD58A`. Cues: curved sofa backs, rolled arms, stud rows, bun/block feet, arched niches, raised-panel wardrobes, stepped pediments, glass-case clocks, drapery with tiebacks, leaning book rows, small mechanisms (typewriter, bells). Wood grain pronounced (vertical on frames, horizontal on paneling). Windows: night rain, a few specks.
**Mines** (damp industrial): `DiamondPlate`, rough planks, rock; thick rails, chunky bolts, octagonal gears; accents hazard yellow `#E8A21E`, red `#E85A66`, cyan glow.
**Office** (sterile retro-tech): painted concrete, slate-blue wainscot `#7F8CAB`, carpet, beige plastic `#C9BFA8`, grey metal; chunky CRTs, boxy cabinets, thick radiator fins; green terminal glow `#5CFF6E`.

Motifs: octagons on round things, harlequin (Manor), hazard stripes (Mines), invented in-universe marks (never copy logos).

---

## 7. Proportions (studs; ~0.28 m)

Measured from a reference set (overall bounds, W x H x D). Doors furniture runs larger and chunkier than real scale: sofa 8.5 x 5 x 4, armchair 4.9 x 5 x 4, ottoman 2.9 x 2.1 x 2.9, wardrobe 6.4 x 9.5 x 3.1, bookcase 6.1 x 10.6 x 2.9 (wall unit 10 x 13 x 3), dresser 3.1 x 3.3 x 2.7, side table 7.9 x 4.3 x 2.5, single bed 7.3 x ~3 x 10.7, double bed 11 x 5.8 x 11.7, grandfather clock 2.7 x 10 x 2, wall clock 3.1 x 3.1 x 0.4, typewriter 2.7 x 1.1 x 2.1, wooden chair 2.4 x 4.4 x 2.1, stool 1.9 x 2 x 1.9, crate 2.75 cube, floor lamp 4.1 x 8.6 x 4.1, wall sconce 2.1 x 1.1 x 1.2, chandelier body 3.8 wide, paintings 4 x 4 to 9.4 x 6, rug ~18 x 21, book ~1.1 tall in a 10.6 case (1.5 in the wall unit). Use these over the older estimates below where they conflict.

Older estimates:

| Object | W x H x D | | Object | W x H x D |
|---|---|---|---|---|
| Door | 4.5 x 8 x 0.5 | | Wardrobe (double) | ~4 x 7 x 2 |
| Crate | 3 x 3 x 3 | | Grandfather clock | ~1.8 x 7 x 1.2 |
| Toolbox | 4 x 1.8 x 1.8 | | Typewriter | ~2.2 x 1 x 1.6 |
| Barrel | 2.3 x 3.2 x 2.3 | | Curtain panel | ~1.5 x 5 x 0.5 |
| Sofa / armchair (feet ~0.4) | 7 x 3.5 x 3 / 3.5 x 3.5 x 3 | | Window (with sill) | ~5 x 4 x 0.6 |
| Bar stool / chair | 1.5 x 2.8 x 1.5 / 2 x 3 x 2 | | Bookshelf | 6 x 7 x 1.5 |
| Radiator | 3.5 x 2 x 0.5 | | Book flat / standing | 1.2 x 0.4 x 1.7 / 0.4 x 1.7 x 1.2 |
| Wall light | 1.1-2.3 x 1.6-2.7 x 1-1.7 | | Wall clock | 3 x 0.4 x 3 |
| Table lamp | 1.9 x 2 x 1.9 | | Planter / topiary | 2.2 x 2 x 2.2 / 2.5 x 6 x 2.5 |

Handles/knobs ~1.5x real thickness. Books thicker than real; vary 10-15%. Keep true relative scale.

---

## 8. Lighting and review

Props must survive Future lighting, dark shadows, low ambient. Warm 2200-3000K (Manor/Mines), cool-neutral (Office). Bulbs: two layers (10.12). Layer 1 is a `Neon` shade (cream-tan, Transparency ~0.1) or a `Glass` shade, with a small `PointLight` for the local glow (Range 1-9, Brightness 0.3-0.5; inside a Glass shade Range ~1.5, Brightness up to 6). Layer 2 is a downward `SpotLight` with Shadows on for the pool (Range 40-55, Brightness 0.3-2). Light color is warm orange (~`#EBA762`-`#FFB694`), more saturated than the shade. A fire uses one shadowed PointLight (Range ~10, Brightness ~3). Neon blooms to near-white in game; judge emitters with Bloom on. Only light sources and interactables glow.
**Review rig (required):** `tk.setup_review_rig(target)`: dark warm world `#2A211C`, one warm point light, camera ~3x widest object away, Material Preview. Compare against reference crops (value steps, Material, silhouette, **density**). Close-ups of every corner, arm joint and repeat row.
Interactables: `ProximityPrompt` key E, hover highlight, visible latch/handle, small attachment dot.

---

## 9. Technical

### 9.1 Triangle budgets
| Class | Target | Hard max |
|---|---|---|
| Small prop | 150-500 | 800 |
| **Dense small prop** (many repeats: typewriter, clock, book row) | 600-1,800 | 2,500 |
| Medium (stool, chair, crate, wardrobe) | 400-1,200 | 2,000 |
| Large (sofa, generator) | 1,000-3,000 | 4,500 |
| Hero set-piece | 2,000-5,000 | 7,000 |
| Architecture kit piece | 50-800 | 1,500 |

Dense class and repeat limits are **provisional**; confirm against real mesh stats. **Repeat unit:** <= 48 tris (<= 24 when > 20 copies). Use shared MeshId instances. No interior faces or n-gons; triangulate; merge by distance. Roblox limit 20,000 tris per mesh.

### 9.2-9.5 Pivot, collision, naming
Pivot: bottom-center (floor), back-center (wall), hinge edge (door). Front = -Z in Roblox (usually -Y in Blender; verify). 1 unit = 1 stud, transforms applied, no Studio resizing. Collision `Box`/`Hull`; `PreciseConvexDecomposition` only for touched hero props; dressing `CanCollide=false`; statics `Anchored=true`. As in the reference set (10.15), large furniture gets invisible, anchored helper parts: `COL_` boxes for simple collision (visual meshes then `CanCollide=false`), a `COL_TopWedge` on tall pieces so players can't stand on them, and `ItemSpawn` / `LootHolder` surface parts where loot sits. Names `<Group>_<Part>` PascalCase; proxies `COL_...`; attributes `Biome`, `Interactable`, `Hideable`/`Lootable`, `LightSource`.

### 9.6 Hand-off (required)
Export each group with `tk.export_fbx(path, group)` (face smoothing, flat vertex colors `Col`, 1 unit = 1 stud; try `colors_type="LINEAR"` if colors look off). Finalize names, then `tk.write_handoff(folder, group, parts)` writes `<group>_apply_materials.luau` + `<group>_manifest.md`. Tell the user: import, run the script (sets Materials, `Color` white), check size/names/colors/corners under Doors lighting, swap neighboring Material if stretched/shiny/busy. State what you could not verify. Final message: meshes, Materials, hex colors, tris, file locations.

---

## 10. Design methods (why the set reads as one world)

Studied from a full Doors-style hotel set (70 furniture types across 163 rooms). These are the methods behind it, not models to copy: apply the reasoning to new objects. Each line gives the method and why it works.

1. **Few meshes, split by value region.** An object is 3-14 meshes, one per color/Material region. The usual split is outer frame/plinth/crown darkest, carcass mid, recessed back or inner panel lightest. *Why:* each mesh is one flat `Color`, so the value steps do the job of ambient occlusion under dark lighting. Recesses read deep without baked shading, and recoloring is one property per region. Split along value boundaries, not along construction.
2. **Color per part, not per vertex.** The reference meshes carry `Part.Color` with the Material texture on top; no vertex paint. *Why:* it keeps colors editable in Studio and lets one mesh be reused in another color. Default to one mesh per color region (Sec 5); vertex color is only a fallback.
3. **Neutral furniture, colored rooms.** Wood furniture stays one low-saturation brown family in every room, while wallpaper hue changes per room (rose, slate blue, green, teal, tan) at the *same value* (~40-45%). *Why:* one furniture set fits every room; rooms get identity from hue, and the steady value keeps the light and dark rhythm. Design props to sit on any wall color: avoid hues that only work on one.
4. **Saturation by area.** Big surfaces (wood carcasses, floors) ~15-25% saturation; walls and upholstery ~30-40%; small repeats (book spines) up to ~50%. Only artwork and light color go higher. *Why:* warm light adds saturation to everything it hits. Low-saturation masses stay brown instead of turning orange, so small saturated things still read as accents.
5. **Accent by value, not hue.** Hardware (knobs, pulls, handles) is pale, near-neutral metal (~75% value, <10% saturation) on dark wood. Paper and candles are cream. *Why:* in low light, value contrast reads first. A pale knob shows where to interact without adding a new hue.
6. **Pattern as a whisper.** Harlequin wallpaper, upholstery diamonds, rug chevrons and button tufting are tiled overlay textures at Transparency 0.85-0.97 over the flat base color. Tile size follows the object (wall ~3 x 2 studs, cushion ~0.6 x 1). The same motif is reused on wall and upholstery. *Why:* patterns give richness without geometry and stay a hint at distance, not noise. Reusing one motif ties furniture to architecture. See the overlay tier, 5.3.
7. **Material by feel, not by name.** Cloth, blankets, cushions, books and paper use `Sand` (soft matte grain), and some book covers and canvases use `Concrete`. `Fabric` is kept for rugs and carpet, and `Wood` is nearly everything else. *Why:* the Material is chosen for how it reads in dim light: `Fabric`'s knit reads as carpet, while `Sand` reads as soft cloth or card.
8. **One house motif, repeated.** The 45-degree clipped corner recurs everywhere: hearth slabs in plan, sconce backplates, headboards, picture frames, arched tops. Arches are 4-6 straight facets (bookcase tops, sofa backs, cart frames, headboards). *Why:* a shared, cheap shape makes different objects feel like one maker's work. Pick one motif per biome and use it on every new piece.
9. **Big plain masses, detail in repeats and edges.** Carcasses, beds and tables are plain chunky blocks; detail sits in repeat arrays (books with two light spine bands, hex key caps, 12 chunky dial ticks, fender bars, button studs) and in raised or recessed panels. *Why:* it reads well at 20 studs and stays cheap. The eye takes the repeat rhythm as "detailed" without micro-geometry.
10. **A shared kit of sub-parts.** The same drawer front, knob, dial-hand and book meshes recur across different furniture, and single and double beds share meshes, scaled. *Why:* consistency and less authoring. When a design needs a drawer, knob, book or dial, build it once as a kit part (`<Biome>Kit_<Part>`) and reuse it, rather than re-modelling.
11. **Emitters open toward their light.** Tulip shades on arms open upward. Tall shades are open frustums with the light inside, and every shade is faceted (octagon or square frustum). *Why:* an open shade shows its lit inner wall, which reads as "lamp" and fits the hollow-shell rule (Sec 11). The glow comes from the light's own direction, not a sealed blob.
12. **Light is two layers.** Each fixture pairs a tiny low point light for the local glow with a shadowed spot light for the pool on the floor (Sec 8). *Why:* the room stays mostly dark, with distinct pools of light and real shadows; one big point light would flood it.
13. **Furniture at the walls, center open.** Pieces line the walls; sconces sit at regular spacing above wainscot height and paintings between them. *Why:* clear paths for chases and hiding spots, with light rhythm along the walls. Design props with a plain back that sits flush against a wall.
14. **Age without gore.** Single transparent cobweb planes in corners, a leaning book, a crooked frame. *Why:* cheap storytelling that fits "mundane props in wrong places" (1.8).
15. **Gameplay parts live in the model.** Invisible, anchored helper parts are named for their job: item spawn surfaces, simplified collision boxes, a wedge on top so players can't stand on tall furniture. *Why:* visual meshes can skip precise collision, and spawn logic finds surfaces by name. See 9.2.

**Room shell (when building architecture):** wallpaper upper wall; plank wainscot about one-third of the wall height, with a chunky top rail and a baseboard; beam crown; plank or coffered ceiling. All trim is the same mid wood value as the furniture carcasses.

---

## 11. Part grammar

| Type | What | Tier | Build | Key rules |
|---|---|---|---|---|
| Plate/slab | panels, lids, backs | CRISP | `tk.slab` | 0.2-0.35 thick, hard corners |
| Block/body | cabinets, chests, seats | CRISP | `tk.auto_box` | Edge rule 4.5; 3-4 masses |
| Round body | stems, bases, drums, wheels | CRISP | `tk.lathe(sides=8)` | 45/90-degree profile turns; base <= 2 levels |
| Bar/arm/post | supports, handles | CRISP | `tk.tube(sides=6)` | hex section; thin-stock exception 4.5 |
| Curved member | rings, hooks, arches | CRISP | `tk.turtle`/`arc` + `tube` | 4.3 |
| Shell/bowl/cup/shade/hood | lamp heads, cups, hoods, any vessel housing something | CRISP | `tk.lathe` on a CLOSED loop profile (outer wall, rim, inner wall, rim) with `cap_bottom=False, cap_top=False` | **Thin HOLLOW two-wall shell:** inner wall offset 0.05-0.08, open on the working side, visible bowl inside. Never solid, never a flat disc closing the open side (`cap_bottom=True` does this: do not use it). Bulb/candle/contents sit INSIDE the cavity (top above the rim plane), hung from an inner stem or resting on the inner bottom. 8-sided, walls >= 45 degrees, thin flat rim |
| Dome | the one smooth focal part (cover, hood, cloche) | SOFT | `tk.hollow_dome` (hollow) or `tk.dome_profile` (solid) + `tk.lathe` + `smooth_tags` | 4-5 even rings; a dome that covers or houses something is HOLLOW (plug the small apex hole with a plain lathe disc); declare reason; if unsure use a faceted shell |
| Stepped base/foot | what it stands on | CRISP | `lathe`/`chamfer_box` | <= 2 levels, short, wide, darker |
| Hand-made | wax, cloth, rope, paper | HAND-MADE | `lathe`/`prism` + `wonky` | 4.4 |
| Organic | foliage, rock | ORGANIC | custom | 4.7 |
| Emitter | bulbs, flames, screens | CRISP | faceted + `Neon` | small, one accent, light added |
| Mark | dial ticks, hands, bands | CRISP | `prism`/`chamfer_box` | flat/low-relief, chunky, separate color |
| Contents | fill of containers | any | per content | visible, just below rim |
| Wrap/strip | tape, straps, bands, stripes | CRISP | `tk.wrap_band` | follows host + its chamfer, offset 1-3%, starts/ends on a face; `audit_clipping` |
| Transition piece | collar, bracket, boss, socket, ferrule, cap, foot, brace | CRISP | `plain_box` / `lathe` with a plain two-point profile | **SHARP plain prism, flat top and bottom, no ring or step on top** (4.5); chunky, slightly wider than what it holds; ONE per joint; flush, no gaps or clipping; never decorative |
| Attachment | handle, latch, knob | CRISP | `chamfer_box`/`tube` | one per function |
| **Array** | keys, books, studs, pleats, ticks, slats | per unit | Python loop over a unit builder + `tk.translate/merge`, seeded jitter | Spec: `count`, `unit_tris`, `pitch`, jitter, palette. Rows staggered by half pitch when keys/bricks; per-instance height/width +/-10-15%, lean 0-5 degrees (one deliberate leaner per shelf allowed, up to ~15), palette color per instance; seated, no overlaps, gaps >= 10% of unit width unless touching by design; shared MeshId |
| **Panel** | raised/recessed door and cabinet panels | CRISP | inset `chamfer_box` or prism frustum | Depth 3-6% of width, one 45-degree bevel (lit top, dark bottom), margin to frame >= 10% of panel width, grid (e.g. 2x3), follows host |
| **Upholstery** | chairs, sofas, cushions | CRISP | `chamfer_box`, `tube`, `slab` | **Back** = thick padded pad, never a flat plate: inset face inside a large bevel, 4-5 facet dome across the crown, leaned back 10-15 degrees, inside a thick wood frame with a small crest block. **Arms** = fat 8-sided rolls, ~19% of overall width each, flared outward at the front scroll, wood strip down the front ending in a round button (a ~11% arm reads as a block). **Seat cushions** = wide, low slabs (lower than they are wide), a lip and visible seam gaps between them. **Pillows** = two tufted throw pillows (pinched button tufts, 1-2 facets per edge), propped on the seat against back and arm. **Feet** = short, squat, angular blocks, wider than tall. **Base rail** = thick wood apron with a stepped lip above the stud row (array) |
| **Drapery** | curtains, valances | HAND-MADE | tapered strips (`prism`) | Tall strips in two alternating shades, wide at top, pinched to ~35-50% at the tieback, hem flares; strip lengths vary +/-5%; top tabs/rings = small dark blocks; tieback = chunky block in the accent color wrapping the pinch |
| **Cornice/pediment** | furniture and doorway crowns | CRISP | `slab`/`chamfer_box` steps | 2-3 stepped layers, overhang <= 8%, straight gable allowed (not a curve), flat seams to the body |
| **Sheet** | paper, cloth sheets, labels | HAND-MADE | thin `slab` | 0.04-0.08 thick (exception to thin-card ban); stacks staggered by height/offset; one gentle bend max |
| **Glass** | clock cases, windows | CRISP | thin box/prism, `Glass` Material | Separate mesh, thin sharp frame, thin-stock mullions, contents visible behind it |
| **Mechanism** | pendulum, carriage, crank, clips, weights | CRISP | `tube`, `lathe`, `prism` | Visible, chunky, one detail per function; counts as structural detail, not ornament |

**Universal rules.** Silhouette first (2-4 masses). Joints visible and clean; no floating, no poking through. Hierarchy of size (one dominant mass). Machined symmetric, hand-made asymmetric. Everything has thickness (3-8% of object size) except declared sheets. Applied parts copy their host's faces, chamfer and a 1-3% offset. One Material, one tier, one decision per part.

### 11.1 Joinery
Every bar end is buried (~half its width) in a named host or deliberately free (`tk.bar_between`). Posts carrying rails rise >= one post-width above and end in a cap (flat seam; chamfer only the cap top). T-joint: crossing bar ends buried in the side of the through bar. Corner: one runs into the other or both mitre. X-crossing: one continuous bar, two buried stubs. Hanging members join the member above and the thing they rest on. Never: bars poking through, stopping short, or overlapping coplanar. Give every touching body its own tag so audits can test each joint. Checks: `tk.audit_connections`, `tk.audit_clipping`, orbit review.

### 11.2 Detail plan
L0 masses -> L1 recognition features -> L2 structure, unless a target shows otherwise (a transition piece at EVERY joint and end, ONE operating detail per functional part, arrays the object needs) -> L3 character (wonk, value variation, one accent). Every object reaches L2. Spend detail where parts meet, then on the hero part (~40-50% of tris, >= 3 features), then ends/tops, then silhouette steps. Test: point at each joint (transition piece?), the hero (3+ features?), the plain faces (large and quiet?).

---

## 12. Spec template (output per asset, then wait for approval)

```yaml
asset_id: MSH_<Category>_<n>_<Variant>
display_name: ""
interpretation: ""
biome: Mines | Manor | Office
texture_mode: off | overlay | on
reference_table: []        # Sec 0 step 2 rows, if references given
reference_mode: none | style | target   # per reference image (3.3); a target is analysed, measured, replicated
recognition_features: []   # 2-4
parts:                     # every unique part
  - {name: "", type: <Sec 11 type>, tier: crisp|hand_made|organic|soft, hollow: yes|no, edge: sharp|chamfer, section: oct8|hex6|box4|none, host: "", tool: "", note: ""}
arrays:                    # repeats
  - {name: "", unit: "", count: 0, unit_tris: 0, pitch: "", jitter: "", palette: []}
detail_plan: {hero_part: "", transition_pieces: [], operating_detail: ""}
curve_plan: []            # each curved member: segment count + joint angles (30-45), e.g. arm: 7 segments, joints 35/35/-35/-35/-30
joints: []                 # "bar -> host, buried 0.5w" or "free"
ornament_note: ""          # what micro-detail was left out
originality_note: ""
gameplay_role: dressing | interactable | hideable | lootable | light_source | architecture
description: ""
dimensions_studs: {x: 0, y: 0, z: 0}
pivot: bottom_center | back_center | hinge_edge
geometry: {triangle_target: 0, triangle_max: 0, dense_class: false, soft_parts: [], hand_made_parts: [], curved_members: [], value_steps: 0}
materials:                 # one entry per Material mesh
  - {mesh: "", roblox_material: "", colors: ["#......"], texture: none}
emissive: {has_emissive: false, color_hex: "", light: {range: 0, brightness: 0}}
collision: {fidelity: Box|Hull|PreciseConvexDecomposition, can_collide: true, anchored: true}
interaction: {prompt: false, key: E, action_text: "", highlight_on_hover: false}
attributes: {Biome: "", Interactable: false}
```

---

## 13. Checklist (run honestly; list failures)

**Process:** `Guide v24 read`; each reference marked style/target; reference table (if any); target overlay loop done (angles ~10 degrees, sizes ~15%); spec approved; real `tk.stats()`; Sec 8 review with close-ups; hand-off written.
**Shape:** recognition features present (gray silhouette reads); joinery clean; detail plan met (hero 3+ features, joint pieces, operating detail); no micro-detail; density matches references (repeats and small accents present); octagons/hexagons correct; edges decided per part (every chamfer passed the four-question test; connectors plain, sharp, flat-topped); curves are facet chains (curved arms 5-10 segments, 30-45 degree joints, no single 90-degree elbow); every shade/hood/cup/bowl is a hollow two-wall shell, checked from below (no disc, light inside); targets not simplified, nothing added that the target lacks; applied parts follow hosts; wonk only on hand-made; arrays seated, jittered, within unit budget; all audits clean; containers show contents; scale true; same world, different object (style mode).
**Methods (Sec 10):** meshes split by value region; furniture wood low-saturation and dark; hardware accented by value; the biome's house motif used; kit parts reused where they fit; plain back for wall pieces; helper/collision parts added.
**Materials:** Roblox Materials only (or 5.2/5.3 declared); flat vertex colors; right Material per part; value steps 2-3; <= 4 colors + <= 1 accent on unique features, <= 6 palette colors on repeats; emissive only on lights/interactables.
**Technical:** tris within 9.1 class; pivot/scale/bounding box verified; collision and naming set; interactables have affordance + prompt.
Never: gore, realistic weapons, real brand logos, copied label text.

---

## 14. Toolkit (v20 toolkit + v22 helpers; Python files next to this guide)

```python
import sys; sys.path.insert(0, "<folder with toolkit and examples>")
import doors_toolkit as tk
```
`Mesh/translate/merge/stats` | `chamfer_box`, `plain_box`, `auto_box`, `edge_style`, `cut_rect` | `lathe` (8-sided; open shells with caps off) | `prism`, `slab`, `inset_poly` | `turtle`, `arc`, `tube(sides=6)` | `bar_between` | `wrap_band` | `wonky` | `audit_mesh/audit_style/audit_connections/audit_clipping` | `to_blender`, `export_fbx`, `setup_review_rig`, `luau_apply_script`, `handoff_manifest`, `write_handoff`.
**v22 helpers (add to the toolkit if missing):** `tk.hollow_dome(r, h, wall=0.06, rings=4, top_r)` returns a closed (r, z) loop for a thin dome shell; use with `tk.lathe(..., cap_bottom=False, cap_top=False)`. `tk.dome_profile(r, h, rings=4, top_r)` returns a clean even profile for the one soft part; use with `tk.lathe(..., cap_bottom=False)` and `smooth_tags`. `tk.edge_style(dims, role)` takes a role (connector / thin stock / mass).
**If absent, improvise (untested):** hollow loop = outer points `(r_i, z_i)` from rim to apex, then the same points reversed as `(r_i - wall, z_i - wall)` (clamped >= 0) with the inner rim kept on the rim plane, closed at the rim; plug the apex hole with a plain lathe disc.
**Arrays need no new helper:** loop a unit builder with `tk.translate` + `tk.merge` and a seeded RNG. If you add helpers, keep them generic and name them `tk.array_*`.
`examples/` are illustrations, not recipes. `to_blender`, `make_materials`, `setup_review_rig`, `write_handoff` are untested glue: if one errors, fix minimally and say what you changed.
