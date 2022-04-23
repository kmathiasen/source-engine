
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_NC_CLIENT_IS_UNKNOWN 0
#define LOCALDEF_NC_CLIENT_IS_MEMBER 1
#define LOCALDEF_NC_CLIENT_IS_NONMEMBER 2
#define LEN_RC_STRINGS 64
#define LEN_RC_PENALTIES 24
#define LEN_NAMEREGEXES 64

// Member info.
new g_iNC_MemberType[MAXPLAYERS + 1];
new String:g_sNC_MemberDefaultNames[MAXPLAYERS + 1][MAX_NAME_LENGTH];
new Handle:g_hNC_MemberCompiledPatterns[MAXPLAYERS + 1];
new bool:g_bNC_MemberEnforced[MAXPLAYERS + 1];
new bool:g_bNC_MemberExact[MAXPLAYERS + 1];
new bool:g_bIsLookingUp[MAXPLAYERS + 1];

// Restricted Content (RC) strings & associated punishments.
new Handle:g_hRC_Strings = INVALID_HANDLE;
new Handle:g_hRC_Penalties = INVALID_HANDLE;

// Declare commonly used ConVars.
new bool:g_bNcModeExact;
new bool:g_bNcModeExclusive;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

NameControl_OnPluginStart()
{
    g_hRC_Strings = CreateArray(LEN_RC_STRINGS);
    g_hRC_Penalties = CreateArray(LEN_RC_PENALTIES);
    for (new i = 1; i <= MaxClients; i++)
        NameControl_ResetClientInfo(i);
}

NameControl_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_bNcModeExact = GetConVarBool(g_hCvNameControlExact);
    g_bNcModeExclusive = GetConVarBool(g_hCvNameControlExclusive);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvNameControlExact, NameControl_OnConVarChange);
    HookConVarChange(g_hCvNameControlExclusive, NameControl_OnConVarChange);
}

public NameControl_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvNameControlExact)
        g_bNcModeExact = GetConVarBool(g_hCvNameControlExact);
    else if (CVar == g_hCvNameControlExclusive)
        g_bNcModeExclusive = GetConVarBool(g_hCvNameControlExclusive);
}

NameControl_OnDbConnect(Handle:conn)
{
    // Clear any existing RC.
    ClearArray(g_hRC_Strings);
    ClearArray(g_hRC_Penalties);

    // Create and execute SQL statement to get RC.
    decl String:q[256];
    Format(q, sizeof(q), "SELECT LEFT(string, %i), LEFT(penalty, %i) FROM rc", (LEN_RC_STRINGS - 1), (LEN_RC_PENALTIES - 1));
    SQL_TQuery(conn, NameControl_GetRc_CB, q, _);
}

NameControl_OnClientPutInServer(client)
{
    NameControl_ResetClientInfo(client);
}

bool:NameControl_OnJoinTeam(client)
{
    switch(g_iNC_MemberType[client])
    {
        case LOCALDEF_NC_CLIENT_IS_MEMBER:
        {
            return NameControl_CheckMember(client, true);
        }
        case LOCALDEF_NC_CLIENT_IS_NONMEMBER:
        {
            return NameControl_CheckNonMember(client, true);
        }
        default:
        {
            // He was not looked up yet.
            // The player will be checked later in the callback.
            NameControl_LookupPlayer(client);
            return true;
        }
    }
    return true;
}

NameControl_OnNameChange(client)
{
    switch(g_iNC_MemberType[client])
    {
        case LOCALDEF_NC_CLIENT_IS_MEMBER:
        {
            NameControl_CheckMember(client);
        }
        case LOCALDEF_NC_CLIENT_IS_NONMEMBER:
        {
            NameControl_CheckNonMember(client);
        }
        default:
        {
            // He was not looked up yet.
            NameControl_LookupPlayer(client);
        }
    }
}

// ####################################################################################
// ##################################### FUNCTIONS ####################################
// ####################################################################################

NameControl_ResetClientInfo(client)
{
    g_iNC_MemberType[client] = LOCALDEF_NC_CLIENT_IS_UNKNOWN;
    g_sNC_MemberDefaultNames[client][0] = '\0';
    if (g_hNC_MemberCompiledPatterns[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hNC_MemberCompiledPatterns[client]);
        g_hNC_MemberCompiledPatterns[client] = INVALID_HANDLE;
    }
    g_bNC_MemberEnforced[client] = false;
    g_bNC_MemberExact[client] = false;
}

