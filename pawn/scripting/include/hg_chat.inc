// Include protection
#if defined _hg_chat_included
  #endinput
#endif
#define _hg_chat_included

/**
 * Returns whether or not a client is gagged
 *
 * @param client     Client Index.
 * @return           Is a client gagged.
 */
native bool:HG_IsClientGagged(client);

/**
 * Returns whether or not a client is gagged
 *
 * @param client     Client Index.
 * @return           Is a client gagged.
 */
native bool:HG_IsClientMuted(client);


public SharedPlugin:__pl_hg_chat = 
{
	name = "hg_chat",
	file = "hg_chat.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_hg_chat_SetNTVOptional()
{
	MarkNativeAsOptional("HG_IsClientGagged");
	MarkNativeAsOptional("HG_IsClientMuted");
}
#endif

