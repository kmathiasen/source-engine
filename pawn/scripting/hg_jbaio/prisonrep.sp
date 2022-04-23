// Shit I gotta do
/*

SQL_TQuery(conn, EmptyCallback, "CREATE TABLE IF NOT EXISTS prisonrep_csgo LIKE prisonrep");
SQL_TQuery(conn, EmptyCallback, "INSERT INTO prisonrep_csgo SELECT * from prisonrep");

 */

// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

enum _:PrisonRep
{
    PR_CSS = 0,
    PR_CSGO,
    PR_TF2,
}

// Storage.
new Handle:g_hPrisonRep_Total = INVALID_HANDLE;             // Trie to hold prison rep level for each Steam ID queried from the DB.
new Handle:g_hRep_UpdateQueue_Array = INVALID_HANDLE;
new Handle:g_hRep_UpdateQueue_Reps = INVALID_HANDLE;        // Trie to hold prison rep points accumulated during the DB connection timer interval.
new Handle:g_hRep_UpdateQueue_Names = INVALID_HANDLE;
new Handle:g_hRep_UpdateAttemptMade = INVALID_HANDLE;       // Prevent double insertion of prisonrep points
new Handle:g_hGivenThisDay = INVALID_HANDLE;
new Handle:g_hGivenThisDayArray = INVALID_HANDLE;

new bool:g_bGotRepFromDB[MAXPLAYERS + 1][PrisonRep];
new g_iLastGive[MAXPLAYERS + 1];

// Timer to periodically give rep for idling.
new Handle:g_hIdleRepTimer = INVALID_HANDLE;

// Declare commonly used ConVars.
new Float:g_fIdleInterval;
new g_iRepForIdling;
new g_iRepForHurtingGuard;
new g_iRepForKillingGuard;
new g_iRepForKillingLead;
new g_iRepForKillingRebel;


// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

PrisonRep_OnPluginStart()
{
    RegConsoleCmd("sm_rep", Command_CheckRep, "A command for people to check their current Prison Rep level");
    RegConsoleCmd("sm_giveplayer", Command_GivePlayer);

    g_hPrisonRep_Total = CreateTrie();
    g_hRep_UpdateQueue_Array = CreateArray(ByteCountToCells(LEN_STEAMIDS));
    g_hGivenThisDayArray = CreateArray(ByteCountToCells(24));
    g_hRep_UpdateQueue_Reps = CreateTrie();
    g_hRep_UpdateQueue_Names = CreateTrie();
    g_hRep_UpdateAttemptMade = CreateTrie();
    g_hGivenThisDay = CreateTrie();

    // Make sure all in-game clients are in the queue array to get looked up.
    decl String:thisSteam[LEN_STEAMIDS];
    decl String:name[MAX_NAME_LENGTH];
    for (new i = 1; i <= MaxClients; i++)
    {
        if ((IsClientConnected(i)) && (IsClientInGame(i)))
        {
            GetClientAuthString2(i, thisSteam, sizeof(thisSteam));
            SetTrieValue(g_hRep_UpdateQueue_Reps, thisSteam, 0);
            GetClientName(i, name, sizeof(name));
            SetTrieString(g_hRep_UpdateQueue_Names, thisSteam, name);
            PushArrayString(g_hRep_UpdateQueue_Array, thisSteam);
        }
    }

    // Gotta prune g_hGivenThisDay, in order to prevent dat memory leak, also to reset everyones totals.
    CreateTimer(60.0 * 60.0, Timer_PruneMaxGive, 100);         // Prune everyone who's given less than 100 every hour
    CreateTimer(60.0 * 60.0 * 2.0, Timer_PruneMaxGive, 250);         // Prune everyone who's given less than 250 every two hours
    CreateTimer(60.0 * 60.0 * 4.0, Timer_PruneMaxGive, 500);         // Prune everyone who's given less than 500 every four hours
    CreateTimer(60.0 * 60.0 * 8.0, Timer_PruneMaxGive, 1000);         // Prune everyone who's given less than 1000 every eight hours
    CreateTimer(60.0 * 60.0 * 24.0, Timer_PruneMaxGive, 696969);         // Prune everyone's points every twenty four hours
}

