
new bool:bFindLocation[MAXPLAYERS + 1];
new bool:bIsExecutioner[MAXPLAYERS + 1];
new bool:bHasSuperKnife[MAXPLAYERS + 1];

new iCellButton = -1;        /* Stores the index of the open cell button */
new Float:fTeleportLocation[MAXPLAYERS + 1][3];

/* ----- Events ----- */


public ServerCommands_OnPluginStart()
{
    RegServerCmd("gang_addhealth", Server_AddHealth);
    RegServerCmd("gang_sethealth", Server_SetHealth);
    RegServerCmd("gang_addspeed", Server_AddSpeed);
    RegServerCmd("gang_setgravity", Server_SetGravity);
    RegServerCmd("gang_give", Server_Give);
    RegServerCmd("gang_noclip", Server_Noclip);
    RegServerCmd("gang_teleport", Server_Teleport);
    RegServerCmd("gang_add_level", Server_AddLevel);
    RegServerCmd("gang_open_cells", Server_OpenCells);
    RegServerCmd("gang_absorb_damage", Server_AbsorbDamage);
    RegServerCmd("gang_extra_damage", Server_ExtraDamage);
    RegServerCmd("gang_respawn", Server_Respawn);
    RegServerCmd("gang_executioner", Server_Executioner);
    RegServerCmd("gang_superknife", Server_SuperKnife);
    RegServerCmd("gang_lightstyle", Server_LightStyle);
    RegServerCmd("gang_give_throwingknives", Server_ThrowingKnives);
}

public Action:ServerCommands_OnMapStart(Handle:timer)
{
    GetCellOpenerIndex();
}

stock ServerCommands_OnPlayerSpawn(client)
{
    CreateTimer(0.1, ResetStatus, client);

    bFindLocation[client] = false;
    bIsExecutioner[client] = false;
    bHasSuperKnife[client] = false;
}

stock ServerCommands_OnPlayerDeath(client)
{
    if (bFindLocation[client])
        FindLocation(client);

    if (fTeleportLocation[client][0] != NULL_VECTOR[0] &&
        fTeleportLocation[client][1] != NULL_VECTOR[1] &&
        fTeleportLocation[client][2] != NULL_VECTOR[2])
        CreateTimer(0.3, Timer_RespawnPlayer, client);
}

Action:ServerCommands_OnTakeDamage(client, attacker, &Float:damage)
{
    if (bHasSuperKnife[attacker])
    {
        decl String:weapon[MAX_NAME_LENGTH];
        GetClientWeapon(attacker, weapon, sizeof(weapon));

        if (StrEqual(weapon, "weapon_knife"))
        {
            damage += 100.0;
            damage *= 2.0;

            bHasSuperKnife[attacker] = false;
            return Plugin_Changed;
        }
    }

    if (!bIsExecutioner[attacker])
        return Plugin_Continue;

    if (GetClientHealth(client) - damage > 1.0 &&
       (damage != 65.0 || GetRandomFloat() > 0.5))
        return Plugin_Continue;

    new bool:dropped;
    new valid;

    for (new i = 0; i < 3; i++)
    {
        new wep = GetPlayerWeaponSlot(client, i);
        if (wep != -1)
        {
            valid++;

            if (!dropped)
            {
                decl String:classname[32];
                decl Float:origin[3];

                GetEntityClassname(wep, classname, sizeof(classname));
                GetClientAbsOrigin(client, origin);

                dropped = true;
                origin[2] += 1.0;

                new index = CreateEntityByName(classname);
                DispatchSpawn(index);
    
                TeleportEntity(index, origin, NULL_VECTOR, NULL_VECTOR);
            }

            RemovePlayerItem(client, wep);
        }
    }

    if (!valid)
        return Plugin_Continue;

    PrintToChat(client,
                "%s \x04%N\x01 has sent you to the electric chair!",
                MSG_PREFIX, attacker);

    TeleportEntity(client, fElectricChair, NULL_VECTOR, NULL_VECTOR);

    if (g_iGame == GAMETYPE_CSS)
        SetEntProp(client, Prop_Data, "m_iFrags", GetClientFrags(attacker) + 1);

    return Plugin_Stop;
}


