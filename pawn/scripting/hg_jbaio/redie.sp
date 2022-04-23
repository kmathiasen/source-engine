// To Do
// Third/first person
// Find a model for ghost

#define SOLIDFLAGS_NO_DAMAGE (1 << 1)
#define SOLIDFLAGS_DEBRIS (1 << 2)
#define GHOSTFLAGS SOLIDFLAGS_NO_DAMAGE|SOLIDFLAGS_DEBRIS
#define GHOST_SETDEBRIS_DISTANCE 75.0
#define GHOST_TELEPORT_DISTANCE 85.0

new bool:g_bMakeGhost[MAXPLAYERS + 1];
new bool:g_bIsGhost[MAXPLAYERS + 1];
new bool:g_bInDuckhunt[MAXPLAYERS + 1];
new g_iLastButtons[MAXPLAYERS + 1];
new g_iLastTeleportedTo[MAXPLAYERS + 1];
new Handle:g_hTeleportDestinations = INVALID_HANDLE;

/* ----- Events ----- */

stock Redie_OnPluginStart()
{
    if (g_iGame != GAMETYPE_TF2)
    {
        CreateTimer(2.5, Timer_GhostKeyHintsAndDuckHunt, _, TIMER_REPEAT);
        CreateTimer(0.02, Timer_GhostGlow, _, TIMER_REPEAT);

        RegConsoleCmd("sm_ghost", Command_Ghost);
        RegConsoleCmd("sm_ghosty", Command_Ghost);
        RegConsoleCmd("sm_ghostmode", Command_Ghost);
        RegConsoleCmd("sm_ghostymode", Command_Ghost);
        RegConsoleCmd("sm_redie", Command_Ghost);
        RegConsoleCmd("sm_deathmatch", Command_Ghost);
        RegConsoleCmd("sm_dm", Command_Ghost);

        HookEvent("player_footstep", OnPlayerFootStep);
        g_hTeleportDestinations = CreateTrie();
    }
}

public Redie_OnRoundStart()
{
    if (g_iGame != GAMETYPE_TF2)
    {
        CreateTimer(1.0, Redie_GetTeleportLocations);
    }
}

public OnPlayerFootStep(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (g_bIsGhost[client])
    {
        SetEntProp(client, Prop_Data, "m_fFlags", 4);
    }
}

public Redie_CellsOpened()
{
    if (g_iGame == GAMETYPE_TF2)
        return;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bIsGhost[i])
        {
            decl Float:origin[3];
            GetClientAbsOrigin(i, origin);

            if (origin[0] < 180.0 && origin[0] > 80.0 &&
                origin[1] > -2080.0 && origin[1] < -688.0)
            {
                if (!Tele_DoClient(0, i, "Bottom of Cell Stairs", false, true))
                {
                    TeleportEntity(i, Float:{273.34, -1447.0, 1.0}, NULL_VECTOR, NULL_VECTOR);
                }
            }
        }
    }
}

public Action:Redie_OnTriggerTouch(trigger, client)
{
    decl Float:ang[3];
    new Float:speed = GetEntPropFloat(trigger, Prop_Data, "m_flSpeed");
    GetEntPropVector(trigger, Prop_Data, "m_vecPushDir", ang);
    ScaleVector(ang, speed);

    if (client > 0 &&
        client <= MaxClients &&
        g_bIsGhost[client] &&
        GetEntityMoveType(client) != MOVETYPE_FLY)
    {
        decl Float:origin[3];
        GetClientAbsOrigin(client, origin);

        origin[2] += 10.0;
        ang[2] += 150.0;

        TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
        SetEntPropVector(client, Prop_Send, "m_vecBaseVelocity", ang);
    }
}

public Action:Redie_OnTeleportTouch(teleporter, client)
{
    if (client > 0 && client <= MAXPLAYERS && g_bIsGhost[client])
    {
        new String:m_target[MAX_NAME_LENGTH];
        decl Float:origin[3];

        GetEntPropString(teleporter, Prop_Data, "m_target", m_target, sizeof(m_target));
        if (GetTrieArray(g_hTeleportDestinations, m_target, origin, sizeof(origin)))
        {
            TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
        }
    }
}

