
new g_iRoundTimerEntity = -1;
new g_iLastActionTaunt[MAXPLAYERS + 1];

new Handle:g_hHudSync = INVALID_HANDLE;
new Handle:g_hRoundTime = INVALID_HANDLE;
new Handle:g_fnGetMaxHealth = INVALID_HANDLE;

new bool:g_bIsSettingProperAmmo[MAXPLAYERS + 1];
new bool:g_bFakeUse[MAXPLAYERS + 1];

new Float:g_fThrowTime[MAXPLAYERS + 1];

/* ----- Cache Data ----- */


new TFClassType:g_iCacheClass[MAXPLAYERS + 1];
new String:g_sCacheWeapon[MAXPLAYERS + 1][3][48];

new g_iCacheHealth[MAXPLAYERS + 1];
new g_iCacheItemIndex[MAXPLAYERS + 1][3];
new g_iCacheAmmo[MAXPLAYERS + 1][3];
new g_iCacheClip[MAXPLAYERS + 1][3];
new g_iCacheMaxPrimaryClip[MAXPLAYERS + 1];
new g_iCacheMaxPrimaryAmmo[MAXPLAYERS + 1];
new g_iCacheMaxSecondaryClip[MAXPLAYERS + 1];
new g_iCacheMaxSecondaryAmmo[MAXPLAYERS + 1];


/* ----- Events ----- */


stock TF2_OnPluginStart()
{
    AddCommandListener(Command_Taunt, "taunt");
    AddCommandListener(Command_Taunt, "+taunt");
    AddCommandListener(Command_ActionTaunt, "+use_action_slot_item_server");
    AddCommandListener(Command_ActionTaunt, "use_action_slot_item_server");
    AddCommandListener(Command_VoiceMenu, "voicemenu");

    RegConsoleCmd("medic", Command_SpoofMedic);
    RegConsoleCmd("aio_strip_meh", Command_StripMeh);

    g_hAmmoPackPercentage = CreateTrie();
    g_hAmmoPackType = CreateTrie();
    g_hHudSync = CreateHudSynchronizer();

    HookEvent("arena_round_start", TF2_ArenaRoundStart);
    HookEvent("item_found", TF2_OnItemFound, EventHookMode_Pre);
    HookEvent("object_deflected", TF2_OnObjectDeflected);

    AddNormalSoundHook(TF2_OnSoundPlayed);

    CreateTimer(0.333, Timer_CheckWeapons, _, TIMER_REPEAT);

    new Handle:hFile = LoadGameConfigFile("sdkhooks.games");

    if (hFile == INVALID_HANDLE)
        SetFailState("Cannot find sdkhooks.games gamedata");

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(hFile, SDKConf_Virtual, "GetMaxHealth");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_fnGetMaxHealth = EndPrepSDKCall();

    if(g_fnGetMaxHealth == INVALID_HANDLE)
        SetFailState("Failed to set up GetMaxHealth sdkcall");

    CloseHandle(hFile);
}

stock TF2_OnMapStart()
{
    PrecacheModel("models/player/hgmodels/scout.mdl", true);
    PrecacheModel("models/player/hgmodels/soldier.mdl", true);
    PrecacheModel("models/player/hgmodels/demo.mdl", true);
    PrecacheModel("models/player/hgmodels/heavy.mdl", true);
    PrecacheModel("models/player/hgmodels/pyro.mdl", true);
    PrecacheModel("models/player/hgmodels/sniper.mdl", true);
    PrecacheModel("models/weapons/w_models/w_shotgun.mdl", true);
}


stock TF2_OnRoundStart()
{
    ClearTrie(g_hAmmoPackPercentage);
    ClearTrie(g_hAmmoPackType);
}

stock TF2_OnRoundEnd()
{
    ClearTrie(g_hAmmoPackPercentage);
    ClearTrie(g_hAmmoPackType);

    if (g_hRoundTime != INVALID_HANDLE)
    {
        CloseHandle(g_hRoundTime);
        g_hRoundTime = INVALID_HANDLE;
    }
}

public Action:TF2_OnItemFound(Handle:event, const String:item[], bool:dontBroadcast)
{
    return Plugin_Handled;
}