/* ----- Commands ----- */


public Action:Server_LightStyle(args)
{
    if (args < 1)
    {
        LogMessage("Gangs Error: Invalid Syntax -- gang_lightstyle <style string>");
        return Plugin_Handled;
    }

    decl String:lightstyle[32];
    GetCmdArg(1, lightstyle, sizeof(lightstyle));

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_T)
            GivePlayerItem(i, "item_nvgs");
    }

    SetLightStyle(0, lightstyle);
    return Plugin_Handled;
}

public Action:Server_SuperKnife(args)
{
    if (args < 1)
    {
        LogMessage("Gangs Error: Invalid Syntax -- gang_superknife <userid>");
        return Plugin_Handled;
    }

    decl String:sTarget[8];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    new client = GetClientOfUserId(StringToInt(sTarget));

    PrintToChat(client, "%s You now have \x04Super Knife", MSG_PREFIX);
    PrintToChat(client, "%s The next CT you knife will die", MSG_PREFIX);

    bHasSuperKnife[client] = true;
    return Plugin_Handled;
}

public Action:Server_Executioner(args)
{
    if (args < 1)
    {
        LogMessage("Gangs Error: Invalid Syntax -- gang_executioner <userid>");
        return Plugin_Handled;
    }

    decl String:sTarget[8];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    new client = GetClientOfUserId(StringToInt(sTarget));

    PrintToChat(client,
                "%s You are now an \x04Executioner\x01 everyone you kill will be sent to the electric chair",
                MSG_PREFIX);

    PrintToChat(client,
                "%s Right-Click knifes also have a \x0450 percent\x01 chance of the same effect.",
                MSG_PREFIX);

    bIsExecutioner[client] = true;
    return Plugin_Handled;
}

public Action:Server_Respawn(args)
{
    if (args < 1)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_spawn <userid> [x] [y] [z]");
        return Plugin_Handled;
    }

    decl String:sTarget[8];

    GetCmdArg(1, sTarget, sizeof(sTarget));
    new client = GetClientOfUserId(StringToInt(sTarget));

    if (args >= 4)
    {
        GetCmdArg(2, sTarget, sizeof(sTarget));
        fTeleportLocation[client][0] = StringToFloat(sTarget); 

        GetCmdArg(3, sTarget, sizeof(sTarget));
        fTeleportLocation[client][1] = StringToFloat(sTarget);

        GetCmdArg(4, sTarget, sizeof(sTarget));
        fTeleportLocation[client][2] = StringToFloat(sTarget); 
    }

    else
        bFindLocation[client] = true;

    if (!JB_IsPlayerAlive(client))
        ServerCommands_OnPlayerDeath(client);

    else
        PrintToChat(client,
                    "%s You will respawn when you next die this round. \x04Prepare to rebel!",
                    MSG_PREFIX);

    return Plugin_Handled;
}

public Action:Server_SetHealth(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_sethealth <#userid/@team/name>");
        return Plugin_Handled;
    }

    decl String:sTarget[MAX_TARGET_LENGTH];
    GetCmdArg(1, sTarget, sizeof(sTarget));

    decl iTargets[MAXPLAYERS + 1];
    decl String:sTargetName[MAX_TARGET_LENGTH];

    new bool:bMultipleUsers;

    new iTargetCount = ProcessTargetString(sTarget, 0, iTargets,
                                           MAXPLAYERS + 1,
                                           COMMAND_FILTER_ALIVE|COMMAND_FILTER_NO_IMMUNITY,
                                           sTargetName,
                                           sizeof(sTargetName), bMultipleUsers);

    decl String:sAmount[8];
    GetCmdArg(2, sAmount, sizeof(sAmount));

    new amount = StringToInt(sAmount);
    for (new i = 0; i < iTargetCount; i++)
    {
        SetEntityHealth(iTargets[i], amount);
        PrintToChat(iTargets[i],
                    "%s Something set your health to \x04%d",
                    MSG_PREFIX, amount);
    }

    return Plugin_Handled;
}

