// To do:
//  Spawn protection (make better, with effects possibly)
//  Knife sounds still play on spawn?
//  find out if we can remove env_blood on team attacks
//  In CS:GO, when a player is pressing the tab button (OnPlayerRunCmd?) display a hint message somewhere on the screen that displays the actual number of alive Ts and CTs
//  Add a kill feed

// dm debug
// these should be CVars
#define DM_RESPAWN_TIME 0.33
#define SPAWNPROTECTION_TIME 1.0

new g_WeaponParent = -1;

new bool:g_bScoreBoardHooked = false;
new bool:g_bDeadDM[MAXPLAYERS + 1];
new g_iLastTeamChange[MAXPLAYERS + 1];
new Float:g_fDMSpawned[MAXPLAYERS + 1];

new String:g_sPathDMSpawns[PLATFORM_MAX_PATH];

new Handle:g_hDMSpawnPoints = INVALID_HANDLE;
new Handle:mp_friendlyfire = INVALID_HANDLE;
new Handle:mp_tkpunish = INVALID_HANDLE;
new Handle:ff_damage_reduction_bullets = INVALID_HANDLE;
new Handle:ff_damage_reduction_grenade = INVALID_HANDLE;
new Handle:ff_damage_reduction_grenade_self = INVALID_HANDLE;
new Handle:ff_damage_reduction_other = INVALID_HANDLE;

/* ----- Events ----- */

stock DM_OnPluginStart()
{
    // so far only enabled on CS:S and CS:GO
    if (g_iGame == GAMETYPE_TF2)
        return;

    g_hDMSpawnPoints = CreateArray(4);

    g_WeaponParent = FindSendPropOffs("CBaseCombatWeapon", "m_hOwnerEntity");

    RegAdminCmd("sm_addspawn", Command_AddSpawn, ADMFLAG_ROOT);

    HookEvent("player_death", DM_OnPlayerDeath_Pre, EventHookMode_Pre);
    BuildPath(Path_SM, g_sPathDMSpawns, sizeof(g_sPathDMSpawns), "data/dmspawns.txt");

    GenerateSpawnPoints();

    if (!HookScoreBoard())
    {
        ServerCommand("sm exts load sendproxy.ext.2.ep2v.so");
    }

    // FFA Deathmatch
    mp_friendlyfire = FindConVar("mp_friendlyfire");
    mp_tkpunish = FindConVar("mp_tkpunish");
    ff_damage_reduction_bullets = FindConVar("ff_damage_reduction_bullets");
    ff_damage_reduction_grenade = FindConVar("ff_damage_reduction_grenade");
    ff_damage_reduction_grenade_self = FindConVar("ff_damage_reduction_grenade_self");
    ff_damage_reduction_other = FindConVar("ff_damage_reduction_other");

    HookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);
    HookUserMessage(GetUserMessageId("HintText"), Hook_HintText, true);

    if (mp_friendlyfire != INVALID_HANDLE)
    {
        SetConVarBool(mp_friendlyfire, true);
        HookConVarChange(mp_friendlyfire, DM_OnConVarChanged);
    }

    if (mp_tkpunish != INVALID_HANDLE)
    {
        SetConVarBool(mp_tkpunish, false);
        HookConVarChange(mp_tkpunish, DM_OnConVarChanged);
    }

    if (ff_damage_reduction_bullets != INVALID_HANDLE)
    {
        SetConVarFloat(ff_damage_reduction_bullets, 1.0);
        HookConVarChange(ff_damage_reduction_bullets, DM_OnConVarChanged);
    }

    if (ff_damage_reduction_grenade != INVALID_HANDLE)
    {
        SetConVarFloat(ff_damage_reduction_grenade, 1.0);
        HookConVarChange(ff_damage_reduction_grenade, DM_OnConVarChanged);
    }

    if (ff_damage_reduction_grenade_self != INVALID_HANDLE)
    {
        SetConVarFloat(ff_damage_reduction_grenade_self, 1.0);
        HookConVarChange(ff_damage_reduction_grenade_self, DM_OnConVarChanged);
    }

    if (ff_damage_reduction_other != INVALID_HANDLE)
    {
        SetConVarFloat(ff_damage_reduction_other, 1.0);
        HookConVarChange(ff_damage_reduction_other, DM_OnConVarChanged);
    }

    CreateTimer(3.0, Timer_RemoveDMWeapons, _, TIMER_REPEAT);
}