public Action:TF2_OnObjectDeflected(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new deflected = GetEventInt(event, "object_entindex");

    if (client > 0 &&
        deflected > 0 &&
        deflected <= MaxClients &&
        GetClientTeam(client) != GetClientTeam(deflected) &&
        JB_IsPlayerAlive(deflected))
    {
        MakeRebel(client);
    }
}

public Action:TF2_ArenaRoundStart(Handle:event, const String:name[], bool:db)
{
    g_bHasRoundStarted = true;
    g_bHasRoundKindaStarted = true;

    if (g_hRoundTime != INVALID_HANDLE)
        CloseHandle(g_hRoundTime);

    g_iRoundTimerEntity = -1;
    g_hRoundTime = CreateTimer(0.05, Timer_ShowTime, GetConVarInt(FindConVar("tf_arena_round_time")));
}

public Action:TF2_OnPlayerSpawn(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);

    g_bHasUber[client] = false;
    g_bHasKritz[client] = false;

    if (client <= 0)
        return Plugin_Handled;

    if (!JB_IsPlayerAlive(client))
        return Plugin_Handled;

    SetEntData(client, m_flModelScale, 1.0);
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1);
    //SetEntProp(client, Prop_Send, "m_CollisionGroup", 2);

    new primary = GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY);
    new secondary = GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY);
    new melee = GetPlayerWeaponSlot(client, WEPSLOT_KNIFE);
    new team = GetClientTeam(client);
    new melee_itemindex = GetEntProp(melee, Prop_Send, "m_iItemDefinitionIndex");

    if (melee_itemindex == TF2_CABER && !g_bHasBomb[client])
    {
        PrintToChat(client, "%s You may not set your melee to the \x03The Ullapool Caber\x04...", MSG_PREFIX);
        TF2_GivePlayerWeapon(client, "tf_weapon_bottle", TF2_BOTTLE, WEPSLOT_KNIFE);
    }

    else if (melee_itemindex == TF2_WRAPASSASSIN)
    {
        PrintToChat(client, "%s You may not set your melee to \x03The Wrap Assassin\x04...", MSG_PREFIX);
        TF2_GivePlayerWeapon(client, "tf_weapon_bat", TF2_BAT, WEPSLOT_KNIFE);
    }

    if (primary > 0)
    {
        g_iMaxPrimaryAmmo[client] = GetWeaponAmmo(primary, client);
        g_iMaxPrimaryClip[client] = GetWeaponClip(primary);

        if (team == TEAM_PRISONERS)
            StripWeaponAmmo(client, primary, WEPSLOT_PRIMARY);
    }

    if (secondary > 0)
    {
        g_iMaxSecondaryAmmo[client] = GetWeaponAmmo(secondary, client);
        g_iMaxSecondaryClip[client] = GetWeaponClip(secondary);

        if (team == TEAM_PRISONERS)
            StripWeaponAmmo(client, secondary, WEPSLOT_SECONDARY);
    }

    TF2_SetProperModel(client);

    if (team == TEAM_PRISONERS &&
        TF2_GetPlayerClass(client) == TFClass_Scout)
        g_fPlayerSpeed[client] -= 40.0;

    if (team == TEAM_GUARDS)
    {
        if (g_iMaxPrimaryAmmo[client] > 0)
            g_iMaxPrimaryAmmo[client] *= 2;

        if (g_iMaxSecondaryAmmo[client] > 0)
            g_iMaxSecondaryAmmo[client] *= 2;

        SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY), client, -1, g_iMaxPrimaryAmmo[client]);
        SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY), client, -1, g_iMaxSecondaryAmmo[client]);
    }

    return Plugin_Handled;
}

stock TF2_OnPlayerRunCmd(client, &buttons)
{
    if (g_bFakeUse[client] && JB_IsPlayerAlive(client))
    {
        g_bFakeUse[client] = false;
        buttons |= IN_USE;
    }
}

public AmmoPack_OnPlayerTouch(const String:output[], entity, client, Float:delay)
{
    AcceptEntityInput(entity, "kill");
}