public Action:Redie_OnDoorTouch(door, client)
{
    if (client > 0 && client <= MaxClients && g_bIsGhost[client])
    {
        decl String:classname[MAX_NAME_LENGTH];
        decl Float:ang[3];
        decl Float:doorOrigin[3];
        decl Float:clientOrigin[3];
        decl Float:vecMins[3];
        decl Float:vecMaxs[3];

        GetEntityClassname(door, classname, sizeof(classname));
        GetEntPropVector(door, Prop_Send, "m_angRotation", ang);
        GetEntPropVector(door, Prop_Send, "m_vecOrigin", doorOrigin);
        GetEntPropVector(door, Prop_Send, "m_vecMins", vecMins);
        GetEntPropVector(door, Prop_Send, "m_vecMaxs", vecMaxs);
        GetClientAbsOrigin(client, clientOrigin);

        if (StrContains(classname, "door_rotating") > -1)
        {
            // The door is closed
            if (ang[1] == 0.0)
            {
                doorOrigin[1] += 25.0;
                doorOrigin[2] = clientOrigin[2];

                if (clientOrigin[0] > doorOrigin[0])
                {
                    doorOrigin[0] -= 40.0;
                }

                else
                {
                    doorOrigin[0] += 40.0;
                }

                TeleportEntity(client, doorOrigin, NULL_VECTOR, NULL_VECTOR);
            }
        }
        
        else
        {
            // If it's larger than this, it's probably not a garage door
            // IE, it's race
            if ((vecMaxs[0] - vecMins[0]) < 380 &&
                (vecMaxs[1] - vecMins[1]) < 380)
            {
                if (clientOrigin[0] > doorOrigin[0])
                {
                    doorOrigin[0] -= 50.0;
                }

                else
                {
                    doorOrigin[0] += 50.0;
                }

                if (clientOrigin[1] > doorOrigin[1])
                {
                    doorOrigin[1] -= 50.0;
                }

                else
                {
                    doorOrigin[1] += 50.0;
                }

                doorOrigin[2] = clientOrigin[2];
                TeleportEntity(client, doorOrigin, NULL_VECTOR, NULL_VECTOR);
            }
        }
    }
}

bool:Redie_OnPlayerSpawn(client)
{
    if (g_iGame == GAMETYPE_TF2 || IsPlayerInDM(client))
        return false;

    if (g_bMakeGhost[client])
    {
        SetEntProp(client, Prop_Send, "m_nHitboxSet", 2);
        g_bMakeGhost[client] = false;
        g_bIsGhost[client] = true;

        return true;
    }

    g_bIsGhost[client] = false;
    SetEntProp(client, Prop_Send, "m_nHitboxSet", 0);

    return false;
}

stock Redie_OnClientCookiesCached(client)
{
    if (g_iGame != GAMETYPE_TF2 &&
        !IsClientCookieFlagSet(client, COOKIE_GHOST_DONT_SHOW_MENU))
    {
        ShowRedieMenu(client);
    }
}

stock Redie_OnPlayerTeamPost(client)
{
    g_bIsGhost[client] = false;
    CreateTimer(0.6969, Timer_Redie, GetClientUserId(client));
}

stock Redie_OnPlayerDeath(client)
{
    CreateTimer(0.666, Timer_Redie, GetClientUserId(client));
}

