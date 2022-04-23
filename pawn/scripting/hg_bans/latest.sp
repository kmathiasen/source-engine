
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

Latest_OnDbTickSuccess(Handle:conn)
{
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT subject_steamid, category FROM bans \
           WHERE (UNIX_TIMESTAMP() - datetime_modified) < %f AND category IN (%i, %i) \
           AND (approved_state = %d or approved_state = %d) \
           AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0)",
           UPDATE_FREQ, BAN_CAT_REGULARBAN, BAN_CAT_TLIST,
           APPROVED_STATE_APPROVED, APPROVED_STATE_SERVERBAN);
    SQL_TQuery(conn, Latest_GetBansSinceLastTick_CB, query);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Latest_GetBansSinceLastTick_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if(Db_QueryFailed(conn, fetch, error))
    {
        LogMessage("ERROR in Latest_GetBansSinceLastTick_CB: %s", error);
        return;
    }

    // A trie is used instead of array due to theoretically faster lookup.
    // The key is the Steam ID and the value is the category (regular ban or T-List).
    new Handle:ht = CreateTrie();
    new category;

    // Get all the short Steam IDs from the database and put them in a trie.
    decl String:steamShortFromDb[LEN_STEAMIDS - 8];
    while(SQL_FetchRow(fetch))
    {
        SQL_FetchString(fetch, 0, steamShortFromDb, sizeof(steamShortFromDb));
        category = SQL_FetchInt(fetch, 1);
        SetTrieValue(ht, steamShortFromDb, category);
    }

    // Now iterate all clients on the server right now and see if any of their Steam IDs are in the above trie.
    decl String:thisSteam[LEN_STEAMIDS];
    decl String:thisSteamShort[LEN_STEAMIDS - 8];
    for(new i = 1; i <= MaxClients; i++)
    {
        // Ensure client is in game and not a bot before getting his Steam ID.
        if(!IsClientInGame(i) || IsFakeClient(i))
            continue;
        GetClientAuthString(i, thisSteam, sizeof(thisSteam));

        // Remove STEAM_0: prefix from this client's Steam ID.
        CopyStringFrom(thisSteamShort, sizeof(thisSteamShort), thisSteam, sizeof(thisSteam), 8);

        // See if client's short Steam ID is one of those retrieved from the DB since the last tick.
        if(GetTrieValue(ht, thisSteamShort, category))
        {
            switch(category)
            {
                case BAN_CAT_REGULARBAN:
                    BanClient(i, IP_BAN_MINUTES, BANFLAG_IP, g_sBanMessage, g_sBanMessage);
                case BAN_CAT_TLIST:
                    TeamCheck_TeamSwitchSlay(i);
            }
        }
    }

    // We're done with the trie.
    ClearTrie(ht);
    CloseHandle(ht);
}