public AmmoPack_GiveFullAmmo(const String:output[], entity, client, Float:delay)
{
    if (client > 0 &&
        client <= MaxClients &&
        IsClientInGame(client) &&
        JB_IsPlayerAlive(client))
        TF2_GiveFullAmmo(client);
}

public Action:OnAmmoPickup(packid, client)
{
    if (client <= 0 || client > MaxClients)
        return Plugin_Handled;

    if ((GetGameTime() - g_fThrowTime[client]) <= 1.0 ||
        g_bIsSettingProperAmmo[client])
        return Plugin_Handled;

    if (OnWeaponCanUse(client, packid) != Plugin_Continue)
        return Plugin_Handled;

    new Float:percentage;
    new slot;

    decl String:sAmmo[8];
    IntToString(packid, sAmmo, sizeof(sAmmo));

    GetTrieValue(g_hAmmoPackPercentage, sAmmo, percentage);
    GetTrieValue(g_hAmmoPackType, sAmmo, slot);

    new wepid = GetPlayerWeaponSlot(client, slot);

    if (wepid <= 0)
        return Plugin_Handled;

    new ammo = GetWeaponAmmo(wepid, client);
    new clip = GetWeaponClip(wepid);
    new maxbullets;

    if (slot == WEPSLOT_PRIMARY)
        maxbullets = g_iMaxPrimaryAmmo[client] + g_iMaxPrimaryClip[client];

    else
        maxbullets = g_iMaxSecondaryAmmo[client] + g_iMaxSecondaryClip[client];

    new Float:player_percentage = float(ammo + clip) / float(maxbullets);
    new Float:to_fill = 1.0 - player_percentage;

    to_fill = to_fill > percentage ? percentage : to_fill;
    percentage -= to_fill;

    new ammo_to_add = RoundToNearest(to_fill * maxbullets);

    if (g_iEndGame == ENDGAME_NONE && GunPlant_OnItemPickup(client, packid, slot))
        ammo_to_add = 0;

    if (percentage <= 0.02)
    {
        new primary = GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY);
        new secondary = GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY);
        new primary_clip;
        new primary_ammo;
        new secondary_clip;
        new secondary_ammo;

        if (primary > 0)
        {
            primary_clip = GetWeaponClip(primary);
            primary_ammo = GetWeaponAmmo(primary, client);
        }

        if (secondary > 0)
        {
            secondary_clip = GetWeaponClip(secondary);
            secondary_ammo = GetWeaponAmmo(secondary, client);
        }

        if (slot == WEPSLOT_PRIMARY)
            primary_ammo += ammo_to_add;

        else
            secondary_ammo += ammo_to_add;

        new Handle:hData = CreateDataPack();

        WritePackCell(hData, client);
        WritePackCell(hData, primary_clip);
        WritePackCell(hData, primary_ammo);
        WritePackCell(hData, secondary_clip);
        WritePackCell(hData, secondary_ammo);

        RemoveFromTrie(g_hAmmoPackPercentage, sAmmo);
        RemoveFromTrie(g_hAmmoPackType, sAmmo);

        g_bIsSettingProperAmmo[client] = true;

        AcceptEntityInput(packid, "kill");
        CreateTimer(0.05, Timer_SetProperAmmo, hData);
    }

    else
        SetTrieValue(g_hAmmoPackPercentage, sAmmo, percentage);

    return Plugin_Handled;
}

public TF2_OnGameFrame()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && JB_IsPlayerAlive(i))
        {
            // The only way to change player speed in TF2.
            // We have to make sure we do the appropriate condition checks, though.

            if (!TF2_IsPlayerInCondition(i, TFCond_Slowed) &&
                !TF2_IsPlayerInCondition(i, TFCond_Zoomed) && 
                !TF2_IsPlayerInCondition(i, TFCond_Bonked))
            {
                new Float:to_set = g_fPlayerSpeed[i];

                if (GetClientTeam(i) == TEAM_GUARDS &&
                    g_iEndGame == ENDGAME_NONE)
                    to_set = to_set + 35.0;

                if (TF2_IsInJumpGame(i))
                    to_set = 240.0;

                if (GetClientButtons(i) & IN_SPEED)
                    to_set = to_set > 120.0 ? 120.0 : to_set;

                SetEntPropFloat(i, Prop_Send, "m_flMaxspeed", to_set);
            }

            // Make it so scouts can't double jump.
            // CT Scouts can double jump, as long as there's no end game.

            if (g_iEndGame != ENDGAME_NONE || GetClientTeam(i) == TEAM_PRISONERS)
                SetEntData(i, m_iAirDash, 3);
        }
    }
}

