
// ####################################################################################
// ###################################### GLOBALS #####################################
// ####################################################################################

// Constants.
#define LOCALDEF_TLIST_CMDTYPE_TLIST 0
#define LOCALDEF_TLIST_CMDTYPE_UNTLIST 1

// For reading bans database (T-Listing).
#define APPROVED_STATE_PENDING 0
#define APPROVED_STATE_APPROVED 1
#define APPROVED_STATE_DISAPPROVED 2
#define APPROVED_STATE_SERVERBAN 3
#define BAN_CAT_REGULARBAN -1
#define BAN_CAT_TLIST -2

// Stores how many times a player tried to join CT in a round (to prevent team join spam).
new g_iTriedJoiningTeam[MAXPLAYERS + 1];

// When someone gets looked-up, they will be held in this known list.
// THIS ARRAY IS ONLY TO DETERMINE WHO SHOULD NOT SHOWS UP IN THE MENU.
// THIS IS NOT A T-LIST CACHE.
// It is only a convienience thing so the menu is not cluttered with people
// who are PROBABLY already T-Listed.  Even clients in this array will be
// looked up again from the db when they try to join ct.
new g_bKnownFreekillers[MAXPLAYERS + 1];

// ####################################################################################
// ####################################### EVENTS #####################################
// ####################################################################################

Tlist_OnPluginStart()
{
    RegAdminCmd("list", Command_Tlist, ADMFLAG_KICK, "T-Lists a player");
    RegAdminCmd("tlist", Command_Tlist, ADMFLAG_KICK, "T-Lists a player");
    RegAdminCmd("rlist", Command_Tlist, ADMFLAG_KICK, "T-Lists a player");
    RegAdminCmd("redlist", Command_Tlist, ADMFLAG_KICK, "T-Lists a player");
    RegAdminCmd("delist", Command_Tlist, ADMFLAG_KICK, "Un-T-Lists a player");
    RegAdminCmd("unlist", Command_Tlist, ADMFLAG_KICK, "Un-T-Lists a player");
    RegAdminCmd("untlist", Command_Tlist, ADMFLAG_KICK, "Un-T-Lists a player");
    RegAdminCmd("unredlist", Command_Tlist, ADMFLAG_KICK, "Un-T-Lists a player");
    RegAdminCmd("unrlist", Command_Tlist, ADMFLAG_KICK, "Un-T-Lists a player");
}

Tlist_OnDbConnect(Handle:conn)
{
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT subject_steamid, category FROM bans \
           WHERE (UNIX_TIMESTAMP() - datetime_modified) < %f AND category IN (%i, %i) \
           AND (approved_state = %d or approved_state = %d) \
           AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0)",
           UPDATE_FREQ, BAN_CAT_REGULARBAN, BAN_CAT_TLIST,
           APPROVED_STATE_APPROVED, APPROVED_STATE_SERVERBAN);
    SQL_TQuery(conn, Tlist_GetBansSinceLastTick_CB, query);
}

Tlist_OnRndStart_General()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        g_iTriedJoiningTeam[i] = 0;
    }
}

Tlist_OnClientPutInServer(client)
{
    g_iTriedJoiningTeam[client] = 0;
    g_bKnownFreekillers[client] = false;
}