public DM_OnConVarChanged(Handle:cvar, const String:oldv[], const String:newv[])
{
    if (cvar == mp_friendlyfire && GetConVarBool(mp_friendlyfire) == false)
    {
        SetConVarBool(mp_friendlyfire, true);
    }

    else if (cvar == mp_tkpunish && GetConVarBool(mp_tkpunish) == true)
    {
        SetConVarBool(mp_tkpunish, false);
    }

    else if (cvar == ff_damage_reduction_bullets && GetConVarFloat(ff_damage_reduction_bullets) != 1.0)
    {
        SetConVarFloat(ff_damage_reduction_bullets, 1.0);
    }

    else if (cvar == ff_damage_reduction_grenade && GetConVarFloat(ff_damage_reduction_grenade) != 1.0)
    {
        SetConVarFloat(ff_damage_reduction_grenade, 1.0);
    }

    else if (cvar == ff_damage_reduction_grenade_self && GetConVarFloat(ff_damage_reduction_grenade_self) != 1.0)
    {
        SetConVarFloat(ff_damage_reduction_grenade_self, 1.0);
    }

    else if (cvar == ff_damage_reduction_other && GetConVarFloat(ff_damage_reduction_other) != 1.0)
    {
        SetConVarFloat(ff_damage_reduction_other, 1.0);
    }
}

stock DM_OnClientPutInServer(client)
{
    g_bDeadDM[client] = false;
    g_iLastTeamChange[client] = 0;
}

stock DM_OnClientDisconnect(client)
{
    g_bDeadDM[client] = false;
}

stock DM_OnRoundStart()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        g_bDeadDM[i] = false;
    }
}

stock DM_OnPlayerRespawned(client)
{
    g_bDeadDM[client] = false;
}

stock DM_OnPlayerSpawn(client)
{
    // debug dm
    // DM check has already been done at this point
    if (client > 0 && IsClientInGame(client))
    {
        decl Float:telecoords[4];
        decl Float:origin[3];
        new Float:angles[3];
        new index = GetRandomInt(0, GetArraySize(g_hDMSpawnPoints) - 1);

        GetArrayArray(g_hDMSpawnPoints, index, telecoords, sizeof(telecoords));

        origin[0] = telecoords[0];
        origin[1] = telecoords[1];
        origin[2] = telecoords[2];
        angles[1] = telecoords[3];

        TeleportEntity(client, origin, angles, NULL_VECTOR);

        // debug dm
        // Give them spawn protection?
    }
}

stock DM_OnPlayerDeath_Post(victim, bool:killed)
{
    // Respawn them, if they have DM enabled
    if (IsClientCookieFlagSet(victim, COOKIE_DEAD_DM_ENABLED) || IsFakeClient(victim))
    {
        // Prevent people from just killing themselves willy nilly
        // debug dm
        if (killed || 1 > 0)
        {
            g_bDeadDM[victim] = true;
            CreateTimer(DM_RESPAWN_TIME, Timer_RespawnDM, GetClientUserId(victim));
        }

        else
        {
            DisplayMSay(victim, "No Death Match This Round", 30, "You will only spawn into deathmatch\n   if someone else kills you\nYou will be eligible again next round");
        }
    }

    else
    {
        g_bDeadDM[victim] = false;
    }

    DM_CheckRoundEnd();
}

stock DM_OnPlayerTeamPost(client)
{
    if (!IsPlayerAlive(client) && GetTime() - g_iLastTeamChange[client] > 360.0)
    {
        g_iLastTeamChange[client] = GetTime();
        DM_OnPlayerDeath_Post(client, true);
    }
}

public Action:DM_OnPlayerDeath_Pre(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    if (client <= 0)
        return Plugin_Continue;

    // Block the kill feed, prevent score from increasing.
    if (g_bDeadDM[client])
    {
        SetEventBroadcast(event, true);
        SetEntProp(client, Prop_Data, "m_iDeaths", GetEntProp(client, Prop_Data, "m_iDeaths") - 1);

        if (attacker > 0)
        {
            new add = GetClientTeam(attacker) == GetClientTeam(client) ? 2 : 0;
            SetEntProp(attacker, Prop_Data, "m_iFrags", GetEntProp(attacker, Prop_Data, "m_iFrags") - 1 + add);
        }

        // Suicides subtract a score
        else
        {
            SetEntProp(client, Prop_Data, "m_iFrags", GetEntProp(attacker, Prop_Data, "m_iFrags") + 1);
        }
    }

    return Plugin_Continue;
}

public DM_ScoreOnThinkPost(entity)
{
    decl isAlive[65]; 
    GetEntDataArray(entity, m_bAlive, isAlive, 65); 

    for (new i = 1; i <= MaxClients; ++i) 
    { 
        if (g_bDeadDM[i] && IsClientInGame(i)) 
        { 
            isAlive[i] = false;
        } 
    }

    SetEntDataArray(entity, m_bAlive, isAlive, 65); 
}

