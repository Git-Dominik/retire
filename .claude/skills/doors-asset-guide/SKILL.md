---
name: doors-asset-guide
description: Build NEW original props, furniture, fixtures and set pieces in the Roblox "Doors" art style in Blender (via MCP) with a Studio hand-off. Use for any Doors-style 3D asset request, especially when reference screenshots are supplied.
---

# Doors Asset Guide v21 (compact, supersedes v20)

**For:** Claude in Blender via MCP. **Scope:** NEW originals of any object type; method + part grammar, no object recipes. Toolkit (`doors_toolkit as tk`), `examples/` and `LEARNINGS.md` are unchanged from v20.
**v21 adds:** reference decomposition (0), instance-aware budgets (9.1), looser ornament/color rules (3, 5), new part types (11: array, panel, drapery, upholstery, cornice, sheet, glass, mechanism), optional texture tier (5.2).
**Confidence:** style traits come from in-game screenshots; sizes, colors, Materials and budgets are estimates. Verified/unverified facts: `LEARNINGS.md`.
**Setting:** `TEXTURE_MODE = off` (default: flat vertex color + built-in Material). Switch to `on` only if the user says so (5.2).

---

## 0. Process (in order)

Read only this guide and files it names. Build from scratch; no marketplace models.
1. **Receipt.** Start the FIRST reply with `Guide v21 read`.
2. **Decompose references** (if supplied). One row per image: `object | unique parts | repeats (count x unit) | color regions | surface source (Material / pattern / texture / geometry) | recognition features | hero part | est. tris`. Use rows for **detail density, shape language, finish**; never copy layout, counts, text or colors. State which surfaces you cannot identify.
3. **Interpret** in one line (canonical form; ask if ambiguous). Default is a NEW design. If the user asks for an exact recreation, say it conflicts with the originality rule and build a new in-style variant.
4. **Spec** (Sec 12) per object, then **wait for approval** unless told to build directly.
5. **Build** part by part with the toolkit and Sec 11. Report real `tk.stats()`.
6. **Review** in the Sec 8 rig (never gray Solid). Orbit 4 sides + above, zoom every joint, compare with reference crops at the same scale and check density matches (same kinds of repeats and small accents, +/-30%).
7. **Audit:** `tk.audit_mesh`, `audit_connections`, `audit_clipping`, `audit_style`, then Sec 13 honestly; list failures.
8. **Hand off** (9.6).

**Precedence (high to low):** 1) hard constraints (Roblox Materials only unless `TEXTURE_MODE=on`; crisp default, <=1 soft part; curves from facets; tech limits; true scale; no gore) 2) recognition + joinery 3) reference density 4) simplicity (large faces plain) 5) controlled wonk 6) palette/polish. If a request conflicts with a hard constraint, follow the constraint and state the deviation.

---

## 1. Style DNA

1. **Crisp chamfered low-poly.** Flat facets, real corners, at most one 45-degree chamfer strip. Smoothness is made from sharp blocks; curves are chains of chunky straight segments with visible joints.
2. **Octagon for round bodies, hexagon for bars** (arms, hooks, handles, rings, rods). No other counts.
3. **Material gives surface, geometry gives silhouette** (patterns only via 5.2).
4. **Warm light vs dark void.** Small bright warm emitters; the rest in shadow. Horror from contrast, not gore.
5. **Readable interactables:** one saturated accent against a muted scene.
6. **Chunky toy proportions.** Handles, knobs, legs, feet thicker than real life.
7. **Machined = exact; hand-made = slightly wonky** (wax, cloth, paper, books, drapery, rough wood).
8. **Mundane props in wrong places.**

Vary freely: object, silhouette, composition, color combos inside biome ranges, counts, layout, wonk seed. Keep: shape language, budgets, naming, hand-off. Pass the "same world, different object" test.

---

## 2. Design procedure

Name + canonical form + biome -> 2-4 recognition features (gray silhouette test) -> size by analogy (Sec 7) -> parts typed from Sec 11 (list repeats as arrays) -> joints + detail plan (11.1-11.2) -> tier per part (4.2) -> split by Material -> Material + flat color per region -> budget -> vary -> build.

---

## 3. Detail calibration

**Simple, never featureless.** Remove micro-detail; keep structural and chunky repeated detail.
- **Banned:** engraving, stitching, filigree, medallions, tassels, ribbons, tall thin finials, individually modeled realistic leaves.
- **Allowed (v21):** studs, buttons, trim strips, inset panels, tiebacks, ticks, keys, book bands, clips, handles. Condition: chunky (>= ~4% of object size), low-relief or flat-faced, purposeful or repeated.
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

