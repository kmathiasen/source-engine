// Include protection
#if defined _hg_jbaio_included
  #endinput
#endif
#define _hg_jbaio_included

// Game definitions.
#define JB_GAMETYPE_NONE   0
#define JB_GAMETYPE_CSS    1 << 0
#define JB_GAMETYPE_CSGO   1 << 1
#define JB_GAMETYPE_TF2    1 << 2
#define JB_GAMETYPE_ALL    JB_GAMETYPE_CSS|JB_GAMETYPE_CSGO|JB_GAMETYPE_TF2

/**
 * Gives a client Prison Rep.
 *
 * @param client    Client Index.
 * @param rep       Integer Amount.
 * @param message   Display chat message.
 * @noreturn
 */
native PrisonRep_AddPoints(client, rep, message=true, game=JB_GAMETYPE_NONE);

/**
 * Returns a client's Prison Rep.
 *
 * @param client     Client Index.
 * @param game       Which game (JB_GAMETYPE_CSS, JB_GAMETYPE_CSGO, JB_GAMETYPE_TF2) to retrieve rep from. Leave as JB_GAMETYPE_NONE for current game
 * @return           Player's Prison Rep.
 */
native PrisonRep_GetPoints(client, game=JB_GAMETYPE_NONE);

/**
 * Adds Prison Rep to an offline player.
 *
 * @param steamid    Steamid.
 * @param amount     Integer Amount.
 * @param game       Which game (JB_GAMETYPE_CSS, JB_GAMETYPE_CSGO, JB_GAMETYPE_TF2) to add rep to. Leave as JB_GAMETYPE_NONE for current game
 * @noreturn
 */
native PrisonRep_AddPoints_Offline(String:steamid[], rep, game=JB_GAMETYPE_NONE);


/**
 * Returns whether or not a client is gagged
 *
 * @param client     Client Index.
 * @return           Is a client gagged.
 */
native bool:JB_IsClientGagged(client);

/**
 * Returns whether or not a client is actually alive (not in deathmatch)
 *
 * @param client    Client Index.
 * @return          Is a client truly alive
 */
native bool:JB_IsPlayerAlive(client);

/**
 * Respawn a player, with the proper death match handling.
 *
 * @param client    Client Index.
 */
native JB_RespawnPlayer(client);

/**
 * Don't give a weapon extra ammo when it's picked up
 *
 * @param entity    Entity Index.
 */
native JB_DontGiveAmmo(entity);

public SharedPlugin:__pl_hg_jbaio = 
{
    name = "hg_jbaio",
    file = "hg_jbaio.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_hg_jbaio_SetNTVOptional()
{
    MarkNativeAsOptional("PrisonRep_AddPoints");
    MarkNativeAsOptional("PrisonRep_AddPoints_Offline");
    MarkNativeAsOptional("PrisonRep_GetPoints");
    MarkNativeAsOptional("JB_IsClientGagged");
    MarkNativeAsOptional("JB_IsPlayerAlive");
    MarkNativeAsOptional("JB_DontGiveAmmo");
}
#endif