stock Redie_OnPlayerRunCmd(client, &buttons)
{
    new inUse = buttons & IN_USE;

    if (!JB_IsPlayerAlive(client))
    {
        buttons &= ~IN_USE;
    }

    if (g_bIsGhost[client])
    {
        // Tele them to the next alive player
        if (buttons & IN_ATTACK && !(g_iLastButtons[client] & IN_ATTACK))
        {
            new runs = 0;

            do
            {
                for (new i = g_iLastTeleportedTo[client] + 1; i <= MaxClients; i++)
                {
                    if (IsClientInGame(i) && JB_IsPlayerAlive(i))
                    {
                        decl Float:origin[3];

                        GetClientAbsOrigin(i, origin);
                        TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);

                        g_iLastTeleportedTo[client] = i;
                        runs++;

                        break;
                    }
                }

                if (runs++ == 0)
                {
                    g_iLastTeleportedTo[client] = 0;
                }
            } while (runs <= 1);
        }

        // Teleport through doors
        if (inUse && !(g_iLastButtons[client] & IN_USE))
        {
            decl Float:eyePos[3];
            decl Float:eyeAng[3];

            GetClientEyePosition(client, eyePos);
            GetClientEyeAngles(client, eyeAng);

            TR_TraceRayFilter(eyePos, eyeAng, MASK_ALL, RayType_Infinite, Trace_NoClients);

            if (TR_DidHit())
            {
                new ent = TR_GetEntityIndex();
                if (ent > 0)
                {
                    decl Float:entOrigin[3];
                    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", entOrigin);

                    if (Distance(entOrigin, eyePos) <= GHOST_TELEPORT_DISTANCE)
                    {
                        decl String:classname[MAX_NAME_LENGTH];
                        GetEntityClassname(ent, classname, sizeof(classname));
        
                        if (StrContains(classname, "door") > -1)
                        {
                            Redie_OnDoorTouch(ent, client);
                        }

                        else if (StrEqual(classname, "trigger_teleport"))
                        {
                            Redie_OnTeleportTouch(ent, client);
                        }
                    }
                }
            }
        }

        new MoveType:movetype = GetEntityMoveType(client);

        // Fly, bitches!
        if (buttons & IN_ATTACK2)
        {
            if (movetype != MOVETYPE_FLY)
            {
                SetEntityMoveType(client, MOVETYPE_FLY);
            }
        }

        // Don't fly, bitches!
        else if (movetype == MOVETYPE_FLY)
        {
            SetEntityMoveType(client, MOVETYPE_WALK);
        }

        buttons &= ~IN_USE;
        g_iLastButtons[client] = buttons|inUse;
    }
}

bool:Redie_OnWeaponCanUse(client)
{
    if (GetEntProp(client, Prop_Send, "m_lifeState") == 1)
        return false; 
    
    return true;
}

public Redie_OnRotatingDoorBlocked(const String:output[], door, client, Float:delay)
{
    if (client > 0 && client <= MaxClients && g_bIsGhost[client])
    {
        PrintToChat(client, "%s You were teleported for blocking a door as a ghost", MSG_PREFIX);

        if (!Tele_DoClient(0, client, "Bottom of Cell Stairs", false, true))
        {
            TeleportEntity(client, Float:{273.34, -1447.0, 1.0}, NULL_VECTOR, NULL_VECTOR);
        }
    }
}

/* ----- Commands ----- */

public Action:Command_Ghost(client, args)
{
    if (client > 0)
    {
        ShowRedieMenu(client);
    }

    return Plugin_Handled;
}

/* ----- Functions ----- */

public bool:Trace_NoClients(entity, contentsMask, any:data)
{
    return (entity > MaxClients) || entity == 0;
}

stock ShowRedieMenu(client)
{
    new Handle:menu = CreateMenu(RedieMenuSelect);
    SetMenuTitle(menu, "Ghost Options");

    if (IsClientCookieFlagSet(client, COOKIE_GHOST_ENABLED))
    {
        AddMenuItem(menu, "", "Don't Spawn As Ghost (When Dead)");
    }

    else
    {
        AddMenuItem(menu, "", "Spawn As Ghost (When Dead)");
    }

    if (IsClientCookieFlagSet(client, COOKIE_DEAD_DM_ENABLED))
    {
        AddMenuItem(menu, "", "Don't Play Death Match (When Dead)");
    }

    else
    {
        AddMenuItem(menu, "", "Play Death Match (When Dead)");
    }

    // debug
    /*if (IsClientCookieFlagSet(client, COOKIE_GHOST_THIRDPERSON))
    {
        AddMenuItem(menu, "", "First Person Ghost");
    }

    else
    {
        AddMenuItem(menu, "", "Third Person Ghost");
    }*/
    AddMenuItem(menu, "", "Third Person Coming Soon", ITEMDRAW_DISABLED);

    if (IsClientCookieFlagSet(client, COOKIE_GHOST_NOHUDHINT))
    {
        AddMenuItem(menu, "", "Show Hud Help");
    }

    else
    {
        AddMenuItem(menu, "", "Hide Hud Help");
    }

    if (IsClientCookieFlagSet(client, COOKIE_GHOST_DONT_SHOW_MENU))
    {
        AddMenuItem(menu, "", "Show Menu On Death");
    }

    else
    {
        AddMenuItem(menu, "", "Don't Show Menu On Death");
    }

    if (IsClientCookieFlagSet(client, COOKIE_GHOST_HIDE_GHOSTS))
    {
        AddMenuItem(menu, "", "Show Ghosts While Dead");
    }

    else
    {
        AddMenuItem(menu, "", "Hide Ghosts While Dead");
    }

    DisplayMenu(menu, client, MENU_TIMEOUT_NORMAL);
}

