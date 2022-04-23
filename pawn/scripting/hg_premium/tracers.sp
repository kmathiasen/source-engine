// ###################### GLOBALS ######################

new bool:g_bTracersEnabled;
new Handle:g_hTracersEnabled = INVALID_HANDLE;

// ###################### EVENTS ######################

public Tracers_OnPluginStart()
{
    g_hTracersEnabled = CreateConVar("hg_premium_tracers", "1.0", "Enables/Disables player tracer rounds.", FCVAR_NONE, true, 0.0, true, 1.0);

    if (g_iGame != GAMETYPE_TF2)
        HookEvent("bullet_impact", Tracers_Event_OnBulletImpact);
}

public Tracers_OnMapStart()
{
    g_bTracersEnabled = GetConVarInt(g_hTracersEnabled) ? true : false;
    
    if(g_hGetWeaponPosition == INVALID_HANDLE)
    {
        LogError("Error: Weapon_ShootPosition signature appears to be invalid; Player Tracers disabled.");
        g_bTracersEnabled = false;
    }
}

stock Tracers_OnPlayerSpawn(client)
{
    g_iPlayerTracerColors[client] = _:GetColorIndex(g_sClientSubValue[client][Item_Tracers]);
}

// ###################### ACTIONS ######################

public Action:Tracers_Event_OnBulletImpact(Handle:event,const String:name[],bool:dontBroadcast)
{
    if(g_bTracersEnabled)
    {
        new client = GetClientOfUserId(GetEventInt(event, "userid"));

        if (!g_bClientEquippedItem[client][Item_StealthMode] &&
            g_bClientEquippedItem[client][Item_Tracers] &&
            GetRandomInt(1, 3) == 2)
        {
            decl Float:_fOrigin[3], Float:_fImpact[3], Float:_fDifference[3];

            SDKCall(g_hGetWeaponPosition, client, _fOrigin);

            _fImpact[0] = GetEventFloat(event, "x");
            _fImpact[1] = GetEventFloat(event, "y");
            _fImpact[2] = GetEventFloat(event, "z");

            new Float:_fDistance = GetVectorDistance(_fOrigin, _fImpact);
            new Float:_fPercent = (0.4 / (_fDistance / 100.0));

            _fDifference[0] = _fOrigin[0] + ((_fImpact[0] - _fOrigin[0]) * _fPercent);
            _fDifference[1] = _fOrigin[1] + ((_fImpact[1] - _fOrigin[1]) * _fPercent) - 0.08;
            _fDifference[2] = _fOrigin[2] + ((_fImpact[2] - _fOrigin[2]) * _fPercent);

            TE_SetupBeamPoints(_fDifference, _fImpact, g_iSpritePhysBeam, 0, 0, 0, 0.1, 3.0, 3.0, 1, 0.0, g_iColors[g_iPlayerTracerColors[client]], 0);
            TE_SendToAll();
        }
    }

    return Plugin_Continue;
}