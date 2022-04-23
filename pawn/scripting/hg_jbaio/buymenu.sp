
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

new String:g_sCTPerksPath[PLATFORM_MAX_PATH];
new Handle:g_hPerksMenu = INVALID_HANDLE;
new Handle:g_hTeleportTimer = INVALID_HANDLE;       // Timer that teleports people out of admin room
new Handle:g_hUsedThisRound = INVALID_HANDLE;
new Handle:g_hPerks = INVALID_HANDLE;
new Handle:g_hPlayerUsedThisRound[MAXPLAYERS + 1];
new bool:g_bBlockAttack;
new bool:g_bGrenadeHacks;
new Float:g_fC4Resistance[MAXPLAYERS + 1];
new g_iLastPurchase[MAXPLAYERS + 1];

// Cache admin room data.
new Float:g_fEntityPos[3];
new Float:g_fAdminRoomCenterPoint[3], Float:g_fAdminRoomDimensions[3];
new bool:g_bGotAdminRoomData = false;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

BuyMenu_OnPluginStart()
{
    BuildPath(Path_SM, g_sCTPerksPath, PLATFORM_MAX_PATH, "data/ctperks.txt");
    BuildPerksMenu();

    RegAdminCmd("adminroom", Command_AdminRoom_Client, ADMFLAG_GENERIC, "Teleports an admin to the admin room");
    RegConsoleCmd("buy", Command_Buy);
    RegServerCmd("aio_adminroom", Command_AdminRoom_Server);
    RegServerCmd("aio_bombarmor", Command_BombArmor_Server);
    RegServerCmd("aio_radarhacks", Command_RadarHacks_Server);
    RegServerCmd("aio_grenadehacks", Command_GrenadeHacks_Server);
    RegServerCmd("aio_give_caber", Command_GiveCaber_Server);
    RegServerCmd("aio_add_speed", Command_AddSpeed_Server);
    RegServerCmd("aio_setammo", Command_SetAmmo_Server);
    RegServerCmd("aio_uber", Command_Uber_Server);
    RegServerCmd("aio_kritz", Command_Kritz_Server);
    RegServerCmd("aio_scale", Command_Scale_Server);

    if (g_iGame != GAMETYPE_TF2)
        HookEvent("player_blind", BuyMenu_OnPlayerBlind);

    g_hUsedThisRound = CreateTrie();
}

public BuyMenu_OnPlayerBlind(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (g_bGrenadeHacks)
        SetEntDataFloat(client, m_flFlashMaxAlpha, 0.5);
}

BuyMenu_OnRndStrt_General()
{
    if (g_hTeleportTimer != INVALID_HANDLE)
        CloseHandle(g_hTeleportTimer);

    g_hTeleportTimer = CreateTimer(float(GetConVarInt(g_hCvAdminRoomTime)),
                                   BuyMenu_TeleportFromAdminRoom);

    g_bBlockAttack = true;
    ClearTrie(g_hUsedThisRound);
}

stock BuyMenu_OnClientPutInServer(client)
{
    g_hPlayerUsedThisRound[client] = CreateTrie();
}

stock BuyMenu_OnClientDisconnect(client)
{
    if (g_hPlayerUsedThisRound[client] != INVALID_HANDLE)
        CloseHandle(g_hPlayerUsedThisRound[client]);

    g_hPlayerUsedThisRound[client] = INVALID_HANDLE;
}

stock BuyMenu_OnPlayerSpawn(client)
{
    g_fC4Resistance[client] = 1.0;
    ClearTrie(g_hPlayerUsedThisRound[client]);
}

stock BuyMenu_OnRoundStart()
{
    g_bGrenadeHacks = false;
}

public Action:BuyMenu_TeleportFromAdminRoom(Handle:timer)
{
    if ((GetTime() - g_iRoundStartTime) > GetConVarInt(g_hCvAdminRoomTime) + 90)
    {
        g_hTeleportTimer = INVALID_HANDLE;
        g_bBlockAttack = false;

        return Plugin_Stop;
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bGotAdminRoomData &&
            IsClientInGame(i) &&
            GetClientTeam(i) == TEAM_GUARDS &&
            !(GetUserFlagBits(i) & ADMFLAG_ROOT)) // Root admins have noclip, and go in admin room all the time thus should be excluded.
        {
            // Get client position.
            GetEntPropVector(i, Prop_Send, "m_vecOrigin", g_fEntityPos);

            // Test if client position is inside cached room location.
            if (MapCoords_IsInRoom(g_fEntityPos, g_fAdminRoomCenterPoint, g_fAdminRoomDimensions))
                Tele_DoClient(0, i, "Top of Electric Chair", false);
        }
    }

    g_hTeleportTimer = CreateTimer(0.5, BuyMenu_TeleportFromAdminRoom);
    return Plugin_Stop;
}