NameControl_LookupPlayer(client)
{
    // Ensure plugin is connected to the DB.
    if (g_hDbConn_NC == INVALID_HANDLE)
        return;

    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return;

    if (g_bIsLookingUp[client])
        return;

    g_bIsLookingUp[client] = true;

    // We're about to get in this info, so clear old info first.
    NameControl_ResetClientInfo(client);

    // Get Steam ID.
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, LEN_STEAMIDS);

    // Package up data that we need in the callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, client);
    WritePackString(data, steam);

    // Look up player from database.
    decl String:q[1024];
    Format(q, sizeof(q), "SELECT LEFT(defaultname, %i), LEFT(nameregex, %i), enforce, exact FROM members WHERE steamid = '%s' LIMIT 1", (MAX_NAME_LENGTH - 1), (LEN_NAMEREGEXES - 1), steam);
    SQL_TQuery(g_hDbConn_NC, NameControl_LookupPlayer_CB, q, data);
}

bool:NameControl_CheckMember(client, bool:callerBlocksJoin=false)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return true;

    // Get player info.
    decl String:steam[LEN_STEAMIDS];
    decl String:name[MAX_NAME_LENGTH];
    GetClientAuthString2(client, steam, LEN_STEAMIDS);
    GetClientName(client, name, MAX_NAME_LENGTH);

    // He should be a member.
    if (g_iNC_MemberType[client] != LOCALDEF_NC_CLIENT_IS_MEMBER)
    {
        // Woah, something's wrong.
        LogMessage("ERROR IN NameControl_CheckMember: %s not a member.", steam);
        return true;
    }

    // If this player should not be enforced, allow.
    if (!g_bNC_MemberEnforced[client])
        return true;

    // If exact is TRUE, the name has to match exactly.
    if (g_bNC_MemberExact[client] || g_bNcModeExact)
    {
        if (strcmp(name, g_sNC_MemberDefaultNames[client]) == 0)
            return true;
        else
        {
            // Let client know why we are moving to spec (a delayed message).
            CreateTimer(1.0, DisplayNotExactMsg, any:GetClientUserId(client));

            // Log.
            LogMessage("[%s] Switching member to team %i for inexact name...", steam, TEAM_SPEC);

            // Move to spec.
            if (!callerBlocksJoin)
            {
                // If not already on spec, switch to spec.
                if (GetClientTeam(client) > TEAM_SPEC)
                    ChangeClientTeam(client, TEAM_SPEC);
            }
            return false;
        }
    }

    // Else, only the tag has to match.
    else
    {
        // Check if name matches name regex pattern.
        if (MatchRegex(g_hNC_MemberCompiledPatterns[client], name) > 0)
            return true;
        else
        {
            // Let client know why we are moving to spec (a delayed message).
            CreateTimer(1.0, DisplayWrongTagMsg, any:GetClientUserId(client));

            // Log
            LogMessage("[%s] Member mame is %s which does not match the name regex pattern", steam, name);

            // Move to spec.
            if (!callerBlocksJoin)
            {
                // If not already on spec, switch to spec.
                if (GetClientTeam(client) > TEAM_SPEC)
                    ChangeClientTeam(client, TEAM_SPEC);
            }
            return false;
        }
    }
}

