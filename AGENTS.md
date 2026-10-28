# Notes for agents

Roblox game synced into Studio with Rojo (see README for setup and layout).
Only what isn't obvious from the code is listed here.

## The game

- The player runs a pawn shop: the `Grocery Store` model, which is also the
  lobby. Shop and pawn features belong in the store.
- The hotel-style elevator at the store's back is only transport. It descends
  to floors where players scavenge items, and the cargo lift sends those items
  up to the store. The owner rejected a pawn counter or merchant inside the
  elevator.
- The art direction is a warm, dark old hotel: atmospheric, slightly cartoonish
  but serious.

## Ground rules from the owner

- Keep changes scoped to what was asked. Working in one area (say, the shop)
  means changing nothing outside it. Leave layout, models and lighting alone
  unless asked.
- Anchor every part you create.
- Don't commit unless asked. Commit messages use short imperative subjects, like
  the existing history.
- Prefer free Creator Store models to props built from primitives. Load a model
  with `game:GetObjects("rbxassetid://ID")`, because `insert_asset` fails for
  models. Strip its scripts and Sounds before use.
- Don't build characters from primitives. The owner deleted a primitive-built
  elevator "being" and doesn't want it back; ask how a character should be
  sourced.
- Size things for a ~5-stud character. A 13-stud door was "far too tall"; the
  elevator door is 5.2 x 7.5.
- Don't spam one light fixture; mix the types. The owner cut 21 chandeliers
  down to a few.

## Building style

- Hand-built boxes (frames, panels, plates, shelves) get single-face 45°
  chamfered edges, not sharp corners. Cylinders and balls stay as they are.
  - Build each one from non-overlapping pieces: a core part, two `<name>_Strip`
    edge strips and four `<name>_Bevel` WedgeParts. The core keeps the name,
    attributes and children, and gets the attribute `Bevelled = true`.
  - Never use two crossed full-length cores; their coplanar faces z-fight.
  - If you resize a bevelled part, delete its `_Strip` / `_Bevel` siblings and
    rebuild them.
- The store's walls (`Grocery Store.PawnshopPaneling`) follow the elevator's
  wall design (`Elevator.Walls`). Both use the same trim stack, colours and
  bevel sizes, from the top down:
  - crown and crown step, frieze, brass picture rail
  - striped Fabric wallpaper
  - dado with a brass cap
  - wainscot panels with insets
  - baseboard
  Build new shop walls to match.
  - Outer corners are closed by `<name>_Miter` CSG fills: each trim runs past
    its end and is cut on the 45° line. Wherever two faces meet, add them, so
    trim never stops short and leaves a notch.
- Interaction prompts use Camera.client's popup, pinned to the object: a cream
  hand tapping it, with a key badge and the action text. Never use a
  bottom-of-screen prompt box.
  - Prompts are switched to `Style = Custom` automatically.
  - Every trigger plays a soft local click, unless the prompt sets
    `SkipInteractSound`.

## Code style

- StyLua (`stylua.toml`: tabs, 100 columns) and selene (`std = "roblox"`). Run
  them only on the files you changed. StyLua re-wraps untouched lines in files
  it never formatted (Journal.client is one), making noisy diffs.
- Every script opens with a plain-prose comment block. It says what the script
  does, who owns the state, and which attributes, tags and remotes it relies on.
  Keep that block current when behaviour changes. Inline comments explain *why*,
  not *what*.
- Tunables go in a config table at the top of the script, or in a shared
  `*Config` module when both client and server need them (see
  `src/shared/StockingConfig.luau`).
- Animations use TweenService or exponential smoothing (the journal book and
  camera follow use smoothing so they react to input instantly). Match the
  surrounding code.

## What lives only in the place file

The repo holds scripts only. Everything below exists only in the Studio place,
so edit it through Studio (MCP `execute_luau`) and wrap the edit in an undo
recording (`ChangeHistoryService:TryBeginRecording`):

- The shop, employee room, elevator and lobby models.
- `ReplicatedStorage.StockItems`: item template Models. Each is pivoted at its
  bottom centre with the front on LookVector, and has an `Extents` attribute.
- Stocking tags, attributes and the invisible `StockSlot` parts on the
  furniture (see below).
- `VolumetricBeam` tags, and the EmployeeRoom `Hinge` / `OpenAngle` /
  `SwingTime` / `Partner` attributes.