bool:BuyMenu_PlayerHurt(attacker)
{
    // If this function returns TRUE, damage is allowed.
    // If this function returns FALSE, damage is blocked.

    if (!g_bBlockAttack)
        return true;

    if (g_bGotAdminRoomData &&
        attacker <= MaxClients &&
        attacker >= 1)
    {
        // Get client position.
        GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", g_fEntityPos);

        // Test if client position is inside cached room location.
        if (MapCoords_IsInRoom(g_fEntityPos, g_fAdminRoomCenterPoint, g_fAdminRoomDimensions))
        {
            PrintToChat(attacker, "%s You cannot hurt people while in admin room", MSG_PREFIX);
            return false;
        }
    }
    return true;
}

stock BuyMenu_OnEntityCreated(entity, const String:classname[])
{
    if ((StrEqual(classname, "env_particlesmokegrenade") || StrEqual(classname, "smokegrenade_projectile"))
        && g_bGrenadeHacks)
        AcceptEntityInput(entity, "kill");
}

// ####################################################################################
// ##################################### COMMANDS #####################################
// ####################################################################################

public Action:Command_Buy(client, args)
{
    if (g_bIsThursday)
    {
        PrintToChat(client, "%s Sorry, due to \x03Throwback Thursday\x04 this command is disabled", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (!IsClientInGame(client))
        return Plugin_Handled;

    // Play nicely with gangs
    if (GetClientTeam(client) != TEAM_GUARDS)
        return Plugin_Continue;

    // Buy time is up
    if ((GetTime() - g_iRoundStartTime) > GetConVarInt(g_hCvBuyMenuCtBuyTime))
    {
        PrintToChat(client, "%s Sorry, buy time is up", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (!JB_IsPlayerAlive(client))
    {
        PrintToChat(client, "%s You must be an alive Guard to use this menu", MSG_PREFIX);
        return Plugin_Handled;
    }

    DisplayMenu(g_hPerksMenu, client, MENU_TIMEOUT_NORMAL);
    return Plugin_Handled;
}

public Action:Command_Uber_Server(args)
{
    decl String:sUserid[7];
    GetCmdArg(1, sUserid, sizeof(sUserid));

    new client = GetClientOfUserId(StringToInt(sUserid));
    if (!client)
        return Plugin_Handled;

    PrintToChat(client,
                "%s You got an \x03Uber\x04! Taunt with your melee to uber yourself.",
                MSG_PREFIX);

    g_bHasUber[client] = true;
    return Plugin_Handled;
}

public Action:Command_Kritz_Server(args)
{
    decl String:sUserid[7];
    decl String:sTime[7];

    GetCmdArg(1, sUserid, sizeof(sUserid));
    GetCmdArg(2, sTime, sizeof(sTime));

    new client = GetClientOfUserId(StringToInt(sUserid));
    new Float:time = StringToFloat(sTime);

    if (!client)
        return Plugin_Handled;

    TF2_AddCondition(client, TFCond_Kritzkrieged, time);
    PrintToChat(client, "%s You got \x03%.1f\x04 seconds of kritz!", MSG_PREFIX, time);

    g_bHasKritz[client] = true;
    return Plugin_Handled;
}

public Action:Command_Scale_Server(args)
{
    decl String:sUserid[7];
    decl String:sAmount[7];

    GetCmdArg(1, sUserid, sizeof(sUserid));
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new client = GetClientOfUserId(StringToInt(sUserid));
    new Float:scale = StringToFloat(sAmount);

    if (!client)
        return Plugin_Handled;

    SetEntData(client, m_flModelScale, scale);
    return Plugin_Handled;
}

public Action:Command_GiveCaber_Server(args)
{
    decl String:sUserid[7];
    GetCmdArg(1, sUserid, sizeof(sUserid));

    new client = GetClientOfUserId(StringToInt(sUserid));
    if (!client)
        return Plugin_Handled;

    GivePlayerBombTF2(client);
    return Plugin_Handled;
}

public Action:Command_AddSpeed_Server(args)
{
    decl String:sUserid[7];
    decl String:sAmount[7];

    GetCmdArg(1, sUserid, sizeof(sUserid));
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new client = GetClientOfUserId(StringToInt(sUserid));
    new Float:amount = StringToFloat(sAmount);

    if (!client)
        return Plugin_Handled;

    g_fPlayerSpeed[client] += 40 * amount;
    PrintToChat(client, "%s You got a \x03%0.2f\x04 speed boost", MSG_PREFIX, amount);

    return Plugin_Handled;
}

public Action:Command_AdminRoom_Server(args)
{
    decl String:sUserid[7];
    GetCmdArg(1, sUserid, sizeof(sUserid));

    new client = GetClientOfUserId(StringToInt(sUserid));
    if (!client)
        return Plugin_Handled;

    if (Tele_DoClient(0, client, "Admin Room", false))
        PrintToChat(client, "%s You have been teleported to the admin room", MSG_PREFIX);
    else
        PrintToChat(client, "%s nothing happened...", MSG_PREFIX);
    return Plugin_Handled;
}

public Action:Command_GrenadeHacks_Server(args)
{
    decl String:sUserid[7];
    GetCmdArg(1, sUserid, sizeof(sUserid));

    new client = GetClientOfUserId(StringToInt(sUserid));
    if (!client)
        return Plugin_Handled;

    g_bGrenadeHacks = true;
    PrintToChatAll("%s \x03%N\x04 bought grenade hacks. Smoke grenades and flashbangs won't work", MSG_PREFIX, client);

    new ent = -1;
    new prev = 0;

    while ((ent = FindEntityByClassname(ent, "env_particlesmokegrenade")) != -1)
    {
         if (prev)
            AcceptEntityInput(prev, "kill");
         prev = ent;
    }

    if (prev)
        AcceptEntityInput(prev, "kill");

    return Plugin_Handled;
}

public Action:Command_RadarHacks_Server(args)
{
    decl String:sUserid[7];
    GetCmdArg(1, sUserid, sizeof(sUserid));

    g_bRadarHacksEnabled = true;
    g_bAlreadyDisplayedRadarMessage = true;

    PrintToChatAll("%s \x03%N\x04 bought %s Hacks for the CT Team",
                   MSG_PREFIX, GetClientOfUserId(StringToInt(sUserid)), g_iGame == GAMETYPE_TF2 ? "Wall" : "Radar");

    if (g_iGame == GAMETYPE_TF2)
        TF2_WallHacks();
}

public Action:Command_SetAmmo_Server(args)
{
    decl String:sUserid[8];
    decl String:sSlot[8];
    decl String:sClip[8];
    decl String:sAmmo[8];

    GetCmdArg(1, sUserid, sizeof(sUserid));
    GetCmdArg(2, sSlot, sizeof(sSlot));
    GetCmdArg(3, sClip, sizeof(sClip));
    GetCmdArg(4, sAmmo, sizeof(sAmmo));

    new client = GetClientOfUserId(StringToInt(sUserid));
    new slot = StringToInt(sSlot);

    if (!client)
        return Plugin_Handled;

    new wepid = GetPlayerWeaponSlot(client, slot);

    if (wepid == -1)
        return Plugin_Handled;

    SetWeaponAmmo(wepid, client, StringToInt(sClip), StringToInt(sAmmo));
    return Plugin_Handled;
}

public Action:Command_BombArmor_Server(args)
{
    decl String:sUserid[7];
    decl String:sAmount[8];

    GetCmdArg(1, sUserid, sizeof(sUserid));
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new client = GetClientOfUserId(StringToInt(sUserid));
    new Float:amount = StringToFloat(sAmount);

    if (!client)
        return Plugin_Handled;

    g_fC4Resistance[client] = amount;
    PrintToChat(client, "%s Explosives will only do \x03%.2f%%\x04 damage to you this round", MSG_PREFIX, amount * 100);

    return Plugin_Handled;
}

public Action:Command_AdminRoom_Client(client, args)
{
    if (!client)
        return Plugin_Handled;

    if (!JB_IsPlayerAlive(client))
    {
        PrintToChat(client, "%s derp", MSG_PREFIX);
        return Plugin_Handled;
    }

    if (GetClientTeam(client) != TEAM_GUARDS)
    {
        PrintToChat(client, "%s Nice try", MSG_PREFIX);
        return Plugin_Handled;
    }

    if ((GetTime() - g_iRoundStartTime) > GetConVarInt(g_hCvAdminRoomTime))
    {
        PrintToChat(client, "%s It's too late too use this command!", MSG_PREFIX);
        return Plugin_Handled;
    }

    new delay = GetConVarInt(g_hCvAdminRoomDelay);
    new timeleft = delay - (GetTime() - g_iRoundStartTime);

    if (timeleft > 0)
    {
        PrintToChat(client,
                    "%s You can not use this command for another \x03%d\x04 seconds",
                    MSG_PREFIX, timeleft);
        return Plugin_Continue;
    }

    if (Tele_DoClient(0, client, "Admin Room", false))
        PrintToChat(client, "%s You have been teleported to the admin room", MSG_PREFIX);
    else
        PrintToChat(client, "%s nothing happened...", MSG_PREFIX);
    return Plugin_Handled;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

BuyMenu_CacheAdminRoom()
{
    g_bGotAdminRoomData = MapCoords_CacheRoomInfo("Admin Room", g_fAdminRoomCenterPoint, g_fAdminRoomDimensions);
}

// ####################################################################################
// ################################# MENU CALLBACKS ###################################
// ####################################################################################

public PerksMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    if (action != MenuAction_Select)
        return;

    if ((GetTime() - g_iRoundStartTime) > GetConVarInt(g_hCvBuyMenuCtBuyTime))
    {
        PrintToChat(client, "%s Sorry, buy time is up", MSG_PREFIX);
        return;
    }

    if (!JB_IsPlayerAlive(client) || GetClientTeam(client) != TEAM_GUARDS)
    {
        PrintToChat(client, "%s You must be an alive Guard to use this menu", MSG_PREFIX);
        return;
    }

    if (GetTime() == g_iLastPurchase[client])
    {
        PrintToChat(client,
                    "%s WOOH. Slow down there, pardna. Your girlfriend wouldn't like it if you were that quick with her.",
                    MSG_PREFIX);
        return;
    }

    g_iLastPurchase[client] = GetTime();

    decl String:key[MAX_NAME_LENGTH];
    GetMenuItem(menu, selected, key, sizeof(key));

    KvRewind(g_hPerks);
    KvJumpToKey(g_hPerks, key);

    /*
    decl String:sChoiceInfo[128];       // Stores data in format cost|command
    decl String:sChoiceParts[122][3];   // First value holds cost, second the command

    GetMenuItem(g_hPerksMenu, selected, sChoiceInfo, sizeof(sChoiceInfo));
    ExplodeString(sChoiceInfo, "|", sChoiceParts, 3, 122);
    */

    new cost = KvGetNum(g_hPerks, "cost");
    new maxround = KvGetNum(g_hPerks, "maxround");
    new maxplayer = KvGetNum(g_hPerks, "maxplayer");

    decl String:command[256];
    KvGetString(g_hPerks, "command", command, sizeof(command));

    new this_round;
    new this_round_player;

    GetTrieValue(g_hUsedThisRound, key, this_round);
    GetTrieValue(g_hPlayerUsedThisRound[client], key, this_round_player);

    if (maxplayer)
    {
        SetTrieValue(g_hPlayerUsedThisRound[client], key, ++this_round_player);
        if (this_round_player > maxplayer)
        {
            PrintToChat(client,
                        "%s Sorry, we're out of stock. You come back next round, ya hear?",
                        MSG_PREFIX);
            return;
        }
    }

    if (maxround)
    {
        SetTrieValue(g_hUsedThisRound, key, ++this_round);
        if (this_round > maxround)
        {
            PrintToChat(client,
                        "%s Sorry, we're out of stock. You come back next round, ya hear?",
                        MSG_PREFIX);
            return;
        }
    }

    if (PrisonRep_GetPoints(client) < cost)
    {
        PrintToChat(client, "%s You need \x03%d\x04 prison rep to buy this", MSG_PREFIX, cost);
        return;
    }

    new add_neg_points = 0 - cost;
    PrisonRep_AddPoints(client, add_neg_points);

    decl String:sUserid[7];
    IntToString(GetClientUserId(client), sUserid, sizeof(sUserid));

    // Replace the %userid with the actual userid
    ReplaceString(command, sizeof(command), "%userid", sUserid, false);

    // Execute the command
    ServerCommand(command);
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

BuildPerksMenu()
{
    decl String:sKeyName[32];
    decl String:sTitle[40];

    if (g_hPerks != INVALID_HANDLE)
        CloseHandle(g_hPerks);

    g_hPerks = CreateKeyValues("ctperks");
    FileToKeyValues(g_hPerks, g_sCTPerksPath);

    // Reset to the top of the keyvalue
    KvGotoFirstSubKey(g_hPerks);

    g_hPerksMenu = CreateMenu(PerksMenuSelect);
    SetMenuTitle(g_hPerksMenu, "Select Your Perk");

    do
    {
        KvGetSectionName(g_hPerks, sKeyName, sizeof(sKeyName));

        Format(sTitle, sizeof(sTitle),
               "%s - %d",
               sKeyName, KvGetNum(g_hPerks, "cost"));

        AddMenuItem(g_hPerksMenu, sKeyName, sTitle);
    } while (KvGotoNextKey(g_hPerks));
}