**Checkable geometry:** chamfer = 1 flat 45-degree segment, ~12% of smallest dimension, clamped 0.03-0.08 studs; base <= 2 levels; solid not hollow (shallow trays/wells OK); overhang <= 5% (cornice <= 8%); plan corners real; every facet turn >= 30 degrees (45/90 ideal); <= 6 segments per half circle; <= 8 sides. A straight gable (two planes) may be any angle; it is not a curve.

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

**4.3 Curves from facets.** Joints >= 30 degrees; quarter circle 2-3 segments, half circle <= 6, ring 8. Mitred planar joints, hex section (`tk.tube(..., sides=6)`), thickness ~0.1-0.25 of length. Plates stay plates. Arches (alcoves, pediment tops, chair backs) are 3-6 facets with a thick frame.

**4.4 Wonk (hand-made only).** Lean 2-4 degrees; uneven taper 10-20%; uneven top; vertex jitter <= 5% of radius; at most one local feature; seated flat; flat-shaded; vary seed per instance. `tk.wonky(m, tags, lean, taper, jitter, top_tilt, seed)`; add tag to `organic_tags` in `audit_mesh`.

**4.5 Edges and sections (decide per part, state in spec).**
1. Seams sharp and flat on both parts; chamfer only exposed outer edges. Post under a cap: flat top, cap flat underside.
2. Thin stock (< ~0.25 thick: planks, rails, slats, panels, trim) stays sharp.
3. Thick exposed solids (>= ~0.3: shelves, tabletops, boxes, seats, posts, bases) get ONE chamfer.
4. Hero/touched parts may chamfer when slightly thinner, never thin stock.
5. Unsure: long+thin = sharp, short+fat = chamfer (`tk.edge_style`, `tk.auto_box`).
- **Sections:** round body = octagon; bar/arm/handle/ring = hexagon; blocky furniture post = box.
- **Thin-stock exception (v21):** mullions, pendulum/platen rods and similar sticks < ~0.15 studs may be flat rectangular strips or small hex rods, sharp-edged, still buried at joints.

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
| Cloth, upholstery, drapery | `Fabric` | flat muted |
| Paper | `SmoothPlastic` (test `Cardboard`, `Sandstone`) | cream |
| Plastic/dials/keys | `Plastic` / `SmoothPlastic` | matte |
| Wax/clay | `SmoothPlastic` / `Plastic` | cream/ochre |
| Soil / foliage | `Ground` / `LeafyGrass` | dark grey-brown / olive |
| Stone/walls | `Slate`, `Concrete`, `Brick`, `Plaster`, ... | per biome |
| Glass | `Glass` | Transparency set in Studio (~0.5-0.7), flat tint |
| Emissive | `Neon` | small, bright |

**Color discipline (v21).** Muted, earthy, ~35-55% saturation (judge under warm light; pick slightly less orange than wanted). 2-3 value steps per part group (dark base, mid body, lighter top). Unique features: <= 4 colors and <= 1 accent. **Repeats** (books, keys, studs, pleats) may draw from a declared palette of <= 6 colors, assigned per instance. No pure black/white (`#1A1A1A`-`#F0E8D8`). Wear = value differences only. **One mesh per Material** if flat per-face vertex colors import correctly in Studio (unverified; test first), else one mesh per color.

**Grain direction.** Model long members as separate pieces along their long axis (posts vertical, shelves horizontal, rails along length, arch facets along each facet). Check grain in Studio; swap Material if it reads wrong. With textures on, use 5.2 UV rules.

Starter palette (+/-10%): terracotta `#A8503C`, brick `#8E4636`, olive `#6B6A38`, dusty plum `#7A5A78`, ochre `#C8803C`, cream `#E3B88A`, warm tan metal `#9A7B5A`, dark base `#3A2D28`. Glows: cyan `#8FE4FF`, green `#5CFF6E`, warm `#FFD58A`.

### 5.2 Texture tier (only if `TEXTURE_MODE=on`; unverified in Studio)
- Patterns the references use: harlequin diamonds (wallpaper, upholstery), stripes (curtains, book bands), directional wood grain, fabric/paper speckle.
- Generate tileable `ColorMap` PNGs procedurally (Python/numpy), <= 512 px, one small atlas per object, consistent texel density, muted values, no baked lighting or gradients beyond the pattern.
- UVs: U runs along the part's long axis; no stretched or mirrored seams on visible faces.
- Use `SurfaceAppearance.ColorMap` only; keep the vertex color as a tint; list every texture in the spec. Images must be uploaded to Roblox; write asset-ID placeholders in the manifest.
- Geometry still carries silhouette: do not replace structural detail (keys, studs, panels) with texture.

