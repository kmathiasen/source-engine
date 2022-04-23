// ###################### GLOBALS ######################

new bool:g_bRagdollsEnding;
new bool:g_bRagdollsEnabled = true;
new bool:g_bRagdollsDelete = true;
new Float:g_fRagdollsDelay = 3.0;
new Float:g_fRagdollsDeleteDelay = 1.5;
new String:g_sRagdollsMagnitude[16];

new Handle:g_hRagdollsEnabled = INVALID_HANDLE;
new Handle:g_hRagdollsDelay = INVALID_HANDLE;
new Handle:g_hRagdollsMagnitude = INVALID_HANDLE;
new Handle:g_hRagdollsDelete = INVALID_HANDLE;
new Handle:g_hRagdollsDeleteDelay = INVALID_HANDLE;


// ###################### EVENTS ######################

public Ragdolls_OnPluginStart() 
{
    g_hRagdollsEnabled = CreateConVar("hg_premium_ragdolls", "1.0", "Enables/Disables ragdoll dissolve on death.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hRagdollsDelay = CreateConVar("hg_premium_ragdolls_delay", "3.0", "The delay after a body is created that it is deleted or dissolved.", FCVAR_NONE);
    g_hRagdollsMagnitude = CreateConVar("hg_premium_ragdolls_magnitude", "15.0", "The magnitude of the dissolve effect.", FCVAR_NONE, true, 0.0);
    g_hRagdollsDelete = CreateConVar("hg_premium_ragdolls_remove", "1.0", "Whether or not to remove (not dissolve) ragdolls for all players (for DM)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hRagdollsDeleteDelay = CreateConVar("hg_premium_ragdolls_remove_delay", "1.5", "Delay for removing ragdolls", FCVAR_NONE, true, 0.0, true, 10.0);

    HookEvent("round_start", Ragdolls_Event_OnRoundStart);
    HookEvent("round_end", Ragdolls_Event_OnRoundEnd);
}

public Ragdolls_OnConfigsExecuted()
{
    g_bRagdollsEnabled = GetConVarInt(g_hRagdollsEnabled) ? true : false;
    g_fRagdollsDelay = GetConVarFloat(g_hRagdollsDelay);
    g_fRagdollsDeleteDelay = GetConVarFloat(g_hRagdollsDeleteDelay);
    GetConVarString(g_hRagdollsMagnitude, g_sRagdollsMagnitude, 32);
    g_bRagdollsDelete = GetConVarBool(g_hRagdollsDelete);
}

// ###################### ACTIONS ######################

public Action:Ragdolls_Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(g_bRagdollsEnabled)
    {
        g_bRagdollsEnding = false;
    }
}

public Action:Ragdolls_Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    if(g_bRagdollsEnabled)
    {
        g_bRagdollsEnding = true;
    }
}

stock Ragdolls_OnPlayerDeath(client)
{
    new _iEntity = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
    if (_iEntity <= 0 || !IsValidEdict(_iEntity))
        return;

    if(g_bRagdollsEnabled &&
       !g_bRagdollsEnding &&
       g_bClientEquippedItem[client][Item_RagDoll] &&
       !g_bClientEquippedItem[client][Item_StealthMode])
    {
        if(g_fRagdollsDelay > 0.0)
            CreateTimer(g_fRagdollsDelay, Ragdolls_Timer_Dissolve, EntIndexToEntRef(_iEntity), TIMER_FLAG_NO_MAPCHANGE);
        else
            Ragdolls_Dissolve(INVALID_ENT_REFERENCE, _iEntity);
    }

    else if (g_bRagdollsDelete)
        CreateTimer(g_fRagdollsDeleteDelay, Timer_RemoveRagdoll, _iEntity);
}

public Action:Timer_RemoveRagdoll(Handle:timer, any:_iEntity)
{
    decl String:classname[MAX_NAME_LENGTH];
    if (IsValidEdict(_iEntity))
    {
        GetEntityClassname(_iEntity, classname, sizeof(classname));

        if (StrEqual(classname, "cs_ragdoll"))
            AcceptEntityInput(_iEntity, "kill");
    }
}

public Action:Ragdolls_Timer_Dissolve(Handle:timer, any:ref)
{
    new entity = EntRefToEntIndex(ref);
    if(entity != INVALID_ENT_REFERENCE && !g_bRagdollsEnding)
        Ragdolls_Dissolve(ref, entity);
}

// ###################### FUNCTIONS ######################

Ragdolls_Dissolve(any:ref, any:entity)
{
    if(entity > 0 && IsValidEdict(entity) && IsValidEntity(entity))
    {
        decl String:dissolve_type[3];
        IntToString(GetRandomInt(0, 3), dissolve_type, sizeof(dissolve_type));

        new g_iDissolve = CreateEntityByName("env_entity_dissolver");
        if(g_iDissolve > 0)
        {
            decl String:g_sName[32];
            Format(g_sName, 32, "Ref_%d_Ent_%d", ref, entity);

            DispatchKeyValue(entity, "targetname", g_sName);
            DispatchKeyValue(g_iDissolve, "target", g_sName);
            DispatchKeyValue(g_iDissolve, "dissolvetype", dissolve_type);
            DispatchKeyValue(g_iDissolve, "magnitude", g_sRagdollsMagnitude);
            AcceptEntityInput(g_iDissolve, "Dissolve");
            AcceptEntityInput(g_iDissolve, "Kill");
        }
        else
            AcceptEntityInput(entity, "Kill");
    }
}