stock TF2_OnPlayerDeathPre(client)
{
    if (!g_bHasRoundStarted)
        return;

    new String:weapon[LEN_ITEMNAMES];
    GetClientWeapon(client, weapon, sizeof(weapon));

    if (StrEqual(weapon, ""))
        return;

    new slot;

    if (!GetTrieValue(g_hWepsAndItems, weapon, slot))
        LogError("TF2: NEW WEAPON (TF2_OnPlayerDeathPre)? %s", weapon);

    if (slot == WEPSLOT_PRIMARY || slot == WEPSLOT_SECONDARY)
    {
        new wepid = GetPlayerWeaponSlot(client, slot);
        if (wepid <= 0)
            return;

        new dummy = CreateDummyGun();

        decl String:sId[8];
        IntToString(dummy, sId, sizeof(sId));

        SetTrieValue(g_hAmmoPackType, sId, slot);
        SetTrieValue(g_hAmmoPackPercentage, sId, 0.25);

        SpawnDummyGun(dummy, GetEntProp(wepid, Prop_Send, "m_iWorldModelIndex"));

        decl Float:origin[3];
        GetClientAbsOrigin(client, origin);

        TeleportEntity(dummy, origin, NULL_VECTOR, NULL_VECTOR);
    }
}

public Action:TF2_OnSoundPlayed(clients[64],
                                &numClients,
                                String:sample[PLATFORM_MAX_PATH],
                                &entity,
                                &channel,
                                &Float:volume,
                                &level,
                                &pitch,
                                &flags)
{
    if (StrContains(sample, "weapon") < 0 ||
        g_iEndGame != ENDGAME_NONE)
        return Plugin_Continue;

    if (entity > 0 && entity <= MaxClients)
    {
        new slot;

        decl String:weapon[64];
        GetClientWeapon(entity, weapon, sizeof(weapon));

        if (!GetTrieValue(g_hWepsAndItems, weapon, slot))
            return Plugin_Stop;

        if (slot == WEPSLOT_KNIFE)
            return Plugin_Stop;
    }

    return Plugin_Continue;
}


/* ----- Commands ----- */


public Action:Command_SpoofMedic(client, args)
{
    ClientCommand(client, "voicemenu 0 0 ");
    return Plugin_Handled;
}

public Action:Command_StripMeh(client, args)
{
    StripWeps(client);
    return Plugin_Handled;
}

public Action:Command_VoiceMenu(client, const String:command[], args)
{
    decl String:argstring[32];
    GetCmdArgString(argstring, sizeof(argstring));

    if (StrEqual(argstring, "0 0"))
    {
        g_bFakeUse[client] = true;
        return Plugin_Handled;
    }

    if (!strncmp(argstring, "0 0", 3))
        return Plugin_Continue;

    return Plugin_Handled;
}

public Action:Command_ActionTaunt(client, const String:command[], args)
{
    if (g_iEndGame == ENDGAME_NONE)
        return Plugin_Handled;

    if (GetTime() - g_iLastActionTaunt[client] < 10)
        return Plugin_Handled;

    g_iLastActionTaunt[client] = GetTime();
    return Plugin_Continue;
}