public Action:Server_ThrowingKnives(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_give_throwingknvies <player> <amount> [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:knives[4];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, knives, sizeof(knives));

    new client = GetClientOfUserId(StringToInt(userid));
    SetClientThrowingKnives(client, GetClientThrowingKnives(client) + StringToInt(knives));

    if (args > 2)
        PrintToChat(client,
                    "%s You have obtained \x04%i\x01 throwing knives",
                    MSG_PREFIX, StringToInt(knives));

    else
        PrintToChat(client,
                    "%s You have bought \x04%i\x01 throwing knives",
                    MSG_PREFIX, StringToInt(knives));

    return Plugin_Handled;
}

public Action:Server_AddHealth(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_addhealth <player> <amount> [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:health[4];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, health, sizeof(health));

    new client = GetClientOfUserId(StringToInt(userid));
    SetEntityHealth(client, GetClientHealth(client) + StringToInt(health));

    if (args > 2)
        PrintToChat(client,
                    "%s You have obtained \x04%i\x01 health",
                    MSG_PREFIX, StringToInt(health));

    else
        PrintToChat(client,
                    "%s You have bought \x04%i\x01 health",
                    MSG_PREFIX, StringToInt(health));

    return Plugin_Handled;
}

public Action:Server_AddSpeed(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_addspeed <player> <amount> [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:speed[5];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, speed, sizeof(speed));

    new client = GetClientOfUserId(StringToInt(userid));
    new Float:currentSpeed = GetEntPropFloat(client, Prop_Data,
                                             "m_flLaggedMovementValue");

    SetEntPropFloat(client, Prop_Data,
                    "m_flLaggedMovementValue",
                    currentSpeed + StringToFloat(speed));

    if (args > 2)
        PrintToChat(client,
                    "%s You obtained an extra \x04%.2f\x01 speed boost",
                    MSG_PREFIX, StringToFloat(speed));

    else
        PrintToChat(client,
                    "%s You bought an extra \x04%.2f\x01 speed boost",
                    MSG_PREFIX, StringToFloat(speed));

    return Plugin_Handled;
}

public Action:Server_SetGravity(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_setgravity <player> <multiplier>");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:gravity[4];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, gravity, sizeof(gravity));

    new client = GetClientOfUserId(StringToInt(userid));

    SetEntityGravity(client, StringToFloat(gravity));
    PrintToChat(client,
                "%s You bought a \x04%s\x01 gravity multiplier",
                MSG_PREFIX, gravity);

    return Plugin_Handled;
}

public Action:Server_Give(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax - gang_give <player> <weapon> [clip] [ammo] [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:sWeaponName[32];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, sWeaponName, sizeof(sWeaponName));

    if (g_iGame == GAMETYPE_CSGO)
    {
        if (StrEqual(sWeaponName, "weapon_usp"))
            Format(sWeaponName, sizeof(sWeaponName), "weapon_hkp2000");

        else if (StrEqual(sWeaponName, "weapon_p228"))
            Format(sWeaponName, sizeof(sWeaponName), "weapon_p250");

        else if (StrEqual(sWeaponName, "weapon_m3"))
            Format(sWeaponName, sizeof(sWeaponName), "weapon_nova");

        else if (StrEqual(sWeaponName, "weapon_scout"))
            Format(sWeaponName, sizeof(sWeaponName), "weapon_ssg08");
    }

    new client = GetClientOfUserId(StringToInt(userid));
    new iWeaponIndex = GivePlayerItem(client, sWeaponName);

    JB_DontGiveAmmo(iWeaponIndex);

    if (iWeaponIndex < 1)
    {
        LogMessage("Gangs Error: Could not create item \"%s\"", sWeaponName);
        return Plugin_Handled;
    }

    if (args > 2)
    {
        decl String:clip[4];
        GetCmdArg(3, clip, sizeof(clip));
        
        SetEntData(iWeaponIndex, m_iClip1, StringToInt(clip));
    }

    if (args > 3)
    {
        decl String:ammo[4];
        GetCmdArg(4, ammo, sizeof(ammo));

        SetEntData(client, m_iAmmo +
                   GetEntProp(iWeaponIndex, Prop_Send, "m_iPrimaryAmmoType") * 4,
                   StringToInt(ammo), _, true);
    }

    ReplaceString(sWeaponName, sizeof(sWeaponName), "weapon_", "", false);

    if (StrEqual("scout", sWeaponName, false))      // lol
        PrintToChat(client,
                    "%s \x04Gratz \x01You won the \x04aQ Scout!\x03 3\x01 shots to prove yourself!",
                    MSG_PREFIX);

    else if (args > 4)
        PrintToChat(client,
                    "%s \x01You obtained a \x04%s", MSG_PREFIX, sWeaponName);

    else
        PrintToChat(client,
                    "%s You bought a \x04%s", MSG_PREFIX, sWeaponName);

    return Plugin_Handled;
}

