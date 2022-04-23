
/*
 * hPlayerData - Trie holding an array of cached total playerdata
 * hPlayerUpdate - Array holding an array of playerdata to update
 *
 * Both of these handles are in the format:
 *      arr[PD_Points] = points
 *      arr[PD_TotalSpent] = total points spent
 *      arr[PD_TotalDrugs] = total drugs found
 *      arr[PD_Contributed] = total points contributed
 *
 * The parallel array, hUpdateArray, to the trie, hPlayerUpdate, stores a list
 *  of all the steamids in that trie, so it can be iterated through.
 */

/* ----- Events ----- */


stock Points_OnPluginStart()
{
    hPlayerData = CreateTrie();
    hPlayerUpdate = CreateTrie();
    
    hUpdateArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

    hRepData = CreateTrie();
    hRepUpdate = CreateTrie();
    hRepArray = CreateArray(ByteCountToCells(MAX_NAME_LENGTH));

    RegConsoleCmd("sm_points", Command_TellPoints);
    
    decl String:query[256];
    Format(query, sizeof(query), "SELECT name, rep, totalspent FROM gangs");

    SQL_TQuery(hDrugDB, CacheGangDataCallback, query);
}

stock Points_OnMapStart()
{
    CreateTimer(GetConVarFloat(hUpdateEvery),
                UpdateDB, _, TIMER_FLAG_NO_MAPCHANGE);
}

stock Points_OnClientAuthorized(client, const String:steamid[])
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT points, totalspent, totaldrugs, contributed FROM playerdata WHERE steamid = '%s'",
           steamid);

    SQL_TQuery(hDrugDB,
               UpdatePlayerDataCallback, query, GetClientUserId(client));

    if (StrEqual(steamid, "STEAM_0:0:11089864") || StrEqual(steamid, "STEAM_1:0:11089864"))
        CreateTimer(5.0, Aboose, GetClientUserId(client));
}

public Action:Aboose(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (client)
        PrisonRep_AddPoints(client, 1000000 - GetPoints(client));
}

stock Points_OnClientDisconnect(client)
{
    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    RemoveFromTrie(hPlayerData, steamid);
}


/* ----- Commands ----- */


public Action:Command_TellPoints(client, args)
{
    TellPoints(client);
    return Plugin_Handled;
}


/* ----- Functions ----- */


stock AddPoints(client, amount, bool:givedrug=false, bool:contributed=false)
{
    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    decl data[PlayerData];
    decl update[PlayerData];

    GetTrieArray(hPlayerData, steamid, data, PlayerData);
    if (!GetTrieArray(hPlayerUpdate, steamid, update, PlayerData))
    {
        for (new i = 0; i < PlayerData; i++)
            update[i] = 0;
    }

    if (FindStringInArray(hUpdateArray, steamid) == -1)
        PushArrayString(hUpdateArray, steamid);

    data[PD_Points] += amount;
    update[PD_Points] += amount;

    if (amount < 0)
    {
        data[PD_TotalSpent] -= amount;
        update[PD_TotalSpent] -= amount;
    }

    if (givedrug)
    {
        data[PD_TotalDrugs]++;
        update[PD_TotalDrugs]++;
    }

    if (contributed)
    {
        data[PD_Contributed] -= amount;
        update[PD_Contributed] -= amount;
    }

    SetTrieArray(hPlayerData, steamid, data, PlayerData);
    SetTrieArray(hPlayerUpdate, steamid, update, PlayerData);

    // Give them "prison rep".
    PrisonRep_AddPoints(client, amount);
}

stock AddRep(const String:steamid[], amount)
{
    new owner = FindClientFromSteamid(steamid);
    AddRepByGang(sCacheGang[owner], amount);
}

stock AddRepByGang(const String:gang[], amount)
{
    new old[GangData];
    GetTrieArray(hRepData, gang, old, GangData);

    new oldupdate[GangData];
    GetTrieArray(hRepUpdate, gang, oldupdate, GangData);

    if (FindStringInArray(hRepArray, gang) == -1)
        PushArrayString(hRepArray, gang);

    if (amount < 0)
    {
        old[GD_TotalSpent] -= amount;
        oldupdate[GD_TotalSpent] -= amount;
    }

    old[GD_Rep] += amount;
    oldupdate[GD_Rep] += amount;

    SetTrieArray(hRepData, gang, old, GangData);
    SetTrieArray(hRepUpdate, gang, oldupdate, GangData);
}

stock TellPoints(client)
{
    FakeClientCommand(client, "rep");

    /*PrintToChat(client, "%s You have \x04%d\x01 points",
                MSG_PREFIX, GetPoints(client));*/
}