public Action:Proxy_LifeState(entity, const String:propname[], &iValue, client)
{
    if (client > 0 && client <= MaxClients && g_bDeadDM[client])
    {
        iValue = 0;
        return Plugin_Changed;
    }

    return Plugin_Continue;
}

// Credits to GoD-Tony
public Action:Hook_TextMsg(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
    /* Block team-attack messages from being shown to players. */ 
    decl String:message[256];

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available &&
        GetUserMessageType() == UM_Protobuf)
    {
        PbReadString(bf, "params", message, sizeof(message), 0);
    }

    else
    {
        BfReadString(bf, message, sizeof(message));
    }

    if (StrContains(message, "teammate_attack") != -1)
        return Plugin_Handled;

    if (StrContains(message, "Killed_Teammate") != -1)
        return Plugin_Handled;
        
    return Plugin_Continue;
}

// Credits to GoD-Tony
public Action:Hook_HintText(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
    /* Block team-attack "tutorial" messages from being shown to players. */ 
    decl String:message[256];

    if (GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available &&
        GetUserMessageType() == UM_Protobuf)
    {
        PbReadString(bf, "text", message, sizeof(message));
    }

    else
    {
        BfReadString(bf, message, sizeof(message));
    }

    if (StrContains(message, "spotted_a_friend") != -1)
        return Plugin_Handled;

    if (StrContains(message, "careful_around_teammates") != -1)
        return Plugin_Handled;
    
    if (StrContains(message, "try_not_to_injure_teammates") != -1)
        return Plugin_Handled;
        
    return Plugin_Continue;
}

Action:DM_OnTakeDamage(victim, attacker, &Float:damage)
{
    if (attacker > 0 && attacker <= MaxClients)
    {
        // Under normal circumstances should never happen
        // But just in case someone finds a way to abuse the system
        if (g_bDeadDM[attacker] && !g_bDeadDM[victim])
        {
            PrintToChat(attacker, "%s Insert funny, and slightly sarcastic message here.", MSG_PREFIX);
            CreateTimer(0.01, DelaySlay, attacker);

            return Plugin_Handled;
        }

        // Spawn Protection
        // dm debug
        // this should be a cvar, also probably should have different color when in spawn protection
        if (g_bDeadDM[victim] && GetEngineTime() - g_fDMSpawned[victim] <= SPAWNPROTECTION_TIME)
            return Plugin_Handled;

        // FFA
        if (GetClientTeam(victim) == GetClientTeam(attacker))
        {
            if (!g_bDeadDM[attacker] || !g_bDeadDM[victim])
                return Plugin_Stop;

            // For CS:S it's hard coded to do less damage
            if (g_iGame == GAMETYPE_CSS)
            {
                damage /= 0.35;
                return Plugin_Changed;
            }
        }
    }

    return Plugin_Continue;
}

/* ----- Commands ----- */

public Action:Command_AddSpawn(client, args)
{
    decl Float:origin[3];
    decl Float:ang[3];

    GetClientAbsOrigin(client, origin);
    GetClientEyeAngles(client, ang);

    new Handle:iFile = OpenFile(g_sPathDMSpawns, "a");

    if (iFile == INVALID_HANDLE)
    {
        PrintToChat(client, "No data  file found under ./addons/sourcemod/data/dmspawns.txt");
        return Plugin_Handled;
    }

    WriteFileLine(iFile, "%.2f,%.2f,%.2f,%.2f", origin[0], origin[1], origin[2], ang[1]);
    CloseHandle(iFile);

    PrintToChat(client, "%s Spawn point added", MSG_PREFIX);
    return Plugin_Handled;
}

/* ----- Functions ----- */

stock DM_Cleanup()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && g_bDeadDM[i])
        {
            g_bDeadDM[i] = false;
            ForcePlayerSuicide(i);
        }
    }
}

/**
 * Since the "dead" players are still technically alive
 * The round won't end unless they're all dead.
 */
stock DM_CheckRoundEnd()
{
    if (!g_bHasRoundStarted)
        return;

    new realAliveTs;
    new realAliveCTs;
    new dmAliveTs;
    new dmAliveCTs;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        new team = GetClientTeam(i);

        if (team == TEAM_PRISONERS)
        {
            if (JB_IsPlayerAlive(i))
            {
                realAliveTs++;
            }

            else if (IsPlayerAlive(i)) // Don't use JB_IsPlayerAlive
            {
                dmAliveTs++;
            }
        }

        else if (team == TEAM_GUARDS)
        {
            if (JB_IsPlayerAlive(i))
            {
                realAliveCTs++;
            }

            else if (IsPlayerAlive(i)) // Don't use JB_IsPlayerAlive
            {
                dmAliveCTs++;
            }
        }
    }

    // Don't end the round if someone did !slay @t, !slay @ct, or !slay @all.
    // At this condition, the round will end naturally.
    if ((dmAliveTs == 0 && realAliveTs == 0) ||
        (dmAliveCTs == 0 && realAliveCTs == 0))
        return;

    // Could happen, I guess.
    if (realAliveTs == 0 && realAliveCTs == 0)
    {
        CS_TerminateRound(3.0, CSRoundEnd_Draw);
    }

    else if (realAliveTs == 0)
    {
        CS_TerminateRound(3.0, CSRoundEnd_CTWin);
    }

    else if (realAliveCTs == 0)
    {
        CS_TerminateRound(3.0, CSRoundEnd_TerroristWin);
    }
}

