# Notes for agents

Roblox game whose scripts live in `src` and are synced into Studio through the
Roblox MCP (see Studio workflow). Only what isn't obvious from the code is listed
here.

**After every feature, update this file**: add what a later agent needs and
can't read off the code (cross-script contracts, place-only setup, owner
decisions, gotchas hit). Keep it short and fix anything it made stale.

## The game

- The player runs a pawn shop: the `Grocery Store` model, which is also the
  lobby. Shop and pawn features belong in the store.
- The hotel-style elevator at the store's back is only transport. It descends
  to floors where players scavenge items, and the cargo lift sends those items
  up to the store. The owner rejected a pawn counter or merchant inside the
  elevator.

## Ground rules from the owner

- Keep changes scoped to what was asked. Working in one area (say, the shop)
  means changing nothing outside it. Leave layout, models and lighting alone
  unless asked.
- Anchor every part you create.
- Don't commit unless asked. Commit messages use short imperative subjects, like
  the existing history.
- Don't spam one light fixture; mix the types. The owner cut 21 chandeliers
  down to a few.

## Interaction prompts

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
      - Each eye's parts are found by name: `Pupil` (attributes `Look`,
        `Pupil`), `Iris` (`Look`), `Sclera`, `Halo`. `Look` parts slide across
        the eye to glance. The client keeps each saved mesh scale and
        multiplies blinks and pupil size on top.
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
    - Each visible chain's `Length` attribute is its route length plus about 5.5
      studs (4.5 on top). Only that much comes out; the rest stays drawn back
      behind the wall. If you change a route, reset its `Length`.
    - The side routes stop in front of the post and the tip carries on onto the
      wall. The top routes start just behind the wall above the hole.
    - The lower-left route is level (y about 3.7). Sloping down, its long tip dug
      into the floor.
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
  - `StorageRacks` in the elevator room: the shelves StockRacks fills.
  - The `SwingDoor` models (the golden pair into the storage room, the street
    entrance and the staff room door), with an `OpenAngle` attribute, swung by
    SwingDoors.client. It only pushes them for players, so customers walk
    through them shut.
  - The customers' helper parts, all invisible and anchored: `CustomerSpawn`
    (street), `CounterSpot_1` / `CounterSpot_2` (on the Service Counter) and
    `CustomerQueue`. CustomerUtil rebuilds any that are missing from the
    store's geometry. The `StaffZone` / `StorageZone` parts keep customers out
    of the back rooms.
  - The three papers on the break room's cork board, tagged `ShopNote` with a
    `Shows` attribute (`Day`, `Quota`, `Money`). ShopHUD writes on them.
  - `ElevatorEntrance`: the hotel-style surround on the storage room's back
    wall (wood pilasters, brass frame, a floor dial parked on STORE). Its
    `Call Panel` model holds the `Call Plate` prompt and `Status Light`, which
    Elevator.server finds by name, so keep those names.

Before deleting or rebuilding anything in the place, look at what's there.
Parts have gone missing before (the employee-room window wall) and had to be
rebuilt from transcript data.

## Studio workflow

- **Don't use Rojo.** Sync through the Roblox MCP instead. Rojo maps `src`
  onto the whole of ServerScriptService, StarterPlayerScripts and
  `ReplicatedStorage.Shared`, and it has wiped Studio-only scripts and put old
  copies back (Elevator.server) before. To recover from that, load an old
  place version with
  `game:GetObjects("http://www.roblox.com/asset/?id=89318278898862&version=N")`
  (every service except Workspace).
- **Compare before you write.** Collaborators edit Studio live, so Studio is
  often *ahead* of `src`, and some scripts exist only in Studio. Before pushing,
  hash every script's `GetEditorSource` in Studio (`execute_luau`) against the
  files in `src`. For each script you're about to change:
  - Studio matches `src`: push yours.
  - Studio differs: pull Studio's copy into `src` first, then make your change
    on top of it. Never overwrite a collaborator's change.
  - Leave scripts you aren't changing alone, but mention any drift you saw.
- **Pushing** (`src` → Studio):
  1. Serve `src` locally with `python3 -m http.server 34877 --bind 127.0.0.1`.
  2. In Studio, read the file with `HttpService:GetAsync` and write it with
     `ScriptEditorService:UpdateSourceAsync`.
  3. Check that `GetEditorSource` equals `.Source` (playtests run the editor
     copy, because the place uses collaborative editing), then kill the server.
- **Pulling** (Studio → `src`): serve `src` with a small server that also
  accepts POST, and `HttpService:PostAsync` the `GetEditorSource` text to it.
- Wrap place edits (models, colours, templates) in a
  `ChangeHistoryService:TryBeginRecording` undo step.