---

## 6. Biomes

**Manor** (candle-lit, uncanny): plum/green harlequin wallpaper `#6A3A5C` (pattern `#7E4A6E`); dark wainscot `#4A3024`-`#6B4533`; floor `#5A3524`; upholstery warm `#A67658` / cool `#7C6C9C`; frame orange `#E8873C`; wax `#F5D9A8`; glow `#FFD58A`. Cues: curved sofa backs, rolled arms, stud rows, bun/block feet, arched niches, raised-panel wardrobes, stepped pediments, glass-case clocks, drapery with tiebacks, leaning book rows, small mechanisms (typewriter, bells). Wood grain pronounced (vertical on frames, horizontal on paneling). Windows: night rain, a few specks.
**Mines** (damp industrial): `DiamondPlate`, rough planks, rock; thick rails, chunky bolts, octagonal gears; accents hazard yellow `#E8A21E`, red `#E85A66`, cyan glow.
**Office** (sterile retro-tech): painted concrete, slate-blue wainscot `#7F8CAB`, carpet, beige plastic `#C9BFA8`, grey metal; chunky CRTs, boxy cabinets, thick radiator fins; green terminal glow `#5CFF6E`.

Motifs: octagons on round things, harlequin (Manor), hazard stripes (Mines), invented in-universe marks (never copy logos).

---

## 7. Proportions (studs; ~0.28 m; estimates, verify in Studio)

| Object | W x H x D | | Object | W x H x D |
|---|---|---|---|---|
| Door | 4.5 x 8 x 0.5 | | Wardrobe (double) | ~4 x 7 x 2 |
| Crate | 3 x 3 x 3 | | Grandfather clock | ~1.8 x 7 x 1.2 |
| Toolbox | 4 x 1.8 x 1.8 | | Typewriter | ~2.2 x 1 x 1.6 |
| Barrel | 2.3 x 3.2 x 2.3 | | Curtain panel | ~1.5 x 5 x 0.5 |
| Sofa / armchair | 7 x 3.5 x 3 / 3.5 x 3.5 x 3 | | Window (with sill) | ~5 x 4 x 0.6 |
| Bar stool / chair | 1.5 x 2.8 x 1.5 / 2 x 3 x 2 | | Bookshelf | 6 x 7 x 1.5 |
| Radiator | 3.5 x 2 x 0.5 | | Book flat / standing | 1.2 x 0.4 x 1.7 / 0.4 x 1.7 x 1.2 |
| Wall light | 1.1-2.3 x 1.6-2.7 x 1-1.7 | | Wall clock | 3 x 0.4 x 3 |
| Table lamp | 1.9 x 2 x 1.9 | | Planter / topiary | 2.2 x 2 x 2.2 / 2.5 x 6 x 2.5 |

Handles/knobs ~1.5x real thickness. Books thicker than real; vary 10-15%. Keep true relative scale.

---

## 8. Lighting and review

Props must survive Future lighting, dark shadows, low ambient. Warm 2200-3000K (Manor/Mines), cool-neutral (Office). Bulbs: `Neon` mesh + `PointLight` (Range 12-20, Brightness 1-2, shadows on hero lights only). Neon blooms to near-white in game; judge emitters with Bloom on. Only light sources and interactables glow.
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
Pivot: bottom-center (floor), back-center (wall), hinge edge (door). Front = -Z in Roblox (usually -Y in Blender; verify). 1 unit = 1 stud, transforms applied, no Studio resizing. Collision `Box`/`Hull`; `PreciseConvexDecomposition` only for touched hero props; dressing `CanCollide=false`; statics `Anchored=true`. Names `<Group>_<Part>` PascalCase; proxies `COL_...`; attributes `Biome`, `Interactable`, `Hideable`/`Lootable`, `LightSource`.

