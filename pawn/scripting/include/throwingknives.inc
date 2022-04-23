#if defined _cssthrowingknives_included_
  #endinput
#endif
#define _cssthrowingknives_included_
 
/**
 * Sets a clients throwing knife count
 *
 * @param client  Client index
 * @param num     Number of knives
 * @return        No return
 */
native SetClientThrowingKnives(client, num);

/**
 * Gets a clients throwing knife count
 *
 * @param client  Client index
 * @return        Knife count
 */
native GetClientThrowingKnives(client);

/**
 * Gets if an entity is a throwing knife
 *
 * @param entity  Entity Index
 * @return        true if entity is a throwing knife
 */
native bool:IsEntityThrowingKnife(entity);

public SharedPlugin:__pl_cssthrowingknives = {

	name = "cssthrowingknives",
	file = "cssthrowingknives.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_cssthrowingknives_SetNTVOptional() {

	MarkNativeAsOptional("SetClientThrowingKnives");
	MarkNativeAsOptional("GetClientThrowingKnives");
}
#endif