
#define MAX_ATTACHMENTS 4

// ###################### GLOBALS ######################

new Handle:g_hHatsEnabled = INVALID_HANDLE;
new Handle:g_hViewForTimePerRound = INVALID_HANDLE;
new Handle:g_hActiveHat = INVALID_HANDLE;
new Handle:g_hHatsAppear = INVALID_HANDLE;
new Handle:g_hHatPaths = INVALID_HANDLE;
new Handle:g_hHatPosition = INVALID_HANDLE;
new Handle:g_hHatAngles = INVALID_HANDLE;
new Handle:g_hHatBone = INVALID_HANDLE;

new Handle:g_hPlayerHats[MAXPLAYERS + 1];
new Handle:g_hViewHatTimer[MAXPLAYERS + 1];
new Handle:g_hHatEntities[MAXPLAYERS + 1];
new Handle:g_hActiveHats[MAXPLAYERS + 1];
new Handle:g_hHatSubTypes[MAXPLAYERS + 1];

new String:g_sHatSubType[MAXPLAYERS + 1][LEN_NAMES];

new bool:g_bHatsEnabled;

new bool:g_bHatAppear[MAXPLAYERS + 1];
new bool:g_bViewingHatCam[MAXPLAYERS + 1];
new bool:g_bHatsWasInSubMenu[MAXPLAYERS + 1];

new g_iEntityHatCam[MAXPLAYERS + 1];
new g_iLastHatChange[MAXPLAYERS + 1];

new Float:g_fViewAngleCam[MAXPLAYERS + 1][3];
new Float:g_fOriginHatData[MAXPLAYERS + 1][3];


// ###################### EVENTS ######################

public Hats_OnPluginStart()
{
    g_hHatsEnabled = CreateConVar("hg_premium_hats", "1.0", "Enables/Disables player hats.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hViewForTimePerRound = CreateConVar("hg_premium_view_per_round", "0", "If non zero, how many seconds in to the round !view may be used", FCVAR_NONE, true, 0.0, true, 540.0);

    HookEvent("player_death", Hats_Event_OnPlayerDeath);
    HookEvent("player_team", Hats_Event_OnPlayerDeath);
    HookEvent("round_end", Hats_Event_OnRoundEnd, EventHookMode_Pre);
    
    if (g_iGame != GAMETYPE_TF2)
    {
        RegConsoleCmd("sm_hat", Command_Hats, "Player hats menu.");
        RegConsoleCmd("sm_hats", Command_Hats, "Player hats menu.");
        RegConsoleCmd("sm_view", Command_ViewHat, "View yourself 3rdperson.");
        RegConsoleCmd("sm_viewhat", Command_ViewHat, "View yourself 3rdperson.");
        RegConsoleCmd("sm_viewhats", Command_ViewHat, "View yourself 3rdperson.");
        RegConsoleCmd("sm_attachments", Command_Hats, "Player hats menu.");
        RegConsoleCmd("sm_attachment", Command_Hats, "Player hats menu.");
    }

    g_hActiveHat = RegClientCookie("hg_premium_hat",
                                   "Active Hat", CookieAccess_Protected);

    g_hHatsAppear = RegClientCookie("hg_premium_hats_appear",
                                    "Does the player's hat appear", CookieAccess_Protected);

    g_bHatsEnabled = GetConVarInt(g_hHatsEnabled) ? true : false;

    g_hHatPaths = CreateTrie();
    g_hHatPosition = CreateTrie();
    g_hHatAngles = CreateTrie();
    g_hHatBone = CreateTrie();
}

public Hats_OnPluginEnd()
{
    for(new i = 1; i <= MaxClients; i++)
        Hats_KillHat(i);
}

public Hats_OnMapStart()
{
    g_bHatsEnabled = GetConVarInt(g_hHatsEnabled) ? true : false;
}

stock Hats_OnDBConnect()
{
    if(g_bHatsEnabled)
        Hats_LoadHats();
}

public Hats_OnMapEnd()
{
    for (new i = 1; i <= MaxClients; i++)
        Hats_KillHat(i);
}

public Hats_OnGameFrame()
{
    if(g_bHatsEnabled)
    {
        for (new i=1; i <= MaxClients; i++)
        {
            if(g_bViewingHatCam[i] && IsClientInGame(i) && IsClientConnected(i) && IsPlayerAlive(i))
            {
                if (GetEntityFlags(i) & FL_ONGROUND)
                {
                    Hats_View360Rotate(i, g_iEntityHatCam[i], g_fOriginHatData[i]);
                }

                else
                {
                    Hats_KillViewCam(i);
                    PrintToChat(i, "%s Your hat preview has been turned off because you are no longer on the ground", MSG_PREFIX);
                }
            }
        }
    }
}

public Hats_OnClientPutInServer(client)
{
    g_hHatEntities[client] = CreateArray();
    g_hActiveHats[client] = CreateArray(ByteCountToCells(LEN_NAMES));
    g_hHatSubTypes[client] = CreateArray(ByteCountToCells(LEN_NAMES));
}

public Hats_OnClientFullyAuthorized(client, const String:steamid[])
{
    if (g_hPlayerHats[client] != INVALID_HANDLE)
        ClearArray(g_hPlayerHats[client]);

    else
        g_hPlayerHats[client] = CreateArray(ByteCountToCells(LEN_NAMES));

    new String:hats_appear[3];
    new String:hats_active[LEN_NAMES];

    GetClientCookie(client, g_hHatsAppear, hats_appear, sizeof(hats_appear));
    GetClientCookie(client, g_hActiveHat, hats_active, sizeof(hats_active));

    if (StrEqual(hats_appear, "") || !StringToInt(hats_appear))
        g_bHatAppear[client] = false;

    else
        g_bHatAppear[client] = true;

    new String:hats[MAX_ATTACHMENTS][LEN_NAMES];
    ExplodeString(hats_active, "|", hats, MAX_ATTACHMENTS, LEN_NAMES);

    new bool:any;

    for (new i = 0; i < MAX_ATTACHMENTS; i++)
    {
        if (HatFound(hats[i]))
        {
            any = true;
            decl String:parent[LEN_NAMES];

            if (GetTrieString(g_hItemSubTypes, hats[i], parent, sizeof(parent)))
            {
                PushArrayString(g_hActiveHats[client], hats[i]);
                PushArrayString(g_hHatSubTypes[client], parent);
            }
        }
    }

    if (!any)
        g_bHatAppear[client] = false;
}

public Hats_OnClientDisconnect(client)
{
    Hats_KillHat(client);

    if(g_iEntityHatCam[client] > 0)
        Hats_KillViewCam(client);

    if (g_hHatEntities[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hHatEntities[client]);
        g_hHatEntities[client] = INVALID_HANDLE;
    }

    if (g_hActiveHats[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hActiveHats[client]);
        g_hActiveHats[client] = INVALID_HANDLE;
    }

    if (g_hHatSubTypes[client] != INVALID_HANDLE)
    {
        CloseHandle(g_hHatSubTypes[client]);
        g_hHatSubTypes[client] = INVALID_HANDLE;
    }
}

// ###################### ACTIONS ######################


stock Hats_OnPlayerSpawn(client)
{
    if (!g_bHatsEnabled)
        return;

    KillHatsStuff(client);

    if(GetClientTeam(client) >= TEAM_T && g_bHatAppear[client])
    {
        CreateTimer(0.01, Hats_Timer_Attach, GetClientUserId(client));
    }
}

public Action:Hats_Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!client || !IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Continue;

    KillHatsStuff(client);
    return Plugin_Continue;
}