- It's a Team Create place with other collaborators editing live.
- Playtests:
  - `solo_playtest`, then `eval_server_runtime` / `eval_client_runtime` and
    `simulate_keyboard_input`.
  - `simulate_keyboard_input` sometimes fails outright. `prompt:InputHoldBegin()`
    from `eval_client_runtime` works once the prompt has been shown (camera aimed
    at it, line of sight clear).
  - Shoplifters will take test stock you leave on shop furniture.
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

### Stocking (StockingService / StockingClient / StockRacks / StockItems / StockingConfig)

The server is authoritative. StockingClient only decides which Stock prompts
*this* player sees. There are no boxes and no placement animation.

- Cargo.server hands delivered items to `StockRacks` (a server module). It
  stocks each into a free slot of the big racks first (`LargeShelf_1/2`,
  StockFurniture under `ElevatorRoom.StorageRacks`). After that, small items go
  on a plain shelf board (`SPOTS_PER_SHELF` per board, tagged `RackItem`).
  Anything left over goes to `ServerStorage.DeliveredCargo`.
  - The LargeShelfs take cargo only: the owner doesn't want players stocking
    them, so they get Take prompts but no Stock prompt.
- A rack item's Take prompt gives the player a Tool (Handle = a copy of the
  item, attributes `ShopItem`, `ItemId`). If the tool is lost without being
  stocked or sold (death, leaving), the item goes back on a rack. A tool marked
  `Stocked` or `Sold` is destroyed with its item.
- A furniture's Stock prompt shows while you hold a `ShopItem` tool and the
  furniture has a free slot that item fits. It places the item there at once.
- Every filled slot has a Take prompt (`ShelfTakePrompt`), shown while your
  hands are empty. It lifts the item back off into a tool (via
  `Levels.placeItem`), so items can be moved or handed to a request client.
- **Prompt placement.** StockingService sets `RequiresLineOfSight` on its
  prompts, so prompts hang from attachments in front of everything, not inside
  the furniture. Stock goes on `StockPoint`, at the next free slot. Each take
  prompt goes on its slot's `ShelfTakePoint`, and moves when the slot fills or
  empties.
  - The front is chosen by which way along the slot's front axis has more room
    before anything solid, because some slots face *into* their furniture.
  - Behind glass, the point goes just above the case.
- Roblox doesn't draw Glass behind Glass, so `StockItems.create` swaps Glass
  pieces for see-through plastic. Before this, the bottle vanished in the cases.

| Tag | On | Attributes |
| --- | --- | --- |
| `RackItem` | An item part on a storage rack (set by StockRacks) | `ItemId`, `Value`, `RestOffset` |
| `StockFurniture` | The furniture Model | the server sets `FreeSlots` |
| `StockSlot` | Invisible slot parts under the furniture | `Occupied`, `SlotIndex`, `SlotSize` (Vector3) |

- To add an item:
  1. Add a template Model to `ReplicatedStorage.StockItems`, pivoted at the
     bottom centre with the front on LookVector, and an `Extents` attribute.
  2. Add an entry to `ITEMS` in `StockItems.luau`, with an optional
     `rotation`, a `size` and placeholder `floorIds`.
- **Item sizes.** `size = "Small"` (the default) is up to 1×1 stud and
  `"Large"` is up to 2×2. `StockItems.fits` only lets a large item into a slot
  whose `SlotSize` is at least 1.5 studs both ways, which means the Display
  Stands in the shop and the LargeShelfs. Within that, `StockItems.create`
  scales items down to fit the slot.
- **Large items on the floors.** They never use a floor's regular 1×1 item
  spot.
  - Instead they spawn on parts tagged `LargeItemSpawn`. Each is invisible and
    anchored, and its top face is the resting surface.
  - The parts have to sit inside a template that gets cloned into a room (for
    example `ServerStorage.WallShop` on floor 2), because rooms are rebuilt on
    every visit.
  - When a room has any, there's a `LARGE_ITEM_CHANCE` (in Levels) that the
    floor's item is a large one on a random point.
  - The owner places these points by hand.
- Backspace (Camera.client → the `DropItem` remote) drops a held shop item or
  scavenged item in front of the player. The server sets the tool's `DropAt`
  and destroys it, and whoever built the tool puts the item down there.
  Dropped shop items are tagged `DroppedItem` and can be taken again.
- Each item has a `value` (what the cargo lift pays the player) and a
  `basePrice` (what customers pay for it at the counter).
- The F2 dev menu spawns any item at your feet by ItemId or name.

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
  store's storage racks (StockRacks).
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

### Shop day (DayNightService / CustomerService / CounterService / QuotaService)

All tunables are in `src/shared/ShopConfig.luau`. Each script's header block
has the details; this is the part that crosses scripts.