public Action:Server_OpenCells(args)
{
    if (g_iGame == GAMETYPE_TF2)
    {
        SetVariantString("");
        AcceptEntityInput(iCellButton, "SetDamageFilter");

        AcceptEntityInput(iCellButton, "Unlock");
        AcceptEntityInput(iCellButton, "PressOut");
        AcceptEntityInput(iCellButton, "Use");
    }

    AcceptEntityInput(iCellButton, "Use");

    decl String:userid[7];
    GetCmdArg(1, userid, sizeof(userid));

    decl String:name[MAX_NAME_LENGTH];
    GetClientName(GetClientOfUserId(StringToInt(userid)), name, sizeof(name));

    PrintToChatAll("%s \x04%s\x01 bought a cell opener", MSG_PREFIX, name);
    return Plugin_Handled;
}

public Action:Server_AbsorbDamage(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax -- gang_absorb_damage <player> <multiplier> [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[8];
    decl String:sMultiplier[8];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, sMultiplier, sizeof(sMultiplier));

    new client = GetClientOfUserId(StringToInt(userid));
    new Float:multiplier = StringToFloat(sMultiplier);

    fAbsorbMultiplier[client] = 1 - multiplier;
    if (args > 2)
        PrintToChat(client,
                    "%s You recieved a \x04%.2f\x01 damage absorb",
                    MSG_PREFIX, 1 - multiplier);

    else
        PrintToChat(client,
                    "%s You bought a \x04%.2f\x01 damage absorb",
                    MSG_PREFIX, 1 - multiplier);

    return Plugin_Handled;
}

public Action:Server_ExtraDamage(args)
{
    if (args < 2)
    {
        LogMessage("Gangs Error: Invalid Syntax -- gang_extra_damage <player> <multiplier> [obtained]");
        return Plugin_Handled;
    }

    decl String:userid[8];
    decl String:sMultiplier[8];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, sMultiplier, sizeof(sMultiplier));

    new client = GetClientOfUserId(StringToInt(userid));
    new Float:multiplier = StringToFloat(sMultiplier);

    fGiveMultiplier[client] = 1 + multiplier;
    if (args > 2)
        PrintToChat(client,
                    "%s You recieved a \x04%.2f\x01 damage multiplier",
                    1 + multiplier);

    else
        PrintToChat(client,
                    "%s You bought a \x04%.2f\x01 damage multiplier",
                    MSG_PREFIX, 1 + multiplier);

    return Plugin_Handled;
}