PrisonRep_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_fIdleInterval = GetConVarFloat(g_hCvRepIdlingInterval);
    g_iRepForIdling = GetConVarInt(g_hCvRepIdling);
    g_iRepForHurtingGuard = GetConVarInt(g_hCvRepHurtGuard);
    g_iRepForKillingGuard = GetConVarInt(g_hCvRepKillGuard);
    g_iRepForKillingLead = GetConVarInt(g_hCvRepKillLead);
    g_iRepForKillingRebel = GetConVarInt(g_hCvRepKillRebel);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvRepIdlingInterval, PrisonRep_OnConVarChange);
    HookConVarChange(g_hCvRepIdling, PrisonRep_OnConVarChange);
    HookConVarChange(g_hCvRepHurtGuard, PrisonRep_OnConVarChange);
    HookConVarChange(g_hCvRepKillGuard, PrisonRep_OnConVarChange);
    HookConVarChange(g_hCvRepKillLead, PrisonRep_OnConVarChange);
    HookConVarChange(g_hCvRepKillRebel, PrisonRep_OnConVarChange);

    // Start timer using ConVar value.
    if (g_hIdleRepTimer != INVALID_HANDLE)
        CloseHandle(g_hIdleRepTimer);
    g_hIdleRepTimer = CreateTimer(g_fIdleInterval, Timer_AFKRep, _, TIMER_REPEAT);
}

public PrisonRep_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvRepIdlingInterval)
    {
        g_fIdleInterval = GetConVarFloat(g_hCvRepIdlingInterval);

        // Kill and restart timer using ConVar value.
        if (g_hIdleRepTimer != INVALID_HANDLE)
            CloseHandle(g_hIdleRepTimer);
        g_hIdleRepTimer = CreateTimer(g_fIdleInterval, Timer_AFKRep, _, TIMER_REPEAT);
    }
    else if (CVar == g_hCvRepIdling)
        g_iRepForIdling = GetConVarInt(g_hCvRepIdling);
    else if (CVar == g_hCvRepHurtGuard)
        g_iRepForHurtingGuard = GetConVarInt(g_hCvRepHurtGuard);
    else if (CVar == g_hCvRepKillGuard)
        g_iRepForKillingGuard = GetConVarInt(g_hCvRepKillGuard);
    else if (CVar == g_hCvRepKillLead)
        g_iRepForKillingLead = GetConVarInt(g_hCvRepKillLead);
    else if (CVar == g_hCvRepKillRebel)
        g_iRepForKillingRebel = GetConVarInt(g_hCvRepKillRebel);
}

PrisonRep_OnPluginEnd()
{
    if (g_hDbConn_Main != INVALID_HANDLE)
    {
        PrisonRep_SaveAndReloadRep(g_hDbConn_Main, false, false);
    }
}

PrisonRep_OnDbConnect(Handle:conn)
{
    PrisonRep_SaveAndReloadRep(conn, true, true);
}

PrisonRep_OnClientDisconnect(client)
{
    decl String:steamid[LEN_STEAMIDS];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    RemoveFromTrie(g_hPrisonRep_Total, steamid);
}

PrisonRep_OnClientAuthorized(client, const String:steam[])
{
    RemoveFromTrie(g_hPrisonRep_Total, steam);

    for (new i = 0; i < _:PrisonRep; i++)
    {
        g_bGotRepFromDB[client][i] = false;
    }

    // Exit if DB handle is invalid.
    if (g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in PrisonRep_OnClientAuthorized: The DB handle was invalid");
        return;
    }

    // Get prison rep from DB.
    LoadAllRep(client);
}

