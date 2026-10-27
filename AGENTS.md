# Notes for agents

Roblox game synced into Studio with Rojo (see README for setup and layout).
Only what isn't obvious from the code is listed here.

## Ground rules from the owner

- Keep changes scoped to what was asked. Working in one area (say, the shop)
  means changing nothing outside it. Leave layout, models and lighting alone
  unless asked.
- Anchor every part you create.
- Don't commit unless asked. Commit messages use short imperative subjects, like
  the existing history.

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

### Other cross-script attributes

- `CrouchOffset` (Player, local only): the camera's crouch drop. Crouching only
  lowers the camera, so Arms.client lowers your own shoulders to match.
- `ReadingJournal` (Player): set while the journal is open. Camera.client
  holds pitch, Arms.client stops holding tools, and StockingClient puts the
  box down.
- `HasJournal` (Player): the player picked up the journal in the lobby.
