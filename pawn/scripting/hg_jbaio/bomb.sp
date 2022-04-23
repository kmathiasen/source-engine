
new g_bHasBomb[MAXPLAYERS + 1];

Bomb_OnRndStrt_EachClient(client)
{
    g_bHasBomb[client] = false;
}

Bomb_OnRndStrt_General()
{
    if (GetRandomFloat() > GetConVarFloat(g_hCvBombOnRoundStartChance))
        return;

    new iClientCount;
    decl iClients[MAXPLAYERS + 1];

    /*
        We only need the first value in the array to have a default value of 0
        This is to account for round start when there are no terrorists
     */

    iClients[0] = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_PRISONERS)
            iClients[iClientCount++] = i;
    }

    new client = iClients[GetRandomInt(0, iClientCount - 1)];
    if (!client)
        return;

    // Give the random person a bomb after 8.666 seconds.
    // This way, people will stop complaining about people mass dieing in armory.

    CreateTimer(8.666, Bomb_GiveBomb, client);
}

stock Bomb_OnPlayerTeamPost(client)
{
    // Prevent people from exploding bombs in spectator.
    g_bHasBomb[client] = false;
}

Bomb_OnItemPickup(client, const String:itemname[])
{
    if (StrEqual(itemname, "c4"))
        g_bHasBomb[client] = true;
}

Bomb_OnPlayerDeath(client)
{
    if (HasBomb(client) && IsClientInGame(client))
    {
        g_bHasBomb[client] = true;
        CreateTimer(0.1, Timer_ExplodePlayer, GetClientUserId(client));
    }
}

Bomb_OnWeaponDrop(client, const String:wepname[])
{
    if (StrEqual(wepname, "weapon_c4") &&
        GetClientTeam(client) >= TEAM_PRISONERS &&
        JB_IsPlayerAlive(client))
    {
        ForcePlayerSuicide(client);
        CreateTimer(0.1, Timer_ExplodePlayer, GetClientUserId(client));
    }
}

public Action:Timer_ExplodePlayer(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (client && GetClientTeam(client) == TEAM_PRISONERS)
        ExplodePlayer(client);
}

stock GivePlayerBombTF2(client)
{
    TF2_GivePlayerWeapon(client, "tf_weapon_stickbomb", TF2_CABER, WEPSLOT_KNIFE);

    PrintToChat(client, "%s You got a \x03Ullapool Caber\x04!", MSG_PREFIX);
    PrintToChat(client, "%s You will explode when you die, taunt with the caber, or hit something", MSG_PREFIX);

    PrintCenterText(client, "You got the Caber! Taunt with it, or hit something to explode!");
    PrintHintText(client, "You got the Caber! Taunt with it, or hit something to explode!");

    g_bHasBomb[client] = true;
}

