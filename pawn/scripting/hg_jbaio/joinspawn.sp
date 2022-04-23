
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

new Handle:g_hSpawnWindow = INVALID_HANDLE;
new Handle:g_hDisconnectors = INVALID_HANDLE;
new bool:g_bCanSpawnThisRound[MAXPLAYERS + 1];

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

JoinSpawn_OnPluginStart()
{
    g_hDisconnectors = CreateTrie();
    HookEvent("player_disconnect", JoinSpawn_WasClientKicked, EventHookMode_Pre);
}

JoinSpawn_OnRndStrt_General()
{
    // Kill and reset window timer.
    if (g_hSpawnWindow != INVALID_HANDLE)
        CloseHandle(g_hSpawnWindow);
    g_hSpawnWindow = CreateTimer(GetConVarFloat(g_hCvSpawnWindowTime), JoinSpawn_SpawnTimeUp);

    // Clear the trie of people who disconnected during the spawn window.
    ClearTrie(g_hDisconnectors);
}

JoinSpawn_OnRoundEnd()
{
    for (new i = 1; i <= MaxClients; i++)
        g_bCanSpawnThisRound[i] = true;
}

public Action:JoinSpawn_WasClientKicked(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    decl String:reason[255];

    GetEventString(event, "reason", reason, sizeof(reason));
    if (!strncmp(reason, "Kicked", 6, false))
    {
        g_bShouldTrackDisconnect[client] = true;
        JoinSpawn_OnClientDisconnect(client);
    }

    return Plugin_Continue;
}

JoinSpawn_OnPlayerTeamPost(client, team)
{
    if (team <= TEAM_SPEC)
    {
        g_bCanSpawnThisRound[client] = false;
    }
}

JoinSpawn_OnPlayerDeath(client)
{
    g_bShouldTrackDisconnect[client] = true;
}

JoinSpawn_OnPlayerSpawn(client)
{
    if (!g_bCanSpawnThisRound[client] && !IsFakeClient(client))
    {
        CreateTimer(1.0, Timer_Slay, GetClientUserId(client));
        ForcePlayerSuicide(client);
    }
}

JoinSpawn_OnClientDisconnect(client)
{
    // Is it during spawn window?
    if (g_hSpawnWindow != INVALID_HANDLE && g_bShouldTrackDisconnect[client])
    {
        // Get Steam ID.
        decl String:steam[LEN_STEAMIDS];
        GetClientAuthString2(client, steam, sizeof(steam));

        // Add his Steam ID to the list of people who disconnected during the spawn window.
        SetTrieValue(g_hDisconnectors, steam, 1);
    }

    g_bCanSpawnThisRound[client] = true;
}

bool:JoinSpawn_OnJoinTeam(client)
{
    // Is it during spawn window?
    if (g_hSpawnWindow != INVALID_HANDLE)
    {
        if (IsFakeClient(client))
            return true;

        // Get Steam ID.
        decl String:steam[LEN_STEAMIDS];
        GetClientAuthString2(client, steam, sizeof(steam));

        // Is this person someone who was already in the game and disconnected during the spawn window?
        new dummy = 0;
        GetTrieValue(g_hDisconnectors, steam, dummy);
        if (dummy == 1)
        {
            // Notify him that he cannot join the team now.
            PrintToChat(client, "%s Please wait until spawn window is over.", MSG_PREFIX);

            // Block him from joining the team.
            return false;
        }
    }
    return true;
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################


public Action:Timer_Slay(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && JB_IsPlayerAlive(client) && !IsFakeClient(client))
    {
        ForcePlayerSuicide(client);
    }
}

public Action:JoinSpawn_SpawnTimeUp(Handle:timer, any:data)
{
    g_hSpawnWindow = INVALID_HANDLE;
    return Plugin_Stop;
}