public Action:Command_Taunt(client, const String:command[], args)
{
    if (!g_bHasRoundKindaStarted)
        return Plugin_Continue;

    new slot;
    new team = GetClientTeam(client);
    new TFClassType:player_class = TF2_GetPlayerClass(client);

    new String:weapon[LEN_ITEMNAMES];
    GetClientWeapon(client, weapon, sizeof(weapon));

    if (StrEqual(weapon, ""))
        return Plugin_Handled;

    if (!GetTrieValue(g_hWepsAndItems, weapon, slot))
        LogError("TF2: NEW WEAPON (Command_Taunt)? %s", weapon);

    if (slot == WEPSLOT_KNIFE)
    {
        if (g_bHasUber[client] &&
            FindValueInArray(g_hLRTs, client) == -1 &&
            FindValueInArray(g_hLRCTs, client) == -1)
        {
            TF2_AddCondition(client, TFCond_Ubercharged, 10.0);
            g_bHasUber[client] = false;

            return Plugin_Handled;
        }

        if (HasBomb(client))
        {
            ExplodePlayer(client);
            return Plugin_Handled;
        }

        PrintToChat(client,
                    "%s Careful, taunting with a non-melee weapon drops the weapon!",
                    MSG_PREFIX);

        if (g_iEndGame == ENDGAME_NONE)
            return Plugin_Handled;

        return Plugin_Continue;
    }

    // You can lag the server REALLY badly by gathering all the guns from armory, and putting them in one location (armory vents)
    // This SHOULD prevent that.

    if (GetTime() - g_iLastDrop[client] < 4)
    {
        if (g_iDrops[client] > 3)
        {
            PrintToChat(client,
                        "%s Slow down. To prevent people from lagging the server, you can't drop your weapons that fast",
                        MSG_PREFIX);

            return Plugin_Handled;
        }

        g_iDrops[client]++;
    }

    else
        g_iDrops[client] = 1;

    g_iLastDrop[client] = GetTime();

    new wepid = GetPlayerWeaponSlot(client, slot);
    new dummy = CreateDummyGun();
    new ammo = GetWeaponAmmo(wepid, client);
    new clip = GetWeaponClip(wepid);

    if (ammo + clip < 1)
        return Plugin_Handled;

    decl String:sWepid[8];
    IntToString(dummy, sWepid, sizeof(sWepid));

    SetTrieValue(g_hAmmoPackType, sWepid, slot);

    if (!ammo && !clip)
        return Plugin_Handled;

    if (slot == WEPSLOT_PRIMARY)
    {
        SetTrieValue(g_hAmmoPackPercentage, sWepid,
                     float(ammo + clip) / float(g_iMaxPrimaryClip[client] + g_iMaxPrimaryAmmo[client]));
        
        StripWeaponAmmo(client, wepid, WEPSLOT_PRIMARY);
    }

    if (slot == WEPSLOT_SECONDARY ||
        (slot == WEPSLOT_PRIMARY && player_class == TFClass_Medic))
    {
        if (g_iPlayerThrowing[client] == -1 && g_iEndGame == ENDGAME_LR)
        {
            g_iPlayerThrowing[client] = dummy;

            if (DT_OnItemDrop(client, 0) == Plugin_Handled)
            {
                RemoveFromTrie(g_hAmmoPackPercentage, sWepid);
                RemoveFromTrie(g_hAmmoPackType, sWepid);

                AcceptEntityInput(dummy, "kill");
                g_iPlayerThrowing[client] = -1;

                return Plugin_Handled;
            }
        }

        // If it's primary (guntoss for medic) it's already been stripped above.
        if (slot == WEPSLOT_SECONDARY)
        {
            SetTrieValue(g_hAmmoPackPercentage, sWepid,
                         float(ammo + clip) / float(g_iMaxSecondaryClip[client] + g_iMaxSecondaryAmmo[client]));

            StripWeaponAmmo(client, wepid, slot);
        }
    }

    SpawnDummyGun(dummy, GetEntProp(wepid, Prop_Send, "m_iWorldModelIndex"));

    decl Float:origin[3];
    decl Float:angles[3];
    decl Float:player_velocity[3];
    decl Float:velocity[3];

    GetEntPropVector(client, Prop_Data, "m_vecVelocity", player_velocity);
    GetClientEyePosition(client, origin);
    GetClientEyeAngles(client, angles);

    new Float:x_mult = Cosine(DegToRad(angles[1]));
    new Float:y_mult = Sine(DegToRad(angles[1]));
    new Float:z_mult = Sine(-DegToRad(angles[0]));

    origin[0] += x_mult * 15.0;
    origin[1] += y_mult * 15.0;

    velocity[0] = x_mult * 280.0;
    velocity[1] = y_mult * 280.0;
    velocity[2] = z_mult * 350.0;

    velocity[0] += player_velocity[0];
    velocity[1] += player_velocity[1];
    velocity[2] += player_velocity[2] * 1.5;

    TeleportEntity(dummy, origin, NULL_VECTOR, velocity);
    g_fThrowTime[client] = GetGameTime();

    // Check to see if the T should be turned back to normal color
    CreateTimer(0.1, RebelTrk_CheckNonRebel, GetClientUserId(client));

    if (team == TEAM_GUARDS && g_iEndGame == ENDGAME_NONE)
        GunPlant_OnDropWeapon(client, dummy, slot);

    return Plugin_Handled;
}

