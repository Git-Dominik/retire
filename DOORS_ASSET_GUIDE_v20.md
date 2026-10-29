# Doors Asset Style Guide

**GUIDE VERSION: v20**
**Audience:** Claude, working in Blender through MCP. **Purpose:** a universal method for making NEW, original props, furniture, fixtures and set pieces for a Roblox game in the "Doors" art style, for ANY object type. This guide teaches how to build any object (the method and a grammar of part types). It contains no recipes for specific objects; worked examples live in `examples/EXAMPLES.md`.
**Newest rules (v20):** (C) edge treatment is DECIDED per part: thin stock (planks, rails, handrails) stays sharp, thick exposed solids (shelves, boxes, posts) get one chamfer, and seams between parts stay flat and sharp (Sec. 4.5); (A) every joint is built properly: bars run INTO their hosts, nothing floats, stops short, crosses through or pokes out (Sec. 11.1); (B) detail is planned, not skipped: every object has a hero part, a transition piece at every joint and an operating detail (Sec. 11.2). Earlier rules: (1) parts are CRISP by default and only one declared focal part may be soft (Sec. 4.2); (2) curves are built from straight, chunky facets with visible joints, never from softening (Sec. 4.3); (3) hand-made parts get a controlled wonky irregularity (Sec. 4.4); (4) bars, arms, hooks, handles and rings have a HEXAGONAL cross-section (Sec. 4.5); (5) tape, straps, bands and stripes are built to follow their host's surface and its single 45-degree chamfer, never as flat sheets lying on or hanging off it (Sec. 11, Wrap).
**Confidence:** style traits come from direct observation of about 24 in-game screenshots; sizes, colors and the Roblox Material choices are estimates. Treat numbers as starting values. Verified and unverified facts live in `LEARNINGS.md`.

---

## 0. How to work (process, do these in order)

**Read only this guide** and the files it names (`toolkit/`, `examples/`, and `LEARNINGS.md` or `references/` when a section says so). Ignore any other copies of the guide, earlier models, and earlier instructions. Build everything from scratch: no free, marketplace or Creator Store models.

1. **Receipt.** Begin your FIRST reply with `Guide v20 read`. If you cannot state "v20", you are reading an old copy: stop and say so.
2. **Interpret.** For each requested object, say in one line how you interpret it. Use the most common, canonical form of the named object (the form most people picture first). If it is genuinely ambiguous, ask. If the user supplies reference images, use them only for detail level, shape language and finish (Sec. 3.3).
3. **Spec first.** For each object output the Sec. 12 spec (including its `parts:` list), then **wait for approval** before building, unless the user said to build directly.
4. **Build** with the toolkit (Sec. 14), part by part, using the part grammar (Sec. 11). Every part is CRISP unless you declare it soft (Sec. 4.2); hand-made parts follow Sec. 4.4. Report real triangle counts from `tk.stats()`.
5. **Review** in the Sec. 8.2 rig (Material Preview, dark warm light), never in a gray Solid viewport. Zoom in on every plate, arm, joint, rim and holder and confirm the corners are hard and the curves are visibly faceted. **Double-check clipping:** orbit every object from at least 4 sides and from above, zoom in on every place two parts meet (strips on a host, arms on plates, candles in holders, lids on bodies, handles on bodies), and confirm nothing pokes through a surface or leaves a gap. Run `tk.audit_clipping` (Sec. 14) too.
6. **Check:** run `tk.audit_mesh`, `tk.audit_connections`, `tk.audit_clipping` and `tk.audit_style` (Sec. 4.2, 11.1), then the Sec. 13 checklist, honestly, and list any failures.
7. **Hand off** to Studio (Sec. 9.6): write the Luau script and manifest, and tell the user the export/import steps.

**Rule precedence when rules conflict (highest first):**
1. Hard constraints: Roblox-materials-only (Sec. 5), **crisp-by-default shading with a soft-part budget of one (Sec. 4.2)**, curves from facets (Sec. 4.3), technical limits (Sec. 9), single-segment chamfers on flat edges, true relative scale, no gore.
2. Recognition features and structural joinery: the object must be nameable from its render (Sec. 3.2), and every part must be properly joined and capped (Sec. 11.1-11.2).
3. Simplicity: remove ornament, keep forms chunky (Sec. 3.1).
4. Character: the controlled wonk on hand-made parts (Sec. 4.4).
5. Everything else (palette, finish, polish).
If a user request conflicts with a hard constraint, follow the constraint and state the deviation.

---

## 1. Style DNA (what every asset keeps)

1. **Crisp chamfered low-poly stylization.** Simplified primitives with flat facets, real corners and (where used) a single flat 45-degree chamfer strip. **There is no softness added anywhere: smoothness is made out of sharp blocks.** A curve is a chain of chunky straight segments whose joints you can see (Sec. 4.3). Smooth shading is the rare exception, reserved for one focal part per object (Sec. 4.2).
2. **Octagon for round bodies, hexagon for bars.** Every round 3D body (buttons, stools, bases, wheels, bulbs, shades, barrels, candles) is 8-sided in plan view. Every bar-like member (arms, hooks, handles, rings, brackets that bend) has a 6-sided (hexagonal) cross-section (Sec. 4.5). No other counts. Flat painted label shapes may use other polygon counts.
3. **Built-in Roblox Materials give surface character; geometry gives silhouette.** No custom textures (Sec. 5).
4. **Warm light versus dark void.** Light sources are small, bright and warm; everything else falls into deep shadow. Horror comes from contrast, not clutter or gore.
5. **Readable gameplay objects.** Interactables read instantly through the one saturated accent against a muted environment.
6. **Chunky, toy-like proportions.** Handles, knobs, arms, legs and feet are thicker than real life.
7. **Machined parts are exact, hand-made parts are a little wonky.** Plates, hardware and frames are regular; wax, clay, cloth, paper, wood and plants lean, taper unevenly and have uneven tops (Sec. 4.4).
8. **Environmental storytelling by mundane props** in places that feel wrong or abandoned.

| Retain (the style DNA) | Vary (make it original) |
|------------------------|-------------------------|
| Chamfered chunky forms, octagonal plans, faceted curves | Object type, function, silhouette, composition |
| Biome palette ranges, accent rules | Specific color combinations inside those ranges |
| Built-in Materials, 2-3 value steps | Which Material fits which part |
| Warm-vs-dark lighting contrast | Light placement, emissive color |
| Oversized, toy-like proportions | Dimensions, part count, arrangement, wonk seed |
| Budgets, naming, hand-off | n/a (always follow) |

**Originality.** Build a NEW design of whatever type is asked. A new asset passes the "same world, different object" test: it fits the game, but nobody could point at a reference image and say it is the same prop. Never copy a reference object's layout, tick counts, text, colors or feature combination.

---

## 2. How to design ANY new item (the procedure)

Use this for every object, including ones nobody has built before.

1. **Name it and fix its canonical form** (Sec. 0, step 2). Pick the biome (Sec. 10).
2. **Find its recognition features** (Sec. 3.2): the 2-4 geometric features a person needs to name it. Method: imagine its gray silhouette from the front and from the side; what would you still recognise? Write them as `recognition_features`.
3. **Size it by analogy** from the anchor table (Sec. 7). Keep true relative scale to its neighbours.
4. **Break it into parts** and give every part a type from the part grammar (Sec. 11): plate, block, round body, bar, curved member, shell, dome, stepped base, hand-made part, organic mass, emitter, mark, contents, attachment. Write the list in the spec as `parts:`.
5. **Plan the joints and the details** (Sec. 11.1-11.2): name the hero part, list every place two parts meet and what joins them (buried end, cap, collar, bracket), and pick one operating detail. Write it in the spec.
6. **Decide the tier of every part** (Sec. 4.2): crisp (default), organic or hand-made wonky (Sec. 4.4), or soft. At most one soft focal part; decide it now, or none.
7. **Split by material/color region.** One MeshPart holds one Roblox Material, and its color is a flat vertex color baked into the FBX, so every distinct region becomes its own mesh (tag). Group regions that belong to one recognition feature as one part group (Sec. 3.1 caps).
8. **Assign a Roblox Material (set in Studio) and a vertex color (exported from Blender)** per region (Sec. 5), with 2-3 value steps and at most one accent.
9. **Budget it** (Sec. 9.1). Under budget is correct. If over, cut ornament and facets, never recognition features.
10. **Vary it** so it is not a copy of any reference or example: different proportions, feature layout, color family, wonk seed.
11. **Build, review, check, hand off** (Sec. 0).

---

## 3. Simplicity and recognition

