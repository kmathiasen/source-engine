
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// Trie to hold the weapon ID of the dropped gun and the client ID of the Guard who dropped it.
new Handle:g_hDroppedWeapons = INVALID_HANDLE;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

GunPlant_OnPluginStart()
{
    g_hDroppedWeapons = CreateTrie();
}

GunPlant_OnRndStart_General()
{
    ClearTrie(g_hDroppedWeapons);
}

GunPlant_OnDropWeapon(client, wepid, slot)
{
    // Only track primary and secondary weapons.
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */
    if ((slot != 0) && (slot!= 1)) return;

    // Track the weapon ID.
    if (IsValidEntity(wepid))
    {
        // Don't worry about it being a gunplant if dropped in the armory.
        // The armory is a place where people drob all kinds of guns to switch to the guns they want.
        if (MapCoords_IsInRoomEz(wepid, "Armory")) return;

        // Trie's need to use strings as their key; not numbers.
        decl String:wepid_tostring[LEN_INTSTRING];
        IntToString(wepid, wepid_tostring, sizeof(wepid_tostring));

        // The key will be the weapon ID, and the value will be which guard dropped it.
        SetTrieValue(g_hDroppedWeapons, wepid_tostring, client);
      //PrintToChat(client, "%s DEBUG: You dropped weapon %i", MSG_PREFIX, wepid);

        // Track weapon ID for a little while.  The duration is from the settings.
        new Float:dur = GetConVarFloat(g_hCvGunplantTrackSeconds);
        CreateTimer(dur, GunPlant_RemoveDroppedWeapon, wepid, TIMER_FLAG_NO_MAPCHANGE);
    }
}

bool:GunPlant_OnItemPickup(client, wepid, slot)
{
  //PrintToChatAll("%s DEBUG: %N picked up %s (id %i), in slot %i", MSG_PREFIX, client, itemname, wepid, slot);

    // Only track primary and secondary weapons.
    /*
        0 = primary
        1 = secondary
        2 = knife
        3 = nade(s)
        4 = c4
        5 = other items
    */
    if ((slot != 0) && (slot!= 1)) return false;

    // This is only applicable when a prisoner picks up a weapon.
    if (GetClientTeam(client) != TEAM_PRISONERS) return false;

    // Trie's need to use strings as their key; not numbers.
    decl String:wepid_tostring[LEN_INTSTRING];
    IntToString(wepid, wepid_tostring, LEN_INTSTRING);

    // Is this item in the Trie of tracked dropped weapons?  If so get which client dropped it.
    new dropper;
    if (!GetTrieValue(g_hDroppedWeapons, wepid_tostring, dropper)) return false;

    // Punish the dropper by teleporting him to the electric chair.
    if (JB_IsPlayerAlive(dropper))
    {
        // Try to tele client to electric chair.
        if (Tele_DoClient(0, dropper, "Electric Chair", false))
        {
            PrintToChatAll("%s \x03%N\x04 was teleported to \x03the electric chair for Gun Planting", MSG_PREFIX, dropper);
        }
        else
        {
            ForcePlayerSuicide(dropper);
            PrintToChatAll("%s \x03%N\x04 was slayed for Gun Planting", MSG_PREFIX, dropper);
        }
    }

    // Strip this weapon from the Prisoner.
    if (g_iGame == GAMETYPE_TF2)
        return true;

    else if (IsValidEntity(wepid))
        RemovePlayerItem(client, wepid);

    return false;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

public Action:GunPlant_RemoveDroppedWeapon(Handle:timer, any:wepid)
{
    // Trie's need to use strings as their key; not numbers.
    decl String:wepid_tostring[LEN_INTSTRING];
    IntToString(wepid, wepid_tostring, LEN_INTSTRING);

    // Delete this wepid from the Trie of tracked weapons.
    RemoveFromTrie(g_hDroppedWeapons, wepid_tostring);
}