PrisonRep_OnPrisonerHurtGuard(attacker, victim)
{
    // Reward the Prisoner for injuring a Guard.
    if (!g_iRepForHurtingGuard)
        return;

    // No rep padding.
    // We only want to do this check for player hurt, and not in PrisonRep_AddPoints
    // Because then people could go into infirm and buy stuff for free
    if (MapCoords_IsInRoomEz(victim, "Infirmary"))
        return;
    PrisonRep_AddPoints(attacker, g_iRepForHurtingGuard);
}

PrisonRep_OnPrisonerKilledGuard(attacker, victim)
{
    // Reward the Prisoner for killing a Guard.
    new rep = g_iRepForKillingGuard;
    if (victim == g_iLeadGuard)
        rep += g_iRepForKillingLead;
    PrisonRep_AddPoints(attacker, rep);
}

PrisonRep_OnGuardKillRebel(attacker)
{
    // Reward the Guard for killing a Rebel.
    PrisonRep_AddPoints(attacker, g_iRepForKillingRebel);
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################


public Action:Command_GivePlayer(client, args)
{
    if (args < 2)
    {
        PrintToChat(client,
                    "%s Invalid syntax -- \x04!giveplayer <target> <amount>",
                    MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:sTarget[MAX_NAME_LENGTH + 2];
    GetCmdArg(1, sTarget, sizeof(sTarget));

    new target = FindTarget(client, sTarget, false, false);
    if (target < 0)
        return Plugin_Handled;

    if (target == client)
    {
        PrintToChat(client, "%s I don't know what you're trying to accomplish", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:sAmount[16];
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new amount = StringToInt(sAmount);
    if (amount < 1 && isAuthed(client, false) < 2)
    {
        PrintToChat(client, "%s Invalid amount", MSG_PREFIX);
        return Plugin_Handled;
    }

    new points = PrisonRep_GetPoints(client);

    if (points < amount)
    {
        PrintToChat(client,
                    "%s You only have \x04%d\x01 points", MSG_PREFIX, points);
        return Plugin_Handled;
    }

    if (GetTime() - g_iLastGive[client] < 10)
    {
        PrintToChat(client,
                    "%s You can not use this command for another \x04%d\x01 second(s)",
                    MSG_PREFIX, 10 - (GetTime() - g_iLastGive[client]));
        return Plugin_Handled;
    }

    decl String:client_steamid[32];
    decl String:target_steamid[32];

    GetClientAuthString2(client, client_steamid, sizeof(client_steamid));
    GetClientAuthString2(target, target_steamid, sizeof(target_steamid));

    new given_this_period;

    GetTrieValue(g_hGivenThisDay, client_steamid, given_this_period);

    if (given_this_period + amount > MAX_REP_TRANSFER_PER_DAY && !isAuthed(client, false))
    {
        PrintToChat(client,
                    "%s \x04ERROR\x01: You have already sent \x04%d\x01 points in the last 24 hours.",
                    MSG_PREFIX, given_this_period);

        PrintToChat(client,
                    "%s You may only send \x04%d\x01 points per day to other players.",
                    MSG_PREFIX, MAX_REP_TRANSFER_PER_DAY);

        return Plugin_Handled;
    }

    if (FindStringInArray(g_hGivenThisDayArray, client_steamid) < 0)
        PushArrayString(g_hGivenThisDayArray, client_steamid);

    SetTrieValue(g_hGivenThisDay, client_steamid, given_this_period + amount);

    g_iLastGive[client] = GetTime();

    PrisonRep_AddPoints(target, amount);
    PrisonRep_AddPoints(client, -amount);

    PrintToChat(client,
                "%s Sending \x04%N\x04 %d\x01 points, you have \x04%d\x01 left",
                MSG_PREFIX, target, amount, points - amount);

    PrintToChat(target,
                "%s \x04%N\x01 has sent you \x04%d\x01 points, you have \x04%d\x01 total",
                MSG_PREFIX, client, amount, PrisonRep_GetPoints(target));

    PrintToChat(target,
                "%s You have given \x04%d\x01 points today. You can only give \x04%d\x01 more today.",
                MSG_PREFIX, given_this_period + amount, MAX_REP_TRANSFER_PER_DAY - (given_this_period + amount));

    if (amount >= 400 || amount <= -400)
    {
        decl String:path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), "scripting/giveplayer.log");

        new Handle:iFile = OpenFile(path, "a");

        LogToOpenFile(iFile, "%N (%s) sent %N (%s) %d rep", client, client_steamid, target, target_steamid, amount);
        CloseHandle(iFile);

        BuildPath(Path_SM, path, sizeof(path), "logs/giveplayer.log");
        iFile = OpenFile(path, "a");

        LogToOpenFile(iFile, "%N (%s) sent %N (%s) %d rep", client, client_steamid, target, target_steamid, amount);
        CloseHandle(iFile);
    }

    return Plugin_Handled;
}

public Action:Command_CheckRep(client, args)
{
    // Client must be in-game.
    if ((client <= 0) || (!IsClientInGame(client)))
    {
        PrintToConsole(0, "%s This command requires you to be in-game", MSG_PREFIX_CONSOLE);
        return Plugin_Handled;
    }

    if (!IsClientInGame(client))
    {
        PrintToChat(client, "%s This command requires you to in-game", MSG_PREFIX);
        return Plugin_Handled;
    }

    // Display rep.
    PrintToChat(client, "%s You have \x03%i\x04 Prison Rep points", MSG_PREFIX, PrisonRep_GetPoints(client));

    if (!g_bGotRepFromDB[client][PrisonRep_GameIndex()])
    {
        PrintToChat(client, "%s NOTE: \x03There was a problem grabbing your rep from the database, if this message persists, rejoin after a few rounds", MSG_PREFIX);
        PrintToChat(client, "%s IMPORTANT: If that does not fix the problem, tough. Do NOT post about missing rep on the forums", MSG_PREFIX);
        PrintToChat(client, "%s PAY HEED: Posting about missing rep on the forums will result in a \x03REAL\x04 loss of your rep, or a ban", MSG_PREFIX);

        DisplayMSay(client, "Error Grabbing Rep", 60,
                    "There was a problem grabbing your rep from the database\nIf this message persists for more than 2 minutes, try rejoining the server\nIf that does not fix the problem. Tough.\nPosting about missing rep on the forums will result in either:\n   A REAL loss of your rep\n   A ban");
    }

    if (g_bIsThursday)
    {
        PrintToChat(client, "%s IMPORTANT: Due to \x03Throwback Thursday\x04 your rep will be interpreted as 0 for all of thursday", MSG_PREFIX);
        PrintToChat(client, "%s Remember though, rep will NEVER be reset, unless there is a thread about it on the forums.", MSG_PREFIX);
    }

    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################


PrisonRep_GameIndex(game=GAMETYPE_NONE)
{
    switch (game)
    {
        case GAMETYPE_CSS:
        {
            return _:PR_CSS;
        }

        case GAMETYPE_CSGO:
        {
            return _:PR_CSGO;
        }

        case GAMETYPE_TF2:
        {
            return _:PR_TF2;
        }

        default:
        {
            return PrisonRep_GameIndex(g_iGame);
        }
    }

    return _:PR_CSS;
}

PrisonRep_TransferLimit(client)
{
    new given_this_period;
    decl String:steamid[LEN_STEAMIDS];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    GetTrieValue(g_hGivenThisDay, steamid, given_this_period);

    if (isAuthed(client, false))
    {
        return 999999;
    }

    return MAX_REP_TRANSFER_PER_DAY - given_this_period;
}

public Native_PrisonRep_AddPoints_Offline(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(1, len);

    decl String:steamArg[len + 1];
    GetNativeString(1, steamArg, len + 1);

    // Check Steam ID (since it's coming from another mod).
    decl String:validSteam[LEN_STEAMIDS];
    new bool:isValid;

    // Test against "STEAM_0:0:1"
    if ((len + 1) >= 11 && (strncmp(steamArg, "STEAM_", 6, false) == 0) && (steamArg[7] == ':') && (steamArg[9] == ':'))
    {
        // It looks like a long-form Steam ID.  Make sure by testing it against a regex pattern.
        if (MatchRegex(g_hPatternSteam, steamArg) > 0)
        {
            // The Steam ID is valid.  Now remove the "STEAM_0:" prefix.
            CopyStringFrom(validSteam, sizeof(validSteam), steamArg, len + 1, 8);
            isValid = true;
        }
    }

    // Test against "0:1"
    else if ((len + 1) >= 3 && (steamArg[0] == '0' || steamArg[0] == '1') && (steamArg[1] == ':'))
    {
        // It looks like a short-form Steam ID.  Make sure by testing it against a regex pattern.
        if (MatchRegex(g_hPatternSteamShort, steamArg) > 0)
        {
            // The Steam ID is valid.  Now copy it to the valid Steam ID buffer.
            Format(validSteam, sizeof(validSteam), steamArg);
            isValid = true;
        }
    }

    // Well, was it valid?
    if (!isValid)
        return;

    new rep_add = GetNativeCell(2);
    decl String:table[32];

    Format(table, sizeof(table), g_sRepTableName);

    if (args > 2)
    {
        new game = GetNativeCell(3);
        switch (game)
        {
            case GAMETYPE_CSS:
            {
                Format(table, sizeof(table), "prisonrep");
            }
    
            case GAMETYPE_CSGO:
            {
                Format(table, sizeof(table), "prisonrep_csgo");
            }

            case GAMETYPE_TF2:
            {
                Format(table, sizeof(table), "prisonrep_tf2");
            }
        }

        // For trade purposes
        // Keep the running total up to date.
        new current_rep_total[PrisonRep];
        new index = PrisonRep_GameIndex(game);

        if (GetTrieArray(g_hPrisonRep_Total, validSteam, current_rep_total, _:PrisonRep))
        {
            new updated_rep_total = current_rep_total[index] + rep_add;
            current_rep_total[index] = updated_rep_total;
            SetTrieArray(g_hPrisonRep_Total, validSteam, current_rep_total, _:PrisonRep);
        }
    }

    decl String:query[255];
    Format(query, sizeof(query),
           "UPDATE %s SET points = points + %d WHERE steamid = '%s'",
           table, rep_add, validSteam);

    SQL_TQuery(g_hDbConn_Main, EmptyCallback, query, 1);
}

public Native_PrisonRep_GetPoints(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    new game = g_iGame;

    if (IsFakeClient(client))
        return 42;

    if (args > 1)
    {
        game = GetNativeCell(2);

        if (g_iGame == GAMETYPE_NONE)
        {
            game = g_iGame;
        }
    }

    // Get Steam ID of client.
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, sizeof(steam));

    // Get and return rep for this Steam ID.
    new rep[PrisonRep];

    if (!GetTrieArray(g_hPrisonRep_Total, steam, _:rep, _:PrisonRep))
        return -1;
    return rep[PrisonRep_GameIndex(game)];
}

public Native_PrisonRep_AddPoints(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    new rep_increase = GetNativeCell(2);
    new bool:message = true;

    if (args > 2)
    {
        message = GetNativeCellRef(3);
    }

    // Make sure this client is in-game and has a Steam ID.
    if (!IsClientInGame(client) || !IsClientAuthorized(client)) return;

    // Get Steam ID of client.
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, sizeof(steam));

    // Add the new points to the rep that this person currently has in the queue.
    new current_rep_period;
    if (GetTrieValue(g_hRep_UpdateQueue_Reps, steam, current_rep_period))
    {
        // There was already an entry for this person in the queue.  We just have to update it.
        SetTrieValue(g_hRep_UpdateQueue_Reps, steam, current_rep_period + rep_increase);
    }

    else
    {
        // There was no queued rep for this person yet.  We need to add him to the queue.
        SetTrieValue(g_hRep_UpdateQueue_Reps, steam, rep_increase);
        decl String:name[MAX_NAME_LENGTH];
        GetClientName(client, name, sizeof(name));
        SetTrieString(g_hRep_UpdateQueue_Names, steam, name);
        PushArrayString(g_hRep_UpdateQueue_Array, steam);
    }

    // Keep the running total up to date.
    new current_rep_total[PrisonRep];
    new index = PrisonRep_GameIndex();

    GetTrieArray(g_hPrisonRep_Total, steam, current_rep_total, _:PrisonRep);

    new updated_rep_total = current_rep_total[index] + rep_increase;
    current_rep_total[index] = updated_rep_total;
    SetTrieArray(g_hPrisonRep_Total, steam, current_rep_total, _:PrisonRep);

    // Notify.
    if (message && rep_increase != 0)
    {
        PrintToChat(client, "%s You recieved \x03%i\x04 prison rep \x01(\x04Total: \x03%i\x01)", MSG_PREFIX, rep_increase, updated_rep_total);
    }
}

PrisonRep_SaveAndReloadRep(Handle:conn, bool:reload, bool:threaded)
{
    decl String:query[512];

    if (!threaded)
    {
        SQL_LockDatabase(conn);
    }

    for (new i = 0; i < GetArraySize(g_hRep_UpdateQueue_Array); i++)
    {
        decl String:name[MAX_NAME_LENGTH];
        decl String:sEscapedName[MAX_NAME_LENGTH * 2 + 1];
        decl String:steam[LEN_STEAMIDS];
        decl String:sEscapeSteam[LEN_STEAMIDS * 2 + 1];

        // Get Steam ID from Array.
        GetArrayString(g_hRep_UpdateQueue_Array, i, steam, sizeof(steam));
        SQL_EscapeString(g_hDbConn_Main, steam, sEscapeSteam, sizeof(sEscapeSteam));

        // Prevent double insertion
        new bool:dummy;
        if (GetTrieValue(g_hRep_UpdateAttemptMade, steam, dummy))
            continue;

        // Get rep from Trie.
        new accumulated_period = 0;
        if (!GetTrieValue(g_hRep_UpdateQueue_Reps, steam, accumulated_period))
            continue;

        // Get name from Trie.
        if (!GetTrieString(g_hRep_UpdateQueue_Names, steam, name, sizeof(name))) name = "unknown";
        SQL_EscapeString(g_hDbConn_Main, name, sEscapedName, sizeof(sEscapedName));

        Format(query, sizeof(query),
               "INSERT INTO %s (steamid, ingamename, points) VALUES ('%s', '%s', %d) ON DUPLICATE KEY UPDATE ingamename = '%s', points = points + %d",
               g_sRepTableName, sEscapeSteam, sEscapedName, accumulated_period, sEscapedName, accumulated_period);

        SetTrieValue(g_hRep_UpdateAttemptMade, steam, true);

        if (threaded)
        {
            new Handle:pack = CreateDataPack();
            WritePackString(pack, steam);

            SQL_TQuery(conn, UpdateRepCallback, query, pack);
        }

        else
        {
            SQL_FastQuery(conn, query);
        }
    }

    if (!threaded)
    {
        SQL_UnlockDatabase(conn);
    }

    if (reload)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i))
                continue;

            LoadAllRep(i);
        }
    }
}