stock ExplodePlayer(client)
{
    new index = GetPlayerWeaponSlot(client, 4);
    new iRadius = GetConVarInt(g_hCvBombRadius);
    new iMagnitude = GetConVarInt(g_hCvBombMagnitude);

    if (index == -1)
    {
        while ((index = FindEntityByClassname(index, "weapon_c4")) != -1)
            if (GetEntProp(index, Prop_Send, "m_hOwnerEntity") == -1)
                break;
    }

    if (index != -1)
        AcceptEntityInput(index, "kill");

    EmitSoundToAll(g_sSoundExplode);
    EmitSoundToAll(g_sSoundJihad);

    decl Float:loc[3];
    GetClientEyePosition(client, loc);

    if (!g_bHasBomb[client] && !HasBomb(client))
        return;

    /* Prevent double explosion on drop, and death */
    g_bHasBomb[client] = false;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || !JB_IsPlayerAlive(i) || GetClientTeam(i) < 2)
            continue;

        decl Float:tempLoc[3];
        GetClientAbsOrigin(i, tempLoc);

        /* The player is within the range of the bomb, slap them */
        if (Pow(Pow(loc[0] - tempLoc[0], 2.0) +
                Pow(loc[1] - tempLoc[1], 2.0) +
                Pow(loc[2] - tempLoc[2], 2.0), 0.5) < iRadius)

            SlapPlayer(i, 0, false);
    }

    decl String:magnitude[LEN_INTSTRING];
    decl String:radius[LEN_INTSTRING];

    /*
     * Just trust me here on this math :P
     *
     * I wanted the multiplier to flatten out as your rep got really high
     *  so I used a square root function
     *
     * I shifted this function to the left by 1000, and subtracted the square
     *  root of 10 (just trust me ^.^)
     * new Float:multiplier = SquareRoot((rep + 1000.0) / 100.0) - 3.162;
     */

    new Float:rep = float(PrisonRep_GetPoints(client)) + 2.0; // Make sure they have at least 1 rep (log(x) where x <= 0 is infinity)

    // New multiplier based on a logarithmic scale.
    new Float:multiplier = Logarithm(1000.0 + rep, 3.33) - Logarithm(1000.0, 3.33);

    new magnitudeadd = RoundToNearest(multiplier * GetConVarFloat(g_hCvBombDamageMultiplier));
    new radiusadd = RoundToNearest(multiplier * GetConVarFloat(g_hCvBombRadiusMultiplier));

    IntToString(iMagnitude + magnitudeadd, magnitude, sizeof(magnitude));
    IntToString(iRadius + radiusadd, radius, sizeof(radius));

    PrintToConsoleAll("%N's rep: %.2f", client, rep);
    PrintToConsoleAll("base magnitude: %d", iMagnitude);
    PrintToConsoleAll("base radius: %d", iRadius);
    PrintToConsoleAll("magnitude bonus: %d", magnitudeadd);
    PrintToConsoleAll("radius bonus: %d", radiusadd);

    new iExplosion = CreateEntityByName("env_explosion");

    // For april fools. :)
    // debug
    // to remove1333256740
    /*
    if (GetRandomFloat() < 0.333)
    {
        PrintToChatAll("%s Uh-Oh, looks like Rip Taylor's started manufacturing bombs.", MSG_PREFIX);
        PrintToChatAll("%s Uh-Oh, looks like Rip Taylor's started manufacturing bombs.", MSG_PREFIX);
        FireWorks(client);
        return;
    }
    */

    if (iExplosion > 0)
    {
        DispatchKeyValueVector(iExplosion, "Origin", loc);

        /* Will count any kills the bomb gets as the owner */
        SetEntPropEnt(iExplosion, Prop_Send, "m_hOwnerEntity", client);

        /* Sets team of the explosion, to prevent team kills */
        SetEntProp(iExplosion, Prop_Send, "m_iTeamNum", TEAM_PRISONERS);

        DispatchKeyValue(iExplosion, "iMagnitude", magnitude);
        DispatchKeyValue(iExplosion, "iRadiusOverride", radius);

        AcceptEntityInput(iExplosion, "Explode");
        AcceptEntityInput(iExplosion, "Kill");
    }

    ForcePlayerSuicide(client);
}

public Action:Bomb_GiveBomb(Handle:timer, any:client)
{
    // Make sure there's not already a bomb this round
    // Note: CS:GO has a bomb that you can't pick up that's already on the ground.
    // So we don't take that into account.

    if (g_iGame != GAMETYPE_TF2)
    {
        new bomb = FindEntityByClassname(-1, "weapon_c4");
        if (bomb > 0)
        {
            if (g_iGame == GAMETYPE_CSS)
                return Plugin_Stop;

            // It's CS:GO, so make sure there's at least 2.
            else if (FindEntityByClassname(bomb, "weapon_c4") > 0)
                return Plugin_Stop;
        }
    }

    if (IsClientInGame(client) &&
        JB_IsPlayerAlive(client) &&
        GetClientTeam(client) == TEAM_PRISONERS)
    {
        if (g_iGame == GAMETYPE_TF2)
        {
            for (new i = 1; i <= MaxClients; i++)
            {
                if (HasBomb(client))
                    return Plugin_Stop;
            }

            GivePlayerBombTF2(client);
        }

        else
        {
            GivePlayerItem(client, "weapon_c4");

            PrintToChat(client,
                        "%s You got a \x03Bomb\x04! You will explode when you drop it",
                        MSG_PREFIX);

            PrintCenterText(client, "You got the bomb! Drop it to explode");
            PrintHintText(client, "You got the bomb! Drop it to explode");
        }
    }

    return Plugin_Handled;
}


