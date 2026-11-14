--!strict
-- Particle sprites in the UI's cartoon style (tools/fx/sprites.py; white, so each emitter tints them): image ids
-- (0 = the engine's default sprite), and how hit bursts throw chunks.

return table.freeze({
	Puff = 98362219688196, -- a bumpy smoke puff: hit bursts, collapse dust
	Star = 108910218818846, -- a four-point sparkle: the stars on a hit
	Chunk = 90654646129975, -- a broken brick chunk thrown out of a hit burst
	ChunkShare = 0.35, -- chunks per burst particle
	ChunkGravity = 70,
})