stock LoadAllRep(client)
{
    decl String:query[256];
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, sizeof(steam));

    if (!g_bGotRepFromDB[client][PR_CSS])
    {
        Format(query, sizeof(query), "SELECT points, %d FROM prisonrep WHERE steamid = '%s'", PR_CSS, steam);
        SQL_TQuery(g_hDbConn_Main, GrabRepCallback, query, GetClientUserId(client));
    }

    if (!g_bGotRepFromDB[client][PR_CSGO])
    {
        Format(query, sizeof(query), "SELECT points, %d FROM prisonrep_csgo WHERE steamid = '%s'", PR_CSGO, steam);
        SQL_TQuery(g_hDbConn_Main, GrabRepCallback, query, GetClientUserId(client));
    }

    if (!g_bGotRepFromDB[client][PR_TF2])
    {
        Format(query, sizeof(query), "SELECT points, %d FROM prisonrep_tf2 WHERE steamid = '%s'", PR_TF2, steam);
        SQL_TQuery(g_hDbConn_Main, GrabRepCallback, query, GetClientUserId(client));
    }
}

public GrabRepCallback(Handle:main, Handle:hndl, const String:error[], any:userid)
{
    decl String:steam[LEN_STEAMIDS];
    new client = GetClientOfUserId(userid);

    if (!StrEqual(error, ""))
    {
        LogError(error);
        return;
    }

    if (client < 1 || IsFakeClient(client))
        return;

    new rep[PrisonRep];
    new game_rep;
    new game_index;

    GetClientAuthString2(client, steam, sizeof(steam));
    GetTrieArray(g_hPrisonRep_Total, steam, rep, _:PrisonRep);

    if (SQL_FetchRow(hndl))
    {
        game_rep = SQL_FetchInt(hndl, 0);
        game_index = SQL_FetchInt(hndl, 1);

        if (g_bGotRepFromDB[client][game_index])
            return;

        rep[game_index] += game_rep;
    }

    // Insert value into Trie for this player's Steam ID.
    SetTrieArray(g_hPrisonRep_Total, steam, rep, _:PrisonRep);

    // Let the script know that we successfully grabbed the clients rep
    g_bGotRepFromDB[client][game_index] = true;

    // If he is not already in the update queue, add him at this time.
    // This is so the next time the DB reconnects, he will be one of them to get updated.
    new current_rep_period;
    if (!GetTrieValue(g_hRep_UpdateQueue_Reps, steam, current_rep_period))
    {
        // There was no queued rep for this person yet.  We need to add him to the queue.
        SetTrieValue(g_hRep_UpdateQueue_Reps, steam, 0);
        decl String:name[MAX_NAME_LENGTH];
        GetClientName(client, name, sizeof(name));
        SetTrieString(g_hRep_UpdateQueue_Names, steam, name);
        PushArrayString(g_hRep_UpdateQueue_Array, steam);
    }
}

