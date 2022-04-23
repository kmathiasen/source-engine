// http://forums.alliedmods.net/showthread.php?t=197452

// ###################### GLOBALS ######################

// Player Data.
new g_iPlayerTrails[MAXPLAYERS + 1];
new g_iLastTrailChange[MAXPLAYERS + 1];

new bool:g_bTrailsEnabled[MAXPLAYERS + 1];
new bool:g_bCanSeeTrails[MAXPLAYERS + 1];

new Handle:g_hPlayerTrails[MAXPLAYERS + 1];

new String:g_sPlayerTrail[MAXPLAYERS + 1][LEN_NAMES];

// Trail Data.
new Handle:g_hTrailPaths = INVALID_HANDLE;

// Cookies. Nom nom nom.
new Handle:g_hTrailsEnabled = INVALID_HANDLE;
new Handle:g_hPlayerTrail = INVALID_HANDLE;
new Handle:g_hCanSeeTrails = INVALID_HANDLE;

// ConVars.
new Handle:g_hStartWidth = INVALID_HANDLE;
new Handle:g_hEndWidth = INVALID_HANDLE;
new Handle:g_hLifeTime = INVALID_HANDLE;
new Handle:g_hDefaultSeeTrails = INVALID_HANDLE;

// Shadow ConVars.
new bool:g_bDefaultSeeTrails = true;
new String:g_sStartWidth[LEN_INTSTRING] = "3";
new String:g_sEndWidth[LEN_INTSTRING] = "5";
new String:g_sLifeTime[LEN_INTSTRING] = "0.5";

// Misc
new bool:g_bEnding = false;

// ###################### EVENTS ######################


stock Trails_OnPluginStart()
{
    g_hTrailsEnabled = RegClientCookie("hg_premium_trails_enabled",
                                       "Are players trails enabled",
                                       CookieAccess_Protected);

    g_hPlayerTrail = RegClientCookie("hg_premium_trail",
                                     "What you have set for your trail",
                                     CookieAccess_Protected);

    g_hCanSeeTrails = RegClientCookie("hg_premium_can_see_trails",
                                      "Can you see other people's trails?",
                                      CookieAccess_Protected);

    g_hTrailPaths = CreateTrie();

    g_hStartWidth = CreateConVar("hg_premium_trails_start_width", "13",
                                 "Start width for player trails",
                                 _, true, 1.0, true, 100.0);

    g_hEndWidth = CreateConVar("hg_premium_trails_end_width", "16",
                               "End width for player trails",
                               _, true, 1.0, true, 100.0);

    g_hLifeTime = CreateConVar("hg_premium_trails_lifetime", "0.5",
                               "Lifetime for player trails",
                               _, true, 0.1, true, 10.0);

    g_hDefaultSeeTrails = CreateConVar("hg_premium_default_see_trails", "1",
                                       "Do players see others trails by default?",
                                       _, true, 0.0, true, 1.0);

    HookConVarChange(g_hStartWidth, Trails_OnConVarChanged);
    HookConVarChange(g_hEndWidth, Trails_OnConVarChanged);
    HookConVarChange(g_hLifeTime, Trails_OnConVarChanged);
    HookConVarChange(g_hDefaultSeeTrails, Trails_OnConVarChanged);

    RegConsoleCmd("sm_trails", Command_TrailsMenu);
    RegConsoleCmd("sm_trail", Command_TrailsMenu);
}

stock Trails_OnDBConnect()
{
    LoadTrails();
}

public Action:Trails_Transmit(entity, client)
{
    if (client < 1 ||
        client > MaxClients ||
        !IsValidEntity(entity) ||
        g_bCanSeeTrails[client])
        return Plugin_Continue;

    return Plugin_Handled;
}

public Trails_OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hStartWidth)
        strcopy(g_sStartWidth, sizeof(g_sStartWidth), newv);

    else if (CVar == g_hEndWidth)
        strcopy(g_sEndWidth, sizeof(g_sEndWidth), newv);

    else if (CVar == g_hLifeTime)
        strcopy(g_sLifeTime, sizeof(g_sLifeTime), newv);

    else if (CVar == g_hDefaultSeeTrails)
        g_bDefaultSeeTrails = GetConVarBool(CVar);
}

