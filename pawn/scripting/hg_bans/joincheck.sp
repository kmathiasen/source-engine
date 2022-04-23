#include <EasyHTTP>

bool:CheckSharedAccountEasyHTTP(client)
{
    if (client == 0)
        return true;

    new String:sQueryURL[300] = "http://hellsgamers.com/api/shared.php?s=";
    new String:SteamID[32];
    GetClientAuthString(client, SteamID, sizeof(SteamID));

    StrCat(sQueryURL, sizeof(sQueryURL), SteamID);
    StrCat(sQueryURL, sizeof(sQueryURL), "&a=");

    decl String:game[PLATFORM_MAX_PATH];
    GetGameFolderName(game, sizeof(game));

    if (StrEqual(game, "csgo"))
        StrCat(sQueryURL, sizeof(sQueryURL), "730");
    else if (StrEqual(game, "cstrike"))
        StrCat(sQueryURL, sizeof(sQueryURL), "240");
    else if (StrEqual(game, "tf"))
        StrCat(sQueryURL, sizeof(sQueryURL), "440");

    // Steam API call to IsPlayingSharedGame
    if(!EasyHTTP(sQueryURL, Helper_GetBanStatus_Complete, GetClientUserId(client))) 
    {
        LogError("ERROR in CheckSharedAccountEasyHTTP: EasyHTTP request failed.");
        return false;
    }

    return true;
}

public Helper_GetBanStatus_Complete(any:userid, const String:sQueryData[], bool:success, error)
{
    new client = GetClientOfUserId(userid);
    if(!client)
        return;

    decl String:auth[LEN_STEAMIDS];
    GetClientAuthString(client, auth, sizeof(auth));

    // Check if the request failed for whatever reason
    if(!success || 
        ((StrEqual(sQueryData, "") || strlen(sQueryData) < 3 || StrContains(sQueryData, "-") > -1) && !StrEqual(sQueryData, "0")))
    {
        JoinCheck_OnClientAuthorized(client, auth);
        LogError("ERROR in Helper_GetBanStatus_Complete: EasyHTTP reported failure. Response: %s - Error: %i", sQueryData, error);

        return;
    }

    if (!StrEqual(sQueryData, "0")) // result was valid, and had valid data in it
    {
        Format(g_sOwnerSteamid[client], LEN_STEAMIDS, sQueryData);
    }

    JoinCheck_OnClientAuthorized(client, auth);
}

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

JoinCheck_OnClientAuthorized(client, const String:auth[])
{
    // Are we disconnected?
    if(g_hDbConn_Main == INVALID_HANDLE)
    {
        LogMessage("ERROR in JoinCheck_OnClientAuthorized: The DB handle was invalid");
        return;
    }

    // Shorten Steam ID.
    decl String:steamShort[LEN_STEAMIDS - 8];
    CopyStringFrom(steamShort, sizeof(steamShort), auth, LEN_STEAMIDS, 8);

    // Check for family shared bans
    new String:familyQuery[LEN_STEAMIDS + 24] = "";
    if (!StrEqual(g_sOwnerSteamid[client], ""))
    {
        Format(familyQuery, sizeof(familyQuery), "OR subject_steamid = '%s'", g_sOwnerSteamid[client][8]);
        LogMessage("%N joined under parent account %s", client, g_sOwnerSteamid[client]);
    }

    // Check if this Steam ID is banned.
    decl String:query[512];
    Format(query, sizeof(query),
           "SELECT id FROM bans \
           WHERE (subject_steamid = '%s' %s) \
           AND category = %i \
           AND (approved_state = %d OR approved_state = %d) \
           AND (((datetime_added + duration_seconds) > UNIX_TIMESTAMP()) OR duration_seconds = 0) \
           LIMIT 1",
           steamShort, familyQuery, BAN_CAT_REGULARBAN, APPROVED_STATE_APPROVED, APPROVED_STATE_SERVERBAN);
    SQL_TQuery(g_hDbConn_Main, JoinCheck_IsBanned_CB, query, any:GetClientUserId(client));
}

// ####################################################################################
// #################################### CALLBACKS #####################################
// ####################################################################################

public JoinCheck_IsBanned_CB(Handle:conn, Handle:fetch, const String:error[], any:targetUser)
{
    new targetClient = GetClientOfUserId(_:targetUser);
    if(!targetClient)
        return;

    if(Db_QueryFailed(conn, fetch, error))
    {
        LogMessage("ERROR in JoinCheck_IsBanned_CB: %s", error);
        return;
    }

    // Get target's Steam ID (...again, since we didn't pass it into this CB).
    decl String:targetSteam[LEN_STEAMIDS];
    GetClientAuthString(targetClient, targetSteam, sizeof(targetSteam));

    // Store target IP for later unban.
    decl String:targetIpToStore[LEN_IPSTRING];
    GetClientIP(targetClient, targetIpToStore, sizeof(targetIpToStore));
    SetTrieString(g_hBannedIps, targetSteam, targetIpToStore);

    // They're banned; let's IP ban them for 5 minutes so they can't reconnect spam.
    if(SQL_FetchRow(fetch)) {
        BanClient(targetClient, IP_BAN_MINUTES, BANFLAG_IP, g_sBanMessage, g_sBanMessage);
    }
}
