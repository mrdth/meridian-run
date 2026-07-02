extends Node
# Global game-flow signals (typed, past-tense). D8: GLOBAL flow ONLY here;
# local/intra-entity comms use direct signals. Add signals as systems land.

signal run_started
signal wave_cleared(wave: int)
signal ship_lost(remaining: int)
signal build_changed
signal score_changed(score: int)
signal game_over