stock Trails_OnClientFullyAuthorized(client, const String:steamid[])
{
    if (g_hPlayerTrails[client] != INVALID_HANDLE)
        CloseHandle(g_hPlayerTrails[client]);
    g_hPlayerTrails[client] = CreateArray(ByteCountToCells(LEN_NAMES));

    decl String:enabled[3];
    decl String:can_see[3];
    decl String:dummy[2];

    GetClientCookie(client, g_hTrailsEnabled, enabled, sizeof(enabled));
    GetClientCookie(client, g_hPlayerTrail, g_sPlayerTrail[client], LEN_NAMES);
    GetClientCookie(client, g_hCanSeeTrails, can_see, sizeof(can_see));

    if (StrEqual(enabled, "") ||
        !StringToInt(enabled) ||
        !GetTrieString(g_hTrailPaths, g_sPlayerTrail[client], dummy, sizeof(dummy)))
        g_bTrailsEnabled[client] = false;

    else
        g_bTrailsEnabled[client] = true;

    if (StrEqual(can_see, ""))
    {
        g_bCanSeeTrails[client] = g_bDefaultSeeTrails;

        if (!g_bDefaultSeeTrails)
        {
            CreateTimer(1.0, Timer_SpamTrailViewing, GetClientUserId(client));
            CreateTimer(7.5, Timer_SpamTrailViewing, GetClientUserId(client));
            CreateTimer(15.0, Timer_SpamTrailViewing, GetClientUserId(client));
            CreateTimer(30.0, Timer_SpamTrailViewing, GetClientUserId(client));
            CreateTimer(60.0, Timer_SpamTrailViewing, GetClientUserId(client));
        }
    }

    else if (StringToInt(can_see))
        g_bCanSeeTrails[client] = true;

    else
        g_bCanSeeTrails[client] = false;
}

public Action:Timer_CheckDead(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (client && !IsPlayerAlive(client))
        Trails_Kill(client);
}

public Action:Timer_SpamTrailViewing(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    PrintToChat(client, "%s By default, you can \x03NOT\x04 see player's trails.", MSG_PREFIX);
    PrintToChat(client, "%s Type \x01!\x03trails\x04 to change this option", MSG_PREFIX);
}

stock Trails_OnRoundStart()
{
    g_bEnding = false;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i))
            Trails_Attach(i);
    }
}

stock Trails_OnRoundEnd()
{
    g_bEnding = true;

    // The source engine will clean up all our trails on round end.
    // So no need to kill them here.
    // Just make sure the script isn't keeping track of invalid entities.

    for (new i = 1; i <= MaxClients; i++)
        g_iPlayerTrails[i] = -1;
}

stock Trails_OnPlayerSpawn(client)
{
    // Just a little note.
    // player_spawn fires BEFORE OnRoundStart.
    // So, having this code here AND in OnRoundStart won't cause duplicate trails.
    // Because g_bEnding is still true for first time spawns (non death match).
    // This Trails_Attach call won't fire.

    if (!g_bEnding)
        CreateTimer(0.34, Timer_TrailsAttach, GetClientUserId(client));
}

public Action:Timer_TrailsAttach(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (client)
        Trails_Attach(client);
}

stock Trails_OnPlayerDeath(client)
{
    Trails_Kill(client);
}


// ###################### Natives ######################

public Native_Premium_OverrideTrail(Handle:plugin, args)
{
    new client = GetNativeCell(1);
    new len;

    GetNativeStringLength(2, len);

    decl String:trail[len + 1];
    GetNativeString(2, trail, len + 1);

    new Handle:data = CreateDataPack();

    WritePackCell(data, GetClientUserId(client));
    WritePackString(data, trail);

    CreateTimer(0.2, Timer_OverrideTrail, data);
}

public Action:Timer_OverrideTrail(Handle:timer, any:data)
{
    ResetPack(data);

    decl String:trail[PLATFORM_MAX_PATH];
    new client = GetClientOfUserId(ReadPackCell(data));

    if (client < 1)
        return Plugin_Handled;

    ReadPackString(data, trail, sizeof(trail));
    CloseHandle(data);

    Trails_Attach(client, trail);
    return Plugin_Handled;
}

// ###################### Functions ######################