bool:NameControl_CheckNonMember(client, bool:callerBlocksJoin = false)
{
    // Ensure client is valid player.
    if (!IsClientInGame(client) || IsFakeClient(client))
        return true;

    // Get player info.
    decl String:steam[LEN_STEAMIDS];
    decl String:name[MAX_NAME_LENGTH];
    GetClientAuthString2(client, steam, sizeof(steam));
    GetClientName(client, name, sizeof(name));

    // He should be a NONmember.
    if (g_iNC_MemberType[client] != LOCALDEF_NC_CLIENT_IS_NONMEMBER)
    {
        // Woah, something's wrong.
        LogMessage("ERROR IN NameControl_CheckNonMember: %s not a NONmember.", steam);
        return true;
    }

    // Check if name matches any of the RC strings.
    decl String:rc_string[LEN_RC_STRINGS];
    decl String:rc_penalty[LEN_RC_PENALTIES];
    new rc_count = GetArraySize(g_hRC_Strings);
    for (new i = 0; i < rc_count; i++)
    {
        // Get RC string.
        GetArrayString(g_hRC_Strings, i, rc_string, LEN_RC_STRINGS);

        // Does name contain RC string?
        if (StrContains(name, rc_string, false) > -1)
        {
            // Get RC penalty.
            GetArrayString(g_hRC_Penalties, i, rc_penalty, LEN_RC_PENALTIES);

            // Punish.
            if (StrEqual(rc_penalty, "kick"))
            {
                KickClient(client, "Forbidden name (contains %s)", rc_string);
                LogMessage("[%s] Kicked %s for RC string %s", steam, name, rc_string);
            }
            else if (StrEqual(rc_penalty, "bant"))
            {
                //ServerCommand("banid 5.0 %s", steam);
                ServerCommand("sm_ban #%d %f \"Forbidden name (contains %s)\"", GetClientUserId(client), 5.0, rc_string);

                // Report in log.
                LogMessage("[%s] 5 min banned %s for RC string %s", steam, name, rc_string);
            }
            else if (StrEqual(rc_penalty, "banp"))
            {
                //ServerCommand("banid 0.0 %s", steam);
                ServerCommand("sm_ban #%d %f \"Forbidden name (contains %s)\"", GetClientUserId(client), 0.0, rc_string);

                // Report in log.
                LogMessage("[%s] Permanently banned %s for RC string %s", steam, name, rc_string);
            }
            else /* spec */
            {
                // Let client know why we are moving to spec (a delayed message).
                CreateTimer(1.0, DisplayReservedTagMsg, any:GetClientUserId(client));

                // Log.
                LogMessage("[%s] Switching %s to team %i for RC string %s", steam, name, TEAM_SPEC, rc_string);

                // Move to spec.
                if (!callerBlocksJoin)
                {
                    // If not already on spec, switch to spec.
                    if (GetClientTeam(client) > TEAM_SPEC)
                        ChangeClientTeam(client, TEAM_SPEC);
                }
            }

            // We don't need to continue checking for any other Restricted Strings.
            // Return false to deny team join.
            return false;
        }
    }

    // Name matched none of the Restricted Strings.
    return true;
}

// ####################################################################################
// ################################## SQL CALLBACKS ###################################
// ####################################################################################

public NameControl_LookupPlayer_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Holders.
    new client;
    decl String:steam[LEN_STEAMIDS];

    // Unpack data-pack.
    ResetPack(Handle:data);
    client = ReadPackCell(Handle:data);
    ReadPackString(Handle:data, steam, LEN_STEAMIDS);

    // Finished with data-pack.
    CloseHandle(data);

    g_bIsLookingUp[client] = false;

    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 12))
    {
        LogMessage("ERROR in NameControl_LookupPlayer_CB");
        return;
    }

    // Is client still in-game?
    if (!IsClientInGame(client))
        return;

    // Did the DB return results?
    if (SQL_GetRowCount(fetch) <= 0)
    {
        // Kick if exclusive mode (members only) is on.
        if (g_bNcModeExclusive)
        {
            KickClient(client, "Sorry, members only event");
            return;
        }

        // Player was not in the DB.  He is not a clan member.
        g_iNC_MemberType[client] = LOCALDEF_NC_CLIENT_IS_NONMEMBER;

        // Check non-member.
        NameControl_CheckNonMember(client);
    }
    else
    {
        // Holders.
        decl String:defaultName[MAX_NAME_LENGTH];
        decl String:nameRegex[LEN_NAMEREGEXES];
        new bool:enforce, bool:exact;

        // Get fetched row(s).
        new bool:gotRow = false;
        while(SQL_FetchRow(fetch))
        {
            // Only 1 row should be returned.
            if (gotRow)
                break;
            else
                gotRow = true;

            // Grab [defaultname].
            SQL_FetchString(fetch, 0, defaultName, MAX_NAME_LENGTH);

            // Grab [nameregex].
            SQL_FetchString(fetch, 1, nameRegex, LEN_NAMEREGEXES);

            // Grab [enforce].
            enforce = bool:SQL_FetchInt(fetch, 2);

            // Grab [exact].
            exact = bool:SQL_FetchInt(fetch, 3);

            // Insert player info into Tries.
            g_iNC_MemberType[client] = LOCALDEF_NC_CLIENT_IS_MEMBER;
            Format(g_sNC_MemberDefaultNames[client], MAX_NAME_LENGTH, defaultName);
            g_hNC_MemberCompiledPatterns[client] = CompileRegex(nameRegex);
            g_bNC_MemberEnforced[client] = enforce;
            g_bNC_MemberExact[client] = exact;

            // Check member.
            NameControl_CheckMember(client);
        }
    }
}