/* ----- Callbacks ----- */

public RedieMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);
    
        case MenuAction_Select:
        {
            switch (selected)
            {
                // Toggle spawning as ghost
                case 0:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_GHOST_ENABLED))
                    {
                        UnsetClientCookieFlag(client, COOKIE_GHOST_ENABLED);
                        PrintToChat(client, "%s You will no longer spawn as a ghost when dead", MSG_PREFIX);
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_GHOST_ENABLED);
                        UnsetClientCookieFlag(client, COOKIE_DEAD_DM_ENABLED);
                        PrintToChat(client, "%s You will now spawn as a ghost when dead", MSG_PREFIX);
                        CreateTimer(0.5, Timer_Redie, GetClientUserId(client));
                    }
                }

                // Play dead death match
                case 1:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_DEAD_DM_ENABLED))
                    {
                        UnsetClientCookieFlag(client, COOKIE_DEAD_DM_ENABLED);
                        PrintToChat(client, "%s You will no longer play deathmatch when dead", MSG_PREFIX);
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_DEAD_DM_ENABLED);
                        UnsetClientCookieFlag(client, COOKIE_GHOST_ENABLED);
                        PrintToChat(client, "%s You will now play deathmatch when dead", MSG_PREFIX);
                        CreateTimer(0.5, Timer_Redie, GetClientUserId(client));
                    }
                }

                // Toggle third person
                case 2:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_GHOST_THIRDPERSON))
                    {
                        UnsetClientCookieFlag(client, COOKIE_GHOST_THIRDPERSON);
                        PrintToChat(client, "%s You will now be in \x03first person mode\x04 as a ghost", MSG_PREFIX);

                        // debug
                        // to do
                        // Make them first person
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_GHOST_THIRDPERSON);
                        PrintToChat(client, "%s You will now be in \x03third person\x04 mode as a ghost", MSG_PREFIX);

                        // debug
                        // to do
                        // Make them third person
                    }
                }

                // Toggle hud help
                case 3:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_GHOST_NOHUDHINT))
                    {
                        UnsetClientCookieFlag(client, COOKIE_GHOST_NOHUDHINT);
                        PrintToChat(client, "%s You will now recieve hud hints for ghost mode", MSG_PREFIX);
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_GHOST_NOHUDHINT);
                        PrintToChat(client, "%s You will no longer recieve hud hints for ghost mode", MSG_PREFIX);
                    }
                }

                // Toggle menu
                case 4:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_GHOST_DONT_SHOW_MENU))
                    {
                        UnsetClientCookieFlag(client, COOKIE_GHOST_DONT_SHOW_MENU);
                        PrintToChat(client, "%s You will now see this menu every time you die", MSG_PREFIX);
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_GHOST_DONT_SHOW_MENU);
                        PrintToChat(client, "%s You will no longer see this menu upon death", MSG_PREFIX);
                        PrintToChat(client, "%s Type \x03!ghost\x04 to re-enable it", MSG_PREFIX);
                    }
                }

                // Toggle show ghosts
                case 5:
                {
                    if (IsClientCookieFlagSet(client, COOKIE_GHOST_HIDE_GHOSTS))
                    {
                        UnsetClientCookieFlag(client, COOKIE_GHOST_HIDE_GHOSTS);
                        PrintToChat(client, "%s You will now see ghosts while you are dead", MSG_PREFIX);
                    }

                    else
                    {
                        SetClientCookieFlag(client, COOKIE_GHOST_HIDE_GHOSTS);
                        PrintToChat(client, "%s You will no longer see ghosts while you are dead", MSG_PREFIX);
                    }
                }
            }

            ShowRedieMenu(client);
        }
    }
}