public UpdateRepCallback(Handle:main, Handle:hndl, const String:error[], any:pack)
{
    new String:steam[LEN_STEAMIDS];

    ResetPack(pack);
    ReadPackString(pack, steam, sizeof(steam));
    CloseHandle(pack);

    if (!StrEqual(error, ""))
    {
        LogError(error);
        return;
    }

    new index = FindStringInArray(g_hRep_UpdateQueue_Array, steam);
    if (index > -1)
        RemoveFromArray(g_hRep_UpdateQueue_Array, index);

    RemoveFromTrie(g_hRep_UpdateQueue_Reps, steam);
    RemoveFromTrie(g_hRep_UpdateQueue_Names, steam);
    RemoveFromTrie(g_hRep_UpdateAttemptMade, steam);
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################


public Action:Timer_PruneMaxGive(Handle:timer, any:amount)
{
    new points;
    decl String:steamid[24];

    for (new i = 0; i < GetArraySize(g_hGivenThisDayArray); i++)
    {
        GetArrayString(g_hGivenThisDayArray, i, steamid, sizeof(steamid));
        GetTrieValue(g_hGivenThisDay, steamid, points);

        if (points <= amount)
        {
            RemoveFromTrie(g_hGivenThisDay, steamid);
            RemoveFromArray(g_hGivenThisDayArray, i--);
        }
    }

    return Plugin_Continue;
}

public Action:Timer_AFKRep(Handle:timer)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) <= TEAM_SPEC)
        {
            if (g_iGame != GAMETYPE_TF2)
                PrintToChat(i, "%s join our TF2 Jailbreak server \x01(\x0364.31.16.212:27015\x01)\x04 in order to gain extra rep for idling!", MSG_PREFIX);

            PrisonRep_AddPoints(i, g_iRepForIdling);
            PrintToChat(i,
                        "%s You have recieved \x03%d\x04 rep for supporting the server by idling!",
                        MSG_PREFIX, g_iRepForIdling);
        }
    }

    return Plugin_Continue;
}
