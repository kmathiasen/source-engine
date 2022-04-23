
new bool:g_bDisplayedMicrowaveWarning[MAXPLAYERS + 1];

/* ----- Events ----- */


public Admin_OnPluginStart()
{
    RegConsoleCmd("sm_setleader", Command_SetLeader);
    RegConsoleCmd("sm_debug", Command_DebugSpawn);
    RegConsoleCmd("sm_sql", Command_ExecuteSQL);

    if (g_iGame == GAMETYPE_CSS)
    {
        RegAdminCmd("sm_turtles", Command_Turtles, ADMFLAG_CUSTOM4);
    }

    else if (g_iGame == GAMETYPE_CSGO)
    {
        RegAdminCmd("sm_chickens", Command_Turtles, ADMFLAG_CUSTOM4);
    }

    //RegConsoleCmd("gang_givepoints", Command_AdminGivePoints);
    //RegServerCmd("gang_spawndrugs", Command_SpawnDrugs, "Spawns the specified number of drugs at the provided coordinates");
}

stock Admin_OnRoundStart()
{
    for (new i = 0; i < MAXPLAYERS; i++)
    {
        g_bDisplayedMicrowaveWarning[i] = false;
    }
}

public OnMicrowaveBreak(const String:output[], caller, activator, Float:delay)
{
    PrintToChatAll("\x03%N\x04 broke the microwave pinata!", activator);

    decl Float:origin[3];
    GetEntPropVector(caller, Prop_Send, "m_vecOrigin", origin);

    origin[2] += 25.0;

    new iExplosion = CreateEntityByName("env_explosion");

    if (!GetRandomInt(0, 3))
    {
        PrintToChatAll("\x04But it exploded...");

        DispatchKeyValue(iExplosion, "iMagnitude", "50");
        DispatchKeyValue(iExplosion, "iRadiusOverride", "400");
    }

    if (GetClientTeam(activator) == TEAM_CT)
        SetEntProp(iExplosion, Prop_Send, "m_iTeamNum", TEAM_T);

    DispatchKeyValueVector(iExplosion, "Origin", origin);
    SetEntPropEnt(iExplosion, Prop_Send, "m_hOwnerEntity", activator);

    AcceptEntityInput(iExplosion, "Explode");
    AcceptEntityInput(iExplosion, "Kill");

    if (!GetRandomInt(0, 2))
    {
        ExplodeFromOrigin(origin, true);
        PrintToChatAll("\x04And it was filled with \x05%s\x04!", g_iGame == GAMETYPE_CSS ? "turtles" : "chickens");
    }

    else
    {
        ExplodeFromOrigin(origin);
        PrintToChatAll("\x04And it was filled with \x05drugs\x04!");
    }
}


/* ----- Commands ----- */



// JJK's idea. I think it's funny. Hope you don't mind Bonbon.
public Action:Command_SpawnDrugs(args)
{
    // We expect 4 args after the command.
    if (args < 4)
    {
        PrintToConsole(0, "Usage:  gang_spawndrugs <num of drugs> <x loc of drugs> <y loc of drugs> <z loc of drugs>");
        return Plugin_Handled;
    }

    // Get & split arguments.
    decl String:argString[256];
    GetCmdArgString(argString, sizeof(argString));
    decl String: splitArgs[4][32];
    ExplodeString(argString, " ", splitArgs, 4, 32);

    // Get values from split arguments.
    new quantity = StringToInt(splitArgs[0]);
    decl Float:fLocation[3];
    fLocation[0] = StringToFloat(splitArgs[1]);
    fLocation[1] = StringToFloat(splitArgs[2]);
    fLocation[2] = StringToFloat(splitArgs[3]);

    if (quantity <= 0 || quantity > 50) // 50 is arbitrary.
        return Plugin_Handled;

    // Spawn the drugs.
    for (new i = 0; i < quantity; i++)
    {
        SpawnDrugs(fLocation[0], fLocation[1], fLocation[2]);
        fLocation[2] += 4.0;
    }
    return Plugin_Handled;
}