public Action:Server_AddLevel(args)
{
    if (args < 2)
    {
        PrintToServer("Gangs Error: Invalid Syntax -- gang_add_level <level> <amount>");
        return Plugin_Handled;
    }
    
    decl String:level[3];
    decl String:cost[8];

    GetCmdArg(1, level, sizeof(level));
    GetCmdArg(2, cost, sizeof(cost));

    new iLevel = StringToInt(level);
    new iCost = StringToInt(cost);

    if (iLevel < 1|| iCost < 1)
    {
        PrintToServer("Gangs Error: Parameters must be positive integers -- gang_add_level <level> <amount>");
        return Plugin_Handled;
    }

    if (iLevel > levels + 1)
    {
        PrintToServer("Gangs Error: Previous level must be 1 more than the last added");
        return Plugin_Handled;
    }

    levels++;
    WritePackCell(hLevelCosts, iCost);

    /* The first level was created, now we can create the "create gang menu" */
    if (iLevel == 1)
    {
        decl String:sConfirmTitle[64];
        hConfirmCreateGangMenu = CreateMenu(ConfirmCreateGangMenuSelect);

        ResetPack(hLevelCosts);
        Format(sConfirmTitle, sizeof(sConfirmTitle),
               "Create Gang For %d Points?", ReadPackCell(hLevelCosts));

        SetMenuTitle(hConfirmCreateGangMenu, sConfirmTitle);

        AddMenuItem(hConfirmCreateGangMenu, "No", "No");
        AddMenuItem(hConfirmCreateGangMenu, "No", "Yes");
    }

    return Plugin_Handled;
}

public Action:Server_Teleport(args)
{
    if (args < 4)
    {
        PrintToServer("Gangs Error: Invalid Syntax -- gang_teleport <userid> <x> <y> <z>");
        return Plugin_Handled;
    }

    decl String:userid[7];
    decl String:x[7];
    decl String:y[7];
    decl String:z[7];

    new Float:loc[3];

    GetCmdArg(1, userid, sizeof(userid));
    GetCmdArg(2, x, sizeof(userid));
    GetCmdArg(3, y, sizeof(y));
    GetCmdArg(4, z, sizeof(z));

    loc[0] = StringToFloat(x);
    loc[1] = StringToFloat(y);
    loc[2] = StringToFloat(z);

    new client = GetClientOfUserId(StringToInt(userid));
    TeleportEntity(client, loc, NULL_VECTOR, NULL_VECTOR);

    if (args > 4)
        PrintToChat(client, "%s You obtained a \x04Teleport!", MSG_PREFIX);

    else
        PrintToChat(client, "%s You bought a \x04Teleport!", MSG_PREFIX);

    return Plugin_Handled;
}

public Action:Server_Noclip(args)
{
    if (args < 1)
    {
        PrintToServer("Gangs Error: Invalid Syntax -- gang_noclip <userid>");
        return Plugin_Handled;
    }

    decl String:userid[7];
    GetCmdArg(1, userid, sizeof(userid));

    new client = GetClientOfUserId(StringToInt(userid));

    SetEntData(client, FindSendPropOffs("CBaseEntity", "movetype"), 8);
    PrintToChat(client, "%s You bought noclip", MSG_PREFIX);

    return Plugin_Handled;
}


/* ----- Functions ----- */


stock FindLocation(client)
{
    bFindLocation[client] = false;

    /* Arbitrary large number */
    new Float:closest = float(1 << 30);

    /* Find the distance of seperation between the two closest players */
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_T)
            continue;

        for (new j = i + 1; j <= MaxClients; j++)
        {
            if (!IsClientInGame(j) || GetClientTeam(j) != TEAM_T)
                continue;

            new Float:temp = PlayerSeperation(i, j);
            if (temp < closest)
                closest = temp;
        }
    }

    /*
     * Just in case two people are stacked, there's still the possibility
     *  that there's a cluster of like 10 people with a greater distance
     * So yeah... see FindAttatchedPlayers for explanation
     */

    closest = closest > CLUSTER_DISTANCE ? closest * 1.5 : float(CLUSTER_DISTANCE);

    new largestClustersPlayers;
    new largestClustersPlayer;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) ||
            GetClientTeam(i) != TEAM_T ||
            !JB_IsPlayerAlive(i))
            continue;

        new data[MAXPLAYERS];
        new totalParts = 1;
        new waveIndex;

        data[0] = i;
        FindAttatchedPlayers(i, closest, totalParts, waveIndex, data);

        if (totalParts > largestClustersPlayers)
        {
            largestClustersPlayers = totalParts;
            largestClustersPlayer = i;
        }

        /* If there's 5 Ts in a cluster... Good enough! */
        if (totalParts >= 5)
            break;
    }

    if (!largestClustersPlayer)
    {
        PrintToChat(client,
                    "%s You were going to respawn... But you don't have any teammates",
                    MSG_PREFIX);
        return;
    }

    GetClientAbsOrigin(largestClustersPlayer, fTeleportLocation[client]);
    fTeleportLocation[client][2] += 1.0;
}