public TF2_OnEntityCreated(entity, const String:classname[])
{
    if (StrEqual(classname, "item_ammopack_small"))
        HookSingleEntityOutput(entity, "OnPlayerTouch", AmmoPack_GiveFullAmmo);

    else if (StrEqual(classname, "item_ammopack_medium") ||
        StrEqual(classname, "item_ammopack_full"))
        HookSingleEntityOutput(entity, "OnPlayerTouch", AmmoPack_OnPlayerTouch);

    else if (StrEqual(classname, "tf_ammo_pack") && g_bHasRoundStarted)
        SDKHook(entity, SDKHook_Spawn, OnAmmoPackSpawned);
    
}

public OnAmmoPackSpawned(entity)
{
    new slot;
    slot += 1;

    decl String:sId[8];
    IntToString(entity, sId, sizeof(sId));

    if (!GetTrieValue(g_hAmmoPackType, sId, slot))
        AcceptEntityInput(entity, "kill");
}

public OnEntityDestroyed(entity)
{
    if (g_iGame != GAMETYPE_TF2 || !g_bHasRoundStarted)
        return;

    new slot;
    new Float:percentage;

    decl String:sEnt[8];
    IntToString(entity, sEnt, sizeof(sEnt));

    if (!GetTrieValue(g_hAmmoPackType, sEnt, slot))
        return;

    GetTrieValue(g_hAmmoPackPercentage, sEnt, percentage);

    decl Float:origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);

    new dummy = CreateDummyGun();
    TeleportEntity(dummy, origin, NULL_VECTOR, NULL_VECTOR);

    RemoveFromTrie(g_hAmmoPackType, sEnt);
    RemoveFromTrie(g_hAmmoPackType, sEnt);

    IntToString(dummy, sEnt, sizeof(sEnt));

    SetTrieValue(g_hAmmoPackType, sEnt, slot);
    SetTrieValue(g_hAmmoPackPercentage, sEnt, percentage);

    SpawnDummyGun(dummy, GetEntProp(entity, Prop_Send, "m_nModelIndex"));
}

/* ----- Timers ----- */


public Action:Timer_ShowTime(Handle:timer, any:timeleft)
{
    SetHudTextParams(-1.0, 0.87, 1.1, 0, 255, 0, 255);
    decl String:text[32];

    if (g_iRoundTimerEntity == -1)
    {
        g_iRoundTimerEntity = FindEntityByClassname(-1, "team_round_timer");
        AcceptEntityInput(g_iRoundTimerEntity, "Disable");
    }

    if (timeleft < 0)
    {
        g_hRoundTime = INVALID_HANDLE;

        AcceptEntityInput(g_iRoundTimerEntity, "Enable");

        SetVariantInt(0);
        AcceptEntityInput(g_iRoundTimerEntity, "SetTime");

        return Plugin_Handled;
    }

    Format(text, sizeof(text), "Timeleft: %d:%02d", timeleft / 60, timeleft % 60);

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
            ShowSyncHudText(i, g_hHudSync, text);
    }

    g_hRoundTime = CreateTimer(1.0, Timer_ShowTime, --timeleft);
    return Plugin_Continue;
}