public Action:Hats_Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    for(new i = 1; i <= MaxClients; i++)
    {
        Hats_KillHat(i);

        if(g_iEntityHatCam[i] > 0)
            Hats_KillViewCam(i);
    }

    return Plugin_Continue;
}

public Action:Command_Hats(client, args)
{
    if (IsAuthed(client) && !DatabaseFailure(client))
        Hats_MenuHats(client);
    return Plugin_Handled;
}

public Action:Command_ViewHat(client, args)
{
    if (IsAuthed(client) && !DatabaseFailure(client))
    {
        if(!g_bViewingHatCam[client])
        {
            if(IsClientInGame(client) && IsClientConnected(client) && IsPlayerAlive(client))
            {
                new tpr = GetConVarInt(g_hViewForTimePerRound);

                if (tpr > 0 && GetTime() - g_iRoundStartTime > tpr)
                {
                    PrintToChat(client, "%s You may only use this command for the first \x03%d \x04seconds of the round", MSG_PREFIX, tpr);
                }
                else if (GetEntityMoveType(client) != MOVETYPE_WALK)
                {
                    PrintToChat(client, "%s You can not use this command while you are frozen, flying, or on a ladder", MSG_PREFIX);
                }
                else if(!(GetEntityFlags(client) & FL_ONGROUND))
                {
                    PrintToChat(client, "%s Don't Jump! Try preview again.", MSG_PREFIX);
                }
                else
                {
                    Hats_ViewHat(client);
                    PrintToChat(client, "%s 360 Preview On!", MSG_PREFIX);
                }
            }
            else
                PrintToChat(client, "%s You must be alive to view yourself!", MSG_PREFIX);
        }
        else
        {
            Hats_KillViewCam(client);
            PrintToChat(client, "%s 360 Preview Off!", MSG_PREFIX);
        }
    }
    return Plugin_Handled;
}

public Action:Hats_Timer_Attach(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);

    if (client > 0 && IsPlayerAlive(client))
    {
        Hats_AttachHat(client);
    }
}