stock Trails_Kill(client)
{
    if (g_iPlayerTrails[client] > MAXPLAYERS &&
        IsValidEntity(g_iPlayerTrails[client]))
    {
        decl String:classname[MAX_NAME_LENGTH];
        GetEntityClassname(g_iPlayerTrails[client], classname, sizeof(classname));

        if (StrEqual(classname, "env_spritetrail", false))
        {
            SDKUnhook(g_iPlayerTrails[client], SDKHook_SetTransmit, Trails_Transmit);
            AcceptEntityInput(g_iPlayerTrails[client], "kill");
        }
    }

    g_iPlayerTrails[client] = -1;
}

/*
new Handle:g_trailTimers[MAXPLAYERS + 1];

bool:EquipTrailTempEnts(client, trail)
{
	new entityToFollow = GetPlayerWeaponSlot(client, 2);
	if (entityToFollow == -1)
		entityToFollow = client;

    PrintCenterText(client, "meow");
	TE_SetupBeamFollow(entityToFollow, 
						trail, 
						0, 
						StringToFloat(g_sLifeTime) + 10.0, 
						StringToFloat(g_sStartWidth), 
						StringToFloat(g_sEndWidth), 
						10, 
						int:{255, 255, 255, 255});
	TE_SendToAll();

	return true;
}

public Action:Timer_RenderBeam(Handle:timer, Handle:pack)
{
	ResetPack(pack);

	new client = GetClientFromSerial(ReadPackCell(pack));

	if (client == 0)
		return Plugin_Stop;

	decl Float:velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);		

	new bool:isMoving = !(velocity[0] == 0.0 && velocity[1] == 0.0 && velocity[2] == 0.0);
	if (isMoving)
		return Plugin_Continue;

	EquipTrailTempEnts(client, ReadPackCell(pack));
	return Plugin_Continue;
}
*/

stock Trails_Attach(client, const String:override[]="")
{
    if (g_bEnding ||
        !g_bTrailsEnabled[client] ||
        g_bClientEquippedItem[client][Item_StealthMode] ||
        (StrEqual(g_sPlayerTrail[client], "") && StrEqual(override, "")) ||
        !IsPlayerAlive(client))
        return;

    if (!IsAuthed(client, g_sPlayerTrail[client]))
    {
        Format(g_sPlayerTrail[client], LEN_NAMES, "");

        if (StrEqual(override, ""))
            return;
    }

    Trails_Kill(client);

    decl Float:origin[3];
    decl String:sprite[PLATFORM_MAX_PATH] = "materials/sprites/trails/canadaflag.vmt";
    decl String:parentname[64];

    if (StrEqual(override, ""))
    {
        if (!GetTrieString(g_hTrailPaths, g_sPlayerTrail[client], sprite, sizeof(sprite)))
            return;

        if (!CanUseModel(client, sprite))
            return;
    }

    else
        Format(sprite, sizeof(sprite), override);

    /*
    new model = PrecacheModel(sprite);
    if (g_iGame == GAMETYPE_CSGO)
    {
        EquipTrailTempEnts(client, model);

        new Handle:pack;
        g_trailTimers[client] = CreateDataTimer(1.0, Timer_RenderBeam, pack, TIMER_REPEAT);

        WritePackCell(pack, GetClientSerial(client));
        WritePackCell(pack, model);
    }
    */

    PrecacheModel(sprite);

    Format(parentname, sizeof(parentname), "trails_%d", GetClientUserId(client));
    DispatchKeyValue(client, "targetname", parentname);

    new index = CreateEntityByName("env_spritetrail");
    SetEntPropFloat(index, Prop_Send, "m_flTextureRes", 0.05);

    DispatchKeyValue(index, "parentname", parentname);
    DispatchKeyValue(index, "renderamt", "255");
    DispatchKeyValue(index, "rendercolor", "255 255 255 255");
    DispatchKeyValue(index, "spritename", sprite);
    DispatchKeyValue(index, "lifetime", g_sLifeTime);
    DispatchKeyValue(index, "startwidth", g_sStartWidth);
    DispatchKeyValue(index, "endwidth", g_sEndWidth);
    DispatchKeyValue(index, "rendermode", "0");

    DispatchSpawn(index);
    g_iPlayerTrails[client] = index;

    GetClientAbsOrigin(client, origin);
    origin[2] += 5.0;

    TeleportEntity(index, origin, NULL_VECTOR, NULL_VECTOR);
    SetVariantString(parentname);
    AcceptEntityInput(index, "SetParent", index, index);

    /*
    lol this is funny
    new index = CreateEntityByName("env_sprite_oriented");

    DispatchKeyValue(index, "model", sprite);
    DispatchKeyValue(index, "classname", "env_sprite_oriented");
    DispatchKeyValue(index, "framerate", "10");
    DispatchKeyValue(index, "spawnflags", "1");
    DispatchKeyValue(index, "scale", "0.1");
    DispatchKeyValue(index, "rendermode", "1");
    DispatchKeyValue(index, "angles", "90 0 0");
    DispatchKeyValue(index, "rendercolor", "255 255 255");
    DispatchKeyValue(index, "targetname", "donator_spr");
    DispatchKeyValue(index, "parentname", parentname);
    DispatchSpawn(index);
    
    new Float:Client_Origin[3];
    GetClientAbsOrigin(client, Client_Origin);
    Client_Origin[2] += 0.0;
    TeleportEntity(index, Client_Origin, NULL_VECTOR, NULL_VECTOR);    

    SetVariantString("!activator");
    AcceptEntityInput(index, "SetParent", client, index, 0);
    SetVariantString("OnUser1 !self:SetParentAttachmentMaintainOffset:forward:0.0:1");
    AcceptEntityInput(index, "AddOutput");
    AcceptEntityInput(index, "FireUser1");
    */

    SDKHook(index, SDKHook_SetTransmit, Trails_Transmit);

    // Check for ghostymode.
    if (g_iGame == GAMETYPE_TF2)
        CreateTimer(1.0, Timer_CheckDead, GetClientUserId(client));
}