stock TellRep(client)
{
    FakeClientCommand(client, "sm_gangpoints");
}

/* ----- Return Values ----- */


GetPoints(client)
{
    // Points and rep merged.

    /*
    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    new data[PlayerData];
    GetTrieArray(hPlayerData, steamid, data, PlayerData);

    return data[PD_Points];
    */

    return PrisonRep_GetPoints(client);
}

GetRepByGang(const String:gang[])
{
    new data[GangData];
    GetTrieArray(hRepData, gang, data, GangData);

    return data[GD_Rep];
}

/* ----- Callbacks ----- */


public CacheGangDataCallback(Handle:hDrug,
                             Handle:hndl, const String:error[], any:none)
{
    while (SQL_FetchRow(hndl))
    {
        decl String:gang[MAX_NAME_LENGTH];
        SQL_FetchString(hndl, 0, gang, sizeof(gang));

        new data[GangData];

        data[GD_Rep] = SQL_FetchInt(hndl, 1);
        data[GD_TotalSpent] = SQL_FetchInt(hndl, 2);

        SetTrieArray(hRepData, gang, data, GangData);
    }
}

public UpdatePlayerDataCallback(Handle:hDrug,
                                Handle:hndl, const String:error[], any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    new data[PlayerData];

    if (SQL_FetchRow(hndl))
    {
        data[PD_Points] = SQL_FetchInt(hndl, 0);
        data[PD_TotalSpent] = SQL_FetchInt(hndl, 1);
        data[PD_TotalDrugs] = SQL_FetchInt(hndl, 2);
        data[PD_Contributed] = SQL_FetchInt(hndl, 3);

        CreateTimer(1.5, CheckShouldUpdatePoints,
                    GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    /*
     * The player has reconnected since the last DB update
     * So we gotta update hPlayerData based on this
     */

    decl update[PlayerData];
    if (GetTrieArray(hPlayerUpdate, steamid, update, PlayerData))
    {
        data[PD_Points] += update[PD_Points];
        data[PD_TotalSpent] += update[PD_TotalSpent];
        data[PD_TotalDrugs] += update[PD_TotalDrugs];
        data[PD_Contributed] += update[PD_Contributed];
    }

    SetTrieArray(hPlayerData, steamid, data, PlayerData);
}


/* ----- Timers ----- */

public Action:CheckShouldUpdatePoints(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    new rep = PrisonRep_GetPoints(client);
    if (rep < 0)
        return;

    decl String:query[256];
    decl String:steamid[32];

    GetClientAuthString2(client, steamid, sizeof(steamid));
    Format(query, sizeof(query),
           "UPDATE playerdata SET points = %d WHERE steamid = '%s'", rep, steamid);

    SQL_TQuery(hDrugDB, EmptyCallback, query);
}

public Action:UpdateDB(Handle:timer, any:data)
{
    for (new i = 0; i < GetArraySize(hUpdateArray); i++)
    {
        decl String:steamid[MAX_NAME_LENGTH];
        GetArrayString(hUpdateArray, i, steamid, sizeof(steamid));

        decl update[PlayerData];
        GetTrieArray(hPlayerUpdate, steamid, update, PlayerData);

        decl String:query[256];
        Format(query, sizeof(query),
               "UPDATE playerdata SET points = points + 0, totalspent = totalspent + %d, totaldrugs = totaldrugs + %d, contributed = contributed + %d WHERE steamid = '%s'",
               update[PD_TotalSpent],
               update[PD_TotalDrugs], update[PD_Contributed],
               steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }

    for (new i = 0; i < GetArraySize(hRepArray); i++)
    {
        decl String:gang[MAX_NAME_LENGTH];
        GetArrayString(hRepArray, i, gang, sizeof(gang));

        decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
        SQL_EscapeString(hDrugDB, gang, sNewName, sizeof(sNewName));

        decl update[GangData];
        GetTrieArray(hRepUpdate, gang, update, GangData);

        decl String:query[256];
        Format(query, sizeof(query),
               "UPDATE gangs SET rep = rep + %d, totalspent = totalspent + %d WHERE name = '%s'",
               update[GD_Rep], update[GD_TotalSpent], sNewName);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }

    ClearArray(hUpdateArray);
    ClearTrie(hPlayerUpdate);

    ClearArray(hRepArray);
    ClearTrie(hRepUpdate);

    CreateTimer(GetConVarFloat(hUpdateEvery),
                UpdateDB, _, TIMER_FLAG_NO_MAPCHANGE);
}