- **Clock.** DayNightService owns it and publishes an anchor on workspace:
  `ClockAnchorTime`, `ClockAnchorHour`, `DayLength` and `ClockPaused`. Clients
  (DayNightClient, ShopHUD) work out the hour every frame from it.
  - To jump the clock in a test, set `ClockAnchorTime` and `ClockAnchorHour`
    together. The server reads them back every tick.
  - workspace `Phase` (`Day` 07:00–19:00, `Night` the rest) and `DayNumber`.
    The PhaseChanged remote fires on each change.
  - The server starts paused at 22:00, the night before Day 1. Day 1 dawns
    the first time `Elevator.Level` returns to 0 (the first trip back up). To
    fake it in a test, set `Level` above 0 and back to 0.
  - Only the outdoor look changes: DayNightClient tweens Lighting and
    Atmosphere between the place's saved values and ShopConfig's night tables.
    The OPEN sign goes dark at night: its `Flicker` script is disabled and the
    parts with a `NeonColor` attribute drop to Glass.
  - The day count shows on the journal's first page and the cork board. Both
    read `DayNumber`.
- **Customers** (CustomerService, with CustomerUtil, CustomerAvatar,
  ShoplifterService):
  - They come by day, only while the store is in the world and the shop hasn't
    failed. There are never more customers than unsold items (on the shop
    furniture or in a customer's hands), capped by the per-player limit.
  - They only browse furniture inside `AmbienceZone` and outside the
    `StaffZone` / `StorageZone` parts. Furniture with `StaffOnly = true` (the
    shelves behind the counter) is skipped too. Shelving West 3/4 sit outside
    the building and were reachable only by walking around.
  - `CustomerUtil.walkTo` sweeps every leg of a path with spheres before
    walking it. The navmesh cuts corners: paths clipped Wall Case East's
    cabinet and the unnamed pillar (`Grocery Store.Part`) near the island. A
    blocked leg gets a detour point beside the obstacle. With no clear route
    the customer doesn't move and `walkTo` returns false.
  - Each one looks like a random friend of a player in the server. Hats are
    stripped, so the shoplifters' grey hat is the only one. The fallback
    presets are in ShopConfig.
  - They're server-owned NPCs in the `Customers` collision group, which
    doesn't collide with `Players`. Welding a carried item hands the assembly
    to a nearby player, so `CustomerUtil.attach` re-asserts
    `SetNetworkOwner(nil)`.
  - Clients see the `Customer` tag in `workspace.Customers`, with the
    `DisplayName`, `Bubble` and `BubbleMood` attributes (CustomerVisuals).
- **Checkout** (CounterService): the players' only job is restocking. The
  owner scrapped haggling as too boring, so don't bring back a counter prompt
  or a player behind the counter.
  - A customer sets their item on a free `CounterSpot_<n>`, waits
    `CHECKOUT_TIME` with the price in a bubble (the spot's `PriceText`), and
    pays the item's `basePrice` by themselves.
  - The sale runs in the customer's own thread, so one sent home mid-checkout
    never pays.
- **Item requests** (QuestService, with QuestClient and the journal's Requests
  pages). At dawn, a client may ask for one item by a due day. Tunables are in
  ShopConfig's QUESTS section.
  - On the due day the client walks straight to the counter and asks for it.
    Players fetch the item (from the racks or with a shelf Take prompt) and
    hold **Sell** on the client's spot (`QuestSellPrompt`). The prompt only
    shows to whoever holds that item.
  - This is the owner's one exception to "no counter prompt". Normal customers
    still pay by themselves, and never want an item that has an active request.
  - The server validates the held item, the player's distance and the client.
    It completes and pays without yielding, so the reward is paid once.
  - Failing a request costs only the reward, never a strike.
  - Clients read `ReplicatedStorage.QuestList` (JSON). Nothing is saved.
  - `floorIds` on items say which floors to look on. They're placeholders, and
    Levels doesn't read them.
- **Quota** (QuotaService): ReplicatedStorage attributes `ShopMoney`,
  `DayEarnings`, `Quota`, `DaySales`, `DayWalkouts`, `DayStolenValue`,
  `Strikes`, `MaxStrikes` and `ShopFailed`. Nothing is saved.
  - Three seconds after dusk the day is judged: `DaySummary` goes to every
    client, and a missed quota is a strike.
  - At `MaxStrikes` the `ShopFailed` remote fires and `onShopFailed()` runs.
    It's an empty hook for the game-over screen.

### Other cross-script attributes

- `CrouchOffset` (Player, local only): the camera's crouch drop. Crouching only
  lowers the camera, so Arms.client lowers your own shoulders to match.
- `ReadingJournal` (Player): set while the journal is open. Camera.client
  holds pitch, Arms.client stops holding tools, and StockingClient puts the
  box down.
- `HasJournal` (Player): the player picked up the journal in the lobby.