public Action:Timer_CheckWeapons(Handle:timer, any:data)
{
    if (g_iEndGame != ENDGAME_NONE)
        return Plugin_Continue;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) ||
            GetClientTeam(i) != TEAM_PRISONERS ||
            IsRebel(i) ||
            g_bIsInvisible[i])
            continue;

        new primary = GetPlayerWeaponSlot(i, WEPSLOT_PRIMARY);
        new secondary = GetPlayerWeaponSlot(i, WEPSLOT_SECONDARY);

        if ((primary > -1 && (GetWeaponClip(primary) > 0 || GetWeaponAmmo(primary, i) > 0)) ||
            (secondary > -1 && (GetWeaponClip(secondary) > 0 || GetWeaponAmmo(secondary, i) > 0)))
        {
            SetEntityRenderMode(i, RENDER_TRANSCOLOR);
            SetEntityRenderColor(i, 50, 50, 255, 255);
        }

        else
        {
            SetEntityRenderMode(i, RENDER_TRANSCOLOR);
            SetEntityRenderColor(i, 255, 255, 255, 255);
        }
    }

    return Plugin_Continue;
}

public Action:Timer_SetProperAmmo(Handle:timer, any:hData)
{
    ResetPack(hData);

    new client = ReadPackCell(hData);
    g_bIsSettingProperAmmo[client] = false;

    new pclip = ReadPackCell(hData);
    new pammo = ReadPackCell(hData);
    new sclip = ReadPackCell(hData);
    new sammo = ReadPackCell(hData);
    
    SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY), client, pclip, pammo);
    SetWeaponAmmo(GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY), client, sclip, sammo);

    CloseHandle(hData);
}


/* ----- Functions ----- */


stock TF2_WallHacks()
{
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) &&
            GetClientTeam(i) == TEAM_PRISONERS &&
            JB_IsPlayerAlive(i))
            SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
    }
}

stock TF2_SaveClassData(client)
{
    g_iCacheClass[client] = TF2_GetPlayerClass(client);
    g_iCacheHealth[client] = GetClientHealth(client);

    for (new slot = 0; slot < 3; slot++)
    {
        new wepid = GetPlayerWeaponSlot(client, slot);
        if (wepid == -1)
            continue;

        GetEntityClassname(wepid, g_sCacheWeapon[client][slot], 48);

        if (slot != WEPSLOT_KNIFE)
        {
            g_iCacheClip[client][slot] = GetWeaponClip(wepid);
            g_iCacheAmmo[client][slot] = GetWeaponAmmo(wepid, client);
        }

        g_iCacheItemIndex[client][slot] = GetEntProp(wepid, Prop_Send, "m_iItemDefinitionIndex");
    }

    g_iCacheMaxPrimaryClip[client] = g_iMaxPrimaryClip[client];
    g_iCacheMaxPrimaryAmmo[client] = g_iMaxPrimaryAmmo[client];

    g_iCacheMaxSecondaryClip[client] = g_iMaxSecondaryClip[client];
    g_iCacheMaxSecondaryAmmo[client] = g_iMaxSecondaryAmmo[client];
}

stock TF2_LoadClassData(client, bool:health=true)
{
    if (!IsClientInGame(client) || !JB_IsPlayerAlive(client))
        return;

    TF2_SetPlayerClass(client, g_iCacheClass[client]);
    TF2_SetProperModel(client);

    if (health)
        SetEntityHealth(client, g_iCacheHealth[client]);

    for (new slot = 0; slot < 3; slot++)
    {
        if (StrEqual(g_sCacheWeapon[client][slot], ""))
            continue;

        new wepid = TF2_GivePlayerWeapon(client, g_sCacheWeapon[client][slot], g_iCacheItemIndex[client][slot], slot);

        if (slot != WEPSLOT_KNIFE)
            SetWeaponAmmo(wepid, client, g_iCacheClip[client][slot], g_iCacheAmmo[client][slot]);
    }

    g_iMaxPrimaryClip[client] = g_iCacheMaxPrimaryClip[client];
    g_iMaxPrimaryAmmo[client] = g_iCacheMaxPrimaryAmmo[client];

    g_iMaxSecondaryClip[client] = g_iCacheMaxSecondaryClip[client];
    g_iMaxSecondaryAmmo[client] = g_iCacheMaxSecondaryAmmo[client];
}