bool:HookScoreBoard()
{
    if (g_bScoreBoardHooked)
        return true;

    // debug dm
    if (m_bAlive > -1)
    {
        new manager = FindEntityByClassname(-1, "cs_player_manager");

        if (manager > -1)
        {
            SDKHook(manager, SDKHook_ThinkPost, DM_ScoreOnThinkPost);
            g_bScoreBoardHooked = true;
        }
    }

    /*
    if (GetFeatureStatus(FeatureType_Native, "SendProxy_HookArrayProp") == FeatureStatus_Available && 
        !g_bScoreBoardHooked)
    {
        new manager = FindEntityByClassname(-1, "cs_player_manager");

        if (manager > -1)
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                SendProxy_HookArrayProp(manager, "m_bAlive", i, Prop_Int, Proxy_LifeState);
            }

            g_bScoreBoardHooked = true;
        }

        return true;
    }*/

    return false;
}

stock GenerateSpawnPoints()
{
    new Handle:oFile = OpenFile(g_sPathDMSpawns, "r");

    if (oFile == INVALID_HANDLE)
    {
        SetFailState("No data  file found under ./addons/sourcemod/data/dmspawns.txt");
        return;
    }

    while (!IsEndOfFile(oFile))
    {
        decl String:line[255];
        if (!ReadFileLine(oFile, line, sizeof(line)))
            break;

        if (strncmp(line, "//", 2) == 0)
            continue;

        ReplaceString(line, sizeof(line), " ", "");

        if (StrEqual(line, ""))
            continue;

        // pos[3] == Horizontal Angle
        decl String:sPos[4][LEN_INTSTRING];
        decl Float:pos[4];

        if (ExplodeString(line, ",", sPos, sizeof(sPos), sizeof(sPos[])) != 4)
            continue;

        pos[0] = StringToFloat(sPos[0]);
        pos[1] = StringToFloat(sPos[1]);
        pos[2] = StringToFloat(sPos[2]);
        pos[3] = StringToFloat(sPos[3]);

        PushArrayArray(g_hDMSpawnPoints, pos, sizeof(pos));
    }
}

public Native_JB_IsPlayerAlive(Handle:plugin, args)
{
    new client = GetNativeCell(1);

    if (!IsPlayerAlive(client) || g_bDeadDM[client])
        return false;

    return true;
}

/* ----- Callbacks ----- */

public Action:Timer_RemoveDMWeapons(Handle:timer, any:data)
{
    // By Kigen (c) 2008 - Please give me credit. :)
    new maxent = GetMaxEntities(), String:weapon[64];
    for (new i=GetMaxClients();i<maxent;i++)
    {
        if ( IsValidEdict(i) && IsValidEntity(i) )
        {
            GetEdictClassname(i, weapon, sizeof(weapon));
            if ( (( StrContains(weapon, "weapon_") != -1 || StrContains(weapon, "item_") != -1 ) && GetEntDataEnt2(i, g_WeaponParent) == -1) || StrEqual(weapon, "cs_ragdoll") )
            {
                decl Float:origin[3];
                GetEntPropVector(i, Prop_Send, "m_vecOrigin", origin);

                // Hard coded :(
                // Oh well, easier.
                if (origin[2] < -1500.0)
                {
                    RemoveEdict(i);
                }
            }
        }
    }

    return Plugin_Continue;
}

public Action:Timer_RespawnDM(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client <= 0 || !g_bHasRoundStarted || !g_bDeadDM[client])
        return;

    if (!IsPlayerAlive(client) && GetClientTeam(client) >= TEAM_PRISONERS)  
    {
        g_fDMSpawned[client] = GetEngineTime();
        RespawnPlayer(client, true);

        PrintToChat(client, "%s You are in \x03Dead DeathMatch\x04 type \x03guns\x04 in chat to change your weapon", MSG_PREFIX);
        PrintToChat(client, "%s in \x03Dead DeathMatch\x04, you do not interact with those playing jailbreak.", MSG_PREFIX);
    }
}
