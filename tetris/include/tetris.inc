#if defined _tetris_included_
  #endinput
#endif
#define _tetris_included_
 
/**
 * Check if a player is currently playing tetris.
 *
 * @param client  Client index.
 * @return        True if the player is currently playing tetris, false otherwise.
 */
native bool IsClientInTetrisGame(int client);

/**
 * Called when a player finishes a tetris game.
 *
 * @param client         The client index of the player playing tetris.
 * @param iLevel         The tetris level the player was in.
 * @param iLines         The number of cleared lines.
 * @param iScore         The end score.
 * @param bNewHighscore  True if this is a new personal highscore of the player.
 * @noreturn
 */
forward void OnTetrisGameEnd(int client, int iLevel, int iLines, int iScore, bool bNewHighscore);

public SharedPlugin __pl_tetris = 
{
	name = "tetris",
	file = "tetris.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_tetris_SetNTVOptional()
{
	MarkNativeAsOptional("IsClientInTetrisGame");
}
#endif