bool:Tlist_AllowedToJoinGuards(client)
{
    // Return values.
    #define BLOCK_PLAYER_JOIN false
    #define ALLOW_PLAYER_JOIN true

    // Reset their assumed status, because we are about to look them up from the DB for sure.
    g_bKnownFreekillers[client] = false;

    // Increase how many times they've tried to join the CT team this round.
    g_iTriedJoiningTeam[client]++;

    // Warn them not to join too many times.
    new limit = GetConVarInt(g_hCvTeamJoinSpamLimit);
    if (g_iTriedJoiningTeam[client] == limit - 1)
        DisplayMSay(client, "Do not spam team join!", MENU_TIMEOUT_QUICK, "You have one join left\nthis round before kick");
    else if (g_iTriedJoiningTeam[client] == limit)
    {
        new dur = GetConVarInt(g_hCvTeamJoinSpamBanDur);
        decl String:reason[LEN_CONVARS];
        Format(reason, sizeof(reason), "Spamming team join (%i minute ban)", dur);
        BanClient(client, dur, BANFLAG_IP, reason, reason, _, _);
        return BLOCK_PLAYER_JOIN;
    }

    // Are we disconnected?
    if (g_hDbConn_Bans == INVALID_HANDLE)
    {
        LogMessage("ERROR in Tlist_AllowedToJoinGuards: The DB handle was invalid");
        return ALLOW_PLAYER_JOIN;
    }

    // Get Steam ID.
    decl String:steam[LEN_STEAMIDS];
    GetClientAuthString2(client, steam, sizeof(steam));

    // Check for family sharing tlists
    new String:familycheck[64];
    if (!StrEqual(g_sOwnerSteamid[client], ""))
    {
        Format(familycheck, sizeof(familycheck), "or subject_steamid = '%s'", g_sOwnerSteamid[client]);
    }

    // Query to check if this Steam ID is banned.
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT id FROM bans \
           WHERE (subject_steamid = '%s' %s)\
           AND category = %i \
           AND (approved_state = %d OR approved_state = %d) \
           AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0) \
           LIMIT 1",
           steam, familycheck, BAN_CAT_TLIST, APPROVED_STATE_APPROVED, APPROVED_STATE_SERVERBAN);

    // Lock database because we're using a non-threaded query.
    SQL_LockDatabase(g_hDbConn_Bans);

    // Execute query.
    new Handle:fetch = SQL_Query(g_hDbConn_Bans, query);

    // Exit if fetch handle is invalid.
    if (fetch == INVALID_HANDLE)
    {
        // Unlock.
        SQL_UnlockDatabase(g_hDbConn_Bans);

        // The fetch handle is invalid; nothing to close.

        // Report error.
        LogMessage("ERROR IN Tlist_AllowedToJoinGuards: Problem getting results for Steam ID (%s)", steam);
        decl String:error[255];
        SQL_GetError(g_hDbConn_Bans, error, sizeof(error));
        Db_QueryFailed(g_hDbConn_Bans, fetch, error, 5);

        // Exit (allow team join).
        return ALLOW_PLAYER_JOIN;
    }
    else
    {
        // Were results returned?
        new bool:playerFound = SQL_FetchRow(fetch);

        // Unlock.
        SQL_UnlockDatabase(g_hDbConn_Bans);

        // Free the fetch handle.
        CloseHandle(fetch);

        // If we found this player in the DB, block him from joining team.
        if (playerFound)
        {
            g_bKnownFreekillers[client] = true;
            CreateTimer(1.0, Tlist_ShowBlockReason, client);
            return BLOCK_PLAYER_JOIN;
        }
    }

    // Because TF2 is free to play, we have to do IP tlists...
    if (g_iGame == GAMETYPE_TF2)
    {
        // debug
        // To write
        // To do
        // To test
    }

    // If we are at this point, the player was not found in the DB.
    return ALLOW_PLAYER_JOIN;
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Tlist(admin, args)
{
    // The command itself could be different things (tlist, untlist, etc).
    decl String:cmd[LEN_CONVARS];
    GetCmdArg(0, cmd, sizeof(cmd));
    new cmdType = LOCALDEF_TLIST_CMDTYPE_TLIST;
    if (!strncmp(cmd, "untl", 4, false) ||
        !strncmp(cmd, "deli", 4, false) ||
        !strncmp(cmd, "unli", 4, false))
        cmdType = LOCALDEF_TLIST_CMDTYPE_UNTLIST;

    // If no arguments, create menu with all players to let the admin select one.
    if (!args)
    {
        new Handle:menu = CreateMenu(Tlist_MenuSelect);
        SetMenuTitle(menu, (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST ?
                            "Select Player To T-List" :
                            "Select Player To Un-T-List"));
        g_iCmdMenuCategories[admin] = cmdType;
        g_iCmdMenuDurations[admin] = GetConVarInt(g_hCvAdminMaxTlistMinutes);
        Format(g_sCmdMenuReasons[admin], LEN_CONVARS, "");
        decl String:sUserid[LEN_INTSTRING];
        decl String:name[MAX_NAME_LENGTH];
        new cnt;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i))
                continue;
            if (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST)
            {
                if (g_bKnownFreekillers[i])
                    continue;
            }
            else // if (cmdType == LOCALDEF_TLIST_CMDTYPE_UNTLIST)
            {
                if (!g_bKnownFreekillers[i])
                    continue;
            }
            cnt++;
            GetClientName(i, name, sizeof(name));
            IntToString(GetClientUserId(i), sUserid, sizeof(sUserid));
            AddMenuItem(menu, sUserid, name);
        }
        if (cnt)
            DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
        else
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin,
                               "%s There is nobody %s",
                               MSG_PREFIX,
                               (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST
                                    ? "Un-T-Listed to T-List"
                                    : "T-Listed to Un-T-List"));
            CloseHandle(menu);
        }
        return Plugin_Handled;
    }

    // Get arguments.
    decl String:argString[LEN_CONVARS * 2];
    GetCmdArgString(argString, sizeof(argString));

    // Analyse arg string.
    decl String:sExtractedTarget[LEN_CONVARS];
    decl String:sExtractedReason[LEN_CONVARS];
    new iExtractedDuration = -1;
    new iAssumedTargetType = -1;
    if (!TryGetArgs(argString, sizeof(argString),
                   sExtractedTarget, sizeof(sExtractedTarget),
                   iAssumedTargetType, iExtractedDuration,
                   sExtractedReason, sizeof(sExtractedReason)))
    {
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s Target could not be identified", MSG_PREFIX);
        return Plugin_Handled;
    }
    switch(iAssumedTargetType)
    {
        case TARGET_TYPE_MAGICWORD:
        {
            if (strcmp(sExtractedTarget, "me", false) == 0)
            {
                Tlist_DoClient(admin, admin, iExtractedDuration, cmdType, sExtractedReason); // <--- target is admin himself
                return Plugin_Handled;
            }
            else
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target identifier \x03@%s\x04 is not valid for this command", MSG_PREFIX, sExtractedTarget);
                return Plugin_Handled;
            }
        }
        case TARGET_TYPE_USERID:
        {
            new target = GetClientOfUserId(StringToInt(sExtractedTarget));
            if (!target)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
            }
            else
                Tlist_DoClient(admin, target, iExtractedDuration, cmdType, sExtractedReason);
        }
        case TARGET_TYPE_STEAM:
        {
            new target = GetClientOfSteam(sExtractedTarget);
            if (!target)
            {
                decl String:targetSteam[LEN_STEAMIDS];
                Format(targetSteam, sizeof(targetSteam), sExtractedTarget);
                Tlist_DoSteam(admin, targetSteam, iExtractedDuration, cmdType, sExtractedReason);
            }
            else
                Tlist_DoClient(admin, target, iExtractedDuration, cmdType, sExtractedReason);
        }
        case TARGET_TYPE_NAME:
        {
            decl targets[MAXPLAYERS + 1];
            new numFound;
            GetClientOfPartialName(sExtractedTarget, targets, numFound);
            if (numFound <= 0)
            {
                EmitSoundToClient(admin, g_sSoundDeny);
                ReplyToCommandGood(admin, "%s No matches found for \x01[\x03%s\x01]", MSG_PREFIX, sExtractedTarget);
            }
            else if (numFound == 1)
            {
                new target = targets[0];
                if (!IsClientInGame(target))
                {
                    EmitSoundToClient(admin, g_sSoundDeny);
                    ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
                }
                else
                    Tlist_DoClient(admin, target, iExtractedDuration, cmdType, sExtractedReason);
            }
            else
            {
                // Multiple hits.  Show a menu to the admin.
                if (admin <= 0 || !IsClientInGame(admin))
                    ReplyToCommandGood(admin, "%s Multiple matches found for \x01[\x03%s\x01]", MSG_PREFIX);
                else
                {
                    new Handle:menu = CreateMenu(Tlist_MenuSelect);
                    SetMenuTitle(menu, (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST ?
                                        "Select Player To T-List" :
                                        "Select Player To Un-T-List"));
                    g_iCmdMenuCategories[admin] = cmdType;
                    g_iCmdMenuDurations[admin] = iExtractedDuration;
                    Format(g_sCmdMenuReasons[admin], LEN_CONVARS, sExtractedReason);
                    decl String:sUserid[LEN_INTSTRING];
                    decl String:name[MAX_NAME_LENGTH];
                    for (new i = 0; i < numFound; i++)
                    {
                        new t = targets[i];
                        GetClientName(t, name, sizeof(name));
                        IntToString(GetClientUserId(t), sUserid, sizeof(sUserid));
                        AddMenuItem(menu, sUserid, name);
                    }
                    DisplayMenu(menu, admin, MENU_TIMEOUT_NORMAL);
                }
            }
        }
        default:
        {
            EmitSoundToClient(admin, g_sSoundDeny);
            ReplyToCommandGood(admin, "%s Target type could not be identified", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

// ####################################################################################
// ################################## MAIN FUNCTIONS ##################################
// ####################################################################################

Tlist_DoClient(admin, target, duration, cmdType, const String:reason[LEN_CONVARS])
{
    // Ensure target is in-game.
    if ((target <= 0) || (!IsClientInGame(target)))
    {
        EmitSoundToClient(admin, g_sSoundDeny);
        ReplyToCommandGood(admin, "%s ERROR: Target %i not in game", MSG_PREFIX, target);
        return;
    }

    // Is subject a bot?
    if (IsFakeClient(target))
    {
        KickClient(target);
        ReplyToCommandGood(admin, "%s Bot kicked", MSG_PREFIX);
        return;
    }

    // Get admin info.
    new approvedState = GetApprovedState(admin, false);
    new adminIpUnsigned = GetPlayerUnsignedIp(admin);
    decl String:adminSteam[LEN_STEAMIDS] = "CONSOLE";
    decl String:adminName[MAX_NAME_LENGTH] = "CONSOLE";
    if (admin && IsClientInGame(admin))
    {
        GetClientAuthString2(admin, adminSteam, sizeof(adminSteam));
        GetClientName(admin, adminName, sizeof(adminName));
    }

    // Get target info.
    decl String:targetSteam[LEN_STEAMIDS];
    decl String:targetName[MAX_NAME_LENGTH];
    decl String:targetIP[LEN_IPS];

    GetClientAuthString2(target, targetSteam, sizeof(targetSteam));
    GetClientName(target, targetName, sizeof(targetName));
    GetClientIP(target, targetIP, sizeof(targetIP));

    // Perform action.
    if (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST)
    {
        // Set known freekiller status.
        g_bKnownFreekillers[target] = true;

        // Get allowed duration from supplied duration.
        new actualDuration = GetAllowedDuration(admin, duration, GetConVarInt(g_hCvAdminMaxTlistMinutes));

        // Team switch and slay them if they're on CT
        TeamSwitchSlay(target, TEAM_PRISONERS);

        // Store the ban UUID (if applicable) for family shared ban purposes.
        new String:familyUUID[LEN_HEXUUID] = "";

        // Ban (T-List) in database.
        Tlist_InsertNewBan(targetSteam,
                           targetName,
                           targetIP,
                           actualDuration,
                           approvedState,
                           reason,
                           BAN_CAT_TLIST,
                           adminSteam,
                           adminName,
                           adminIpUnsigned,
                           admin,
                           "",
                           familyUUID,
                           sizeof(familyUUID));

        // Tlist the owner account too, if applicable.
        if (!StrEqual(g_sOwnerSteamid[target], ""))
        {
            decl String:familyreason[LEN_CONVARS];
            Format(familyreason, sizeof(familyreason), "Family sharing tlist from %s: %s", targetSteam, reason);

            // Ban (T-List) in database.
            Tlist_InsertNewBan(g_sOwnerSteamid[target],
                               targetSteam,
                               targetIP,
                               actualDuration,
                               approvedState,
                               familyreason,
                               BAN_CAT_TLIST,
                               adminSteam,
                               adminName,
                               adminIpUnsigned,
                               admin,
                               familyUUID);
        }

        // Display notice to players.
        decl String:sDisplay[LEN_CONVARS];
        Format(sDisplay, sizeof(sDisplay), "%s \x03%s\x04 was T-Listed by \x03%s", MSG_PREFIX, targetName, adminName);
        if (actualDuration == 0)
        {
            decl String:tocat[LEN_CONVARS];
            Format(tocat, sizeof(tocat), " \x03permanently", actualDuration);
            StrCat(sDisplay, sizeof(sDisplay), tocat);
        }
        else
        {
            decl String:tocat[LEN_CONVARS];
            Format(tocat, sizeof(tocat), " \x04for \x03%d\x04 minutes", actualDuration);
            StrCat(sDisplay, sizeof(sDisplay), tocat);
        }
        PrintToChatAll(sDisplay);
        DisplayMSayAll("Player T-Listed",
                       MENU_TIMEOUT_QUICK,
                       "%s\nwas T-Listed by\n%s",
                       targetName,
                       adminName);
    }

    else // if (cmdType == LOCALDEF_TLIST_CMDTYPE_UNTLIST)
    {
        // Set known freekiller status.
        g_bKnownFreekillers[target] = false;

        // Unban (Un-T-List) in database.
        TList_UnbanActiveBans(targetSteam, g_sOwnerSteamid[target], targetName, adminSteam, adminName, BAN_CAT_TLIST, admin);
    }
}

Tlist_DoSteam(admin, const String:targetSteam[LEN_STEAMIDS], duration, cmdType, const String:reason[LEN_CONVARS])
{
    // Get admin info.
    new approvedState = GetApprovedState(admin, true);
    new adminIpUnsigned = GetPlayerUnsignedIp(admin);
    decl String:adminSteam[LEN_STEAMIDS] = "CONSOLE";
    decl String:adminName[MAX_NAME_LENGTH] = "CONSOLE";
    if (admin && IsClientInGame(admin))
    {
        GetClientAuthString2(admin, adminSteam, sizeof(adminSteam));
        GetClientName(admin, adminName, sizeof(adminName));
    }

    // Get dummy target info to pass.
    decl String:targetName[MAX_NAME_LENGTH] = "";

    // Perform action.
    if (cmdType == LOCALDEF_TLIST_CMDTYPE_TLIST)
    {
        // Get allowed duration from supplied duration.
        new actualDuration = GetAllowedDuration(admin, duration, GetConVarInt(g_hCvAdminMaxTlistMinutes));

        // Ban (T-List) in database.
        Tlist_InsertNewBan(targetSteam,
                           targetName,
                           "unknown",
                           actualDuration,
                           approvedState,
                           reason,
                           BAN_CAT_TLIST,
                           adminSteam,
                           adminName,
                           adminIpUnsigned,
                           admin);

        // Display notice to players.
        decl String:sDisplay[LEN_CONVARS];
        Format(sDisplay, sizeof(sDisplay), "%s \x03%s\x04 was T-Listed by \x03%s", MSG_PREFIX, targetSteam, adminName);
        if (actualDuration == 0)
        {
            decl String:tocat[LEN_CONVARS];
            Format(tocat, sizeof(tocat), " \x03permanently", actualDuration);
            StrCat(sDisplay, sizeof(sDisplay), tocat);
        }
        else
        {
            decl String:tocat[LEN_CONVARS];
            Format(tocat, sizeof(tocat), " \x04for \x03%d\x04 minutes", actualDuration);
            StrCat(sDisplay, sizeof(sDisplay), tocat);
        }
        PrintToChatAll(sDisplay);
    }

    else // if (cmdType == LOCALDEF_TLIST_CMDTYPE_UNTLIST)
    {
        // Unban (Un-T-List) in database.
        TList_UnbanActiveBans(targetSteam, "", targetName, adminSteam, adminName, BAN_CAT_TLIST, admin);
    }
}

// ####################################################################################
// ################################ INTERNAL FUNCTIONS ################################
// ####################################################################################

Tlist_InsertNewBan(const String:targetSteam[LEN_STEAMIDS],
                   const String:targetName[],
                   const String:targetIP[LEN_IPS],
                   durationMins,
                   approvedState,
                   const String:reason[LEN_CONVARS],
                   category,
                   const String:adminSteam[LEN_STEAMIDS],
                   const String:adminName[MAX_NAME_LENGTH],
                   adminIpUnsigned,
                   admin,
                   const String:linkToUUID[]="",
                   String:banUUID[]="",
                   uuid_maxlength=0)
{
    // Are we disconnected?
    if (g_hDbConn_Bans == INVALID_HANDLE)
    {
        LogMessage("ERROR in Tlist_InsertNewBan: The DB handle was invalid");
        ReplyToCommandGood(admin, "%s ERROR: Lost connection to database. Ban has not been recorded", MSG_PREFIX);
        return;
    }

    // Escape names.
    decl String:esc_adminName[MAX_NAME_LENGTH * 2 + 1];
    decl String:esc_targetName[MAX_NAME_LENGTH * 2 + 1];
    SQL_EscapeString(g_hDbConn_Bans, adminName, esc_adminName, sizeof(esc_adminName));
    SQL_EscapeString(g_hDbConn_Bans, targetName, esc_targetName, sizeof(esc_targetName));

    // If there is a reason, escape the reason.
    new bool:isReason = false;
    decl String:esc_reason[LEN_CONVARS * 2 + 1] = "";
    if (strlen(reason))
    {
        isReason = true;
        SQL_EscapeString(g_hDbConn_Bans, reason, esc_reason, sizeof(esc_reason));
    }

    // Create UUID string (without dashes).
    decl String:uuid[LEN_HEXUUID];
    GetUUID(uuid, false);

    // Return the UUID
    if (uuid_maxlength > 0)
    {
        Format(banUUID, uuid_maxlength, uuid);
    }

    // Pack info to pass into callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, (admin && IsClientInGame(admin)) ? GetClientUserId(admin) : 0);
    WritePackCell(data, adminIpUnsigned);
    WritePackString(data, uuid);
    WritePackString(data, linkToUUID);
    WritePackCell(data, isReason);
    WritePackString(data, esc_reason);

    // Insert ban.
    decl String:query[2048];
    Format(query, sizeof(query),
            "INSERT INTO bans (\
                uuid, \
                category, \
                subject_steamid, \
                subject_name, \
                subject_ip, \
                datetime_added, \
                datetime_modified, \
                duration_seconds, \
                approved_state, \
                admin_forumid_or_steamid, \
                admin_name, \
                bannedfrom_ip, \
                bannedfrom_port, \
                lastpost_formods_forumid, \
                lastpost_forregs_forumid, \
                lastpost_formods_datetime, \
                lastpost_forregs_datetime) \
            VALUES (\
                UNHEX('%s'), \
                %i, \
                '%s', \
                '%s', \
                '%s', \
                UNIX_TIMESTAMP(), \
                UNIX_TIMESTAMP(), \
                %i, \
                %i, \
                '%s', \
                '%s', \
                %u, \
                %i, \
                %i, \
                %i, \
                %s, \
                %s)", // These last two %s's have no quotes on purpose.
            uuid,
            category,
            targetSteam,
            esc_targetName,
            targetIP,
            durationMins * 60,
            approvedState,
            adminSteam,
            esc_adminName,
            GetConVarInt(FindConVar("hostip")),
            GetConVarInt(FindConVar("hostport")),
            (isReason ? -1 : 0), // This -1 tells the PHP script to use whoever was the banning admin as the poster.
            (isReason ? -1 : 0), // Same as above.
            (isReason ? "UNIX_TIMESTAMP()" : "0"),
            (isReason ? "UNIX_TIMESTAMP()" : "0"));

    SQL_TQuery(g_hDbConn_Bans, Tlist_FinishInserting_CB, query, any:data);
}

TList_UnbanActiveBans(
    const String:targetSteam[LEN_STEAMIDS],
    const String:targetOwnerSteam[LEN_STEAMIDS],
    const String:targetName[MAX_NAME_LENGTH],
    const String:adminSteam[LEN_STEAMIDS],
    const String:adminName[MAX_NAME_LENGTH],
    category,
    admin)
{
    // Are we disconnected?
    if (g_hDbConn_Bans == INVALID_HANDLE)
    {
        LogMessage("ERROR in TList_UnbanActiveBans: The DB handle was invalid");
        ReplyToCommandGood(admin, "%s ERROR: Lost connection to database. Could not unban", MSG_PREFIX);
        return;
    }

    // Pack info to pass into callback.
    new Handle:data = CreateDataPack();
    WritePackCell(data, admin ? GetClientUserId(admin) : 0);
    WritePackCell(data, category);
    WritePackString(data, targetSteam);
    WritePackString(data, targetOwnerSteam);
    WritePackString(data, targetName);
    WritePackString(data, adminSteam);
    WritePackString(data, adminName);

    // Family sharing
    new String:family[64];
    if (!StrEqual(targetOwnerSteam, ""))
    {
        Format(family, sizeof(family), " or subject_steamid = '%s'", targetOwnerSteam);
    }

    // Select.
    decl String:query[512];
    Format(query, sizeof(query),
            "SELECT \
                HEX(uuid), \
                approved_state AS uuid \
            FROM bans \
            WHERE (subject_steamid = '%s' %s)\
            AND category = %i \
            AND (approved_state = %d OR approved_state = %d) \
            AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0) \
            LIMIT 20",
            targetSteam,
            family,
            category,
            APPROVED_STATE_APPROVED,
            APPROVED_STATE_SERVERBAN);
    SQL_TQuery(g_hDbConn_Bans, TList_CheckCanUnban_CB, query, any:data);
}

// ####################################################################################
// ################################## SQL CALLBACKS ###################################
// ####################################################################################

public Tlist_FinishInserting_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new admin_temp = ReadPackCell(Handle:data);
    new admin = admin_temp ? GetClientOfUserId(admin_temp) : 0;

    new adminIpUnsigned = ReadPackCell(Handle:data);
    decl String:uuid[LEN_HEXUUID];
    decl String:linkToUUID[LEN_HEXUUID];
    ReadPackString(Handle:data, uuid, sizeof(uuid));
    ReadPackString(Handle:data, linkToUUID, sizeof(linkToUUID));
    new bool:isReason = bool:ReadPackCell(Handle:data);
    decl String:esc_reason[LEN_CONVARS * 2 + 1];
    ReadPackString(Handle:data, esc_reason, sizeof(esc_reason));
    CloseHandle(Handle:data);

    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 6))
    {
        LogError("ERROR in DoBan_Finish - %s", error);
        ReplyToCommandGood(admin, "%s ERROR: Lost connection to database. Ban has not been recorded", MSG_PREFIX);
        return;
    }

    // Was ban successfully inserted?
    if (SQL_GetAffectedRows(conn) <= 0)
    {
        ReplyToCommandGood(admin, "%s ERROR: Ban was not inserted into database", MSG_PREFIX);
        return;
    }

    // Insert reason as a new post.
    decl String:query[512 + sizeof(uuid)+ sizeof(esc_reason)];

    if (!StrEqual(linkToUUID, ""))
    {
        new id = SQL_GetInsertId(fetch);
        decl String:family_reason[LEN_CONVARS];

        Format(family_reason, sizeof(family_reason),
               "Family shared account ban. Reply to http://hellsgamers.com/hgbans/?i=%d", id);

        Format(query, sizeof(query),
                            "INSERT INTO posts \
                                (uuid, ban_uuid, datetime, poster_forumid, poster_ip, content) \
                            VALUES \
                                (UNHEX(REPLACE(UUID(),'-','')), UNHEX('%s'), UNIX_TIMESTAMP(), %i, %u, '%s%s')",
                            linkToUUID,
                            -1, // This tells the PHP script to use whoever was the banning admin as the poster.
                            adminIpUnsigned,
                            "__PLAIN__",
                            family_reason);

        SQL_TQuery(g_hDbConn_Bans, EmptyCallback, query, 2);

        Format(query, sizeof(query), "UPDATE bans SET thread_locked = 1 WHERE uuid = UNHEX('%s')", linkToUUID);
        SQL_TQuery(g_hDbConn_Bans, EmptyCallback, query, 15);
    }

    // If there is no reason, we're done.
    if (!isReason)
        return;

    Format(query, sizeof(query),
                        "INSERT INTO posts \
                            (uuid, ban_uuid, datetime, poster_forumid, poster_ip, content) \
                        VALUES \
                            (UNHEX(REPLACE(UUID(),'-','')), UNHEX('%s'), UNIX_TIMESTAMP(), %i, %u, '%s%s')",
                        uuid,
                        -1, // This tells the PHP script to use whoever was the banning admin as the poster.
                        adminIpUnsigned,
                        "__PLAIN__",
                        esc_reason);

    SQL_TQuery(g_hDbConn_Bans, EmptyCallback, query, 2);
}

