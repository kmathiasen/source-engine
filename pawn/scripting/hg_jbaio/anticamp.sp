
// ####################################################################################
// ##################################### GLOBALS ######################################
// ####################################################################################

// Constants.
#define ARMORY_X_CENTER 1059.5
#define ARMORY_Y_CENTER -3027.5
#define ARMORY_WIDTH 340.5
#define ARMORY_LENGTH 192.5

// Time each player has spent in armory.
new g_iTime[MAXPLAYERS + 1];

// Declare commonly used ConVars.
new g_iRoundTime = 0;
new g_iWarnTime = 15;
new g_iTeleportTime = 20;
new g_iSecondTeleportTime = 7;

// ####################################################################################
// ###################################### EVENTS ######################################
// ####################################################################################

AntiCamp_OnPluginStart()
{
    CreateTimer(1.0, Timer_CheckCamp, _, TIMER_REPEAT);
}

AntiCamp_OnConfigsExecuted()
{
    // Read commonly used ConVars.
    g_iSecondTeleportTime = GetConVarInt(g_hCvArmorySecondTeleportTime);
    g_iWarnTime = GetConVarInt(g_hCvArmoryWarnTime);
    g_iTeleportTime = GetConVarInt(g_hCvArmoryTeleportTime);

    // Hook changes to commonly used ConVars.
    HookConVarChange(g_hCvArmorySecondTeleportTime, AntiCamp_OnConVarChange);
    HookConVarChange(g_hCvArmoryWarnTime, AntiCamp_OnConVarChange);
    HookConVarChange(g_hCvArmoryTeleportTime, AntiCamp_OnConVarChange);
}

public AntiCamp_OnConVarChange(Handle:CVar, const String:old[], const String:newv[])
{
    // Update commonly used ConVars when they change.
    if (CVar == g_hCvArmorySecondTeleportTime)
        g_iSecondTeleportTime = GetConVarBool(g_hCvArmorySecondTeleportTime);
    else if (CVar == g_hCvArmoryWarnTime)
        g_iWarnTime = GetConVarInt(g_hCvArmoryWarnTime);
    else if (CVar == g_hCvArmoryTeleportTime)
        g_iTeleportTime = GetConVarInt(g_hCvArmoryTeleportTime);
}

AntiCamp_OnRndStrt_General()
{
    for (new i = 1; i <= MAXPLAYERS; i++)
        g_iTime[i] = 0;

    g_iRoundTime = 0;
}

// ####################################################################################
// #################################### FUNCTIONS #####################################
// ####################################################################################

public Action:Timer_CheckCamp(Handle:timer)
{
    new iAddTime;
    g_iRoundTime++;

    /* Warn players to leave armory for the first teleport */
    if (g_iRoundTime >= g_iWarnTime &&
        g_iRoundTime < g_iTeleportTime &&
        g_iEndGame == ENDGAME_NONE)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsValidPlayer(i, 3) && GetPlayerAddTime(i) == 1)
                PrintToChat(i,
                            "%s Unless it's a warday, you have \x03%d\x04 seconds to get away from armory",
                            MSG_PREFIX, g_iTeleportTime - g_iRoundTime);
        }
    }

    /* Teleport everyone that's still in armory for the first time*/
    else if (g_iRoundTime == g_iTeleportTime && g_iEndGame == ENDGAME_NONE)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsValidPlayer(i, 3) && GetPlayerAddTime(i) == 1)
                TeleportPlayer(i);
        }
    }

    /* The rest of the shitz */
    else if (g_iEndGame == ENDGAME_NONE && g_iRoundTime > g_iTeleportTime)
    {
        new bool:bRun = true;

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsValidPlayer(i, 2) && GetPlayerAddTime(i) == 1)
                bRun = false;
        }

        if (bRun)
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                if (!IsValidPlayer(i, 3))
                    continue;

                iAddTime = GetPlayerAddTime(i);

                /*
                 * If they're in armory, increase time by 1
                 * If they're half way to armory, don't increase/decrease
                 * If they're far enough away from armory, decrease by 2
                 * But make sure it doesn't go under 0!
                 */

                g_iTime[i] = max(g_iTime[i] + iAddTime, 0);

                if (g_iTime[i] >= g_iSecondTeleportTime && iAddTime == 1)
                    TeleportPlayer(i);

                else if (g_iTime[i] > 0 && iAddTime == 1)
                    PrintToChat(i,
                                "%s Unless it's a warday, you have \x03%d\x04 seconds to get away from armory",
                                MSG_PREFIX, g_iSecondTeleportTime - g_iTime[i]);
            }
        }
    }
    return Plugin_Continue;
}

TeleportPlayer(client)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        /* There's an alive T in armory */
        if (IsValidPlayer(i, 2) && GetPlayerAddTime(i) == 1)
            return;
    }

    TeleportSafe(client);
}

TeleportSafe(client)
{
    /* On top of electric chair, so they don't get knifed */
    new Float:fLoc[3] = {-64.27, -3169.44, 224.09};

    TeleportEntity(client, fLoc, NULL_VECTOR, NULL_VECTOR);
    g_iTime[client] = 0;

    GiveStockWeapons(client);
    SetEntityHealth(client, 50);
}

GiveStockWeapons(client)
{
    if (GetPlayerWeaponSlot(client, 0) <= 0)
        GivePlayerItem(client, "weapon_m4a1");

    if (GetPlayerWeaponSlot(client, 1) <= 0)
        GivePlayerItem(client, "weapon_deagle");
}

/* Like python's max function, returns greatest of the two values */
max(x, y)
{
    return (x > y ? x : y);
}


/*
 * This is just a basic "is player in a box" function
 * If the absolute value of the difference in x and y, of the players
 *  location and the center of armory is greater than the armory width
 *  and armory length, respectively, then the player has to be in armory
 * Note that 'z' direction is not included because there is nothing above
 *  or below armory, so we dont' have to worry about that
 */

bool:InBox(Float:x, Float:y,
            Float:centerX, Float:centerY,
            Float:xLength, Float:yLength)
{
    if (FloatAbs(x - centerX) < xLength &&
        FloatAbs(y - centerY) < yLength)
        return true;
    return false;
}

bool:IsValidPlayer(client, team)
{

    if (!IsClientInGame(client) ||
        !JB_IsPlayerAlive(client) ||
        GetClientTeam(client) != team)
        return false;
    return true;
}

GetPlayerAddTime(client)
{
    decl Float:fLocation[3];
    GetClientEyePosition(client, fLocation);

    /* Player's in armory */
    if (InBox(fLocation[0], fLocation[1],
                ARMORY_X_CENTER, ARMORY_Y_CENTER,
                ARMORY_WIDTH, ARMORY_LENGTH))
        return 1;

    /* Player's halfway to armory */
    else if (InBox(fLocation[0], fLocation[1],
                   ARMORY_X_CENTER, ARMORY_Y_CENTER,
                   ARMORY_WIDTH * 1.4, ARMORY_LENGTH * 1.1))
        return 0;

    /* Player's no where near armory */
    return -2;
}
