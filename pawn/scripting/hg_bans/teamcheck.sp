
// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

TeamCheck_OnClientPutInServer(client)
{
    g_iTriedJoiningTeam[client] = 0;
}

TeamCheck_OnRoundStart()
{
    for(new i = 1; i <= MaxClients; i++)
    {
        g_iTriedJoiningTeam[i] = 0;
    }
}

TeamCheck_OnJoinTeam(client, team)
{
    // Return values.
    #define BLOCK_PLAYER_JOIN 0
    #define ALLOW_PLAYER_JOIN 1

    // The chose auto assign, deny and re-direct them to join Prisoner team.
    if(team == TEAM_UNASSIGNED)
    {
        // Force them to join terrorist.
        FakeClientCommand(client, "jointeam %i", TEAM_PRISONERS);

        // Don't let the server auto assign them to CT.
        return BLOCK_PLAYER_JOIN;
    }

    // We only check them if they are joining the CT team.
    if(team != TEAM_GUARDS)
        return ALLOW_PLAYER_JOIN;

    // Increase how many times they've tried to join the CT team this round.
    g_iTriedJoiningTeam[client]++;

    // Warn them not to join too many times.
    if(g_iTriedJoiningTeam[client] == g_iTeamSpamProtection - 1)
        DisplayMSay(client, "Do not spam team join!", MENU_TIMEOUT_QUICK, "You have one join left\nthis round before kick");
    else if(g_iTriedJoiningTeam[client] == g_iTeamSpamProtection)
    {
        BanClient(client, 1, BANFLAG_IP,
            "Spamming team join (1 minute ban)",
            "Spamming team join (1 minute ban)",
            _, _);
        return BLOCK_PLAYER_JOIN;
    }

    // Are we disconnected?
    if(g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in TeamCheck_OnJoinTeam: The DB handle was invalid");
        return ALLOW_PLAYER_JOIN;
    }

    // Get Steam ID.
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString(client, steam, sizeof(steam));

    // Shorten Steam ID.
    decl String:steamShort[LEN_STEAMIDS - 8];
    CopyStringFrom(steamShort, sizeof(steamShort), steam, LEN_STEAMIDS, 8);

    // Quert to check if this Steam ID is banned.
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT id FROM bans \
           WHERE subject_steamid = '%s' \
           AND category = %i \
           AND (approved_state = %d OR approved_state = %d) \
           AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0) \
           LIMIT 1",
           steamShort, BAN_CAT_TLIST, APPROVED_STATE_APPROVED, APPROVED_STATE_SERVERBAN);

    // Lock database because we're using a non-threaded query.
    SQL_LockDatabase(g_hDbConn_Main);

    // Execute query.
    new Handle:fetch = SQL_Query(g_hDbConn_Main, query);

    // Exit if fetch handle is invalid.
    if(fetch == INVALID_HANDLE)
    {
        // Unlock.
        SQL_UnlockDatabase(g_hDbConn_Main);

        // The fetch handle is invalid; nothing to close.

        // Report error.
        LogMessage("ERROR IN TeamCheck_OnJoinTeam: Problem getting results for Steam ID (%s)", steam);
        decl String:error[255];
        SQL_GetError(g_hDbConn_Main, error, sizeof(error));
        Db_QueryFailed(g_hDbConn_Main, fetch, error);

        // Exit (allow team join).
        return ALLOW_PLAYER_JOIN;
    }
    else
    {
        // Were results returned?
        new bool:playerFound = SQL_FetchRow(fetch);

        // Unlock.
        SQL_UnlockDatabase(g_hDbConn_Main);

        // Free the fetch handle.
        CloseHandle(fetch);

        // If we found this player in the DB, block him from joining team.
        if(playerFound)
        {
            PrintToChatAll("%s T-Listed freekiller \x03%N\x04 was blocked from joining Guards", MSG_PREFIX, client);
            EmitSoundToClient(client, g_sSoundDeny);
            CreateTimer(1.0, TeamCheck_ShowBlockReason, client);
            return BLOCK_PLAYER_JOIN;
        }
    }

    // If we are at this point, the player was not found in the DB.
    return ALLOW_PLAYER_JOIN;
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public Action:TeamCheck_ShowBlockReason(Handle:timer, any:client)
{
    if(IsClientInGame(client))
    {
        PrintToChat(client, "%s You are currently on the T-List.", MSG_PREFIX);
        PrintToChat(client, "%s This means you cannot be a Guard.", MSG_PREFIX);
        PrintToChat(client, "%s Please do not break MOTD rules.", MSG_PREFIX);
        PrintToChat(client, "%s For removal visit this link:", MSG_PREFIX);
        PrintToChat(client, "%s http://hellsgamers.com/hgbans", MSG_PREFIX);
    }
    return Plugin_Continue;
}

TeamCheck_TeamSwitchSlay(client)
{
    if(!g_bTlistEnabled || !IsClientInGame(client) || GetClientTeam(client) != TEAM_GUARDS)
        return;

    // Slay.
    if(IsPlayerAlive(client)) SlapPlayer(client, GetClientHealth(client));

    // Switch.
    ChangeClientTeam(client, TEAM_PRISONERS);

    // Display message after delay.
    CreateTimer(1.0, TeamCheck_ShowBlockReason, client);
}