public Action:Timer_GhostKeyHintsAndDuckHunt(Handle:timer, any:data)
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (g_bIsGhost[i] &&
            IsClientInGame(i))
        {
            decl Float:origin[3];
            GetClientAbsOrigin(i, origin);

            if (origin[0] > 15.0 && origin[0] < 1170.0 &&
                origin[1] > 1455.0 && origin[1] < 1910.0)
            {
                if (!g_bInDuckhunt[i])
                {
                    g_bInDuckhunt[i] = true;
                    SetEntProp(i, Prop_Send, "m_usSolidFlags", (GetEntProp(i, Prop_Send, "m_usSolidFlags") & ~SOLIDFLAGS_DEBRIS));
                    SetEntData(i, m_CollisionGroup, 2, 4, true);
                }
            }

            else if (g_bInDuckhunt[i])
            {
                g_bInDuckhunt[i] = false;
                SetEntData(i, m_CollisionGroup, 1, 4, true);
                SetEntProp(i, Prop_Send, "m_usSolidFlags", (GetEntProp(i, Prop_Send, "m_usSolidFlags") | GHOSTFLAGS));
            }

            if (!IsClientCookieFlagSet(i, COOKIE_GHOST_NOHUDHINT))
            {
                KeyHintText(i, "+use ('e' key) to tele through doors\nLeft mouse to teleport\nHold right mouse to fly\nYou can't interact with the living");
            }
        }
    }

    return Plugin_Continue;
}

public Action:Timer_Redie(Handle:timer, any:userid)
{
    if (g_iGame == GAMETYPE_TF2)
        return Plugin_Stop;

    new client = GetClientOfUserId(userid);

    if (client <= 0 ||
        !IsClientInGame(client) ||
        JB_IsPlayerAlive(client) ||
        g_bIsGhost[client] ||
        GetClientTeam(client) <= TEAM_SPEC ||
        IsPlayerInDM(client))
        return Plugin_Stop;

    if (AreClientCookiesCached(client) &&
        !IsClientCookieFlagSet(client, COOKIE_GHOST_DONT_SHOW_MENU))
    {
        ShowRedieMenu(client);
    }

    if (IsClientCookieFlagSet(client, COOKIE_GHOST_ENABLED) || IsFakeClient(client))
    {
        g_bMakeGhost[client] = true;
        CS_RespawnPlayer(client);
        StripWeps(client, false);

        SetEntProp(client, Prop_Send, "m_lifeState", 1);
        SetEntData(client, m_CollisionGroup, 1, 4, true);
        SetEntProp(client, Prop_Send, "m_usSolidFlags", (GetEntProp(client, Prop_Send, "m_usSolidFlags") | GHOSTFLAGS));

        PrintHintText(client, "You are a ghost!\nLeft mouse to teleport\nHold right mouse to fly");
        PrintCenterText(client, "You are a ghost!\nLeft mouse to teleport\nHold right mouse to fly");
        PrintToChat(client, "%s You are now a ghost. Left mouse to teleport, hold right mouse to fly.", MSG_PREFIX);
    }

    return Plugin_Stop;
}

public Action:Timer_GhostGlow(Handle:timer, any:data)
{
    decl clients[MAXPLAYERS];
    new numClients;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) &&
            !JB_IsPlayerAlive(i) &&
            !IsClientCookieFlagSet(i, COOKIE_GHOST_HIDE_GHOSTS))
        {
            clients[numClients++] = i;
        }
    }

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || JB_IsPlayerAlive(i) || !g_bIsGhost[i])
            continue;

        decl Float:origin[3];
        GetClientAbsOrigin(i, origin);
        origin[2] += 40.0;

        TE_SetupGlowSprite(origin, g_iSpriteGlowBlue, 0.111, 1.4, 30);
        TE_Send(clients, numClients);
    }

    return Plugin_Continue;
}

public Action:Redie_GetTeleportLocations(Handle:timer, any:data)
{
    new index = INVALID_ENT_REFERENCE;
    ClearTrie(g_hTeleportDestinations);

    while ((index = FindEntityByClassname(index, "info_teleport_destination")) != INVALID_ENT_REFERENCE)
    {
        decl String:name[MAX_NAME_LENGTH];
        decl Float:origin[3];

        GetEntPropString(index, Prop_Data, "m_iName", name, sizeof(name));
        GetEntPropVector(index, Prop_Data, "m_vecOrigin", origin);

        SetTrieArray(g_hTeleportDestinations, name, origin, 3);
    }
}