public Action:Hats_Transmit(entity, client)
{
    if (client < 1 || client > MaxClients || !IsValidEntity(entity) || g_bViewingHatCam[client])
        return Plugin_Continue;

    new mode = Client_GetObserverMode(client);

    if (mode == OBS_MODE_NONE && FindValueInArray(g_hHatEntities[client], entity) > -1)
        return Plugin_Handled;

    if (mode == OBS_MODE_IN_EYE)
    {
        new observing = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
        if (observing > 0 && FindValueInArray(g_hHatEntities[observing], entity) > -1)
            return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action:Hats_ClearCamTimer(Handle:timer, any:client)
{
    g_hViewHatTimer[client] = INVALID_HANDLE;
    if(g_iEntityHatCam[client] > 0)
        Hats_KillViewCam(client);
}

public Action:Hats_View360Rotate(Client, Entity, Float:origin[3])
{
    new Float:angles[3];

    if(g_fViewAngleCam[Client][1] > 179.5)
        g_fViewAngleCam[Client][1] = -179.9;

    angles[0] = 0.0; // Force 0.0 look up/down to perform perfect circle.
    angles[1] = g_fViewAngleCam[Client][1] + 0.5;
    angles[2] = 0.0;

    g_fViewAngleCam[Client][1] = angles[1];
    
    // Calculate distance radius circle from player origin.
    new Float:entcoords[3];

    entcoords[0]=origin[0]+64.0*Cosine(DegToRad(0.0-angles[0]))*Cosine(DegToRad(angles[1]));
    entcoords[1]=origin[1]+64.0*Cosine(DegToRad(0.0-angles[0]))*Sine(DegToRad(angles[1]));
    entcoords[2]=origin[2]+64.0*Sine(DegToRad(0.0-angles[0]));

    // Flip view cam to point back at player's model.
    angles[1] = angles[1] - 180;

    TeleportEntity(Entity, entcoords, angles, NULL_VECTOR);
}

// ###################### FUNCTIONS ######################


stock KillHatsStuff(client)
{
    Hats_KillHat(client);

    if(g_bViewingHatCam[client])
        Hats_KillViewCam(client);
}

bool:HatFound(const String:hat[])
{
    decl String:temp[PLATFORM_MAX_PATH];
    return (GetTrieString(g_hHatPaths, hat, temp, sizeof(temp)));
}

bool:Hats_GetPath(client, const String:hat_name[], String:path[], maxlength)
{
    decl String:key[PLATFORM_MAX_PATH + 3];
    new team = GetClientTeam(client);

    if (team == TEAM_T)
        Format(key, sizeof(key), hat_name);

    else if (team == TEAM_CT)
        Format(key, sizeof(key), "%s_ct", hat_name);

    else
        return false;

    if (!GetTrieString(g_hHatPaths, key, path, maxlength))
    {
        LogError("Key - %s, Active Attachment - %s", key, hat_name);

        PrintToChat(client,
                    "%s Something messed up setting your attachment to \x03%s",
                    MSG_PREFIX, hat_name);
        return false;
    }

    return CanUseModel(client, path);
}

Hats_AttachHat(client)
{
    if ((!g_bCanUseHats[client] && g_iGame == GAMETYPE_CSS) ||
        !GetArraySize(g_hActiveHats[client]) ||
        g_bClientEquippedItem[client][Item_StealthMode])
        return;

    for (new i = 0; i < GetArraySize(g_hActiveHats[client]); i++)
    {
        decl String:hat_name[LEN_NAMES];
        GetArrayString(g_hActiveHats[client], i, hat_name, sizeof(hat_name));

        if (!IsAuthed(client, hat_name))
        {
            RemoveFromArray(g_hHatSubTypes[client], i);
            RemoveFromArray(g_hActiveHats[client], i--);

            continue;
        }

        decl String:path[PLATFORM_MAX_PATH];
        if (!Hats_GetPath(client, hat_name, path, sizeof(path)))
            continue;

        new hat = CreateEntityByName("prop_dynamic_override");

        if(hat > 0 && IsValidEntity(hat)) 
        {
            PushArrayCell(g_hHatEntities[client], hat);

            decl Float:g_fOrigin[3], Float:g_fAngle[3], String:g_sName[32];
            Format(g_sName, sizeof(g_sName), "PlayerHat_%d", GetClientUserId(client));

            DispatchKeyValue(client, "targetname", g_sName);
            DispatchKeyValue(hat, "parentname", g_sName);
            DispatchKeyValue(hat, "model", path);
            DispatchKeyValue(hat, "Solid", "0");
            DispatchSpawn(hat);

            GetClientAbsOrigin(client, g_fOrigin);
            GetClientAbsAngles(client, g_fAngle);

            decl Float:fwd[3];
            decl Float:right[3];
            decl Float:up[3];

            GetAngleVectors(g_fAngle, fwd, right, up);

            decl String:bone[MAX_NAME_LENGTH];
            decl Float:padd[3];
            decl Float:aadd[3];

            GetTrieString(g_hHatBone, path, bone, sizeof(bone));
            GetTrieArray(g_hHatPosition, path, padd, sizeof(padd));
            GetTrieArray(g_hHatAngles, path, aadd, sizeof(aadd));

            // Hard coding :(
            new team = GetClientTeam(client);
            if (StrEqual(path, "models/Naruto/props/anbumask.mdl") &&
                team == TEAM_T)
                padd[1] -= 0.9;

            else if (StrEqual(path, "models/Naruto/props/oininmask.mdl") &&
                     team == TEAM_T)
                 padd[1] -= 1.0;

            g_fAngle[0] += aadd[0];
            g_fAngle[1] += aadd[1];
            g_fAngle[2] += aadd[2];

            if (g_iGame == GAMETYPE_CSGO)
            {
                if (StrEqual(bone, "hat"))
                {
                    g_fAngle[0] += 180.0;
                    g_fAngle[1] += 180.0;

                    padd[0] += 1.0;
                    g_fAngle[1] += -5.0;

                    if (team == TEAM_CT)
                    {
                        padd[0] += -1.0;
                        padd[1] += 0.75;

                        if (!(g_iServerType & SERVER_CSGOJB))
                            padd[1] += -1.5;
                    }

                    if (StrEqual(path, "models/player/hgitems/hats/moose.mdl"))
                    {
                        padd[0] += -3.0;
                        padd[1] += -1.75;
                        padd[2] += -0.75;
                    }

                    else if (StrEqual(path, "models/player/hgitems/hats/deadmau5.mdl") ||
                             StrEqual(path, "models/player/hgitems/hats/jackinthebox.mdl") ||
                             StrEqual(path, "models/player/hgitems/hats/awsome.mdl") ||
                             StrEqual(path, "models/player/hgitems/hats/pumpkinhead.mdl"))
                    {
                        padd[0] -= 2.5;
                        if (team == TEAM_CT && g_iServerType & SERVER_CSGOJB)
                            padd[0] -= 0.9;
                    }

                    else if (StrEqual(path, "models/player/hgitems/hats/rasta.mdl"))
                    {
                        padd[0] -= 3.0; // + = Backwards
                        padd[1] -= 1.0; // + = Up
                        padd[2] -= 1.5; // + = Left

                        g_fAngle[1] += 20.0; // + = Tilt Down
                    }

                    else if (StrEqual(path, "models/player/hgitems/hats/baseballcap.mdl"))
                    {
                        padd[0] += 1.2;
                        padd[1] += -0.6;

                        if (team == TEAM_T)
                        {
                            padd[0] += -0.4;
                            padd[1] += -0.3;
                        }
                    }

                    else if (StrEqual(path, "models/player/hgitems/hats/potogold.mdl"))
                    {
                    
                    }

                    else if (StrEqual(path, "models/player/hgitems/hats/jester.mdl"))
                    {
                        padd[1] -= 2.0;
                        padd[2] -= 1.0;

                        if (team == TEAM_CT && g_iServerType & SERVER_CSGOJB)
                        {
                            padd[0] += 1.0;
                            padd[1] += 0.7;

                            g_fAngle[1] -= 10.0;
                        }
                    }
                }

                else if (StrEqual(bone, "forward"))
                {
                    g_fAngle[0] += 180.0;
                    g_fAngle[1] += 180.0;

                    /*
                     Seuss
                     KFC Bucket

                     Tophat
                     Witchhat
                     Dunce
                     Fedora
                     */

                    Format(bone, sizeof(bone), "hat");
        
                    g_fAngle[0] += 90.0;

                    padd[0] += 0.0; // backwards (+) forwards (-)
                    padd[1] += 6.0; // up (+) and down (-)
                    padd[2] -= 3.2; // left (+) right (-)

                    g_fAngle[0] += 0.0; // Tilts hat left (+) right (-)
                    g_fAngle[1] -= 10.0; // Tilt head forward (+) backwards (-)

                    if (StrContains(hat_name, "seus", false) != -1)/* ||
                        StrContains(hat_name, "witch", false) != -1 ||
                        StrContains(hat_name, "tophat", false) != -1 ||
                        StrContains(hat_name, "dunce", false) != -1 ||
                        StrContains(hat_name, "fedora", false) != -1)*/
                        padd[2] -= 3.0;
                }

                else if (StrEqual(bone, "pelvis"))
                {
                    g_fAngle[0] += -270.0;

                    if (team == TEAM_T)
                    {
                        Format(bone, sizeof(bone), "eholster");

                        g_fAngle[0] += -54.0;
                        g_fAngle[1] += -2.0;

                        g_fAngle[0] += 45.0;
                        g_fAngle[1] += 90.0;
                        g_fAngle[2] += 135.0;
                    }

                    else
                    {
                        Format(bone, sizeof(bone), "defusekit");

                        g_fAngle[2] += 90.0;
                    }
                }

                else if (StrEqual(bone, "spine"))
                {
                    if (team == TEAM_T)
                    {
                        Format(bone, sizeof(bone), "primary");

                        g_fAngle[1] += 180.0;
                        g_fAngle[2] += 10.0;

                        padd[0] += 7.0;
                        padd[1] += 5.0;

                        if (StrEqual(path, "models/gmod_tower/fairywings.mdl"))
                        {
                            g_fAngle[0] += 10.0;

                            padd[0] += 1.0;
                            padd[1] += -12.5;
                        }
                    }

                    else
                    {
                        Format(bone, sizeof(bone), "Hat2");
                        padd[0] += 2.3;

                        if (!(g_iServerType & SERVER_CSGOJB))
                            padd[0] += 2.5;
                    }
                }
            }

            else
            {
                if (team == TEAM_CT)
                {
                    if (StrEqual(path, "models/player/hgitems/hats/baseballcap.mdl"))
                    {
                        padd[0] += 0.3;
                        padd[1] += 1.6;

                        g_fAngle[1] -= 5.5;
                    }
                }
            }

            g_fOrigin[0] += (padd[0] * right[0]) + (padd[1] * fwd[0]) + (padd[2] * up[0]);
            g_fOrigin[1] += (padd[0] * right[1]) + (padd[1] * fwd[1]) + (padd[2] * up[1]);
            g_fOrigin[2] += (padd[0] * right[2]) + (padd[1] * fwd[2]) + (padd[2] * up[2]);

            TeleportEntity(hat, g_fOrigin, g_fAngle, NULL_VECTOR);

            SetVariantString(g_sName);
            AcceptEntityInput(hat, "SetParent");
            AcceptEntityInput(hat, "TurnOn");

            SetVariantString(bone);

            AcceptEntityInput(hat, "SetParentAttachmentMaintainOffset");

            SDKHook(hat, SDKHook_SetTransmit, Hats_Transmit);
        }
    }
}

Hats_KillHat(client)
{
    if (g_hHatEntities[client] == INVALID_HANDLE)
        return;

    for (new i = 0; i < GetArraySize(g_hHatEntities[client]); i++)
    {
        new hat = GetArrayCell(g_hHatEntities[client], i);

        // Kill hat model if exists.
        if(hat > 0 && IsValidEdict(hat))
        {
            SDKUnhook(hat, SDKHook_SetTransmit, Hats_Transmit);

            decl String:classname[MAX_NAME_LENGTH];
            GetEntityClassname(hat, classname, sizeof(classname));

            if (StrContains(classname, "prop_dynamic") != -1)
            {
                AcceptEntityInput(hat, "ClearParent");
                AcceptEntityInput(hat, "Kill");
            }
        }
    }

    ClearArray(g_hHatEntities[client]);
}

Hats_KillViewCam(client)
{
    // Kill old timers.
    if(g_hViewHatTimer[client] != INVALID_HANDLE)
        CloseHandle(g_hViewHatTimer[client]);
        
    // Kill 360deg hat cam model is exists.
    if(g_iEntityHatCam[client] > 0 && IsValidEdict(g_iEntityHatCam[client]))
    {
        
        decl String:classname[MAX_NAME_LENGTH];
        GetEntityClassname(g_iEntityHatCam[client], classname, sizeof(classname));

        if (StrContains(classname, "prop_dynamic") != -1)
        {
            AcceptEntityInput(g_iEntityHatCam[client], "ClearParent");
            AcceptEntityInput(g_iEntityHatCam[client], "Kill");
        }
    }

    // Set View back to Client Eyes.
    SetClientViewEntity(client, client);

    // Re-enable the radar
    SetEntProp(client, Prop_Send, "m_iHideHUD", 0);

    // Set View back to Firstperson.
    Client_SetObserverTarget(client, -1);
    Client_SetObserverMode(client, OBS_MODE_NONE, false);
    Client_SetDrawViewModel(client, true);
    Client_SetFOV(client, 90);

    // Un freeze player.
    SetEntityMoveType(client, MOVETYPE_WALK);

    g_bViewingHatCam[client] = false;
    g_iEntityHatCam[client] = -1;
}

Hats_ViewHat(Client)
{
    // Precache model
    new String:StrModel[64];
    Format(StrModel, sizeof(StrModel), "models/blackout.mdl");
    PrecacheModel(StrModel, true);

    // Spawn dynamic prop entity
    new Entity = CreateEntityByName("prop_dynamic_override");
    if (Entity == -1)
        return false;

    DispatchKeyValue(Entity, "model",	  StrModel);
    DispatchKeyValue(Entity, "solid",	  "0");
    DispatchKeyValue(Entity, "rendermode", "10"); // dont render
    DispatchKeyValue(Entity, "disableshadows", "1"); // no shadows

    new Float:angles[3];
    GetClientEyeAngles(Client, angles);
    angles[0] = 0.0; // force 0.0 look up/down
    //angles[1] = 0.0;
    angles[2] = 0.0;
    
    g_fViewAngleCam[Client][1] = angles[1];
    
    new Float:origin[3];
    GetClientEyePosition(Client, origin);
    
    new String:CamTargetAngles[64];
    Format(CamTargetAngles, 64, "%f %f %f", angles[0], angles[1], angles[2]);
    DispatchKeyValue(Entity, "angles", CamTargetAngles);
    
    angles[1] = angles[1] - 180;
    
    TeleportEntity(Entity, origin, angles, NULL_VECTOR);

    SetEntityModel(Entity, StrModel);
    DispatchSpawn(Entity);

    SetEntProp(Client, Prop_Send, "m_iHideHUD", (1 << 12));

    AcceptEntityInput(Entity, "TurnOn");
    SetClientViewEntity(Client, Entity);
    
    SetEntityMoveType(Client, MOVETYPE_NONE);
    SetEntityMoveType(Entity, MOVETYPE_NONE);

    Client_SetObserverTarget(Client, 0);
    Client_SetObserverMode(Client, OBS_MODE_DEATHCAM, false);
    Client_SetDrawViewModel(Client, false);
    Client_SetFOV(Client, 90);
    
    g_iEntityHatCam[Client] = Entity;
    g_fOriginHatData[Client] = origin;
    g_bViewingHatCam[Client] = true;

    return true;
}

Hats_MenuHats(client)
{
    decl String:g_sDisplay[128];
    new Handle:g_hMenu = CreateMenu(MenuHandler_HatsMenu);
    Format(g_sDisplay, sizeof(g_sDisplay), "Player Attachments:");
    SetMenuTitle(g_hMenu, g_sDisplay);
    SetMenuExitBackButton(g_hMenu, true);

    Format(g_sDisplay, sizeof(g_sDisplay), "%s Attachment", g_bHatAppear[client] ? "Disable" : "Enable");
    AddMenuItem(g_hMenu, "0", g_sDisplay);
    
    Format(g_sDisplay, sizeof(g_sDisplay), "Select Model");
    AddMenuItem(g_hMenu, "1", g_sDisplay);
    
    Format(g_sDisplay, sizeof(g_sDisplay), "360 Preview [%s]", g_bViewingHatCam[client] ? "On" : "Off");
    AddMenuItem(g_hMenu, "2", g_sDisplay);
    
    DisplayMenu(g_hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_HatsMenu(Handle:menu, MenuAction:action, client, item)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if(g_bViewingHatCam[client])
                Hats_KillViewCam(client);

            if (item == MenuCancel_ExitBack)
                MainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:g_sTemp[32];
            GetMenuItem(menu, item, g_sTemp, sizeof(g_sTemp));
            new g_iTemp = StringToInt(g_sTemp);

            switch(g_iTemp)
            {
                case 0:
                {
                    if(!g_bHatAppear[client])
                    {
                        g_bHatAppear[client] = true;
                        SetClientCookie(client, g_hHatsAppear, "1");

                        if(IsPlayerAlive(client))
                            Hats_AttachHat(client);

                        PrintToChat(client, "%s You've enabled your attachment!", MSG_PREFIX);
                    }
        
                    else
                    {
                        g_bHatAppear[client] = false;
                        SetClientCookie(client, g_hHatsAppear, "0");

                        if(IsPlayerAlive(client))
                            Hats_KillHat(client);

                        PrintToChat(client, "%s You've disabled your attachment!", MSG_PREFIX);
                    }

                    Hats_MenuHats(client);
                }

                case 1:
                    Hats_MenuModels(client, "");

                case 2:
                {
                    if(!g_bViewingHatCam[client])
                    {
                        if(IsClientInGame(client) && IsClientConnected(client) && IsPlayerAlive(client))
                        {
                            if(!(GetEntityFlags(client) & FL_ONGROUND))
                            {
                                PrintToChat(client, "%s Don't Jump! Try preview again.", MSG_PREFIX);
                            }
                            else
                            {
                                Hats_ViewHat(client);
                                PrintToChat(client, "%s 360 Preview On!", MSG_PREFIX);
                            }
                        }
                        else
                            PrintToChat(client, "%s You must be alive to view yourself!", MSG_PREFIX);
                    }
                    else
                    {
                        Hats_KillViewCam(client);
                        PrintToChat(client, "%s 360 Preview Off!", MSG_PREFIX);
                    }

                    // Display menu again.
                    Hats_MenuHats(client);
                }
            }
        }
    }

    return;
}

Hats_MenuModels(client, const String:subtype[], index=0, bool:issubtype=false)
{
    decl String:display[LEN_NAMES + 10];
    Format(g_sHatSubType[client], LEN_NAMES, subtype);

    new Handle:g_hMenu = CreateMenu(MenuHandler_ModelsMenu);
    SetMenuTitle(g_hMenu, "Select Model:");

    SetMenuExitButton(g_hMenu, true);
    SetMenuExitBackButton(g_hMenu, true);

    new bool:found;
    decl String:hat_name[LEN_NAMES];

    new Handle:already_subs = CreateArray(ByteCountToCells(LEN_NAMES));
    g_bHatsWasInSubMenu[client] = issubtype;

    for (new i = 0; i < GetArraySize(g_hPlayerHats[client]); i++)
    {
        GetArrayString(g_hPlayerHats[client], i, hat_name, sizeof(hat_name));

        if (FindStringInArray(g_hActiveHats[client], hat_name) > -1)
            Format(display, sizeof(display), "%s [Active]", hat_name);

        else
            Format(display, sizeof(display), hat_name);

        decl String:sub[LEN_NAMES] = "";
        if (!issubtype)
        {
            if (GetTrieString(g_hItemSubTypes, hat_name, sub, sizeof(sub)))
            {
                if (FindStringInArray(already_subs, sub) > -1)
                    continue;

                AddMenuItem(g_hMenu, sub, sub);
                PushArrayString(already_subs, sub);

                found = true;
                continue;
            }
        }

        else
        {
            decl String:restricted[24];
            decl String:newdisplay[128];

            new drawtype = GetRestrictedPrefix(hat_name, client, restricted, sizeof(restricted));
            Format(newdisplay, sizeof(newdisplay), "%s%s", display, restricted);

            if (subtype[0] == '\0')
            {
                AddMenuItem(g_hMenu, display, newdisplay, drawtype);
                found = true;
            }

            else if (GetTrieString(g_hItemSubTypes, hat_name, sub, sizeof(sub)) &&
                     StrEqual(subtype, sub, false))
            {
                AddMenuItem(g_hMenu, display, newdisplay, drawtype);
                found = true;
            }
        }
    }

    if (!found)
    {
        AddMenuItem(g_hMenu, "", "NO HATS FOUND", ITEMDRAW_DISABLED);
        AddMenuItem(g_hMenu, "", "Keep pressing back", ITEMDRAW_DISABLED);
        AddMenuItem(g_hMenu, "", "Or type !shop", ITEMDRAW_DISABLED);
        AddMenuItem(g_hMenu, "", "To purchase hats", ITEMDRAW_DISABLED);
    }

    DisplayMenuAtItem(g_hMenu, client, index, MENU_TIME_FOREVER);
}

public MenuHandler_ModelsMenu(Handle:menu, MenuAction:action, client, item)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                if (g_bHatsWasInSubMenu[client])
                    Hats_MenuModels(client, "");

                else
                    Hats_MenuHats(client);
            }
        }

        case MenuAction_Select:
        {
            decl String:g_sTemp[LEN_NAMES];
            GetMenuItem(menu, item, g_sTemp, sizeof(g_sTemp));

            decl Handle:hArrayOfShit;
            new g_iTemp = RoundToFloor(float(item / g_iMaxItems)) * g_iMaxItems;

            if (GetTrieValue(g_hSubTypes, g_sTemp, hArrayOfShit))
            {
                Hats_MenuModels(client, g_sTemp, 0, true);
                return;
            }

            // CSGO
            if (!g_bCanUseHats[client] && g_iGame == GAMETYPE_CSS)
            {
                PrintToChat(client,
                            "%s You must select a model before using attachments!",
                            MSG_PREFIX);

                return;
            }

            if ((GetTime() - g_iLastHatChange[client]) < 4)
            {
                PrintToChat(client, "%s You can't change your attachment that quickly!", MSG_PREFIX);
                Hats_MenuModels(client,
                                g_sHatSubType[client],
                                g_iTemp,
                                !StrEqual(g_sHatSubType[client], ""));

                return;
            }

            if (StrContains(g_sTemp, "[Active]") > -1)
            {
                ReplaceString(g_sTemp, sizeof(g_sTemp), " [Active]", "");
                new i = FindStringInArray(g_hActiveHats[client], g_sTemp);

                if (i > -1)
                {
                    RemoveFromArray(g_hHatSubTypes[client], i);
                    RemoveFromArray(g_hActiveHats[client], i);

                }

                if (!GetArraySize(g_hActiveHats[client]))
                    PrintToChat(client, "%s You've disabled your attachment model", MSG_PREFIX);

                else
                    PrintToChat(client, "%s You've disabled your \x03%s\x04 attachment", MSG_PREFIX, g_sTemp);
            }

            else
            {
                decl String:subtype[LEN_NAMES];
                GetTrieString(g_hItemSubTypes, g_sTemp, subtype, sizeof(subtype));

                new already_in = -1;

                if (!g_bClientHasItem[client][Item_MultipleAttachments])
                {
                    PrintToChat(client, "%s Your attachment model is now %s!", MSG_PREFIX, g_sTemp);

                    ClearArray(g_hActiveHats[client]);
                    ClearArray(g_hHatSubTypes[client]);
                }

                else if ((already_in = FindStringInArray(g_hHatSubTypes[client], subtype)) > -1)
                {
                    PrintToChat(client,
                                "%s You already have a \x03%s\x04 attachment",
                                MSG_PREFIX, subtype);

                    PrintToChat(client,
                                "%s Replacing your last set \x03%s\x04 attachment with \x03%s",
                                MSG_PREFIX, subtype, g_sTemp);

                    
                    RemoveFromArray(g_hHatSubTypes[client], already_in);
                    RemoveFromArray(g_hActiveHats[client], already_in);
                }

                else if ((FindStringInArray(g_hHatSubTypes[client], "Masks") > -1 && StrEqual(subtype, "Glasses")) ||
                         (FindStringInArray(g_hHatSubTypes[client], "Glasses") > -1 && StrEqual(subtype, "Masks")))
                {
                    Hats_MenuModels(client,
                                    g_sHatSubType[client],
                                    g_iTemp,
                                    !StrEqual(g_sHatSubType[client], ""));

                    PrintToChat(client, "%s Who wears glasses on a mask?", MSG_PREFIX);
                    return;
                }

                else if (GetArraySize(g_hActiveHats[client]) == MAX_ATTACHMENTS)
                {
                    PrintToChat(client,
                                "%s You have reached your maximum number of attachments (\x03%d\x04)",
                                MSG_PREFIX, MAX_ATTACHMENTS);

                    PrintToChat(client,
                                "%s Replacing your last set attachment with \x03%s",
                                MSG_PREFIX, g_sTemp);

                    RemoveFromArray(g_hHatSubTypes[client], MAX_ATTACHMENTS - 1);
                    RemoveFromArray(g_hActiveHats[client], MAX_ATTACHMENTS - 1);
                }

                else
                    PrintToChat(client, "%s You have added \x03%s\x04 to your list of attachments", MSG_PREFIX, g_sTemp);

                PushArrayString(g_hHatSubTypes[client], subtype);
                PushArrayString(g_hActiveHats[client], g_sTemp);

                g_bHatAppear[client] = true;
                SetClientCookie(client, g_hHatsAppear, "1");
            }

            new String:cookie[LEN_NAMES];

            for (new i = 0; i < GetArraySize(g_hActiveHats[client]); i++)
            {
                decl String:temp[LEN_NAMES];
                GetArrayString(g_hActiveHats[client], i, temp, sizeof(temp));

                if (i > 0)
                    StrCat(cookie, sizeof(cookie), "|");
                StrCat(cookie, sizeof(cookie), temp);
            }

            SetClientCookie(client, g_hActiveHat, cookie);

            if(IsPlayerAlive(client))
            {
                g_iLastHatChange[client] = GetTime();

                Hats_KillHat(client);

                if (g_bHatAppear[client])
                    Hats_AttachHat(client);
            }

            Hats_MenuModels(client,
                            g_sHatSubType[client],
                            g_iTemp,
                            !StrEqual(g_sHatSubType[client], ""));
        }
    }

    return;
}

