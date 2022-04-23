
// ###################### GLOBALS ######################


new Handle:g_hKnifeSyphonDamage = INVALID_HANDLE;
new Handle:g_hKnifeSyphonBonus = INVALID_HANDLE;

new g_iKnifeSyphonDamage = 25;
new g_iKnifeSyphonBonus = 25;


// ###################### EVENTS ######################


stock Syphon_OnPluginStart()
{
    g_hKnifeSyphonDamage = CreateConVar("hg_premium_knife_syphon_health", "25",
                                        "The amount of health everyone gets for killing with a knife");

    g_hKnifeSyphonBonus = CreateConVar("hg_premium_knife_syphon_bonus", "25",
                                       "The amount of EXTRA health premium users who have advanced knife syphon get");

    HookConVarChange(g_hKnifeSyphonDamage, Syphon_OnConVarChanged);
    HookConVarChange(g_hKnifeSyphonBonus, Syphon_OnConVarChanged);
}

public Syphon_OnConVarChanged(Handle:CVar, const String:oldv[], const String:newv[])
{
    if (CVar == g_hKnifeSyphonDamage)
        g_iKnifeSyphonDamage = GetConVarInt(CVar);

    else if (CVar == g_hKnifeSyphonBonus)
        g_iKnifeSyphonBonus = GetConVarInt(CVar);
}

public Syphon_OnPlayerDeath(attacker, const String:weapon[])
{
    if (StrEqual(weapon, "knife") ||
        (g_iGame == GAMETYPE_CSGO &&
            ((StrContains(weapon, "knife") > -1) || (StrContains(weapon, "bayonet") > -1))))
    {
        decl String:map[MAX_NAME_LENGTH];
        GetCurrentMap(map, sizeof(map));

        if (StrContains(map, "35hp_") == 0)
            return;

        new damage = g_iKnifeSyphonDamage;
        if (g_bClientEquippedItem[attacker][Item_KnifeSyphon])
            damage += g_iKnifeSyphonBonus;

        if (!damage)
            return;

        PrintToChat(attacker,
                    "%s You obtained \x03%d\x04 health for killing with a knife",
                    MSG_PREFIX, damage);

        SetEntityHealth(attacker, GetClientHealth(attacker) + damage);
    }
}

