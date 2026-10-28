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
- `Elevator.FloorSelector`: the floor-selector pedestal, saved in its *raised*
  pose. It vanished from the place once and had to be rebuilt; if it's
  missing, Elevator.server hangs on `WaitForChild` and the elevator stops
  working. Never give another model the name `Elevator`; scripts look it up with
  `WaitForChild("Elevator")`.

- The store: an `AmbienceZone` part (StoreAmbience.client), the `StoreRadio`
  on the Service Counter (Radio.server), and the `CargoCrate` / `CargoDrop`
  beside the freight door.
  - Collaborators move the store, so don't hardcode its position.
  - A decorative model named `Radio` also exists, so never look the radio up
    by that name.
  - `DoorTrigger`: an invisible part in the street doorway (east wall).
    DoorBell.client rings the entrance bell (the desk-bell asset pitched up;
    the owner rejected "Store Entry Bell 1") when a player walks through it
    from the street. Teleports (elevator arrival, respawn) stay silent.
  - `ElevatorStoreBack` is an older, doorless copy of the elevator. It has to
    keep that name.
  - `StorageRacks` in the elevator room: the shelves StockRacks fills.
  - The `SwingDoor` models (the golden pair into the storage room), with an
    `OpenAngle` attribute, swung by SwingDoors.client. It only pushes them for
    players, so customers walk through them shut.
  - The customers' helper parts, all invisible and anchored: `CustomerSpawn`
    (street), `CounterSpot_1` / `CounterSpot_2` (on the Service Counter) and
    `CustomerQueue`. CustomerUtil rebuilds any that are missing from the
    store's geometry. The `StaffZone` / `StorageZone` parts keep customers out
    of the back rooms.
  - The three papers on the break room's cork board, tagged `ShopNote` with a
    `Shows` attribute (`Day`, `Quota`, `Money`). ShopHUD writes on them.

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

- Cargo.server hands delivered items to `StockRacks` (a server module), which
  puts each on a free spot of a shelf board in `ElevatorRoom.StorageRacks`
  (`SPOTS_PER_SHELF` per board) and tags it `RackItem`. If every rack is full,
  items go to `ServerStorage.DeliveredCargo`.
- A rack item's Take prompt gives the player a Tool (Handle = a copy of the
  item, attributes `ShopItem`, `ItemId`). If the tool is lost without being
  stocked (death, leaving), the item goes back on a rack.
- A furniture's Stock prompt shows while you hold a `ShopItem` tool and the
  furniture has `FreeSlots`. It places the item in the next free slot at once.

| Tag | On | Attributes |
| --- | --- | --- |
| `RackItem` | An item part on a storage rack (set by StockRacks) | `ItemId`, `Value`, `RestOffset` |
| `StockFurniture` | The furniture Model | the server sets `FreeSlots` |
| `StockSlot` | Invisible slot parts under the furniture | `Occupied`, `SlotIndex`, `SlotSize` (Vector3) |

- To add an item:
  1. Add a template Model to `ReplicatedStorage.StockItems`.
  2. Add an entry to `ITEMS` in `StockItems.luau`, with an optional
     `rotation`.
- `StockItems.create` scales items down to fit the slot.
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
