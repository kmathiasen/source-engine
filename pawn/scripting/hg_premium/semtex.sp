// ###################### GLOBALS ######################

#define SEMTEX_MDL "models/player/hgitems/weapons/semtex.mdl"
#define SND_BEEP   "hgitems/weapons/semtex.wav"

#define MAX_RADIUS	25.0
#define HALF_HEIGHT 40.0

#define SemtexColor	{75,255,75,100}

new g_SemtexModel;

new Handle:g_hSemtexStickPlayers = INVALID_HANDLE;
new Handle:g_hSemtexStickWalls = INVALID_HANDLE;
new Handle:g_hSemtexNormalPower = INVALID_HANDLE;
new Handle:g_hSemtexNormalRadius = INVALID_HANDLE;
new Handle:g_hSemtexStuckPower = INVALID_HANDLE;
new Handle:g_hSemtexStuckRadius = INVALID_HANDLE;

new bool:g_bSemtexEnabled = true;
new bool:g_bSemtexStickPlayers, bool:g_bSemtexStickWalls, Float:g_fSemtexNormalPower, Float:g_fSemtexNormalRadius, Float:g_fSemtexStuckPower, Float:g_fSemtexStuckRadius;

// ###################### EVENTS ######################

public Semtex_OnPluginStart()
{
    g_hSemtexStickPlayers = CreateConVar("hg_premium_semtex_stick_to_players", "1",   "Make HE Grenades stick to players",                    FCVAR_NONE);
    g_hSemtexStickWalls   = CreateConVar("hg_premium_semtex_stick_to_walls",   "1",   "Make HE Grenades stick to walls",                      FCVAR_NONE);
    g_hSemtexNormalPower  = CreateConVar("hg_premium_semtex_normal_power",     "100", "Power of a HE grenade when not stuck to a player",     FCVAR_NONE);
    g_hSemtexNormalRadius = CreateConVar("hg_premium_semtex_normal_radius",    "350", "Radius of a HE grenade when not stuck to a player",    FCVAR_NONE);
    g_hSemtexStuckPower   = CreateConVar("hg_premium_semtex_stuck_power",      "250", "Power of a HE grenade when stuck to a player",         FCVAR_NONE);
    g_hSemtexStuckRadius  = CreateConVar("hg_premium_semtex_stuck_radius",     "350", "Radius of a HE grenade when stuck to a player",        FCVAR_NONE);
}

stock Semtex_OnMapStart()
{
    g_SemtexModel = PrecacheModel(SEMTEX_MDL, true);

    if(!g_SemtexModel)
    {
        LogError("Error: Semtex Model appears to be invalid; Sticky Grenades disabled.");
        g_bSemtexEnabled = false;
    }
}

stock Semtex_OnConfigsExecuted()
{
    g_bSemtexStickPlayers = GetConVarInt(g_hSemtexStickPlayers) ? true : false;
    g_bSemtexStickWalls = GetConVarInt(g_hSemtexStickWalls) ? true : false;
    g_fSemtexNormalPower = GetConVarFloat(g_hSemtexNormalPower);
    g_fSemtexNormalRadius = GetConVarFloat(g_hSemtexNormalRadius);
    g_fSemtexStuckPower = GetConVarFloat(g_hSemtexStuckPower);
    g_fSemtexStuckRadius = GetConVarFloat(g_hSemtexStuckRadius);
}

public Semtex_OnEntityCreated(Entity, const String:Classname[])
{
    if (!g_bSemtexEnabled)
        return;

    if (StrEqual(Classname, "hegrenade_projectile"))
        CreateTimer(0.01, Semtex_Timer_SetModel, Entity);
}

public GrenadeTouch(iGrenade, iEntity) 
{
    //Stick if player
    if(g_bSemtexStickPlayers && iEntity > 0 && iEntity <= MaxClients)
    {
        // Ghost mode enabled on JB
        if (IsPlayerAlive(iEntity))
        {
            Semtex_StickGrenade(iEntity, iGrenade);
        }
    }

    // Stick to wall
    else if(g_bSemtexStickWalls && (GetEntityMoveType(iGrenade) != MOVETYPE_NONE))
        SetEntityMoveType(iGrenade, MOVETYPE_NONE);
}

// ###################### ACTIONS ######################

public Action:Semtex_Timer_SetModel(Handle:timer, any:Entity)
{
    if (!IsValidEntity(Entity))
        return;

    decl String:classname[MAX_NAME_LENGTH];
    GetEntityClassname(Entity, classname, sizeof(classname));

    if (!StrEqual(classname, "hegrenade_projectile", false))
        return;

    SetEntPropFloat(Entity, Prop_Send, "m_flDamage",  g_fSemtexNormalPower);
    SetEntPropFloat(Entity, Prop_Send, "m_DmgRadius", g_fSemtexNormalRadius);

    // Don't know why this works, but fuck it.
    if (g_iGame == GAMETYPE_CSGO)
        SetEntProp(Entity, Prop_Send, "m_CollisionGroup", 0);

    new iClient = GetEntPropEnt(Entity, Prop_Send, "m_hThrower");

    if(iClient <= 0 ||
       !g_bClientEquippedItem[iClient][Item_Semtex] ||
       g_bClientEquippedItem[iClient][Item_StealthMode])
        return;

    new iTeam = GetClientTeam(iClient);
    if(iTeam > 1)
    {
        SetEntityModel(Entity, SEMTEX_MDL);
        SetEntProp(Entity, Prop_Send, "m_clrRender", -1);
    }

    SDKHook(Entity, SDKHook_StartTouch, GrenadeTouch);
    Semtex_BeamFollowCreate(Entity, SemtexColor);
}

// ###################### FUNCTIONS ######################


stock Semtex_StickGrenade(iClient, iGrenade)
{
    decl String:sClass[32];
    GetEdictClassname(iGrenade, sClass, sizeof(sClass));

    // HE Grenade.
    if(StrEqual(sClass, "hegrenade_projectile"))
    {
        SetEntPropFloat(iGrenade, Prop_Send, "m_flDamage",  g_fSemtexStuckPower);
        SetEntPropFloat(iGrenade, Prop_Send, "m_DmgRadius", g_fSemtexStuckRadius);

        SetEntityMoveType(iGrenade, MOVETYPE_NONE);
        SetEntProp(iGrenade, Prop_Send, "m_CollisionGroup", 2);

        // Stick grenade to victim.
        SetVariantString("!activator");
        AcceptEntityInput(iGrenade, "SetParent", iClient);
        SetVariantString("idle");
        AcceptEntityInput(iGrenade, "SetAnimation");

        SetEntProp(iGrenade, Prop_Send, "m_nSolidType", 6);

        SetEntPropVector(iGrenade, Prop_Send, "m_angRotation", Float:{0.0, 0.0, 0.0});
    }
}

Semtex_BeamFollowCreate(Entity, Color[4])
{
    TE_SetupBeamFollow(Entity, g_iSpriteBeam, 0, Float:1.0, Float:1.0, Float:1.0, 5, Color);
    TE_SendToAll();	
}