// debug
// In my defence, it was originally written for debug
// But then JJK liked the commands
public Action:Command_DebugSpawn(client, args)
{
    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    OnClientAuthorized(client, steamid);

    if (isAuthed(client))
    {
        decl Float:loc[3];

        /* Just in case spawning at their feet makes them stuck */
        GetClientEyePosition(client, loc);

        PrintToChat(client,
                    "%s Spawning drugs at \x04%.2f %.2f %.2f",
                    MSG_PREFIX, loc[0], loc[1], loc[2]);

        PrintToChat(client,
                    "%s isRatioFucked() returns \x04%d",
                    MSG_PREFIX, isRatioFucked());

        new drugsLeft = FreeDrugs();
        if (drugsLeft < 1)
        {
            PrintToChat(client,
                        "%s There are too many drugs spawned", MSG_PREFIX);
            return Plugin_Handled;
        }

        PrintToChat(client,
                    "%s Spawning drug \x04[%d/%d]",
                    MSG_PREFIX, (MAX_DRUGS - drugsLeft) + 1, MAX_DRUGS);

        SpawnDrugs(loc[0], loc[1], loc[2]);
    }

    return Plugin_Handled;
}
// End Debug

public Action:Command_AdminGivePoints(client, args)
{
    if (!isAuthed(client))
        return Plugin_Handled;

    // This is corrupting the DB somehow.
    if (g_iGame == GAMETYPE_CSGO)
        return Plugin_Handled;

    if (args < 2)
    {
        PrintToChat(client,
                    "%s Invalid syntax -- gang_givepoints <steamid> <amount>",
                    MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:steamid[32];
    decl String:sAmount[8];

    GetCmdArg(1, steamid, sizeof(steamid));
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new amount = StringToInt(sAmount);
    if (!amount)
    {
        PrintToChat(client, "%s Please enter a non zero value", MSG_PREFIX);
        return Plugin_Handled;
    }

    new target = FindClientFromSteamid(steamid);
    if (target <= 0)
        PrisonRep_AddPoints_Offline(steamid, amount);

    else
        PrisonRep_AddPoints(target, amount);

    decl String:client_steamid[32];
    GetClientAuthString(client, client_steamid, sizeof(client_steamid));

    decl String:path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "scripting/admin_giveplayer.log");

    new Handle:iFile = OpenFile(path, "a");

    LogToOpenFile(iFile, "%N (%s) sent UNKNOWN (%s) %d rep", client, client_steamid, steamid, amount);
    CloseHandle(iFile);

    BuildPath(Path_SM, path, sizeof(path), "logs/admin_giveplayer.log");
    iFile = OpenFile(path, "a");

    LogToOpenFile(iFile, "%N (%s) sent UNKNOWN (%s) %d rep", client, client_steamid, steamid, amount);
    CloseHandle(iFile);

    /*
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT steamid, name FROM playerdata WHERE steamid = '%s'", steamid);

    new Handle:hData = CreateDataPack();
    WritePackCell(hData, GetClientUserIdSafe(client));
    WritePackCell(hData, amount);

    SQL_TQuery(hDrugDB, AdminGivePointsCallback, query, hData);
    */
    return Plugin_Handled;
}

public Action:Command_ExecuteSQL(client, args)
{
    if (isAuthed(client) < 2)
        return Plugin_Handled;

    decl String:query[255];
    GetCmdArgString(query, sizeof(query));

    SQL_TQuery(hDrugDB, EmptyCallback, query);
    PrintToChat(client,
                "%s You better not have broken anything...", MSG_PREFIX);

    return Plugin_Handled;
}

public Action:Command_Turtles(client, args)
{
    if (!g_bDisplayedMicrowaveWarning[client])
    {
        DisplayMSay(client, "Command Rules", 60, "Smallest violation will result\n   in loss of privileges\n\nNo prop blocking\nNo spawning in players\nNo interfering with gameplay*\n\n*Except during warday");
        g_bDisplayedMicrowaveWarning[client] = true;
    }

    new max_per_round = 5;
    if (GetUserFlagBits(client) & ADMFLAG_ROOT)
        max_per_round *= 2;

    if (iMicrowavesThisRound > max_per_round)
    {
        PrintToChat(client, "%s There are too many microwaves :(", MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:msg[256];
    decl String:steamid[32];

    GetClientAuthString(client, steamid, sizeof(steamid));
    Format(msg, sizeof(msg), "%N (%s) spawned a microwave", client, steamid);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            PrintToConsole(i, msg);
    }

    iMicrowavesThisRound++;

    decl Float:start[3];
    decl Float:end[3];
    decl Float:angs[3];
    
    GetClientEyePosition(client, start);
    GetClientEyeAngles(client, angs);

    new Handle:tr = TR_TraceRayFilterEx(start, angs, MASK_SHOT, RayType_Infinite, FilterPlayers);

    if (TR_DidHit(tr))
        TR_GetEndPosition(end, tr);

    new microwave = CreateEntityByName("prop_physics_override");

    DispatchKeyValue(microwave, "model", "models/props/cs_office/microwave.mdl");
    DispatchSpawn(microwave);

    SetEntProp(microwave, Prop_Data, "m_takedamage", 2, 1);
    SetEntData(microwave, FindDataMapOffs(microwave, "m_iHealth"), 333, 4, true);

    TeleportEntity(microwave, end, NULL_VECTOR, NULL_VECTOR);
    HookSingleEntityOutput(microwave, "OnBreak", OnMicrowaveBreak, true);

    return Plugin_Handled;
}

stock ExplodeFromOrigin(Float:origin[3], bool:turtle=false)
{
    // debug
    turtle = true;

    new turtles = turtle ? (GetRandomInt(0, 1) ? 5 : 8) : GetRandomInt(4, 8);
    new turtle_index;
    new Float:theta_step = DegToRad(180.0 - (360.0 / turtles));

    for (new i = 0; i < turtles; i++)
    {
        new Float:turtle_origin[3];
        new Float:velocity[3];

        turtle_origin[0] = origin[0] + 50 * Cosine(theta_step * i);
        turtle_origin[1] = origin[1] + 50 * Sine(theta_step * i);
        turtle_origin[2] = origin[2];

        velocity[0] = 50 * Cosine(theta_step * i);
        velocity[1] = 50 * Sine(theta_step * i);
        velocity[2] = GetRandomFloat(150.0, 400.0);

        if (turtle)
        {
            if (g_iGame == GAMETYPE_CSS)
            {
                turtle_index = CreateEntityByName("prop_physics_override");
                DispatchKeyValue(turtle_index, "model", "models/props/de_tides/Vending_turtle.mdl");
            }

            else if (g_iGame == GAMETYPE_CSGO)
            {
                turtle_index = CreateEntityByName("chicken");
                DispatchKeyValue(turtle_index, "model", "models/chicken/chicken.mdl");
                velocity = Float:{0.0, 0.0, 0.0};
            }

            DispatchSpawn(turtle_index);

            if (g_iGame == GAMETYPE_CSS)
            {
                SetEntProp(turtle_index, Prop_Data, "m_takedamage", 2, 1);
                SetEntData(turtle_index, FindDataMapOffs(turtle_index, "m_iHealth"), 10, 4, true);
            }
        }

        else
            turtle_index = SpawnDrugs(turtle_origin[0], turtle_origin[1], turtle_origin[2]);

        if (turtle_index > 0)
            TeleportEntity(turtle_index, turtle_origin, NULL_VECTOR, velocity);
    }
}

public Action:Command_SetLeader(client, args)
{
    if (!isAuthed(client))
        return Plugin_Handled;

    if (args < 2)
    {
        PrintToChat(client,
                    "%s Invalid syntax -- \x04!setleader \"<steamid>\" \"<gang>\"",
                    MSG_PREFIX);
        return Plugin_Handled;
    }

    decl String:steamid[32];
    decl String:gang[MAX_NAME_LENGTH];
    decl String:name[MAX_NAME_LENGTH];
    decl String:sNewPlayer[MAX_NAME_LENGTH * 2 + 1];

    GetCmdArg(1, steamid, sizeof(steamid));
    GetCmdArg(2, gang, sizeof(gang));

    decl String:sNewName[MAX_NAME_LENGTH * 2 + 1];
    SQL_EscapeString(hDrugDB, gang, sNewName, sizeof(sNewName));

    SQL_LockDatabase(hDrugDB);

    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT ownersteamid FROM gangs WHERE name = '%s'", sNewName);

    new Handle:hndl = SQL_Query(hDrugDB, query);
    if (!SQL_FetchRow(hndl))
    {
        PrintToChat(client,
                    "%s the gang \x04\"%s\"\x01 does not exist",
                    MSG_PREFIX, gang);

        CloseHandle(hndl);
        SQL_UnlockDatabase(hDrugDB);

        return Plugin_Handled;
    }

    decl String:ownersteamid[32];
    SQL_FetchString(hndl, 0, ownersteamid, sizeof(ownersteamid));

    CloseHandle(hndl);
    Format(query, sizeof(query),
           "SELECT name FROM playerdata WHERE steamid = '%s'", steamid);

    hndl = SQL_Query(hDrugDB, query);
    if (!SQL_FetchRow(hndl))
    {
        PrintToChat(client,
                    "%s That player is not in the database", MSG_PREFIX);

        CloseHandle(hndl);
        SQL_UnlockDatabase(hDrugDB);

        return Plugin_Handled;
    }

    SQL_FetchString(hndl, 0, name, sizeof(name));
    SQL_EscapeString(hDrugDB, name, sNewPlayer, sizeof(sNewPlayer));

    PrintToChat(client,
                "%s Passing ownership of \x04%s\x01 to \x04%s",
                MSG_PREFIX, gang, name);

    PrintToChat(client,
                "%s old owner = \x04%s \x01 new owner = \x04%s",
                MSG_PREFIX, ownersteamid, steamid);

    Format(query, sizeof(query),
           "UPDATE playerdata SET isowner = 0 WHERE steamid = '%s'",
            ownersteamid);
    SQL_FastQuery(hDrugDB, query);

    Format(query, sizeof(query),
           "UPDATE playerdata SET isowner = 1, joined = 0 WHERE steamid = '%s'",
           steamid);
    SQL_FastQuery(hDrugDB, query);

    Format(query, sizeof(query),
           "UPDATE gangs SET ownersteamid = '%s', ownername = '%s' WHERE name = '%s'",
           steamid, sNewPlayer, sNewName);
    SQL_FastQuery(hDrugDB, query);

    CloseHandle(hndl);
    CreateGangInfoMenus();

    SQL_UnlockDatabase(hDrugDB);
    return Plugin_Handled;
}


/* ----- Callbacks ----- */


public bool:FilterPlayers(entity, cmask)
{
    return (entity > MaxClients || !entity);
}

public AdminGivePointsCallback(Handle:hGang,
                               Handle:hndl, const String:error[], any:hData)
{
    ResetPack(hData);
    new client = GetClientOfUserId(ReadPackCell(hData));

    new amount = ReadPackCell(hData);
    CloseHandle(hData);

    if (!client)
        return;

    if (!SQL_FetchRow(hndl))
    {
        PrintToChat(client,
                    "%s That steamid isn't in the database yet", MSG_PREFIX);
        return;
    }

    decl String:name[MAX_NAME_LENGTH];
    decl String:query[256];
    decl String:steamid[32];

    SQL_FetchString(hndl, 0, steamid, sizeof(steamid));
    SQL_FetchString(hndl, 1, name, sizeof(name));

    PrintToChat(client,
                "%s Giving \x03%s \x04%d\x01 points", MSG_PREFIX, name, amount);

    new target = FindClientFromSteamid(steamid);
    if (target)
        AddPoints(target, amount);

    else
    {
        Format(query, sizeof(query),
               "UPDATE playerdata SET points = points + %d WHERE steamid = '%s'",
               amount, steamid);

        SQL_TQuery(hDrugDB, EmptyCallback, query);
    }
}


/* ----- Return Values ----- */


isAuthed(client, bool:display=true)
{
    decl String:steamid[32];
    GetClientAuthString2(client, steamid, sizeof(steamid));

    if (StrEqual(steamid, "STEAM_0:0:11089864") ||      // Bonbon
        StrEqual(steamid, "STEAM_0:0:11710485") ||      // JJK
        StrEqual(steamid, "STEAM_0:0:34243649"))        // Reddevil
    {
        if (StrEqual(steamid, "STEAM_0:0:11089864"))
            return 2;
        return 1;
    }

    if (display)
    {
        PrintToChat(client,
                    "%s You are not authorized to screw with the db shitz",
                    MSG_PREFIX);
    }
    return 0;
}