### 3.1 Simple, never featureless
**Doors props are simple but not blank.** Remove ORNAMENT; never remove a recognition feature. Forms are clean, chunky and few-part, with large plain faces.
- **Part counts (a minimum AND a maximum):** small props 5-10 parts, medium props 8-18, hero set-pieces 15-30 (a group of regions serving one feature counts as one part). Fewer than the minimum means the object is under-built (Sec. 3.4); more than the maximum means clutter.
- **Ornament is banned; structural detail is required.** Ornament is decoration that explains nothing about how the object is built or used: stitching, ribbons, medallions, studs, filigree, engravings, tassels, finials, gold trim. **Structural detail shows how parts are held, joined, capped, hinged or operated: collars, brackets, sockets, caps, bosses, feet, braces, straps, big bolts, latches, hinges, step rings.** Remove ornament; never remove structural detail (Sec. 11.2). Trim and molding are for architecture only (Sec. 4.8).
- **Leave large faces plain:** one flat vertex color on one built-in Material.
- **Squint test:** the silhouette reads in about one second and you can describe the object in one short sentence.
- **Reuse beats variety:** make 2-3 simple variants and vary scale, tilt or color.
- **Tall, thin, fussy top pieces are banned:** knobs, finials and caps are short, chunky and flat-capped.