stock TF2_GiveFullAmmo(client)
{
    new primary = GetPlayerWeaponSlot(client, WEPSLOT_PRIMARY);
    new secondary = GetPlayerWeaponSlot(client, WEPSLOT_SECONDARY);

    if (primary > 0)
        SetWeaponAmmo(primary, client, g_iMaxPrimaryClip[client], g_iMaxPrimaryAmmo[client]);

    if (secondary > 0)
        SetWeaponAmmo(secondary, client, g_iMaxSecondaryClip[client], g_iMaxSecondaryAmmo[client]);
}

stock TF2_SetProperModel(client)
{
    new String:model[PLATFORM_MAX_PATH];
    new TFClassType:class = TF2_GetPlayerClass(client);

    switch (class)
    {
        case TFClass_Scout:
            Format(model, sizeof(model), "models/player/hgmodels/scout.mdl");

        case TFClass_Soldier:
            Format(model, sizeof(model), "models/player/hgmodels/soldier.mdl");

        case TFClass_DemoMan:
            Format(model, sizeof(model), "models/player/hgmodels/demo.mdl");

        case TFClass_Heavy:
            Format(model, sizeof(model), "models/player/hgmodels/heavy.mdl");

        case TFClass_Pyro:
            Format(model, sizeof(model), "models/player/hgmodels/pyro.mdl");

        case TFClass_Sniper:
            Format(model, sizeof(model), "models/player/hgmodels/sniper.mdl");

        case TFClass_Medic:
            Format(model, sizeof(model), "models/player/medic.mdl");
    }

    if (!StrEqual(model, ""))
    {
        SetVariantString(model);
        AcceptEntityInput(client, "SetCustomModel");

        SetEntProp(client, Prop_Send, "m_nSkin", GetClientTeam(client) - 1);
        SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
        SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
    }

    g_fPlayerSpeed[client] = g_fDefaultSpeed[class];
}

TF2_GivePlayerWeapon(client, String:classname[], iItemDefinitionIndex, slot)
{
    new wepid = GetPlayerWeaponSlot(client, slot);

    if (wepid > 0 && IsValidEdict(wepid))
        TF2_RemoveWeaponSlot(client, slot);

    new Handle:item = TF2Items_CreateItem(OVERRIDE_CLASSNAME|OVERRIDE_ITEM_DEF);

    TF2Items_SetClassname(item, classname);
    TF2Items_SetItemIndex(item, iItemDefinitionIndex);
    TF2Items_SetLevel(item, 1);
    TF2Items_SetQuality(item, 1);
    TF2Items_SetNumAttributes(item, 0);

    new weapon = TF2Items_GiveNamedItem(client, item);
    CloseHandle(item);

    EquipPlayerWeapon(client, weapon);
    return weapon;
}

CreateDummyGun()
{
    new dummy = CreateEntityByName("tf_ammo_pack");

    // Have to first set a dummy model, before setting the real one, or it will be invisible.
    DispatchKeyValue(dummy, "model", "models/weapons/w_models/w_shotgun.mdl");

    return dummy;
}

stock SpawnDummyGun(dummy, model)
{
    DispatchSpawn(dummy);
    SetEntProp(dummy, Prop_Send, "m_nModelIndex", model);

    SDKHook(dummy, SDKHook_Touch, OnAmmoPickup);
    SDKHook(dummy, SDKHook_StartTouch, OnAmmoPickup);
}

stock TF2_SetHealthBonus(client, amount)
{
    TF2Attrib_SetByName(client, "max health additive bonus", float(amount));
}

TF2_GetMaxHealth(client)
{
    return SDKCall(g_fnGetMaxHealth, client);
}

bool:TF2_IsInJumpGame(client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    // Fountain Jump
    if (origin[2] > 120.0 &&
        origin[0] < 450.0 && origin[0] > -140.0 &&
        origin[1] < -2180.0 && origin[1] > -2650.0)
        return true;

    // Obstacle
    else if (origin[0] > -1500.0 && origin[0] < -880.0 &&
             origin[1] > -3450.0 && origin[1] < -1760.0)
        return true;

    // Hurdles
    else if (origin[2] < 220.0 &&
             origin[0] > -2150.0 && origin[0] < -1730.0 &&
             origin[1] > -3700.0 && origin[1] < -1700.0)
         return true;

    return false;
}