stock MaterialsMenu(client, at_item=0)
{
    new i;
    new Handle:menu = CreateMenu(MaterialsMenuSelect);

    SetMenuTitle(menu, "Select Material");
    SetMenuExitBackButton(menu, true);

    decl String:dummy[2];
    decl String:trail[LEN_NAMES];
    decl String:display[LEN_NAMES + 10];

    for (i = 0; i < GetArraySize(g_hPlayerTrails[client]); i++)
    {
        GetArrayString(g_hPlayerTrails[client], i, trail, sizeof(trail));
        if (StrEqual(trail, g_sPlayerTrail[client]))
            Format(display, sizeof(display), "%s [Active]", trail);

        else
            Format(display, sizeof(display), trail);

        decl String:restricted[24];
        decl String:newdisplay[128];

        new drawtype = GetRestrictedPrefix(trail, client, restricted, sizeof(restricted));
        Format(newdisplay, sizeof(newdisplay), "%s%s", display, restricted);

        AddMenuItem(menu, trail, newdisplay,
                    GetTrieString(g_hTrailPaths,
                                  trail, dummy,
                                  sizeof(dummy)) ? drawtype : ITEMDRAW_DISABLED);
    }

    if (!i)
    {
        AddMenuItem(menu, "", "NO TRAILS FOUND", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Type !shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "Or press back twice", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "And select shop", ITEMDRAW_DISABLED);
        AddMenuItem(menu, "", "To purchase materials", ITEMDRAW_DISABLED);
    }

    DisplayMenuAtItem(menu, client, at_item, MENU_TIME_FOREVER);
}