### 3.2 Recognition features (required)
A recognition feature is something a person needs in order to name the object. It is always allowed and required: flat or low-relief (thickness about 3-6% of the object's size), large and chunky, never micro-detail. **Test:** show the render to someone without the label. If they cannot name it, you removed too much. If they see a pile of tiny parts, you added too much.

**Derive features, do not look them up.** Ask three questions: (1) What does it DO, and which part does that job (the part that holds, shows, opens, lights, pours, rests on)? (2) What is the first thing you would draw to make a child name it? (3) What would still be there in a gray silhouette? Keep those parts, make them chunky, drop the rest. The output is 2-4 features, written in the spec.

### 3.3 Reference images are instructions, not objects to copy
Take only: **detail level** (what features survive), **shape language** (chamfers, octagons, faceted curves, taper, relief depth), **value and color logic**, and **finish** (what is geometry versus a color region). Do NOT take: layout, counts, text, colors, accent placement or any specific feature combination. If the output could be mistaken for the reference at a glance, vary it. Reference images and their lessons are in `references/` (read `references/REFERENCE_NOTES.md` when you need them).

The universal lessons from the references, in one place:
- **Sharp blocks make smoothness.** Curved objects are built from a few big flat facets; the facets are the style. Nothing is softened.
- **Machined parts are exact and chunky; hand-made parts are slightly off.**
- **Detail level:** every object has 2-4 clearly readable features on plain volumes; features are large and shallow.
- **Wide plates and thick members:** mounting plates are wide flat slabs with hard corners; arms and rims are thick.

### 3.4 Calibration by failure direction
For ANY object there are two ways to be wrong. Place your design between them.

| Direction | Symptoms | Fix |
|-----------|----------|-----|
| **Over-detailed** | Stacked thin slabs, terraced profiles, ornament, many tiny parts, engraved or realistic surface detail, individually modeled leaves/bolts/tufts | Delete ornament; merge parts; keep recognition features only |
| **Under-built** | Too few parts; the object is one bar and one blob; parts meet with no collar, cap, socket or bracket; no operating detail; plain faces everywhere | Run the Sec. 11.2 detail plan: hero part, a transition piece at every joint, one operating detail |
| **Badly joined** | Bars float, stop short of their post, cross through each other and stick out, sit in the same space, or end as raw cut faces | Rebuild each joint per Sec. 11.1 (`tk.bar_between`) |
| **Featureless** | A plain box, cone or sphere with a color; no part you can name | Add back the 2-4 recognition features as chunky low-relief parts |
| **Softened** | Rounded corners, smooth tubes, many-sided cylinders, smooth shading, subdivision | Rebuild as facets; curves as chains of straight blocks (Sec. 4.3) |
| **Machined-wonky mix-up** | Candles/clay/cloth perfectly regular, or plates/hardware randomly warped | Regular for machined parts, controlled wonk for hand-made parts (Sec. 4.4) |

### 3.5 Anti-patterns (reject on sight)
Stepped or terraced domes and cylinders; ornamental extras; jewel-tone or metallic-gold colors; separate geometry for pure ornament; domes built as cones of hard panels; the wrong Roblox Material on a part (Wood on a metal dome); more than 4 color regions on one object; decorative contrasting rims that exist only for detail; no value contrast between parts; flowers, berries, fruit or nubs on plants unless the user asks; a straight thin pin trunk; a container whose contents are missing or a flat disc; unusual variants of the named object; **bars that float, stop short, cross through each other, poke out past a post or overlap in the same space; joints with no collar, cap, socket or bracket; a dome with lumps, noise or irregular rings (a soft part is a clean surface of revolution); rounded or softened corners on plates, arms, trays, holders or candles; smooth round tubes and smooth cylinders for functional parts; arms bent with rounded or subdivided bends; smooth shading, Auto Smooth, Bevel, Subdivision or Weighted Normal on a crisp part; cylinders with more than 8 sides; shallow slopes (gentler than about 30 degrees) that read as a soft dome; hand-made parts that are perfectly regular or machined parts that are randomly warped; arms, hooks or handles with a square or octagonal section instead of a hexagon; tape, straps, bands or labels that are flat sheets floating above a surface, hang off an edge, ignore the host's chamfer or stand out as a separate slab.**

### 3.6 Checkable geometry rules (verify numerically before delivering)
- **Where a chamfer is used (decided per part, Sec. 4.5) it is exactly 1 segment** (flat 45-degree chamfer), about 12% of the part's smallest dimension (0.03-0.08 studs; 2-3% on architecture). Thin stock and seams stay sharp. Multi-segment rounding is allowed ONLY on a declared soft part (Sec. 4.2).
- **Bases = at most 2 stacked levels** (one flange plus one block). Never 3+ tiers or stacked slabs.
- **Solid objects stay solid:** no hollow wrap-around shells or deep cavities. Small steps are allowed and required for readability.
- **Overhangs are tiny:** any lid, cover or top overhang is at most ~5% of the smallest dimension.
- **Plan-view corners are real corners.** Plates and flat bodies are octagons or rectangles with equal-leg 45-degree cuts, never rounded, never superellipses. A plain prism (no chamfer) is a perfectly good plate.
- **Every turn between adjacent facets is about 45 or 90 degrees,** never gentler than about 30 degrees (except coplanar triangulation). **A curve has at most 6 straight segments per half circle.**
- **At most 8 sides** on any round form.
- Report the bevel segment count, base level count, soft parts and wonky parts in the spec.

---

## 4. Shape language

### 4.1 Silhouette
Chunky, slightly oversized, toy-like but not cartoonish. Strong, readable primary silhouette at 20+ studs. Slight overhangs and slight taper add a "designed" feel; keep them subtle and symmetric for machined parts. One chunky protruding affordance (handle, lever, knob) is fine; do not add a pile of small extras. Pairs and sets (two arms, three legs) are mirrored or evenly spaced.

### 4.2 Crisp by default: shading tiers and the soft-part budget
**Doors low-poly means hard facets and real corners.** Roundness is the exception, reserved for the one part of an object that needs it to be recognised and that deserves the player's attention. Everything else keeps the crisp low-poly look. (Seen in real tests: mounting plates with softened corners, arms as smooth tubes, candles as smooth cylinders, trays with rounded rims. The overall shapes were right, but the rounding broke the style.)

| Tier | Which parts | Rules |
|------|-------------|-------|
| **CRISP** (default for everything not declared otherwise) | Plates, brackets, arms, posts, stems, legs, handles, trays, holders, bases, feet, flanges, brims, frames, bodies, boxes, lids, bezels, hands, doors, shelves, hardware, and every "round-looking" functional part (tubes, cylinders, rings) | Flat-shaded planar facets. Round forms are 8-sided prisms or lathes (never more than 8 sides). Plan-view corners are real corners (equal-leg 45-degree cuts on plates). Edges are either sharp or ONE flat 45-degree chamfer strip, decided per part (Sec. 4.5). Every turn between adjacent facets is about 45 or 90 degrees (never gentler than about 30). No bevel segments beyond 1, no subdivision, no custom or weighted normals, no smooth shading. Curves are chains of straight segments (Sec. 4.3) |
| **HAND-MADE / WONKY** (declared per part; flat-shaded like everything else) | Parts that are hand-made, soft-bodied or aged: wax, clay, dough, cloth bundles, paper stacks, sacks, rope coils, roughly cut wood, crumpled things | Still faceted, flat-shaded, at most 8 sides, no smoothing. Add controlled irregularity: lean, uneven taper, uneven top, irregular facet sizes (Sec. 4.4). Machined neighbours stay regular |
| **ORGANIC FACETED** | Foliage, soil, rubble, rock | Flat-shaded irregular facets (Sec. 4.7). Rough, not smooth |
| **SOFT** (declared; at most 1 per object, 2 only with a stated reason) | Only the focal part whose smooth curvature IS its recognition feature, a dome-like or bulb-like shape that the eye goes to first | Smooth-shaded through 4-5 evenly spaced profile rings; a CLEAN surface of revolution (no noise, lumps, displacement or irregular rings; wonk never applies here); no long thin triangles. Its neighbours (rim, base, knob, arm) stay crisp. Listed as `soft_parts` in the spec |

**Attention test.** A part may be soft only if (a) its curve is what makes the object recognisable and (b) a player's eye goes to it first. A plate, bracket, arm, tray, holder or any other functional part fails both: crisp. When in doubt, make it a faceted curve (Sec. 4.3) instead of a soft part.

**Common mistakes to avoid:**
- Softened or rounded corners on a plate (superellipse, subdivided, smooth-shaded).
- Arms, posts and rings as smooth round tubes or as bends with rounded profiles. Build them as faceted chains.
- Trays and rims with soft multi-segment edges; hand-made round parts as smooth perfect cylinders.
- "Making it nicer" with `shade_smooth`, Auto Smooth, Smooth by Angle, Weighted Normal, Bevel or Subdivision on a whole object.
- 12, 16 or 32 sides on a cylinder.
- Shallow cone tops or slopes that read as a soft dome.

**How to build crisp parts (toolkit):** plates with `tk.slab`; blocks with `tk.chamfer_box`; straight and bent arms with `tk.tube(..., sides=6)`; round-looking parts with `tk.lathe(..., sides=8)`; bent arms, rings and handles with `tk.turtle` + `tk.tube(..., sides=6)` (Sec. 4.3); flat chunky pieces with `tk.prism`; tape, straps and bands with `tk.wrap_band` (Sec. 11). Smooth shading only through `to_blender(..., smooth_tags=("<soft tag>",))`. Never call `shade_smooth` on anything else.

**Checks (required before the hand-off):**
- `tk.audit_mesh(mesh, soft_tags=(...), organic_tags=(...))` returns no issues. It flags runs of softly rounded edges (6-28 degree turns): multi-segment bevels, 16-sided cylinders, smooth profile rings, and faceted curves whose joints turn less than 30 degrees. `soft_tags` are the regions you declared soft; `organic_tags` are the foliage-like and hand-made regions whose facets are meant to be irregular.
- `tk.audit_style(parts, soft_tags=(...))` in Blender returns no issues (no smooth-shaded polygons, custom normals or rounding modifiers on crisp parts).
- Zoom in on plate corners, rims, arms, joints and holders in the review render: corners must be hard.
- State the soft part(s), or "none", in the final report.

### 4.3 Curves from facets: sharp blocks create smoothness
**Doors never softens a curve; it builds the curve out of a few big straight blocks.** A bent arm, a ring, a handle, a hoop or an arch reads as smooth because it is made of chunky straight segments with visible joints, not because anything is rounded. This is the signature of the style.

- **Segment budget:** every joint turns **30 degrees or more** (45 is ideal). A quarter circle (90 degrees) is 2-3 segments; a half circle is at most 6 (usually 4-5); a full ring is 8 sides. Fewer, longer segments look better than many short ones.
- **Mitred, planar joints:** neighbouring segments meet at a mitred angle with flat faces, so every face stays planar and the joint is a visible crease. `tk.tube` does this for you.
- **Chunky hexagonal cross-section:** bent members are thick HEXAGONAL bars (`sides=6`, one flat face toward the viewer), never square, never octagonal, never thin wires; thickness about 0.1-0.25 of the member's length.
- **Plates stay plates.** A flat mounting piece never becomes a curve. Curves belong to arms, rings, handles, rims and frames.
- **Pure arcs vs. straight lead-ins:** `tk.arc(center, radius, a0, a1, segs)` builds a pure curve. For a member that leaves a surface straight and then bends, use `tk.turtle(start, direction, axis, [("f", len), ("t", deg), ...])`; both return points for `tk.tube(m, pts, r, tag, sides=6)`.
- **Shape language of a fixture or fitting (universal):** a wide flat mounting plate with hard octagonal corners; thick faceted members leaving it; a faceted bend; the working head (cup, tray, shade) as an open 8-sided faceted shell with 45-degree walls. Nothing rounded is added anywhere; the whole object reads smooth because the blocks are big and the angles are even.

### 4.4 Hand-made parts: the controlled wonk
Not everything is machined. Parts that are hand-made, soft-bodied or aged feel more stylized and alive when they are a little wonky: **a bit off, like a real stylized object, yet still simple.** This is the one place where the style is deliberately not exact.

**When to use:** wax, clay, dough, cloth bundles, paper stacks, sacks, rope, roughly hewn wood, anything crumpled, melted or stacked by hand. **Never** on plates, hardware, frames, boxes, dials or any machined part: those stay exact.

**How (all together, in small amounts so it reads at 10 studs without looking broken):**
- **Lean:** the part tilts off vertical by about 2-4 degrees (up to ~5% of its height sideways).
- **Uneven taper:** it is 10-20% narrower (or wider) at one end, not a perfect cylinder.
- **Uneven top:** one side of the top sits higher or is cut at a slant; the top is not a flat disc.
- **Irregular facets:** per-vertex offsets of up to ~5% of the radius so the facets are unequal. Still at most 8 sides; no new ring rows.
- **A local feature:** at most one extra characterful bump or sag (a drip, a dent, a fold). One only.
- **Seated:** the base stays flat and seated on its support; the part never floats or intersects another.
- **Flat-shaded and faceted:** wonk comes from the facets, never from smoothing.
- **Vary per instance:** change the seed so copies are not identical; neighbours of the same kind differ in height and lean.

**Toolkit:** build the part with `tk.lathe(..., sides=8)` and then `tk.wonky(m, ("<tag>",), lean=0.05, taper=-0.14, jitter=0.05, top_tilt=0.2, seed=n)`. Pass its tag as an `organic_tag` to `tk.audit_mesh`.

### 4.5 Edge treatment, octagons and cross-sections
**Edge treatment is DECIDED per part; it is never applied to everything.** A chamfer (ONE flat 45-degree strip that catches rim light, the Doors "smoothed corner") is something a part earns; a sharp edge is the default. A chamfer is a flat cut, never a rounded profile. Decide in this order and write `edge: sharp | chamfer` for every part in the spec:
1. **Seams first.** Where two parts meet face to face (a cap on a post, a lid on a body, a bar end in a host, a part against a wall), the meeting edges are SHARP and flat on both parts so they seat cleanly. Chamfer only the exposed outer edges. A chamfered post top under a chamfered cap leaves a groove. A post that carries a cap has a FLAT top (chamfer its vertical edges only, `tk.slab` + `tk.cut_rect`) and the cap has a flat underside with the chamfer on its top edge only.
2. **Thin stock stays SHARP:** planks, boards, rails, handrails, slats, flat bars, panels, skirting, trim pieces, anything under about 0.25 studs thick. A chamfer on thin stock eats its thickness and reads as a doubled edge. Repeated thin pieces in a group (fence boards, rack bars, slats) stay sharp however large the group.
3. **Thick, exposed, chunky solids get ONE chamfer on the exposed edges:** shelf tops and tabletops about 0.3 studs or thicker, crates, boxes, chests, counters, seats, thick posts and beams, bezels, bases. Size about 12% of the part's smallest dimension, clamped to 0.03-0.08 studs. Chamfered shelf fronts and box edges look good and are wanted.
4. **Hero or touched parts** (a handle, a bezel) may take the chamfer when slightly thinner than 0.3, but never thin stock.
5. **When unsure:** long and thin = sharp; short and fat = chamfer. `tk.edge_style(dims)` and `tk.auto_box(...)` encode this.
The same decision is made inside one object: a rack has chamfered thick uprights and shelf tops but sharp thin cross bars.

Round bodies become 8-sided prisms and lathes (seats, bases, buttons, wheels, bulbs, shades, barrels). Rotate the octagon so a flat faces the front axis.

**Cross-section rule (decide it per part, state it in the spec as `section`):**
- **Round body (lathe, plan view): octagon, 8 sides.**
- **Bar-like member (arm, hook, handle, ring, bent bracket, stem of a fitting): hexagon, 6 sides**, built with `tk.tube(..., sides=6)`; one flat face points outward. This is the default for every such member; do not build it as a square box section or an octagon.
- **Blocky post or leg of furniture:** square (`chamfer_box`) is allowed.
- If a reference or the user shows a different section for a part, copy that SHAPE LANGUAGE for the part, but when no section is stated use the rule above. Never mix two sections for the same kind of part inside one object. The octagon defines the plan-view footprint; it does not mean the elevation profile must be an angular panel.

### 4.6 Shading
- **Default: flat shading on every part.** Planes, chamfers, round-looking functional parts, faceted curves, hand-made wonky parts and organic masses are all flat-shaded.
- **Smooth-shade only a declared soft part** (Sec. 4.2): one soft continuous curve with gentle highlight falloff, even ring spacing, no long thin triangles. In the toolkit: `to_blender(..., smooth_tags=("<soft tag>",))` smooths only the listed regions. Never smooth a whole object, and never smooth its neighbours.

### 4.7 Organic masses (plants, rubble, rock)
The one organic exception. Rough, irregular, flat-shaded.
- **Silhouette:** a tall tapered mass **widest at about 30-45% of its height**, narrowing to a blunt top; never a ball, never a perfect egg.
- **Surface:** crumpled and ragged; facets of mixed sizes (some large planes, many small notches), never a uniform field of equal triangles. Non-convex outline with notches and protrusions of ~5-12% of the radius.
- **Detail units:** 30-50 small folded blades (two triangles each) lying over the surface and pointing up and out, never thorns, spikes, berries or individually modeled realistic leaves.
- **Stems and trunks:** short, chunky, faceted, slightly leaning or kinked, tapered with a flare where they meet the ground; never a straight thin pin.
- **Ground contact and contents:** anything sitting in a container shows its contents (Sec. 11, Contents).
- **Composition:** crisp geometric container versus rough organic mass is the signature contrast.
- **No flowers, fruit or berries** unless the user explicitly asks; then a few chunky faceted blobs of ONE muted accent color.
- **Budget:** a whole potted organic object stays under 600 tris. If over, cut blades and facets, never contents or stem.

### 4.8 Architecture trim (architecture only, never on small props)
Wainscoting, crown molding, baseboards, door frames and ceiling beams are layered stepped profiles (2-3 steps). Archways are simple semicircular or segmental cuts built as faceted chains (Sec. 4.3) with a thick frame and chunky corner blocks. Ceilings are long staggered planks (Manor) or a flat acoustic grid (Office).

---

## 5. Materials and color (Roblox built-in only)

**Doors uses ONLY Roblox's built-in `Enum.Material`. The color comes from a flat VERTEX COLOR that is baked in Blender and travels automatically inside the FBX; the Material is the only thing set in Studio. There are no custom textures.**

- **Every part = one flat vertex color (from Blender) + one `Enum.Material` (set in Studio).** One MeshPart holds one Material, so **every material/color region is its own mesh** (one tag each in the toolkit). `tk.to_blender` writes the vertex color for you (a flat color attribute named `Col`).
- **Forbidden:** custom image textures, `SurfaceAppearance` (any map), `MaterialVariant`, `TextureID`, baked albedo or AO, UV painting, decals for detail, painted or gradient vertex colors (only FLAT per-region vertex colors are allowed). Anywhere a source or old note says texture, normal map, albedo or tiling, choose a built-in Material and a flat vertex color instead.
- **Surface character comes from the Material.** Pick the Material whose built-in look fits. You cannot paint grain, weave or plate patterns. Do not fake patterns with extra geometry.
- **The color arrives with the FBX; the Material is set in Studio.** Studio multiplies the vertex colors by the MeshPart's `Color`, which defaults to grey, so the hand-off script sets `Color` to white (255, 255, 255) and sets only the Material. Roblox's Materials add their own texture and shine on top of the color, so judge the final look in Studio (Sec. 9.6) and swap the Material there if needed.
- Emissive parts use `Neon` plus a light (Sec. 8.1). Signage and text are added in Studio, not in the mesh.

**Starter mapping (confirm each in Studio):**
| Part is... | Roblox Material | Color notes | Never |
|------------|-----------------|-------------|-------|
| Metal (domes, hardware, frames, barrels) | `Metal` (`DiamondPlate` for Mines machinery; test `CorrodedMetal`) | Muted bronze/steel/olive, no pink tint | Wood, Fabric |
| Dark base / underside / hoops | `Metal` (dark) or `Slate` | Near-black brown | |
| Wood (trunk, furniture, crates, trim, frames) | `Wood` (`WoodPlanks` for wide planks) | Warm browns | Metal |
| Cloth, covers, upholstery, fabric shades | `Fabric` | Flat muted color | Wood |
| Paper / page edge | `SmoothPlastic` | Flat cream | |
| Plastic (dials, marks, hands, housings) | `Plastic` or `SmoothPlastic` | Matte beige/cream or dark | Neon |
| Fired clay / ceramic | `Wood` (reference shows horizontal grain; test `ClayRoofTiles`, `Brick`, `Concrete`) | Terracotta | |
| Wax, clay, dough, other hand-made soft parts | `SmoothPlastic` or `Plastic` (test `Limestone`, `Sandstone`) | Cream, ochre or dusty tone; slightly lighter than neighbours | Metal, Neon |
| Soil / ground fill | `Ground` (test `Mud`, `Pebble`, `Slate`) | Dark grey-brown | |
| Foliage | `LeafyGrass` (test `Grass`) | Olive; leaf blades a lighter/warmer tint (value variation, not painted flecks) | |
| Stone / walls | `Slate`, `Concrete`, `Cobblestone`, `Granite`, `Brick`, `Plaster` | Per biome (Sec. 6) | |
| Emissive | `Neon` | Flat bright | Anything else |

Biome Material candidates: **Mines** `DiamondPlate`, `Metal`, `WoodPlanks`, `Wood`, `Slate`, `Granite`, `Cobblestone`. **Manor** `Wood`, `WoodPlanks`, `Fabric`, `Plaster`, `Brick`, `Metal`. **Office** `Concrete`, `Plaster`, `Fabric`, `Carpet`, `Plastic`, `SmoothPlastic`, `Metal`. Patterns no built-in Material provides (damask, harlequin, hazard stripes, eye icon) are not built into the asset; they are optional Studio decoration or left out. Roblox has 43 built-in materials (Asphalt, Basalt, Brick, Cardboard, Carpet, CeramicTiles, ClayRoofTiles, Cobblestone, Concrete, CorrodedMetal, CrackedLava, DiamondPlate, Fabric, Foil, ForceField, Glacier, Glass, Granite, Grass, Ground, Ice, LeafyGrass, Leather, Limestone, Marble, Metal, Mud, Neon, Pavement, Pebble, Plaster, Plastic, Rock, RoofShingles, Rubber, Salt, Sand, Sandstone, Slate, SmoothPlastic, Snow, Wood, WoodPlanks) per Roblox's docs.

**Unverified (check in Studio before trusting):** how each Material tiles and scales on a MeshPart, and how the vertex colors combine with each one, and whether the sRGB/linear export choice makes the colors match Blender. If a Material looks stretched, too busy or too shiny on a small prop, try a neighbouring one.

### 5.1 Color discipline
- **Muted, earthy, slightly dusty;** albedo-like saturation about 35-55%, values mid-to-dark. Avoid jewel tones (crimson, royal purple, emerald) and metallic gold. Typical: terracotta, brick red, olive, ochre, dusty plum, warm brown, cream bands.
- **2-3 value steps per object** (dark base, mid body, lighter top or rim). Undersides and bases darker; tops and rims lighter. Do not rely on lighting to create contrast.
- **At most ONE accent per object:** either one glowing strip/lamp OR one saturated lever/button color. Emissive area stays small. Interactables are the highest-saturation element in a scene.
- **2-3 color regions per object, 4 maximum.** No pure black or pure white as a vertex color (stay within about `#1A1A1A` to `#F0E8D8`).
- **Wear and dirt** are expressed only through color value differences between parts (slightly darker underside or base, slightly lighter edge parts), never painted grime. Mines: grime in recesses; Manor: cleaner, lightly worn; Office: sterile but aged. No blood or gore.
- Lighting shifts hues on screen (cool purple ambient turns terracotta pink and olive blue-grey): judge the vertex color against a warm-lit reference and do not bake the shifted hue in. Choose the color slightly less orange than you want on screen, since warm lighting adds warmth.

Starter muted prop palette (adjust within +/-10%): terracotta `#A8503C`, brick `#8E4636`, olive `#6B6A38`, dusty plum `#7A5A78`, ochre `#C8803C`, cream band `#E3B88A`, warm tan metal `#9A7B5A`, dark base `#3A2D28`. Cloth objects: one main color, optionally one cream/ochre band color, nothing else. Glow colors: cyan `#8FE4FF`, green `#5CFF6E`, warm `#FFD58A`.

---

## 6. Biome palettes (approximate sRGB hex)

**Mines** (grimy industrial): base wood `#6B4B3B`; light wood `#B5764F`; dark metal brown `#3A2A24`; olive military green `#3C4128`; copper/rose metal `#B98368`; stone `#4A4660` to `#7B6F80` (cool purple-grey); hazard yellow `#E8A21E`; accent red `#E85A66`; accent cyan (emissive) `#8FE4FF`.

**Manor** (Victorian-gothic-lite, candle-lit): wallpaper plum `#6A3A5C` (pattern `#7E4A6E`); wainscot wood `#4A3024` to `#6B4533`; warm floor wood `#5A3524`; warm upholstery `#A67658`; cool upholstery `#7C6C9C`; frame orange `#E8873C`; candle wax `#F5D9A8`; flame/lamp glow `#FFD58A`; rug terracotta `#B0694F`; planter terracotta lit `#A4432E` / shade `#5E241C`; foliage olive `#5E5B2C` (dark `#2E2A14`, highlight `#8A8340`); plant stem `#8A6A48`; soil `#3B332C`; wood frame highlight-to-dark `#B5623A` to `#6B3524`.

**Office** (cool, desaturated, institutional): wall slate-blue `#7F8CAB`; lower band `#6B7794`; ceiling dark `#2B2E3A`; plastic beige `#C9BFA8`; cabinet grey-blue `#7A8296`; binders `#667AA6` / `#8A6A8E`; carpet green `#4F7F3A`; carpet red `#A84A3C`; terminal green (emissive) `#5CFF6E`; chair blue `#46608C`.

Environments are desaturated to mid-saturation; saturated color is reserved for interactables, hazards and emissives. Overall value range skews dark.

---

## 7. Proportions and scale (estimates, studs; 1 stud about 0.28 m)

These are size calibration anchors, not object designs. Use them to size NEW objects by analogy. Build every prop at true relative scale; when several props share a review scene keep their relative sizes and move the camera instead. If the user wants a miniature, say so in the spec.

| Object | Approx. W x H x D | Notes |
|--------|-------------------|-------|
| Standard door | 4.5 x 8 x 0.5 | Door about 1.4x character height |
| Door handle plate | 0.4 x 1.2 | |
| Toolbox | 4 x 1.8 x 1.8 | Low, wide, chunky |
| Generator | 5 x 3.5 x 3 | |
| Crate | 3 x 3 x 3 | Stacked in pyramids of 3 |
| Industrial barrel | 2.3 x 3.2 x 2.3 | Straight 8-sided body with 45-degree chamfered ends |
| Pedestal button | 1.5 x 4 x 1.5 | Cap about 1 stud |
| Floor candle stand | base 1, stem 4-4.5 | |
| Sofa (3-seat) / armchair | 7 x 3.5 x 3 / 3.5 x 3.5 x 3 | |
| Bed (four-poster) | 8 x 9 x 10 | |
| Bar stool / waiting chair | 1.5 x 2.8 x 1.5 / 2 x 3 x 2 | |
| Radiator | 3.5 x 2 x 0.5 | About 9 fins |
| Bookshelf | 6 x 7 x 1.5 | |
| Chandelier | 6-8 across | |
| Wall light (candle arm / hooded / cup) | 1.1-2.3 W x 1.6-2.7 H x 1.0-1.7 D | Backplate about 0.9-1.1 wide, 1.7-2.0 tall, 0.26 thick; fixture projects about 1-1.6 studs from the wall |
| Wall clock | 3 x 0.4 x 3 | About 0.4 deep |
| Table lamp | 1.9 x 2.0 x 1.9 | |
| Planter pot | 2.2 x 2 x 2.2 | |
| Topiary total | 2.5 x 6 x 2.5 | |
| Book (flat) / standing | 1.2 x 0.4 x 1.7 / 0.4 x 1.7 x 1.2 | Thicker than a real book; vary 10-15% between copies |
| Desk bell | about 0.9 across x 0.45 | About half the book's width |

Handles and knobs are about 1.5x realistic thickness. Hallways are about 10-20 studs wide; grand rooms 40+.

---

## 8. Lighting, review and interaction

### 8.1 Lighting the props must survive
Future lighting, real fairly dark shadows, low ambient fill. Light sources are part of the prop. Warm 2200-3000K in Manor/Mines, cool-neutral in Office. Bulbs: emissive (`Neon`) mesh plus a `PointLight` (Range 12-20, Brightness 1-2, shadows only on hero lights). Candles: PointLight Range ~10, Brightness ~1, warm. **Only light sources and interactables get emissive.**

### 8.2 Review rig (required before approving any model)
Flat bright backgrounds hide problems. Run `tk.setup_review_rig(target=(x, y, z))` (dark warm world `#2A211C`, ONE warm point light `#FFD58A` upper-front, camera about 3x the widest object away, viewport switched to Material Preview). Compare next to the reference crops at the same scale: value steps, material correctness, accent, silhouette, crispness. If the asset looks flatter, pinker, busier or cheaper than the reference, revise. Then render a close-up of every plate, rim, arm joint and holder and check for hard corners, flat faces and visibly faceted curves (Sec. 4.2-4.3). A gray Solid-mode viewport is NOT a review. Check shape and readability in gray first, then re-review with colors.

### 8.3 Interaction readability
Interactables (buttons, levers, lamps, frames) are the highest-saturation element. Use a `ProximityPrompt` with key "E" and the hover highlight; add a small attachment dot at the interact point. Hideable/lootable objects have visible latches or handles. Chunky octagonal buttons on pedestals with stenciled caps. Do not add glow to non-interactive props.
UI/labels (if requested): condensed bold sans (Oswald-like), cream `#F5E8D0` on a translucent dark-brown band; cream rounded-square prompt buttons with a dark glyph.

---

## 9. Technical specifications (Roblox)

### 9.1 Triangle budgets
| Class | Target | Hard max |
|-------|--------|----------|
| Small prop (candle, knob, book, bell, clock, lamp) | 150-500 | 800 |
| Medium prop (stool, chair, crate, radiator, barrel) | 400-1,200 | 2,000 |
| Large prop (sofa, generator, toolbox) | 1,000-3,000 | 4,500 |
| Hero set-piece (bed, chandelier, terminal) | 2,000-5,000 | 7,000 |
| Architecture kit piece | 50-800 | 1,500 |
| Roblox upload limit | | 20,000 per mesh; never approach it |

Stay inside the target band: over it means ornament, under it means under-built (Sec. 3.4). These bands are estimates. Prefer instancing the same MeshId. No interior faces, hidden geometry or n-gons on export (triangulate); merge by distance. Avoid thin cards for solid objects.

### 9.2 Pivot, orientation, scale
Pivot bottom-center for floor props, back-center for wall props, hinge edge for doors. Roblox front face = -Z (in Blender the front is typically -Y; verify the import in Studio). +Y up in Roblox. Build at 1 Blender unit = 1 stud, apply all transforms (scale 1,1,1) and verify the bounding box in Studio. Do not rely on resizing in Studio.

### 9.3 Collision and physics
Visual meshes use `CollisionFidelity = Box` or `Hull` for dressing; `PreciseConvexDecomposition` only for hero props players physically touch. Use invisible simple collision proxies (`Transparency = 1`, `CanCollide = true`) for complex shapes. Dressing that should not block movement: `CanCollide = false` (candles, sconces, wall art, books, clocks). Static props: `Anchored = true`, `CanTouch = false`, `CastShadow = true` (except items under 0.5 studs).

### 9.4 Performance
Group each room as a `Model` with `ModelStreamingMode = Atomic`. Keep under about 400 parts and 150k triangles in view per room. `RenderFidelity = Automatic`. Reuse Material + color combinations across a biome. Only hero lights cast shadows.

### 9.5 Naming and tags
- Mesh naming: `<Group>_<Part>` in PascalCase from the toolkit (for example `Fixture_Plate`, `Chest_Lid`, `Stand_Foot`). Studio hierarchy: `ReplicatedStorage/Assets/{Biome}/{Category}/{Asset}`. PascalCase asset names, no spaces or special characters; collision proxies `COL_...`.
- Attributes/tags (CollectionService): `Biome` = Mines | Manor | Office; `Interactable` true/false; `Hideable` / `Lootable` where relevant; `LightSource` = true on emissive/lit props.

### 9.6 Blender pipeline and Studio hand-off (required final deliverable)
- Build with the toolkit. Octagonal plan = 8-sided lathes; plates = `slab`; flat-sided bodies and straight arms = `chamfer_box` (1-segment chamfers); bent members = `turtle` + `tube(sides=6)`; tape and bands = `wrap_band`; hand-made parts = `lathe` + `wonky`. Only a declared soft part gets a few smooth-shaded lathe rings (`smooth_tags`). Everything else stays flat-shaded (Sec. 4.2).
- Run the crisp audits (`tk.audit_mesh`, `tk.audit_style`), apply transforms, and make sure NO bevel, subdivision, smooth or weighted-normal modifiers are left. Export each group (the Empty plus its child meshes) with `tk.export_fbx(path, group)`: FBX with **face smoothing** (flat normals, so crisp corners survive the import), the flat vertex colors (`Col`) so the colors import automatically, no materials/textures embedded, 1 unit = 1 stud. **Colors come through the FBX; only Materials are edited in Studio.** If you export by hand, set Smoothing = Face and never export smooth or custom normals on crisp parts. Whether Studio's importer keeps flat normals exactly as exported is unverified: check the corners in Studio.
- When all objects are built and checked, for EVERY object group:
  1. **Finalize mesh names** (`<Group>_<Part>`, unique across the scene). Do not rename afterwards; if you do, regenerate.
  2. **Write the hand-off files** next to the .blend: `tk.write_handoff(folder, "<group>", parts)` writes `<group>_apply_materials.luau` (paste into Studio's command bar) and `<group>_manifest.md` (mesh name -> Roblox Material -> vertex color -> tris, for doing it by hand).
  3. **Hand-built meshes:** set the custom properties on each region mesh yourself (`ob["roblox_material"] = "Metal"`, `ob["roblox_color"] = "#RRGGBB"`), name them `<Group>_<Part>`, and give each a flat vertex color attribute named `Col` in that same color (`tk.to_blender` does this automatically), so they join the hand-off.
  4. **Tell the user, in plain words:** import the file(s) into Studio, select the imported Model, run the contents of the matching `_apply_materials.luau` (it sets the Materials and sets each MeshPart's `Color` to white so the imported vertex colors show true; or follow the manifest by hand), then check size, part names, colors and look against the references under Doors-style lighting; swap a Material for a neighbouring one if it looks stretched, shiny or busy.
  5. **State what you could not verify.** `to_blender`, `write_handoff` and the Luau script depend on Blender/Studio behaviour that the guide's authors have not fully tested: report errors and what you changed.
  6. **Final message format:** each group's meshes, Roblox Materials, vertex color hex values, triangle counts, and where the two hand-off files were written.

---

## 10. Biome style sheets

**Mines.** Mood: damp, industrial, cramped, dangerous. Materials: `DiamondPlate`, rough planks, cave rock, flagstone, chain-link. Cues: thick rails, chunky bolts, octagonal gears, cast-iron feel. Accents: hazard stripes, red/cyan glows. Content: crates, toolboxes, generators, gate buttons, ladders, lamps, fences, carts, pipes, barrels.

**Manor.** Mood: decadent, quiet, candle-lit, uncanny. Materials: plum damask, dark wainscot, polished floors, harlequin upholstery, brass-brown metals. Cues: curved sofa backs, rolled arms, bun feet, canopy-bed posts with turned collars, arched niches. Accents: orange frames, warm bulbs, red food props. Content: sofas, armchairs, beds, trunks, paintings, candle stands, sconces, wagon-wheel chandeliers, kitchen gear, stools, potted topiaries, bellhop cart, desk bells. Extra traits: heavy wood door frames and paneling with pronounced grain (vertical on frames, horizontal on paneling); diamond-lattice partitions; scalloped valances; night windows with a few white specks; dark red-brown floor tiles with grout; topiaries flanking doorways and windows; occasional cobwebs (flat decal cards).

**Office / Institutional.** Mood: sterile, bureaucratic, slightly retro-tech. Materials: painted concrete, slate-blue wainscot, carpet, laminate door, beige plastic, grey metal. Cues: chunky chamfered CRT-style monitors, boxy cabinets with chamfered tops, thick radiator fins. Accents: green terminal glow, green carpet, mauve/blue binders. Content: terminals, radiators, shelves, binders, waiting chairs, doors with closers, vents, ceiling panels, wall clocks.

**Repeating motifs** that keep new assets on-brand: diamond plate on Mines metal; harlequin/rounded-diamond damask in Manor; hazard stripes (yellow/black) on industrial surfaces; octagons on everything round; a stylized eye icon in a hex frame on Manor frames and signage; an in-universe green swirl on Office terminals. Invent new in-universe marks; never copy a logo or label text.

Prefer inventing objects not listed here; never rebuild a listed object one-to-one.

---

## 11. Part grammar (build ANY object from these part types)

Every object is a short list of parts, and every part is one of these types. A type says what the part is, which tier it takes (Sec. 4.2), how to build it and what to avoid. These are building rules, not recipes: compose them freely and size them with Sec. 7. Part caps from Sec. 3.1 apply.

| Part type | What it is | Tier | Build with | Rules |
|-----------|-----------|------|-----------|-------|
| **Plate / slab** | Mounting plates, panels, signs, lids, boards, covers, flat backs | CRISP | `tk.slab` (plain prism or ONE flat chamfer) | Octagon or rectangle with equal-leg 45-degree corner cuts; 0.2-0.35 studs thick (or ~5-8% of its width); hard corners; wide and chunky; never rounded, never a superellipse |
| **Block / body** | Boxes, cabinets, casings, chests, frames, seat masses | CRISP | `tk.auto_box` (decides), `tk.chamfer_box` / `tk.plain_box` | Edge style per Sec. 4.5 (sharp or one chamfer segment); large plain faces; 3-4 clear masses, not many small ones |
| **Round body** | Vessels, bases, stems, stools, drums, bulbs, wheels, posts | CRISP | `tk.lathe(..., sides=8)` | 8-sided; profile turns of 45 or 90 degrees only; at most 2 stacked levels in a base; no shallow slopes |
| **Bar / arm / post** | Straight or L-shaped supports, arms, handles, brackets, fitting stems | CRISP | `tk.tube(..., sides=6)`; `tk.chamfer_box` only for blocky furniture posts | **Hexagonal cross-section** (Sec. 4.5), chunky, never a thin wire, a smooth tube, a square or an octagon; leaves its support at a clear angle |
| **Curved member** | Bent arms, rings, hoops, handles, hooks, arches | CRISP | `tk.turtle` + `tk.tube(..., sides=6)`, or `tk.arc` + `tk.tube(..., sides=6)` | Hexagonal section; chain of straight segments with mitred, visible joints; every joint turns >= 30 degrees; <= 6 segments per half circle (Sec. 4.3) |
| **Shell / bowl / cup / shade** | Open vessels, trays, cups, shades, hoods built from flat walls | CRISP | `tk.lathe` open shell (outer wall, rim, inner wall, rim; caps off) | 8-sided; walls at 45 degrees or steeper; thin flat rim; one wall thickness; glowing contents sit visibly inside |
| **Dome** | The one smooth focal part (round cover, bulb, cloche) | SOFT (the budget) | `tk.lathe` + `smooth_tags` | 4-5 evenly spaced rings; neighbours crisp; declared in the spec with a reason; if unsure, make it a faceted shell instead |
| **Stepped base / flange / foot** | What the object stands on or is capped by | CRISP | `tk.lathe`, `tk.chamfer_box` | At most 2 levels; short and wide; darker value; flat cap on knobs and feet |
| **Hand-made part** | Wax, clay, cloth, paper, rope, rough wood, anything not machined | HAND-MADE | `tk.lathe`/`tk.prism` + `tk.wonky` | Lean, uneven taper, uneven top, irregular facets, one local feature, seated; still faceted and flat-shaded (Sec. 4.4) |
| **Organic mass** | Foliage, soil, rocks, rubble | ORGANIC | custom, see `examples/` | Sec. 4.7 |
| **Emitter** | Bulbs, flames, screens, glowing strips | CRISP (or SOFT if it is the focal dome) | faceted shape + `Neon` | Small, bright, warm, the single accent; sits inside or under its housing; add a light (Sec. 8.1); faceted, never a smooth sphere |
| **Mark / face** | Dial marks, label shapes, bands, stripes, hands, buttons | CRISP | `tk.prism`, `tk.chamfer_box` | Flat or low-relief (3-6% of size); large; a separate color region; no engraving, text or micro-detail |
| **Contents / fill** | What a container holds: soil, liquid, items, light | ORGANIC or CRISP | as the content type | If the container is open, its contents are visible and sit just below the rim; never an empty shell or a flat disc |
| **Wrap / strip** | Tape, straps, bands, stripes, labels, hoops: anything applied to the surface of a host part | CRISP | `tk.wrap_band` (box hosts), `tk.lathe` band rings (round hosts) | **Follows the host:** it is the host's own cross-section pushed out 1-3% (`t`), so it lies flat on each face and turns every corner on the host's single 45-degree chamfer face. It never floats, clips into the host, overhangs, flaps off an edge or sits as a flat sheet on top; check it with `tk.audit_clipping`. It starts and ends on a face (tape stops partway down a side) or closes into a full ring. Width >= 10% of the host. Its own edges are hard, no chamfer needed at 1-3% thickness. Separate color region |
| **Transition piece** | Collar, bracket, boss, socket, cap, foot, step ring, brace: the piece that shows how two parts are joined | CRISP | `tk.chamfer_box`, `tk.lathe` | Chunky, slightly wider than the part it holds; ONE per joint; sits flush on both parts (no gaps, no clipping); never decorative |
| **Attachment** | Handle, latch, knob, lever, hook | CRISP | `tk.chamfer_box`, `tk.tube(..., sides=6)` | One per function; short, chunky, flat-capped; never ornamental |

**Universal construction rules**
1. **Silhouette first.** Build the 2-4 largest masses, check the gray silhouette (Sec. 3.2), then add the smaller recognition features.
2. **Joints are visible and clean.** Where two parts meet (plate to arm, arm to head, body to lid) the meeting is a clear step or crease, never a blend. Parts that join are buried into each other only as deep as a hidden joint needs (open end buried inside the host, never reaching the far side). Surface parts (strips, labels) sit FLUSH: no gap and no clipping. Nothing pokes through a surface; nothing floats.
3. **Hierarchy of size.** One dominant mass, one or two secondary masses, small chunky details. Equal-sized parts look like a pile.
4. **Symmetry for machined, asymmetry for hand-made.** Mirror pairs and sets; give hand-made parts different heights, leans and seeds.
5. **Everything has thickness.** Rims, plates, walls and lips have visible thickness (about 3-8% of the object's size); no zero-thickness cards for solid things.
6. **Applied parts follow their host.** Anything that sits on another part's surface (tape, strap, band, stripe, label, trim line) copies the host's structure: same faces, same corner chamfer, tiny uniform offset. Build it from the host's own dimensions, never as an independent flat plane.
7. **Plan the joints and the details before building** (Sec. 11.1 and 11.2).
8. **One decision per part.** A part has one tier, one Roblox Material and one flat vertex color. If a part needs two, it is two parts.

### 11.1 Joinery: how bars and parts connect
Structure must read as honestly built. **Every bar end is either buried in a host or deliberately free.** (Seen in a real test: a frame whose rails and posts overlapped, crossed through each other, stopped short and left a post hanging. Clean version: posts rise above the rail and finish in a chamfered cap, and the rail runs into both posts.)
- **Default joint = buried end.** The bar's end runs about half its own width INTO the host, so the end face is hidden inside it. The whole end face sits inside the host's flat face (the bar is narrower than the host minus its chamfers). If the bar has its own chamfer, bury it at least that deep so the chamfered end is hidden too. Build with `tk.bar_between(m, p0, p1, w, tag, host0, host1, bury, c)`.
- **Posts carrying a rail finish above it:** the post extends at least one post-width above the rail and ends in a cap (a block slightly wider than the post, overhang <= 5%). **Post top and cap underside are both FLAT and sharp so they seat in a clean seam; only the cap's top edge is chamfered** (Sec. 4.5, rule 1). A rail never ends flush with the top of a post.
- **T-joint:** the crossing bar ends in the SIDE of the through bar (buried). **Corner:** one bar runs into the other, or both end in a mitre; never two raw ends meeting. **X-crossing:** avoid; one bar is continuous and the other is two buried stubs.
- **Hanging members** (braces, pendants, drops) join into the member above AND into the thing they rest on.
- **Never:** a bar that passes through another and sticks out the far side; a bar that stops short of its host (a gap); a bar wider than the host's flat face; two bars occupying the same space (coplanar overlap, z-fighting); a free end that was meant to be joined; a visible raw cut end where a joint should be.
- **Hex/tube members** (Sec. 4.3) obey the same rule: the end that meets a plate or body is buried (`cap_start=False` and the first segment starts inside the host).
- **Tags:** give each body that touches another body its own tag (post, rail, brace, cap), even if they share a color, so the checks can test each joint. Merge tags with the same Material afterwards if you like.
- **Checks:** `tk.audit_connections` (every joined end fully inside its host) and `tk.audit_clipping`, plus the orbit-and-zoom review (Sec. 0, step 5).

### 11.2 Where details go: the detail plan
Under-detailed objects fail as much as over-detailed ones. Decide detail deliberately, in this order, and write it into the spec as `detail_plan`:
- **L0 Masses:** the 2-4 big forms and their silhouette.
- **L1 Recognition features** (Sec. 3.2).
- **L2 Structure:** a transition piece at EVERY joint and end (a collar where an arm meets a plate, a socket or boss under a shade or head, a cap on a post top, a foot under a leg, a bracket under a shelf, a band where two materials meet), plus ONE operating detail on every functional part (a switch, handle, latch, dial, button).
- **L3 Character:** the wonk on hand-made parts, value variation between parts, the single accent.
**Every object reaches L2.** Where to spend detail, in priority order: (1) where parts meet; (2) the hero part, the working end that people look at or use, which gets about 40-50% of the triangles and at least 3 distinct features; (3) the ends and tops of members; (4) silhouette steps. **Large faces, backs and undersides stay plain** (a wall object's wall side gets nothing).
**Test:** point at every place two parts meet: is there a visible transition piece or a deliberate step? Point at the hero part: does it have 3 or more features? Point at the plain faces: are they large and quiet? If any answer is no, fix it before the review.

---

## 12. Spec template (output this for each new asset and wait for approval)

```yaml
asset_id: MSH_<Category>_<Name>_<Variant>
display_name: ""
interpretation: ""         # one line: how you read the request (canonical form)
biome: Mines | Manor | Office
recognition_features: []   # 2-4 features that make it nameable in gray (Sec. 3.2)
parts:                     # EVERY part, typed from the Sec. 11 grammar
  - {name: "", type: plate | block | round_body | bar | curved_member | shell | dome | stepped_base | hand_made | organic | emitter | mark | wrap | contents | attachment, tier: crisp | hand_made | organic | soft, edge: sharp | chamfer, section: oct8 | hex6 | box4 | none, host: "", tool: "", note: ""}   # section: bars = hex6, round bodies = oct8; host: the part a wrap sits on
detail_plan:                    # Sec. 11.2 (every object reaches L2)
  hero_part: ""                # the working end that gets about half the detail
  transition_pieces: []         # collar / bracket / socket / cap / foot at each joint
  operating_detail: ""          # switch, handle, latch, dial, button
joints: []                      # Sec. 11.1: each bar end as "bar -> host, buried 0.5w" or "free"
simplicity_justification: ""   # what ORNAMENT was deliberately left out (structural detail stays)
originality_note: ""       # how it differs from any reference/example it resembles
style_rules_applied: []    # cite section numbers
gameplay_role: dressing | interactable | hideable | lootable | light_source | architecture
description: >
  One paragraph visual description.
dimensions_studs: {x: 0, y: 0, z: 0}
pivot: bottom_center | back_center | hinge_edge
geometry:
  triangle_target: 0
  triangle_max: 0
  part_groups: 0
  bevel_segments_flat_edges: 1   # exactly 1
  tier_count: 0                  # max 2 stacked levels in a base
  solid_not_hollow: true
  color_regions: 0               # 2-3 preferred, 4 max
  curved_members: []             # each curve: segment count and smallest joint turn (>= 30 degrees)
  soft_parts: []                 # declared soft tags, normally 0 or 1 (2 only with a reason)
  soft_part_reason: ""           # why its curve is the recognition feature and deserves attention
  hand_made_parts: []            # tags that get the controlled wonk (Sec. 4.4), with the seed
  shading: all_flat_except_soft_parts
  crisp_audit: ""                # result of tk.audit_mesh / tk.audit_style (must be clean)
  value_steps: 0                 # 2-3
materials:                       # one entry per color/material REGION = one mesh each
  - mesh: ""
    part_type: metal | wood | cloth | paper | plastic | wax | clay | foliage | soil | emissive
    roblox_material: ""          # Enum.Material name
    color_hex: "#......"        # flat vertex color baked into the FBX
emissive: {has_emissive: false, color_hex: "", parts: [], light: {type: PointLight, range: 0, brightness: 0, color: "#......", shadows: false}}
textures: none
collision: {fidelity: Box | Hull | PreciseConvexDecomposition, proxy_parts: [], can_collide: true, anchored: true}
interaction: {prompt: {enabled: false, key: E, action_text: "", hold_duration: 0}, highlight_on_hover: false}
attributes: {Biome: "", Interactable: false}
```

---

## 13. Checklist (run honestly; list every failure)

**Process**
- [ ] First reply started with `Guide v20 read`; interpretation and `recognition_features` stated per object; spec with typed `parts:` approved before building.
- [ ] Built from scratch with the toolkit; real `tk.stats()` triangle counts reported (0 degenerate triangles).
- [ ] Reviewed in the Sec. 8.2 rig (Material Preview, not gray), including close-ups of corners and joints.
- [ ] Studio hand-off written for every group (Sec. 9.6); mesh names final.

**Style and shape**
- [ ] Recognition features present: someone without the label could name each object (Sec. 3.2); reads in a plain gray viewport.
- [ ] **Joinery (Sec. 11.1):** every bar end is buried in a host or declared free; posts carrying rails finish above them in a cap; nothing crosses through, floats, stops short, pokes out or overlaps in the same space; `tk.audit_connections` clean.
- [ ] **Detail plan (Sec. 11.2):** hero part with 3+ features; a transition piece at every joint; one operating detail; part count within Sec. 3.1; plain faces large; the object is not under-built.
- [ ] No ornament, no stepped/terraced rings, no domes built as hard-paneled cones, no tall fussy finials.
- [ ] Octagonal plans for round forms; flat edges have exactly 1-segment chamfers; base <= 2 levels; solid; overhang <= 5%.
- [ ] **Crisp by default (Sec. 4.2):** every part is flat-shaded with hard corners except the declared soft part(s) (at most 1, max 2 with a reason); plates have real corners; arms/posts are box or 8-sided sections, not smooth tubes; no more than 8 sides; no bevel/subdivision/smooth/weighted-normal modifiers.
- [ ] **Curves are facet chains (Sec. 4.3):** every bent member is a chain of straight segments with visible mitred joints, each joint >= 30 degrees, <= 6 segments per half circle.
- [ ] **Edge treatment decided per part (Sec. 4.5):** thin stock sharp; thick exposed solids one chamfer; seams (cap/post, lid/body, bar ends) flat and sharp with no groove; `edge:` stated per part.
- [ ] **Cross-sections (Sec. 4.5):** round bodies are octagons; every arm, hook, handle and ring is a hexagon (`sides=6`); stated per part in the spec.
- [ ] **Applied parts follow the host (Sec. 11, Wrap):** tape, straps, bands and stripes hug the host's faces and corner chamfers, do not float, overhang or hang off edges, and start and end on a face.
- [ ] **Hand-made parts are wonky (Sec. 4.4):** lean, uneven taper, uneven top, irregular facets; machined parts are exact; copies differ.
- [ ] **Audits clean:** `tk.audit_mesh` and `tk.audit_style` return no issues.
- [ ] **No clipping, no gaps (double-checked):** orbited every object from 4+ sides and above, zoomed on every joint and strip; `tk.audit_clipping` clean (tape and other wraps clip by <= 0.004 studs; buried joints by their declared depth only); nothing pokes through a surface or floats.
- [ ] Containers show their contents.
- [ ] True relative scale kept in the review scene (Sec. 7); silhouette readable at 20 studs.
- [ ] Same world, different object: not a copy of any reference or example.

**Materials and color**
- [ ] Roblox materials only: every mesh has ONE flat vertex color (exported in the FBX) + ONE built-in `Enum.Material` (set in Studio); no custom textures, `SurfaceAppearance` or `MaterialVariant`; no painted/gradient vertex colors; `Col` color attribute present on every mesh.
- [ ] Right Material on every part (Sec. 5 table); each color/material region is its own mesh.
- [ ] Muted earthy colors, 2-3 value steps, <= 4 color regions, <= 1 accent; emissive only on light sources/interactables; no pure black/white.

**Technical**
- [ ] Triangle count within the Sec. 9.1 budget; no hidden or interior faces.
- [ ] Pivot, scale (1 unit = 1 stud) and forward axis correct; bounding box verified.
- [ ] Collision fidelity/proxies set; dressing non-colliding where needed; naming and attributes done.
- [ ] Interactables have a visible affordance, ProximityPrompt configuration and hover highlight.

Also never: gore or blood decals, realistic weapons, real-world brand logos (invent in-universe marks), copied label text or logos from references.

---

## 14. Toolkit and examples

Both are plain Python files next to this guide. Load them in Blender through the MCP Python tool:

```python
import sys; sys.path.insert(0, "<folder containing toolkit and examples>")
import doors_toolkit as tk
import doors_examples as ex      # optional
```

**`toolkit/doors_toolkit.py` (generic building blocks; use these for any object):**
- `tk.Mesh()`, `tk.translate`, `tk.merge`, `tk.stats(m)` (triangles, bbox, signed volume, degenerate count).
- `tk.chamfer_box(m, lo, hi, c, tag, skip=())`: box with exactly one flat chamfer segment on every edge (44 tris). `tk.plain_box` for chamfer-free boxes.
- `tk.lathe(m, profile, tag, sides=8, cx, cy, z0, cap_bottom, cap_top)`: 8-sided revolve of a `[(r, z), ...]` profile, r = half flat-to-flat. Open shells (shades, bowls, cups) as outer wall, rim, inner wall, rim with both caps off.
- `tk.prism(m, poly, z0, z1, tag)`: extruded convex 2D polygon for flat chunky parts (hands, blades, label plates).
- `tk.slab(m, poly, z0, z1, tag, c=0.0, both=False)`: CRISP plate from a convex polygon. `c=0` is a plain prism; `c>0` adds exactly one flat 45-degree chamfer on the front edge. `tk.inset_poly` offsets a polygon inward.
- **Curves from facets (Sec. 4.3):** `tk.turtle(start, direction, axis, ops)` builds a bent path (`ops` = `("f", length)` and `("t", degrees)`); `tk.arc(center, radius, a0, a1, segs, plane)` builds a pure arc as a polyline; `tk.tube(m, pts, r, tag, sides=6, taper=1.0, cap_start=True, cap_end=True)` sweeps a chunky mitred hexagonal bar along the points (use `sides=6` for arms, hooks, handles and rings; `sides=8` is for round bodies). Both path helpers warn if a turn is below 30 degrees.
- **Edge decisions (Sec. 4.5):** `tk.edge_style(dims, role)` returns ("sharp", 0) or ("chamfer", c); `tk.auto_box(m, lo, hi, tag, role)` builds the box with that treatment; `tk.cut_rect(x0, y0, x1, y1, k)` gives the plan of a post with chamfered vertical edges (use with `tk.slab` so top and bottom stay flat).
- **Joinery (Sec. 11.1):** `tk.bar_between(m, p0, p1, w, tag, host0, host1, bury=None, c=0.0, h=None)` builds an axis-aligned bar whose ends run INTO named host tags (or "free"); `tk.audit_connections(m)` verifies every joined end sits fully inside its host.
- **Clipping check:** `tk.audit_clipping(m, [("tape", "carton"), ("arm", "backplate")], eps=0.004)` flags any vertex of the first tag that sits inside the closed host tag by more than `eps` studs (the overlap you allow; raise it only for a deliberately buried joint).
- **Applied strips (Sec. 11):** `tk.wrap_band(m, lo, hi, c, axis, pos, width, t, tag, edges=None, reach=1.0)` builds tape, straps and bands that hug a `chamfer_box` host. `edges` picks a run of the host's cross-section edges (e.g. `[2,3,4,5,6]` = over the top and down both sides), `reach` stops the strip partway down the side faces, `t` is the 1-3% offset.
- **Hand-made irregularity (Sec. 4.4):** `tk.wonky(m, tags, lean, taper, jitter, top_tilt, seed)` edits vertices in place. Only for hand-made parts.
- `tk.audit_mesh(m, soft_tags, organic_tags)`: pure-geometry check for accidental rounding and too-gentle curve joints (Sec. 4.2). `tk.audit_style(parts, soft_tags)` (Blender) checks shading and modifiers. `tk.export_fbx(path, group)` exports with face smoothing.
- `tk.to_blender(name, mesh, palette, location, smooth_tags)`: one Blender object per tag (named `<Name>_<Tag>` in PascalCase), grouped under an Empty, flat preview material and flat vertex color attribute `Col` (the color that travels in the FBX), custom properties `roblox_material` and `roblox_color`. `palette` is `{tag: (hex, "RobloxMaterial")}`; you define it per object (Sec. 5).
- `tk.export_fbx(path, group, colors_type="SRGB")` exports with the vertex colors; if the colors look too dark or too light in Studio, re-export with `colors_type="LINEAR"`.
- `tk.setup_review_rig`, `tk.luau_apply_script`, `tk.handoff_manifest`, `tk.write_handoff`.
- Geometry helpers need no Blender (testable anywhere); the Blender glue needs `bpy`.

**`examples/doors_examples.py` and `examples/EXAMPLES.md` (OPTIONAL; learn from them, do not clone them):** worked examples that show the rules in practice, each with notes on which part types and tiers it uses. `EXAMPLES.md` also holds object-specific cue lists, calibration tables and plant/candle details that used to be in the guide. They are illustrations, not recipes. Rules for using them:
- Design new objects with the Sec. 2 procedure, the Sec. 11 grammar and the toolkit. Use an example directly only when the user asks for exactly that object type, and say how your result differs from it (proportions, features, colors, seed).
- The examples are also a fallback: if your own build fails the Sec. 13 checklist, find the example closest in part types and study how it passes.
- Check `LEARNINGS.md` when a render fails: it lists failure modes seen in real tests and what fixes them.

**Untested glue:** `to_blender`, `make_materials`, `setup_review_rig` and `write_handoff` were written without access to Blender. If one errors, fix it minimally, say what you changed, and still do a colored, lit review.
