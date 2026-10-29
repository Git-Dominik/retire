-- Player movement speeds (studs/s). Camera.client drives the character with them;
-- the server's Noise module reads them back off the character's speed to tell
-- crouching, walking and sprinting apart.

return {
	CROUCH_SPEED = 5.6,
	WALK_SPEED = 10.2,
	SPRINT_SPEED = 18.5,
}
