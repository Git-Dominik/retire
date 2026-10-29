# MSH_Vehicle_Forklift_A

Built to DOORS_ASSET_GUIDE v18, proportioned off the side reference (~96 px per stud).
Size 4.22 x 6.70 x 11.05 studs (W x H x L), pivot bottom centre, forks toward -Y in Blender
(-Z / front in Roblox). 1,848 triangles in total.

| Mesh | Roblox Material | Vertex colour | Tris |
| --- | --- | --- | --- |
| Forklift_Frame (chassis, cowl, deck, seat base, axles, mast, forks, roof hoops and slats, steering) | DiamondPlate | #3A3530 | 1044 |
| Forklift_Paint (body with counterweight and rear wheel arch, hubs) | Metal | #B8892E | 300 |
| Forklift_Tyres (tyres, fuel caps) | Rubber | #262220 | 296 |
| Forklift_Seat (one L-shaped seat with a leaning back, two grab grips) | Leather | #5A4A3E | 208 |

Every MeshPart: `Color` = 255, 255, 255 (the colour is in the FBX), Anchored, CanTouch off,
CollisionFidelity Box. Attributes on the model: `Biome = Mines`, `Interactable = false`.
If DiamondPlate looks too busy on the frame, use Metal.

Joints: where two parts meet, the smaller one's contact face is left unchamfered and sits on the
host's flat face, so no chamfer groove opens at the seam.
