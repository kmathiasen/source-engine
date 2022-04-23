// Include protection
#if defined _hg_premium_included
  #endinput
#endif
#define _hg_premium_included

 
/**
 * Gives a client HG Bux.
 *
 * @param client    Client Index.
 * @param rep       Integer Amount.
 * @param message   Display chat message.
 * @noreturn
 */
native Premium_AddPoints(client, rep, message=true);

/**
 * Returns a client's HG Bux.
 *
 * @param client     Client Index.
 * @return           Player's HG Bux.
 */
native Premium_GetPoints(client);

/**
 * Overrides a player's trail.
 *
 * @param client    Client Index.
 * @param trail     Trail Filepath.
 * @noreturn
 */
native Premium_OverrideTrail(client, String:trail[]);


public SharedPlugin:__pl_hg_premium = 
{
	name = "hg_premium",
	file = "hg_premium.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_hg_premium_SetNTVOptional()
{
	MarkNativeAsOptional("Premium_OverrideTrail");
	MarkNativeAsOptional("Premium_AddPoints");
	MarkNativeAsOptional("Premium_GetPoints");
}
#endif