stock Hats_LoadHats()
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT name, filepath, filepath_ct, hat_angles, hat_position, hat_bone FROM items WHERE (type = %d) and (servertype & %d) and (servertype > 0)",
           ITEMTYPE_HAT, g_iServerType);

    SQL_TQuery(g_hDbConn, LoadHatsCallback, query);
}

stock Client_SetObserverTarget(client, entity, bool:resetFOV=true)
{
    SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", entity);
    if (resetFOV) {
        Client_SetFOV(client, 0);
    }
}

stock Client_SetDrawViewModel(client, bool:drawViewModel)
{
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", drawViewModel);
}

stock Client_SetFOV(client, value)
{
	SetEntProp(client, Prop_Send, "m_iFOV", value);
}

stock Client_GetObserverMode(client)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode");
}

stock Client_SetObserverLastMode(client, any:mode)
{
	SetEntProp(client, Prop_Data, "m_iObserverLastMode", _:mode);
}

stock Client_SetViewOffset(client, Float:vec[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecViewOffset", vec);
}

stock bool:Client_SetObserverMode(client, any:mode, bool:updateMoveType=true)
{
    if (mode < OBS_MODE_NONE || mode >= NUM_OBSERVER_MODES) {
        return false;
    }
    
    // check mp_forcecamera settings for dead players
    if (mode > OBS_MODE_FIXED && GetClientTeam(client) > TEAM_SPEC)
    {
        new Handle:mp_forcecamera = FindConVar("mp_forcecamera");

        if (mp_forcecamera != INVALID_HANDLE) {
            switch (GetConVarInt(mp_forcecamera))
            {
                case OBS_ALLOW_TEAM: {
                    mode = OBS_MODE_IN_EYE;
                }
                case OBS_ALLOW_NONE: {
                    mode = OBS_MODE_FIXED; // don't allow anything
                }
            }
        }
    }

    new observerMode = Client_GetObserverMode(client);
    if (observerMode > OBS_MODE_DEATHCAM) {
        // remember mode if we were really spectating before
        Client_SetObserverLastMode(client, observerMode);
    }

    SetEntProp(client, Prop_Send, "m_iObserverMode", _:mode);

    switch (mode) {
        case OBS_MODE_NONE, OBS_MODE_FIXED, OBS_MODE_DEATHCAM: {
            Client_SetFOV(client, 0);	// Reset FOV

            if (updateMoveType) {
                SetEntityMoveType(client, MOVETYPE_NONE);
            }
        }

        case OBS_MODE_CHASE, OBS_MODE_IN_EYE: {
            // udpate FOV and viewmodels
            Client_SetViewOffset(client, NULL_VECTOR);
            
            if (updateMoveType) {
                SetEntityMoveType(client, MOVETYPE_OBSERVER);
            }
        }

        case OBS_MODE_ROAMING: {
            SetEntPropFloat(client, Prop_Send, "m_flFlashDuration", 3600.0);
            SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.5);

            Client_SetFOV(client, 0);	// Reset FOV
            Client_SetViewOffset(client, NULL_VECTOR);
            
            if (updateMoveType) {
                SetEntityMoveType(client, MOVETYPE_OBSERVER);
            }
        }
    }

    return true;
}