stock TrailsMenu(client)
{
    new Handle:menu = CreateMenu(TrailsMainMenuSelect);

    SetMenuTitle(menu, "Trails");
    SetMenuExitBackButton(menu, true);

    if (g_bTrailsEnabled[client])
        AddMenuItem(menu, "0", "Disable Your Trail");

    else
        AddMenuItem(menu, "0", "Enable Your Trail");

    AddMenuItem(menu, "1", "Select Material");

    if (g_bCanSeeTrails[client])
        AddMenuItem(menu, "2", "Hide All Trails");

    else
        AddMenuItem(menu, "2", "View All Trails");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

stock LoadTrails()
{
    decl String:query[256];
    Format(query, sizeof(query),
           "SELECT name, filepath, id FROM items WHERE (servertype & %d) and (type = %d) and (servertype > 0)",
           g_iServerType, ITEMTYPE_TRAIL);

    SQL_TQuery(g_hDbConn, LoadTrailsCallback, query);
}

// ###################### Callbacks ######################


public LoadTrailsCallback(Handle:main, Handle:hndl, const String:error[], any:data)
{
    if (!CheckConnection(hndl, error))
        return;

    decl String:filepath[PLATFORM_MAX_PATH];
    decl String:name[LEN_NAMES];

    while (SQL_FetchRow(hndl))
    {
        SQL_FetchString(hndl, 0, name, sizeof(name));
        SQL_FetchString(hndl, 1, filepath, sizeof(filepath));

        SetTrieString(g_hTrailPaths, name, filepath);
    }
}

public MaterialsMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                TrailsMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:trail[LEN_NAMES];
            GetMenuItem(menu, selected, trail, sizeof(trail));

            SetClientCookie(client, g_hTrailsEnabled, "1");
            g_bTrailsEnabled[client] = true;

            Format(g_sPlayerTrail[client], LEN_NAMES, trail);
            SetClientCookie(client, g_hPlayerTrail, trail);

            new at_item = (selected / g_iMaxItems) * g_iMaxItems;
            MaterialsMenu(client, at_item);

            if ((GetTime() - g_iLastTrailChange[client]) < 5)
            {
                PrintToChat(client, "%s You can't change your trail that quickly...", MSG_PREFIX);
                PrintToChat(client, "%s Your material won't be set until your next spawn", MSG_PREFIX);
            }

            else
            {
                PrintToChat(client,
                            "%s Your material is now \x03%s", MSG_PREFIX, trail);

                g_iLastTrailChange[client] = GetTime();

                if (IsPlayerAlive(client))
                    Trails_Attach(client);
            }
        }
    }
}

public TrailsMainMenuSelect(Handle:menu, MenuAction:action, client, selected)
{
    switch (action)
    {
        case MenuAction_End:
            CloseHandle(menu);

        case MenuAction_Cancel:
        {
            if (selected == MenuCancel_ExitBack)
                MainMenu(client);
        }

        case MenuAction_Select:
        {
            decl String:ss[3];
            GetMenuItem(menu, selected, ss, sizeof(ss));

            switch (StringToInt(ss) + 1)
            {
                // Enable/Disable trails
                case 1:
                {
                    if (g_bTrailsEnabled[client])
                    {
                        SetClientCookie(client, g_hTrailsEnabled, "0");
                        g_bTrailsEnabled[client] = false;

                        PrintToChat(client,
                                    "%s You have \x03disabled\x04 your trails",
                                    MSG_PREFIX);

                        Trails_Kill(client);
                    }

                    else
                    {
                        SetClientCookie(client, g_hTrailsEnabled, "1");
                        g_bTrailsEnabled[client] = true;

                        PrintToChat(client,
                                    "%s You have \x03enabled\x04 your trails. They will be visible next spawn.",
                                    MSG_PREFIX);
                    }

                    TrailsMenu(client);
                }

                // Select Material
                case 2:
                    MaterialsMenu(client);

                // Enable/Disable viewing of trails.
                case 3:
                {
                    if (g_bCanSeeTrails[client])
                    {
                        g_bCanSeeTrails[client] = false;
                        SetClientCookie(client, g_hCanSeeTrails, "0");
    
                        PrintToChat(client, "%s You can no longer see any player trails.", MSG_PREFIX);
                        PrintToChat(client, "%s Type \x01!\x03trails\x04 to enable them again", MSG_PREFIX);
                    }

                    else
                    {
                        g_bCanSeeTrails[client] = true;
                        SetClientCookie(client, g_hCanSeeTrails, "1");

                        PrintToChat(client, "%s You can now see all player trails.", MSG_PREFIX);
                        PrintToChat(client, "%s Type \x01!\x03trails\x04 to disable them again", MSG_PREFIX);
                    }

                    TrailsMenu(client);
                }
            }
        }
    }
}

public Action:Command_TrailsMenu(client, args)
{
    if (!client)
        return Plugin_Continue;

    if (DatabaseFailure(client))
        return Plugin_Handled;

    TrailsMenu(client);
    return Plugin_Handled;
}