### 9.6 Hand-off (required)
Export each group with `tk.export_fbx(path, group)` (face smoothing, flat vertex colors `Col`, 1 unit = 1 stud; try `colors_type="LINEAR"` if colors look off). Finalize names, then `tk.write_handoff(folder, group, parts)` writes `<group>_apply_materials.luau` + `<group>_manifest.md`. Tell the user: import, run the script (sets Materials, `Color` white), check size/names/colors/corners under Doors lighting, swap neighboring Material if stretched/shiny/busy. State what you could not verify. Final message: meshes, Materials, hex colors, tris, file locations.

---

## 11. Part grammar

| Type | What | Tier | Build | Key rules |
|---|---|---|---|---|
| Plate/slab | panels, lids, backs | CRISP | `tk.slab` | 0.2-0.35 thick, hard corners |
| Block/body | cabinets, chests, seats | CRISP | `tk.auto_box` | Edge rule 4.5; 3-4 masses |
| Round body | stems, bases, drums, wheels | CRISP | `tk.lathe(sides=8)` | 45/90-degree profile turns; base <= 2 levels |
| Bar/arm/post | supports, handles | CRISP | `tk.tube(sides=6)` | hex section; thin-stock exception 4.5 |
| Curved member | rings, hooks, arches | CRISP | `tk.turtle`/`arc` + `tube` | 4.3 |
| Shell/bowl/shade | open vessels | CRISP | open `tk.lathe` | 45-degree+ walls; contents visible |
| Dome | the one smooth focal part | SOFT | `tk.lathe` + `smooth_tags` | 4-5 rings; declare reason |
| Stepped base/foot | what it stands on | CRISP | `lathe`/`chamfer_box` | <= 2 levels, short, wide, darker |
| Hand-made | wax, cloth, rope, paper | HAND-MADE | `lathe`/`prism` + `wonky` | 4.4 |
| Organic | foliage, rock | ORGANIC | custom | 4.7 |
| Emitter | bulbs, flames, screens | CRISP | faceted + `Neon` | small, one accent, light added |
| Mark | dial ticks, hands, bands | CRISP | `prism`/`chamfer_box` | flat/low-relief, chunky, separate color |
| Contents | fill of containers | any | per content | visible, just below rim |
| Wrap/strip | tape, straps, bands, stripes | CRISP | `tk.wrap_band` | follows host + its chamfer, offset 1-3%, starts/ends on a face; `audit_clipping` |
| Transition piece | collar, bracket, cap, foot | CRISP | `chamfer_box`/`lathe` | one per joint, chunky, flush |
| Attachment | handle, latch, knob | CRISP | `chamfer_box`/`tube` | one per function |
| **Array** (v21) | keys, books, studs, pleats, ticks, slats | per unit | Python loop over a unit builder + `tk.translate/merge`, seeded jitter | Spec: `count`, `unit_tris`, `pitch`, jitter, palette. Rows staggered by half pitch when keys/bricks; per-instance height/width +/-10-15%, lean 0-5 degrees (one deliberate leaner per shelf allowed, up to ~15), palette color per instance; seated, no overlaps, gaps >= 10% of unit width unless touching by design; shared MeshId |
| **Panel** (v21) | raised/recessed door and cabinet panels | CRISP | inset `chamfer_box` or prism frustum | Depth 3-6% of width, one 45-degree bevel (lit top, dark bottom), margin to frame >= 10% of panel width, grid (e.g. 2x3), follows host |
| **Upholstery** (v21) | chairs, sofas, cushions | CRISP | `chamfer_box`, `tube`, `slab` | Rolled arm = octagon-section bar with flat front + wood trim strip ending in a button; seat cushion = slab, 1 chamfer, optional single raised 45-degree top facet; arched back = 3-6 facet arch inside a wood frame; stud row along base rail (array); chunky block feet |
| **Drapery** (v21) | curtains, valances | HAND-MADE | tapered strips (`prism`) | Tall strips in two alternating shades, wide at top, pinched to ~35-50% at the tieback, hem flares; strip lengths vary +/-5%; top tabs/rings = small dark blocks; tieback = chunky block in the accent color wrapping the pinch |
| **Cornice/pediment** (v21) | furniture and doorway crowns | CRISP | `slab`/`chamfer_box` steps | 2-3 stepped layers, overhang <= 8%, straight gable allowed (not a curve), flat seams to the body |
| **Sheet** (v21) | paper, cloth sheets, labels | HAND-MADE | thin `slab` | 0.04-0.08 thick (exception to thin-card ban); stacks staggered by height/offset; one gentle bend max |
| **Glass** (v21) | clock cases, windows | CRISP | thin box/prism, `Glass` Material | Separate mesh, thin sharp frame, thin-stock mullions, contents visible behind it |
| **Mechanism** (v21) | pendulum, carriage, crank, clips, weights | CRISP | `tube`, `lathe`, `prism` | Visible, chunky, one detail per function; counts as structural detail, not ornament |