// ###################### CALLBACKS ######################


public LoadHatsCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    decl String:name[LEN_NAMES];
    decl String:filepath[PLATFORM_MAX_PATH];
    decl String:filepath_ct[PLATFORM_MAX_PATH];
    decl String:key[PLATFORM_MAX_PATH + 3];
    decl String:sAngles[64];
    decl String:sPosition[64];
    decl String:sTemp[3][8];
    decl String:bone[MAX_NAME_LENGTH];

    decl Float:fAngles[3];
    decl Float:fPosition[3];

    ClearTrie(g_hHatPaths);

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 1, filepath, sizeof(filepath));
        SQL_FetchString(hndl, 2, filepath_ct, sizeof(filepath_ct));
        SQL_FetchString(hndl, 3, sAngles, sizeof(sAngles));
        SQL_FetchString(hndl, 4, sPosition, sizeof(sPosition));
        SQL_FetchString(hndl, 5, bone, sizeof(bone));

        SetTrieString(g_hHatPaths, name, filepath);
        Format(key, sizeof(key), "%s_ct", name);

        SetTrieString(g_hHatBone, filepath, bone);
        SetTrieString(g_hHatBone, filepath_ct, bone);

        if (ExplodeString(sAngles, " ", sTemp, 3, 8) >= 3)
        {
            fAngles[0] = StringToFloat(sTemp[0]);
            fAngles[1] = StringToFloat(sTemp[1]);
            fAngles[2] = StringToFloat(sTemp[2]);

            SetTrieArray(g_hHatAngles, filepath, fAngles, 3);
            SetTrieArray(g_hHatAngles, filepath_ct, fAngles, 3);
        }

        else
        {
            SetTrieArray(g_hHatAngles, filepath, NULL_VECTOR, 3);
            SetTrieArray(g_hHatAngles, filepath_ct, NULL_VECTOR, 3);
        }

        if (ExplodeString(sPosition, " ", sTemp, 3, 8) >= 3)
        {
            fPosition[0] = StringToFloat(sTemp[0]);
            fPosition[1] = StringToFloat(sTemp[1]);
            fPosition[2] = StringToFloat(sTemp[2]);

            SetTrieArray(g_hHatPosition, filepath, fPosition, 3);
            SetTrieArray(g_hHatPosition, filepath_ct, fPosition, 3);
        }

        else
        {
            SetTrieArray(g_hHatPosition, filepath, NULL_VECTOR, 3);
            SetTrieArray(g_hHatPosition, filepath_ct, NULL_VECTOR, 3);
        }

        if (!StrEqual(filepath_ct, ""))
            SetTrieString(g_hHatPaths, key, filepath_ct);

        else
            SetTrieString(g_hHatPaths, key, filepath);
    }
}