/**
 * Yay recursive functions!
 * This is pretty much a "flood" algorithm.
 *
 * 1. Start at "Ground Zero" the passed client.
 * 2. Loop through all the players (which have not already been checked)
 *      If that player is closer than "distance", add them to "parts"
 *      Then increment "totalParts"
 * 3. Set "waveIndex" to "totalParts" minus the amount of people found this "wave"
 * 4. Go back to step 2, until thisWave == 0
 */

stock FindAttatchedPlayers(client, Float:distance, &totalParts, &waveIndex, parts[MAXPLAYERS])
{
    new thisWave;
    new cc;

    for (new i = waveIndex; i < totalParts; i++)
    {
        cc = parts[i];

        for (new j = 1; j <= MaxClients; j++)
        {
            if (j == cc ||
                !IsClientInGame(j) ||
                GetClientTeam(j) != TEAM_T ||
                !JB_IsPlayerAlive(j))
                continue;

            new bool:counted = false;

            for (new k = 0; k < totalParts; k++)
            {
                if (j == parts[k])
                {
                    counted = true;
                    break;
                }
            }

            if (counted)
                continue;

            if (PlayerSeperation(j, cc) < distance)
            {
                thisWave++;
                parts[totalParts++] = j;
            }
        }
    }

    /*
     * Either the flood algorithm has gone as far as it can
     * Or the recursive function has gone too deep (5 iterations)
     */
    if (!thisWave || totalParts >= 5)
        return;

    waveIndex = totalParts - thisWave;
    FindAttatchedPlayers(client, distance, totalParts, waveIndex, parts);
}

public Action:ResetStatus(Handle:timer, any:client)
{
    fTeleportLocation[client] = NULL_VECTOR;
}

public Action:Timer_RespawnPlayer(Handle:timer, any:client)
{
    RespawnPlayer(client);
    TeleportEntity(client, fTeleportLocation[client], NULL_VECTOR, NULL_VECTOR);

    fTeleportLocation[client] = NULL_VECTOR;

    PrintToChat(client,
                "%s You have been respawned, I hope you were paying attention \x04#NoBitching",
                MSG_PREFIX);
}

stock GetCellOpenerIndex()
{
    /* Get the index of the open cell button */
    new index = -1;
    decl Float:fLocation[3];

    while ((index = FindEntityByClassname(index, "func_button")) != -1)
    {
        GetEntPropVector(index, Prop_Send, "m_vecOrigin", fLocation);
        if (fLocation[0] == (g_iGame == GAMETYPE_TF2 ? 66.0 : 23.0) &&
            fLocation[1] == (g_iGame == GAMETYPE_TF2 ? -2118.0 : -2082.0))
        {

            iCellButton = index;
            break;
        }
    }
}


/* ----- Return Values ----- */


Float:PlayerSeperation(client1, client2)
{
    decl Float:origin1[3];
    decl Float:origin2[3];

    GetClientAbsOrigin(client1, origin1);
    GetClientAbsOrigin(client2, origin2);

    return SquareRoot(Pow(origin1[0] - origin2[0], 2.0) +
                       Pow(origin1[1] - origin2[1], 2.0) +
                       Pow(origin1[2] - origin2[2], 2.0));
}