**Universal rules.** Silhouette first (2-4 masses). Joints visible and clean; no floating, no poking through. Hierarchy of size (one dominant mass). Machined symmetric, hand-made asymmetric. Everything has thickness (3-8% of object size) except declared sheets. Applied parts copy their host's faces, chamfer and a 1-3% offset. One Material, one tier, one decision per part.

### 11.1 Joinery
Every bar end is buried (~half its width) in a named host or deliberately free (`tk.bar_between`). Posts carrying rails rise >= one post-width above and end in a cap (flat seam; chamfer only the cap top). T-joint: crossing bar ends buried in the side of the through bar. Corner: one runs into the other or both mitre. X-crossing: one continuous bar, two buried stubs. Hanging members join the member above and the thing they rest on. Never: bars poking through, stopping short, or overlapping coplanar. Give every touching body its own tag so audits can test each joint. Checks: `tk.audit_connections`, `tk.audit_clipping`, orbit review.

### 11.2 Detail plan
L0 masses -> L1 recognition features -> L2 structure (a transition piece at EVERY joint and end, ONE operating detail per functional part, arrays the object needs) -> L3 character (wonk, value variation, one accent). Every object reaches L2. Spend detail where parts meet, then on the hero part (~40-50% of tris, >= 3 features), then ends/tops, then silhouette steps. Test: point at each joint (transition piece?), the hero (3+ features?), the plain faces (large and quiet?).

---

## 12. Spec template (output per asset, then wait for approval)

```yaml
asset_id: MSH_<Category>_<n>_<Variant>
display_name: ""
interpretation: ""
biome: Mines | Manor | Office
texture_mode: off | on
reference_table: []        # Sec 0 step 2 rows, if references given
recognition_features: []   # 2-4
parts:                     # every unique part
  - {name: "", type: <Sec 11 type>, tier: crisp|hand_made|organic|soft, edge: sharp|chamfer, section: oct8|hex6|box4|none, host: "", tool: "", note: ""}
arrays:                    # repeats
  - {name: "", unit: "", count: 0, unit_tris: 0, pitch: "", jitter: "", palette: []}
detail_plan: {hero_part: "", transition_pieces: [], operating_detail: ""}
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

**Process:** `Guide v21 read`; reference table (if any); spec approved; real `tk.stats()`; Sec 8 review with close-ups; hand-off written.
**Shape:** recognition features present (gray silhouette reads); joinery clean; detail plan met (hero 3+ features, joint pieces, operating detail); no micro-detail; density matches references (repeats and small accents present); octagons/hexagons correct; edges decided per part; curves are facet chains; applied parts follow hosts; wonk only on hand-made; arrays seated, jittered, within unit budget; all audits clean; containers show contents; scale true; same world, different object.
**Materials:** Roblox Materials only (or 5.2 declared); flat vertex colors; right Material per part; value steps 2-3; <= 4 colors + <= 1 accent on unique features, <= 6 palette colors on repeats; emissive only on lights/interactables.
**Technical:** tris within 9.1 class; pivot/scale/bounding box verified; collision and naming set; interactables have affordance + prompt.
Never: gore, realistic weapons, real brand logos, copied label text.

---

## 14. Toolkit (unchanged; Python files next to this guide)

```python
import sys; sys.path.insert(0, "<folder with toolkit and examples>")
import doors_toolkit as tk
```
`Mesh/translate/merge/stats` | `chamfer_box`, `plain_box`, `auto_box`, `edge_style`, `cut_rect` | `lathe` (8-sided; open shells with caps off) | `prism`, `slab`, `inset_poly` | `turtle`, `arc`, `tube(sides=6)` | `bar_between` | `wrap_band` | `wonky` | `audit_mesh/audit_style/audit_connections/audit_clipping` | `to_blender`, `export_fbx`, `setup_review_rig`, `luau_apply_script`, `handoff_manifest`, `write_handoff`.
**Arrays need no new helper:** loop a unit builder with `tk.translate` + `tk.merge` and a seeded RNG. If you add helpers, keep them generic and name them `tk.array_*`.
`examples/` are illustrations, not recipes. `to_blender`, `make_materials`, `setup_review_rig`, `write_handoff` are untested glue: if one errors, fix minimally and say what you changed.