public TList_CheckCanUnban_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Extract passed data.
    ResetPack(Handle:data);
    new admin = GetClientOfUserId(ReadPackCell(Handle:data));
    new category = ReadPackCell(Handle:data);
    decl String:targetSteam[LEN_STEAMIDS];
    decl String:targetOwnerSteam[LEN_STEAMIDS];
    decl String:targetName[MAX_NAME_LENGTH];
    decl String:adminSteam[LEN_STEAMIDS];
    decl String:adminName[MAX_NAME_LENGTH];
    ReadPackString(Handle:data, targetSteam, sizeof(targetSteam));
    ReadPackString(Handle:data, targetOwnerSteam, sizeof(targetOwnerSteam));
    ReadPackString(Handle:data, targetName, sizeof(targetName));
    ReadPackString(Handle:data, adminSteam, sizeof(adminSteam));
    ReadPackString(Handle:data, adminName, sizeof(adminName));
    CloseHandle(Handle:data);

    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 7))
    {
        LogMessage("ERROR in TList_CheckCanUnban_CB");
        ReplyToCommandGood(admin, "%s ERROR: Lost connection to database. Could not query bans", MSG_PREFIX);
        return;
    }
    if (!SQL_FetchRow(fetch))
    {
        ReplyToCommandGood(admin, "%s No active records found for \x03%s", MSG_PREFIX, targetSteam);
        return;
    }

    // Store the unique IDs of all the bans we're going to remove.
    decl String:uuids[20][LEN_HEXUUID];

    // And the old approved states.
    decl old_approved_states[20];

    new total;
    new staff;
    do
    {
        // Fetch the unique ID.
        SQL_FetchString(fetch, 0, uuids[total], LEN_HEXUUID);

        // And the old approved state.
        old_approved_states[total] = SQL_FetchInt(fetch, 1);

        // If the ban was already approved, then it cannot be undone from in game by a regular admin.
        if (old_approved_states[total] == APPROVED_STATE_APPROVED)
            staff++;

        total++;
    } while(SQL_FetchRow(fetch));

    // One or more of the bans were already approved, so regular admins can't unban him.
    if (admin && staff)
    {
        new admin_flags = GetUserFlagBits(admin);
        if (!(admin_flags & ADMFLAG_CHANGEMAP) && !(admin_flags & ADMFLAG_ROOT))
        {
            // We already know it's an in game admin.
            PrintToChat(admin,
                        "%s \x01%d/%d\x04 of the ban(s) on \x03%s\x04 were already approved by staff.",
                        MSG_PREFIX, staff, total, targetSteam);
            PrintToChat(admin,
                        "%s You can not Un-T-List this person from in game; please post on the bans topic",
                        MSG_PREFIX);
            return;
        }
    }

    // Notify players of unban or Un-T-List.
    ReplyToCommandGood(admin,
                       "%s There were \x03%d\x04 active records on \x03%s",
                       MSG_PREFIX, total, targetSteam);
    PrintToChatAll("%s \x03%s \x04Un-T-Listed \x03%s", MSG_PREFIX,
                   adminName,
                   (strlen(targetName) ? targetName : targetSteam));

    // Escape names.
    decl String:esc_adminName[MAX_NAME_LENGTH * 2 + 1];
    SQL_EscapeString(g_hDbConn_Bans, adminName, esc_adminName, sizeof(esc_adminName));

    /**************************** Execute unban query ****************************/

    new String:family[64];
    if (!StrEqual(targetOwnerSteam, ""))
    {
        Format(family, sizeof(family), "or subject_steamid = '%s'", targetOwnerSteam);
    }

    decl String:query[512];
    Format(query, sizeof(query),
           "UPDATE bans SET approved_state = %d WHERE (subject_steamid = '%s' %s) AND category = %i",
           APPROVED_STATE_DISAPPROVED, targetSteam, family, category);
    SQL_TQuery(g_hDbConn_Bans, EmptyCallback, query, 3);

    /*********************** Add UPDATE HISTORY for this unban *******************/

    for (new i = 0; i < total; i++)
    {
        Format(query, sizeof(query),
                "INSERT INTO updates (\
                    ban_uuid, \
                    datetime, \
                    admin_forumid_or_steamid, \
                    admin_name, \
                    field, \
                    old_value, \
                    new_value) \
                VALUES (\
                    UNHEX('%s'), \
                    UNIX_TIMESTAMP(), \
                    '%s', \
                    '%s', \
                    'approved_state', \
                    %d, \
                    %d)",
                uuids[i],
                adminSteam,
                esc_adminName,
                old_approved_states[i],
                APPROVED_STATE_DISAPPROVED);
        SQL_TQuery(g_hDbConn_Bans, EmptyCallback, query, 4);
    }
}