bool:HasBomb(client)
{
    if (g_iGame == GAMETYPE_TF2)
    {
        new wepid = GetPlayerWeaponSlot(client, WEPSLOT_KNIFE);
        if (wepid > 0)
            return (GetEntProp(GetPlayerWeaponSlot(client, WEPSLOT_KNIFE), Prop_Send, "m_iItemDefinitionIndex") == TF2_CABER);

        else
            return bool:g_bHasBomb[client];
    }

    else
        return bool:g_bHasBomb[client];
}

// for april fools
// dont' forget to take out
// all taken from http://forums.alliedmods.net/showthread.php?t=71051&highlight=css+effects

/*
new g_RedGlowSprite;
new g_GreenGlowSprite;
new g_YellowGlowSprite;
new g_PurpleGlowSprite;
new g_BlueGlowSprite;
new g_OrangeGlowSprite;
new g_WhiteGlowSprite;
new precache_fire_line;

stock AprilFools_OnMapStart()
{
	PrecacheModel("materials/sprites/blueflare1.vmt",true);
	PrecacheModel("materials/effects/redflare.vmt",true);
	PrecacheModel("materials/sprites/yellowflare.vmt",true);
	PrecacheModel("materials/sprites/orangeflare1.vmt",true);
	PrecacheModel("materials/sprites/flare1.vmt",true);

	g_BlueGlowSprite = PrecacheModel("materials/sprites/blueglow1.vmt",true);
	g_RedGlowSprite = PrecacheModel("materials/sprites/redglow1.vmt",true);
	g_GreenGlowSprite = PrecacheModel("materials/sprites/greenglow1.vmt",true);
	g_YellowGlowSprite = PrecacheModel("materials/sprites/yellowglow1.vmt",true);
	g_PurpleGlowSprite = PrecacheModel("materials/sprites/purpleglow1.vmt",true);
	g_OrangeGlowSprite = PrecacheModel("materials/sprites/orangeglow1.vmt",true);
	g_WhiteGlowSprite = PrecacheModel("materials/sprites/glow1.vmt",true);
	precache_fire_line = PrecacheModel("materials/sprites/fire.vmt",true);

	// Sounds
	PrecacheSound( "ambient/fireworks/fireworks_pang01.mp3", true);
	PrecacheSound( "ambient/fireworks/fireworks_shatter01.mp3", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark001.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark002.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark003.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark004.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark005.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark006.wav", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark007.mp3", true);
	PrecacheSound( "ambient/fireworks/fireworks_spark008.mp3", true);
}

stock FireWorks(client)
{
    decl Float:origin[3];
    GetClientAbsOrigin(client, origin);

    origin[2] += 32.5;
    FireSprites(origin);

    CreateTimer(GetRandomFloat(0.0, 0.1), Timer_First, GetClientUserId(client));
    CreateTimer(GetRandomFloat(0.1, 0.2), Timer_Second, GetClientUserId(client));
    CreateTimer(GetRandomFloat(0.2, 0.3), Timer_Second, GetClientUserId(client));
    CreateTimer(GetRandomFloat(0.3, 0.4), Timer_Second, GetClientUserId(client));
    CreateTimer(GetRandomFloat(0.4, 0.5), Timer_Second, GetClientUserId(client));
    CreateTimer(GetRandomFloat(0.5, 0.6), Timer_Third, GetClientUserId(client));
}

public Action:Timer_First(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    decl Float:dir[3];
    decl Float:origin[3];

    GetClientAbsOrigin(client, origin);
    origin[2] += 32.5;

    EmitSoundFromOrigin("ambient/fireworks/fireworks_shatter01.mp3", origin);

    dir[0] = GetRandomFloat(0.0, 360.0);
    dir[1] = GetRandomFloat(0.0, 360.0);
    dir[2] = GetRandomFloat(-30.0, -90.0);

    env_shooter(client, dir, 2.0, 0.1, dir, 1200.0, 1.0, 2.5, origin, "materials/sprites/flare1.vmt");
}

public Action:Timer_Second(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    decl Float:dir[3];
    decl Float:origin[3];

    GetClientAbsOrigin(client, origin);
    origin[2] += 32.5;

    EmitSoundFromOrigin("ambient/fireworks/fireworks_shatter01.mp3", origin);

    dir[0] = GetRandomFloat(0.0, 360.0);
    dir[1] = GetRandomFloat(0.0, 360.0);
    dir[2] = GetRandomFloat(-30.0, -90.0);

    origin[2] -= 32.5;
    FireSprites(origin);
}

public Action:Timer_Third(Handle:timer, any:client)
{
    client = GetClientOfUserId(client);
    if (!client)
        return;

    decl Float:dir[3];
    decl Float:origin[3];

    GetClientAbsOrigin(client, origin);
    origin[2] += 32.5;

    EmitSoundFromOrigin("ambient/fireworks/fireworks_shatter01.mp3", origin);

    dir[0] = GetRandomFloat(0.0, 360.0);
    dir[1] = GetRandomFloat(0.0, 360.0);
    dir[2] = GetRandomFloat(-30.0, -90.0);

    origin[2] -= 32.5;
    FireSprites(origin);
}

stock FireSprites(Float:vec[3])
{
    new Float:vec2[3];
    vec2 = vec;
    vec2[0] += GetRandomFloat(-100.0, 100.0);
    vec2[1] += GetRandomFloat(-100.0, 100.0);
    vec2[2] += GetRandomFloat(100.0, 300.0);
    fire_line(vec,vec2);
    sound(vec);
    //explode(vec2);
    sphere(vec);
    spark(vec);
}

stock sound(Float:vec[3])
{
    new rand = GetRandomInt(1,9);
    switch(rand)
    {
        case 1: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark001.wav", vec);
        case 2: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark002.wav", vec);
        case 3: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark003.wav", vec);
        case 4: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark004.wav", vec);
        case 5: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark005.wav", vec);
        case 6: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark006.wav", vec);
        case 7: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark007.mp3", vec);
        case 8: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark008.mp3", vec);
        case 9: EmitSoundFromOrigin("ambient/fireworks/fireworks_spark009.mp3", vec);
    }
}

stock spark(Float:vec[3])
{
	new Float:dir[3]={0.0,0.0,0.0};
	TE_SetupSparks(vec, dir, 500, 50);
	TE_SendToAll();
}

stock sphere(Float:vec[3])
{
	new Float:rpos[3], Float:radius, Float:phi, Float:theta, Float:live, Float: size, Float:delay;
	new Float:direction[3];
	new Float:spos[3];
	new bright = 255;
	direction[0] = 0.0;
	direction[1] = 0.0;
	direction[2] = 0.0;
	radius = GetRandomFloat(75.0,150.0);
	new rand = GetRandomInt(0,6);
	for (new i=0;i<50;i++)
	{
		delay = GetRandomFloat(0.0,0.5);
		bright = GetRandomInt(128,255);
		live = 2.0 + delay;
		size = GetRandomFloat(0.5,0.7);
		phi = GetRandomFloat(0.0,6.283185);
		theta = GetRandomFloat(0.0,6.283185);
		spos[0] = radius*Sine(phi)*Cosine(theta);
		spos[1] = radius*Sine(phi)*Sine(theta);
		spos[2] = radius*Cosine(phi);
		rpos[0] = vec[0] + spos[0];
		rpos[1] = vec[1] + spos[1];
		rpos[2] = vec[2] + spos[2];

		switch(rand)
		{
			case 0:	TE_SetupGlowSprite(rpos, g_BlueGlowSprite,live, size, bright);
			case 1:	TE_SetupGlowSprite(rpos, g_RedGlowSprite,live, size, bright);
			case 2: TE_SetupGlowSprite(rpos, g_GreenGlowSprite,live, size, bright);
			case 3: TE_SetupGlowSprite(rpos, g_YellowGlowSprite,live, size, bright);
			case 4: TE_SetupGlowSprite(rpos, g_PurpleGlowSprite,live, size, bright);
			case 5: TE_SetupGlowSprite(rpos, g_OrangeGlowSprite,live, size, bright);
			case 6: TE_SetupGlowSprite(rpos, g_WhiteGlowSprite,live, size, bright);
		}
		TE_SendToAll(delay);
	}
}

stock fire_line(Float:startvec[3],Float:endvec[3])
{
	new color[4]={255,255,255,200};
	TE_SetupBeamPoints( startvec,endvec, precache_fire_line, 0, 0, 0, 0.8, 2.0, 1.0, 1, 0.0, color, 10);
	TE_SendToAll();
}

stock env_shooter(client ,Float:Angles[3], Float:iGibs, Float:Delay, Float:GibAngles[3], Float:Velocity, Float:Variance, Float:Giblife, Float:Location[3], String:ModelType[] )
{
	//decl Ent;

	//Initialize:
	new Ent = CreateEntityByName("env_shooter");

	//Spawn:

	if (Ent == -1)
	return;

  	//if (Ent>0 && IsValidEdict(Ent))

	if (Ent>0 && IsValidEntity(Ent) && IsValidEdict(Ent))
  	{

		//Properties:
		//DispatchKeyValue(Ent, "targetname", "flare");

		// Gib Direction (Pitch Yaw Roll) - The direction the gibs will fly.
		DispatchKeyValueVector(Ent, "angles", Angles);

		// Number of Gibs - Total number of gibs to shoot each time it's activated
		DispatchKeyValueFloat(Ent, "m_iGibs", iGibs);

		// Delay between shots - Delay (in seconds) between shooting each gib. If 0, all gibs shoot at once.
		DispatchKeyValueFloat(Ent, "delay", Delay);

		// <angles> Gib Angles (Pitch Yaw Roll) - The orientation of the spawned gibs.
		DispatchKeyValueVector(Ent, "gibangles", GibAngles);

		// Gib Velocity - Speed of the fired gibs.
		DispatchKeyValueFloat(Ent, "m_flVelocity", Velocity);

		// Course Variance - How much variance in the direction gibs are fired.
		DispatchKeyValueFloat(Ent, "m_flVariance", Variance);

		// Gib Life - Time in seconds for gibs to live +/- 5%.
		DispatchKeyValueFloat(Ent, "m_flGibLife", Giblife);

		// <choices> Used to set a non-standard rendering mode on this entity. See also 'FX Amount' and 'FX Color'.
		DispatchKeyValue(Ent, "rendermode", "5");

		// Model - Thing to shoot out. Can be a .mdl (model) or a .vmt (material/sprite).
		DispatchKeyValue(Ent, "shootmodel", ModelType);

		// <choices> Material Sound
		DispatchKeyValue(Ent, "shootsounds", "-1"); // No sound

		// <choices> Simulate, no idea what it realy does tbh...
		// could find out but to lazy and not worth it...
		//DispatchKeyValue(Ent, "simulation", "1");

		SetVariantString("spawnflags 4");
		AcceptEntityInput(Ent,"AddOutput");

		ActivateEntity(Ent);

		//Input:
		// Shoot!
		AcceptEntityInput(Ent, "Shoot", client);

		//Send:
		TeleportEntity(Ent, Location, NULL_VECTOR, NULL_VECTOR);

		//Delete:
		//AcceptEntityInput(Ent, "kill");
		CreateTimer(3.0, KillEnt, Ent);
	}
}
public Action:KillEnt(Handle:Timer, any:Ent)
{
        if (IsValidEntity(Ent))
        {
                decl String:classname[64];
                GetEdictClassname(Ent, classname, sizeof(classname));
                if (StrEqual(classname, "env_shooter", false) || StrEqual(classname, "gib", false) || StrEqual(classname, "env_sprite", false))
                {
                        RemoveEdict(Ent);
                }
        }
}

stock EmitSoundFromOrigin(const String:sound[],const Float:orig[3])
{
	EmitSoundToAll(sound,SOUND_FROM_WORLD,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,SNDVOL_NORMAL,SNDPITCH_NORMAL,-1,orig,NULL_VECTOR,true,0.0);
}