public NameControl_GetRc_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 13))
    {
        LogMessage("ERROR in NameControl_GetRc_CB");
        return;
    }

    // Did the DB return results?
    if (SQL_GetRowCount(fetch) <= 0)
    {
        LogMessage("NOTICE: No RC returned from DB");
    }
    else
    {
        // Holders.
        decl String:rc_string[LEN_RC_STRINGS];
        decl String:rc_penalty[LEN_RC_PENALTIES];

        // Get results.
        while(SQL_FetchRow(fetch))
        {
            // Grab [string].
            SQL_FetchString(fetch, 0, rc_string, sizeof(rc_string));

            // Grab [penalty].
            SQL_FetchString(fetch, 1, rc_penalty, sizeof(rc_penalty));

            // Insert into Trie(s).
            PushArrayString(g_hRC_Strings, rc_string);
            PushArrayString(g_hRC_Penalties, rc_penalty);
        }
    }
}

// ####################################################################################
// ################################# TIMER CALLBACKS ##################################
// ####################################################################################

public Action:DisplayNotExactMsg(Handle:timer, any:userid)
{
    // Extract passed client.
    new client = GetClientOfUserId(_:userid);
    if (!IsClientInGame(client))
        return Plugin_Continue;

    // Display message(s) to client.
    PrintToChat(client, "%s Your name is incorrect!", MSG_PREFIX);
    PrintToChat(client, "%s This server requires your exact clan name.", MSG_PREFIX);
    PrintToChat(client, "%s Your correct name is:", MSG_PREFIX);
    PrintToChat(client, "%s \x01%s\x04", MSG_PREFIX, g_sNC_MemberDefaultNames[client]);
    PrintToChat(client, "%s \x03Please check the spelling of your name.", MSG_PREFIX);
    PrintToChat(client, "%s TS3: voice.hellsgamers.com:2010", MSG_PREFIX);
    return Plugin_Continue;
}

public Action:DisplayWrongTagMsg(Handle:timer, any:userid)
{
    // Extract passed client.
    new client = GetClientOfUserId(_:userid);
    if (!IsClientInGame(client))
        return Plugin_Continue;

    // Display message(s) to client.
    PrintToChat(client, "%s Your tag differs from your HG rank!", MSG_PREFIX);
    PrintToChat(client, "%s Your correct name is:", MSG_PREFIX);
    PrintToChat(client, "%s \x01%s\x04", MSG_PREFIX, g_sNC_MemberDefaultNames[client]);
    PrintToChat(client, "%s Your name can vary, but not the tag.", MSG_PREFIX);
    PrintToChat(client, "%s \x03Please check the spelling of your tag.", MSG_PREFIX);
    PrintToChat(client, "%s TS3: voice.hellsgamers.com:2010", MSG_PREFIX);
    return Plugin_Continue;
}

public Action:DisplayReservedTagMsg(Handle:timer, any:userid)
{
    // Extract passed client.
    new client = GetClientOfUserId(_:userid);
    if (!IsClientInGame(client))
        return Plugin_Continue;

    // Display message(s) to client.
    PrintToChat(client, "%s You may not use this tag in your name!", MSG_PREFIX);
    PrintToChat(client, "%s If you are a HG member, and are seeing", MSG_PREFIX);
    PrintToChat(client, "%s this, make sure that the SteamId you", MSG_PREFIX);
    PrintToChat(client, "%s are currently using is the same one you", MSG_PREFIX);
    PrintToChat(client, "%s entered in your forum profile on the", MSG_PREFIX);
    PrintToChat(client, "%s website @ www.hellsgamers.com.", MSG_PREFIX);
    PrintToChat(client, "%s \x03Please rename yourself....", MSG_PREFIX);
    PrintToChat(client, "%s TS3: voice.hellsgamers.com:2010", MSG_PREFIX);
    return Plugin_Continue;
}