public Tlist_GetBansSinceLastTick_CB(Handle:conn, Handle:fetch, const String:error[], any:data)
{
    // Did it fail?
    if (Db_QueryFailed(conn, fetch, error, 8))
    {
        LogMessage("ERROR in Tlist_GetBansSinceLastTick_CB");
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
    for (new i = 1; i <= MaxClients; i++)
    {
        // Ensure client is in game and not a bot before getting his Steam ID.
        if (!IsClientInGame(i) || IsFakeClient(i))
            continue;
        GetClientAuthString2(i, thisSteam, sizeof(thisSteam));

        // See if client's short Steam ID is one of those retrieved from the DB since the last tick.
        if (GetTrieValue(ht, thisSteam, category))
        {
            switch(category)
            {
                case BAN_CAT_REGULARBAN:
                {/*pass*/}
                case BAN_CAT_TLIST:
                    TeamSwitchSlay(i, TEAM_PRISONERS);
            }
        }
    }

    // We're done with the trie.
    ClearTrie(ht);
    CloseHandle(ht);
}

// ####################################################################################
// ################################# TIMER CALLBACKS ##################################
// ####################################################################################

public Action:Tlist_ShowBlockReason(Handle:timer, any:client)
{
    if (IsClientInGame(client))
    {
        PrintToChat(client, "%s You are currently T-Listed.", MSG_PREFIX);
        PrintToChat(client, "%s This means you cannot be a Guard.", MSG_PREFIX);
        PrintToChat(client, "%s Please do not break MOTD rules.", MSG_PREFIX);
    }
    return Plugin_Continue;
}

// ####################################################################################
// ################################# MENU CALLBACKS ###################################
// ####################################################################################

public Tlist_MenuSelect(Handle:menu, MenuAction:action, admin, selected)
{
    if (action == MenuAction_Select)
    {
        decl String:sUserid[LEN_INTSTRING];
        GetMenuItem(menu, selected, sUserid, sizeof(sUserid));
        new target = GetClientOfUserId(StringToInt(sUserid));
        if (!target)
            ReplyToCommandGood(admin, "%s Target has left the server", MSG_PREFIX);
        else
            Tlist_DoClient(admin,
                         target,
                         g_iCmdMenuDurations[admin],
                         g_iCmdMenuCategories[admin],
                         g_sCmdMenuReasons[admin]);
    }
    else if (action == MenuAction_End)
        CloseHandle(menu);
}

// ####################################################################################
// ################################# STOCK FUNCTIONS ##################################
// ####################################################################################

stock GetApprovedState(adminClient, bool:steamBan)
{
    // Should the ban start off as "approved"? (trusted+ only)
    new approvedState = APPROVED_STATE_SERVERBAN;
    if (!adminClient)
        approvedState = APPROVED_STATE_APPROVED;
    else
    {
        if (IsClientInGame(adminClient))
        {
            new adminFlags = GetUserFlagBits(adminClient);
            if ((adminFlags & ADMFLAG_CHANGEMAP) || (adminFlags & ADMFLAG_ROOT))
                approvedState = APPROVED_STATE_APPROVED;

            else if (steamBan)
                approvedState = APPROVED_STATE_PENDING;
        }
        else // The admin banned himself. He's not in-game. Can't get his flags.
            approvedState = APPROVED_STATE_SERVERBAN;
    }
    return approvedState;
}

stock GetAllowedDuration(adminClient, suppliedMins, defaultMins)
{
    // If duration is not specified, set it to default.
    if (suppliedMins < 0)
        return defaultMins;

    // If the duration is more than the default, the admin must be trusted (or RCON).
    if (suppliedMins > defaultMins || suppliedMins == 0)
    {
        if (adminClient)
        {
            new adminFlags = GetUserFlagBits(adminClient);
            if (!(adminFlags & ADMFLAG_CHANGEMAP) && !(adminFlags & ADMFLAG_ROOT))
            {
                return defaultMins;
            }
        }
    }

    // The supplied minutes are fine.
    return suppliedMins;
}

stock GetPlayerUnsignedIp(client)
{
    // Get admin's IP.
    new unsignedIp = GetConVarInt(FindConVar("hostip"));
    if (client)
    {
        if (IsClientInGame(client))
        {
            decl String:adminIpString[LEN_IPS];
            GetClientIP(client, adminIpString, sizeof(adminIpString));
            unsignedIp = NetAddr2Long(adminIpString);
        }
        else // The admin banned himself.  He's not in-game.  Can't get his IP.
            unsignedIp = 0;
    }

    // The server issued the command.  Use the server's IP.
    return unsignedIp;
}