- `ServerStorage.WallShop`: floor 2's shop in a hole in the back wall. Levels
  cuts the hole from its `OpeningSize` attribute and clones it in on each visit.
  - It's pivoted at the bottom centre of the opening, on the wall's room face,
    with its front (-Z) facing the room.
  - The `Void` is black Neon so no light shows inside. Its parts start inside
    the wall's thickness; flush with the wall face they z-fight.
  - The owner is decorating the shop by hand, so leave its dressing alone.
    The shopkeeper entity is `Eyes` plus `Tentacles`.
  - WallShop.client animates the shopkeeper:
    - `Eyes` (tag `ShopEyes`) is saved hidden. The owner chose a cluster of
      mismatched eyes over two big ones: `Eye1`..`Eye7` models (`Size`
      attribute) around a `Root` that carries the Glow light.
      - The cluster opens within 22 studs and shuts past 26. The eyes open
        one after another (middle first), and each blinks and glances on its
        own: mostly at the player, sometimes anywhere. The pupils shrink as
        the player comes closer.
      - Each eye is a stack of sphere meshes. From the room inwards: `Pupil`
        (black SmoothPlastic, `Look` and `Pupil` attributes), a flattened
        `Iris` disc (Neon, `Look`), the `Sclera`, then a flattened `Halo`.
        `Look` parts slide across the eye to glance.
      - Keep the pupil in front of the iris's front face, and keep the sclera
        a dim grey-blue. A bright sclera blooms out the iris and pupil under
        the place's Bloom and DepthOfField.
      - The client keeps each saved mesh scale and multiplies blinks and
        pupil size on top.
    - `Effects` (tag `ShopEffects`) holds the `Mist`, `Dust` (`DustCloud`
      and `DustGrit`) and `Motes` emitters, saved off. The client switches
      them on while the shop is open, and an emitter's `Burst` attribute
      puffs out that many particles as it opens.
      - The dust only reads on the dark floor because it's partly self-lit
        (LightInfluence about 0.3).
      - While the player is close, the client also adds a local `ShopDread`
        ColorCorrection to Lighting, which desaturates and darkens the room.
    - Sounds are made by WallShop.client and play locally. The IDs are in its
      config, all checked as loading in this place:
      - two muffled loops (an EqualizerSoundEffect cuts the highs) that fade
        with the shop: the ambience bed 9114244977, slowed, and the swell
        9043337370, restarted from its start each time the eyes open;
      - breathing now and then: 9113983944, 9113984054 and 9113984056.
      The owner liked the ambience and asked for it looped and more muffled.
      They called the tentacle squirm and slap sounds "very bad", so the
      tentacles stay silent. TentacleRig.update still returns its "emerge"
      and "grip" events, unused.
    - `Tentacles` holds three copies (`Left`, `Right`, `Top`, tag
      `ShopTentacles`) of the free "Animated tentacles" rig (135280093987265).
      Each copy has 10 bone chains under one `RootPart`. Each copy's knot sits
      behind the wall beside or above the hole, so the tentacles reach in from
      the dark edges, never out of the eyes.
    - Shared.TentacleRig poses them. Its header documents the per-chain
      attributes: `Mode` (`Grip` / `Reach` / `Hidden`), `Way1`..`WayN`,
      `HookNormal`, `Sway`, `Speed` and `Phase`.
    - Five tentacles show, deliberately lopsided because the owner found a
      symmetric layout too perfect:
      - two on the left: one rising high, one sloping low;
      - one on the right at mid height;
      - two over the header, off-centre (x -3.1 and +1.4).
      The owner removed the two floor crawlers and found more tentacles too
      busy. The small chains are `Hidden`: from the knots they can't reach
      past the rim.
    - The owner wants thick, smooth, horn-like tentacles that show only about
      6 studs past the frame.
      - The side copies are scaled 3.3 and the top one 3.0, giving chains of
        about 27 and 25 studs. Their knots sit deeper, at x ±12, z 2.8 and
        y 12.6, z 2.2.
      - Each visible chain's `Length` attribute is its route length plus
        about 5.5 studs (4.5 on top). Only that much comes out; the rest
        stays drawn back behind the wall.
      - So whatever shows is the thick part near each tentacle's middle. If
        you change a route, reset its `Length`.
      - Resizing only the mesh (Handle10.Size) makes them thicker but lumpy
        at every joint, so scale the whole rig instead.
      - The side routes stop in front of the post and the tip carries on
        onto the wall. The top routes start just behind the wall above the
        hole.
      - The lower-left route is level (y about 3.7). Sloping down, its long
        tip dug into the floor.
    - Bones follow the leader along a smoothed curve, so no joint can fold
      back. Aiming each bone at a point a fixed distance along the route
      zigzagged, with 150° joints. Per-bone temporal smoothing made it worse;
      don't add it back.
    - The tip is whatever comes out past the route's end, now about 5 studs.
      It sweeps across slowly, curling one way, holding, then curling the
      other. The curl is capped so the end swings at most `TipSwing` (1.2
      studs) to each side, so long horns don't fling into each other.
    - The owner wants neighbours to move in different directions, so give
      each tentacle its own `Phase` and `Speed`, never a shared one. Tips curl
      about 1.7 studs to each side, so neighbours on the same wall need routes
      at least 4.5 studs apart.
    - The owner found slow emergence "way too slow" twice. Now a tentacle
      skips the hidden stretch of its route, appears at the hole within about
      0.4 s, and settles in about 1 s (CreepSpeed 11).
    - Each tentacle's hidden run-on is bent into the wall, along its route's
      backward direction plus the wall's depth. One that pointed slightly
      into the room left a withdrawn tentacle visible under the ceiling.
    - Emerging: the rig creeps each tentacle out at its own pace (`open` comes
      from the eyes' `wanted` flag, not their fade), staggered by `Phase`.
      The part not yet out lies straight back along the route's run-on: the
      root bone slides back that far, behind the wall.
      - A hidden fold-back loop made the chain skip across it, and the tips
        lunged into the room.
      - Moving a root stretches the knot's shared skin into spikes. That's
        only acceptable because it happens behind the wall, so never move a
        root while its tentacle is out.
    - Keep waypoints in front of the frame at z -1.45 or less. Closer, the
      tentacles cut into the posts and header.
    - Start each route with a waypoint inside the void, about 1.5 studs
      behind the hole. Without it, the curve cuts through the wall's corner.
      The top routes drop below the lintel (y 8.3) before coming out.
    - Check changes in a playtest over a full sweep cycle (~16 s), sampling
      bones from the client:
      - no bone inside the wall, posts, header, lintel or ceiling;
      - no two chains closer than 1.2 studs;
      - worst visible joint about 45°.
      Build the test room with Levels.build(2) at y 600, and pin the camera
      with a RenderStep bound after Camera.client.
- `Elevator.FloorSelector`: the floor-selector pedestal, saved in its *raised*
  pose. It vanished from the place once and had to be rebuilt; if it's
  missing, Elevator.server hangs on `WaitForChild` and the elevator stops
  working. Never give another model the name `Elevator`; scripts look it up with
  `WaitForChild("Elevator")`.
- `Elevator.ShaftWindow`: an invisible slab in the doorway between the iron
  gate and the wooden doors, front face into the car. ElevatorShaft.client
  runs the shaft wall through it during a ride.
- `Elevator.Doors`: the wooden leaves (`DoorLeft*` / `DoorRight*`, saved
  open, with `ClosedOffset` on the core part) run inside the car's front wall
  and slide into it when open. Keep them there: the storage room's back wall
  moved once and left them standing out in the room.

- The store: an `AmbienceZone` part (StoreAmbience.client), the `StoreRadio`
  on the Service Counter (Radio.server), and the `CargoCrate` / `CargoDrop`
  beside the freight door.
  - Collaborators move the store, so don't hardcode its position.
    - Its back wall still has to line up with the elevator, which never moves:
      the `ElevatorEntrance` centred on the car doorway (x -11.9) and the
      store's back wall in front of the car's front face (z -54.6). Moving the
      store 1.7 studs towards the elevator once pushed its wall through the
      car, hid the call panel and put the doors off-centre.
  - A decorative model named `Radio` also exists, so never look the radio up
    by that name.
  - `DoorTrigger`: an invisible part in the street doorway (east wall).
    DoorBell.client rings the entrance bell (the desk-bell asset pitched up;
    the owner rejected "Store Entry Bell 1") when a player walks through it
    from the street. Teleports (elevator arrival, respawn) stay silent.
  - `MuffleZone`-tagged invisible parts where RadioMuffle.client muffles the
    radio: `StorageZone` and `StaffZone` in the store, `ElevatorZone` in the
    `Elevator` model.
  - `ElevatorStoreBack` is an older, doorless copy of the elevator. It has to
    keep that name.
  - `ElevatorEntrance`: the hotel-style surround on the storage room's back
    wall (wood pilasters, brass frame, a floor dial parked on STORE). Its
    `Call Panel` model holds the `Call Plate` prompt and `Status Light`, which
    Elevator.server finds by name, so keep those names.

Before deleting or rebuilding anything in the place, look at what's there.
Parts have gone missing before (the employee-room window wall) and had to be
rebuilt from transcript data.

## Studio workflow

- Rojo isn't always connected. To push a script without it:
  1. Serve `src` locally with `python3 -m http.server 34877 --bind 127.0.0.1`.
  2. In Studio, read the file with `HttpService:GetAsync` and write it with
     `ScriptEditorService:UpdateSourceAsync`.
  3. Kill the server afterwards.
- Keep the repo and Studio copies identical. If you edit in Studio, mirror the
  edit back to the file.
  - Studio can be *ahead* of `src`. Before overwriting a script, compare the
    two and edit whichever is newer.
- Playtests run the script *editor* copy (`ScriptEditorService:GetEditorSource`),
  not `.Source`, because the place uses collaborative editing.
  - Always write with `UpdateSourceAsync`, then check that `GetEditorSource`
    equals `.Source`.
- **Rojo can delete Studio-only scripts.** `default.project.json` maps
  `src/server`, `src/client` and `src/shared` onto the whole of
  ServerScriptService, StarterPlayerScripts and `ReplicatedStorage.Shared`.
  Connecting Rojo from an old checkout wiped scripts that existed only in
  Studio.
  - Keep every script in `src` and committed.
  - This keeps happening: a collaborator's Rojo replaced Elevator.server with
    an old copy. Before a playtest, diff every Studio script against `src`.
    Merge any collaborator change found in Studio rather than overwriting it.
  - `ServerStorage.__Rojo_SessionLock` shows who is connected.
  - To recover, load an old place version with
    `game:GetObjects("http://www.roblox.com/asset/?id=89318278898862&version=N")`.
    This returns every service except Workspace.
- It's a Team Create place with other collaborators editing live.
- Playtests:
  - `solo_playtest`, then `eval_server_runtime` / `eval_client_runtime` and
    `simulate_keyboard_input`.
  - Always close an undo recording, even when the edit fails: run the body in
    `pcall`, then `FinishRecording` (Commit, or Cancel on error).
    - A script that errored between `TryBeginRecording` and `FinishRecording`
      once left a recording open. Every later `TryBeginRecording` then
      returned nil, so those edits made no undo steps and all sat inside the
      orphan. One undo rolled them all back: the wall shop "reset" to an old
      version, and its client script lost its rename.
    - Check with `ChangeHistoryService:IsRecordingInProgress()`. An orphan
      can't be finished without its ID, which is gone, so restart Studio to
      clear it.
    - `assets/WallShop.rbxm` is a backup of the wall shop template from
      then.
  - `solo_playtest` start needs `mode: "play"`. Without it the call fails
    with a bare "Unknown error".
  - While a playtest runs, `capture_screenshot` captures the play view, not
    the edit viewport.
  - The playtest server can restart on its own. If world state "vanishes",
    check uptime before calling it a bug.
- The owner tests with a regular R15 character. Calibrate arm and grip
  numbers against that rig.
- `workspace.StreamingEnabled` is on. Clients may not have far-away parts, so
  use `WaitForChild` or nil checks.

## Engine gotchas we've hit

- **ProximityPrompts:**
  - With `Exclusivity = OnePerButton`, E goes to the prompt nearest the centre
    of the screen.
  - Prompts off screen can't be triggered. Point the camera at the target
    before simulating E in a test.
  - The elevator call plate near *Rack West 1* also uses E.
  - **Line of sight:** a prompt whose object sits behind its own trim never
    shows if `RequiresLineOfSight` is true (the call plate's `ButtonRing`
    blocks its ray, as does the selector pedestal). Prompt scripts set it to
    `false` on purpose.
    - Camera.client once forced `true` on every prompt in the workspace. That
      hid the journal, call plate, floor selector, elevator chairs, bell and
      Send up button. It now applies only to prompts under
      `Grocery Store.Employee Area`, where through-the-wall use is a risk.
    - A prompt in that area can opt out with the `IgnoreSight` attribute. The
      journal, call plate and selector prompts set it too, so they stay safe if
      the scope is widened.
    - When a prompt's popup doesn't appear, raycast from the player's side to
      the prompt's part and see what it hits before blaming the script.
- **Tools:**
  - Setting `Tool.Grip` on the client does nothing because the weld is made on
    the server. Set Grip on the server.
  - For local-only motion (the reject shake), tween
    `RightHand.RightGrip.C1` instead.
- **Sounds:** some asset IDs log "not trusted for this place" (9120839581 did).
  Pro Sound Effects IDs (the cardboard sounds in StockingConfig) work. Check
  the output after adding a sound.
- **Picking a model's main part:** go by surface area, not volume. By volume
  you get kick plates and trim.
- **Playtest testing:**
  - A playtest started right after `UpdateSourceAsync` can still run the old
    code. Check for something new (a remote, an attribute) before you trust a
    result.
  - Moving an *anchored* character with `PivotTo` on the client doesn't
    replicate. The server still sees the old position and rejects prompts by
    distance, so unanchor the character first.
- **Viewmodels lead the camera:** Camera.client smooths the view, but the body
  turns with the raw mouse. Mid-turn, anything held in torso space is up to
  `MAX_LOOK_LAG` (15°) ahead of what the player sees.
  - To simulate a mouse turn, rotate `camera.CFrame` in a RenderStep bound at
    `Camera.Value - 1`. Rotating only the rendered camera never turns the body.
  - Measure viewmodel results in camera space.
- **Lighting:** never set `Sky.CelestialBodiesShown = false`. It blew out the
  elevator floor with an orange glow.
- **Fonts:** `rbxasset://fonts/families/Garamond.json` fails to load. Use
  `Font.fromEnum(Enum.Font.Garamond)` and set the weight on that.

## Systems and their contracts

### Arms (Arms.client / Arms.server)

- Two-bone IK on the R15 arms, solved in upper-torso space, blended over the
  Animator during PreSimulation.
- The right hand reaches for triggered prompts; Arms.server relays this over
  the `ArmReach` remote.
- Tool attributes, both in upper-torso space:
  - `HoldPoint` (Vector3): where the right hand holds the tool.
  - `LeftHoldPoint` (Vector3): makes the hold two-handed. While it's set,
    neither hand reaches for prompts.
  - Tools without them (the Candle) use the default one-handed hold.
- The held pose tilts by camera pitch × 0.6 about the right shoulder,
  (1, 0.563, 0) in torso space.

### Stocking (StockingService / StockingClient / StockItems / StockingConfig)

The server is authoritative. Clients only play visuals and decide which
prompts *they* see. Everything goes through the `ReplicatedStorage.Stocking`
RemoteEvent:

- Server → client: `Hold`, `Place`, `Close`, `Release`, `Reject`.
- Client → server: `PutDown`.

Tags and attributes:

| Tag | On | Attributes |
| --- | --- | --- |
| `StockBox` | The main `Box` part of a rack box | `ItemId` (a key in StockItems), `Count`, `Capacity`; the server sets `HeldBy` (UserId, 0 if free) |
| `StockFurniture` | The furniture Model | the server sets `FreeSlots` |
| *(none)* | `StockSlot` parts under the furniture | `Occupied`, `SlotIndex`, `SlotSize` (Vector3) |

- To add an item:
  1. Add a template Model to `ReplicatedStorage.StockItems`.
  2. Add an entry to `ITEMS` in `StockItems.luau`, with an optional
     `rotation`.
- `StockItems.create` scales items down to fit the slot.
- The held box is a server-built Tool:
  - It's always `BOX_HELD_SIZE`, whatever the rack box's size.
  - Its floor is the Handle.
  - Its flaps hang on `FlapHinge` welds, which clients tween.
- **`BOX_GRIP` is calibrated, not hand-written.** If you change
  `BOX_HOLD_CENTER`, `BOX_HELD_SIZE`, `BOX_HAND_GAP` or `BOX_HAND_DROP`, refit
  it in a playtest:
  1. Set Grip to identity.
  2. Measure the handle frame G in torso space.
  3. Build the desired floor frame D:
     `CFrame.new(S) * Angles(pitch) * CFrame.new(-S) * CFrame.new(CENTER) * Angles(20°) * CFrame.new(0, -h/2 + WALL/2, 0)`,
     where S is the right shoulder and `WALL = 0.035`.
  4. Set `grip = D:Inverse() * G`.
- The box is put back when the player dies, leaves, presses Q, equips another
  tool, or opens the journal (the `ReadingJournal` player attribute).

### Elevator and floor selector (Elevator.server / FloorSelector.client)

- The elevator never moves. During a ride the room outside the doors is
  swapped. `travel(target)` goes to any floor 0–8, where 0 is the store (lobby).
  - To sell the motion, ElevatorShaft.client streams a concrete shaft wall
    past the doorway from the `RideDir` (1 down, -1 up, 0 still), `RideStart`
    and `RideTime` attributes Elevator.server sets on the Elevator model.
  - While the elevator is down, the `Grocery Store` model is parked in
    ServerStorage and the lobby spawn is hidden.
  - Arriving back at 0 restores both.
- The elevator only leaves once someone has sent a floor from the selector and
  everyone is aboard. That includes the lobby: there is no auto-descend.
- The server owns the state, as attributes on `FloorSelector`:
  - `Selected`: 0 = STORE, 1–8.
  - `Sent`: the lever has been pulled.
  - `SendSeq`: bumped on each pull, so clients play the lever and bell.
  - `Busy`: the elevator is riding.
  - `Locked`: on a floor until `CargoLift.SendSeq` bumps. It isn't set when
    no cargo trips are left, or it would never unlock.
  - `Raised` and `FacingUserId`: whether it's up and who its head follows.
    The server decides these, so every player sees the same thing.
- Turning the dial:
  - E is the knob's prompt and turns right, to a deeper floor.
  - Q is the knob prompt's `AltKey` and turns left. It goes through the
    `SelectorTurn` remote, which checks the player's distance.
  - The dial clamps at both ends and skips the current floor.
  - The server ignores a turn within `TURN_COOLDOWN` (0.45s) of the last one,
    so mashing can't stack the 0.42s detent click. The knob prompt sets
    `SkipInteractSound`, because the dial's click is its feedback.
- The lever's prompt sends the selected floor (hold 0.5s).
- The server raises it while any player aboard is within 4.5 studs of the hatch
  (the owner wants it close), and lowers it once nobody is within 5.5.
  - It stays down while `Locked` or `Busy`, and from 1s after a send (time for
    the lever throw) until the ride ends.
  - The head follows the nearest player in range.
  - Turn and send are ignored unless `Raised`.
- FloorSelector.client animates all of that from the attributes, on every
  client at its own frame rate (server-side `PivotTo` looks choppy):
  - Each moving group (Pedestal, Head, Pointer, Lever, LeafL, LeafR) is posed
    from an invisible pivot part, using offsets recorded from the built pose.
  - The server never writes prompt `Enabled`; the client owns it.
- **Prompt `AltKey` attribute:** Camera.client draws a second key badge left
  of the prompt's own key, and gives it the same click and press. Arms.client
  reaches for the prompt on that key, as it does on a trigger. The prompt's
  script has to handle the key's action itself.

### Cargo lift (Cargo.server / CargoLift.client)

- The lift fills the centre bay of the elevator's back wall. Players load
  scavenged tools onto its car, and the send button carries them up to the
  store's `CargoCrate`.
- Each run gets `MAX_TRIPS` (3) trips.
- Cargo.server owns the rules. CargoLift.client does all the motion and sound
  locally; server-side `PivotTo` looked choppy. It reads these attributes:
  - `CargoLift.CargoValue`: the value aboard, shown on the drum counter.
  - `CargoLift.SendSeq` / `SendAt`: bumped when a trip starts, with its server
    time.
  - The timing attributes: `PressLead`, `GateTime`, `RideTime`, `TopPause`,
    `ReturnTime` and `Rise`.
  - `Elevator.CargoTripsLeft`: drives the trip lamps and the gate.
- Scavenged tools carry `ScavengedLevel`. Loading one marks it `Stored`.
- Any scavenged tool still held when the elevator leaves a floor is destroyed.
  Only cargo reaches the store.
- The owner found Bounce/Elastic easing too bouncy. Use a single small rebound
  (the `landing()` helper).
- Look parts up by name, not `PrimaryPart`. Team Create once dropped 23
  PrimaryPart refs.

### Other cross-script attributes

- `CrouchOffset` (Player, local only): the camera's crouch drop. Crouching only
  lowers the camera, so Arms.client lowers your own shoulders to match.
- `ReadingJournal` (Player): set while the journal is open. Camera.client
  holds pitch, Arms.client stops holding tools, and StockingClient puts the
  box down.
- `HasJournal` (Player): the player picked up the journal in the lobby.
