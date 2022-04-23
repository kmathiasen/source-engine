#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define VEC_PUNCH_FORCE_FIRST 100
#define VEC_PUNCH_FORCE_SECOND 500

#define SLOW_SPEED 0.333

new Float:fAdminRoom[3] = {1907.75, -27.48, 1.0};
new Float:fOldSpeed[MAXPLAYERS + 1];

new Handle:hCheckTimers[MAXPLAYERS + 1];

new iClientExplodeTime[MAXPLAYERS + 1];
new iSnipe = -1;

new m_vecPunchAngle = -1;

public OnPluginStart()
{
    HookEvent("round_start", OnRoundStart);
    HookEvent("item_pickup", OnItemPickup);
    HookEvent("player_death", OnPlayerDeath);

    m_vecPunchAngle = FindSendPropInfo("CBasePlayer", "m_vecPunchAngle");
}

public OnPlayerDeath(Handle:event, const String:name[], bool:db)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client)
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
}

public OnRoundStart(Handle:event, const String:name[], bool:db)
{
    iSnipe = CreateEntityByName("weapon_g3sg1");

    DispatchKeyValue(iSnipe, "ammo", "90");
    DispatchSpawn(iSnipe);

    TeleportEntity(iSnipe, fAdminRoom, NULL_VECTOR, NULL_VECTOR);
}

public OnItemPickup(Handle:event, const String:name[], bool:db)
{
    decl String:weapon[MAX_NAME_LENGTH];
    GetEventString(event, "item", weapon, sizeof(weapon));

    if (!StrEqual(weapon, "g3sg1", false))
        return;

    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client)
        return;

    decl String:steamid[32];
    GetClientAuthString(client, steamid, sizeof(steamid));

    PrintToChat(client, "\x01Cool, bro, you got the \x05Bonbon\x04 G3SG1");
    if (StrEqual(steamid, "STEAM_0:0:11089864"))
        return;

    PrintToChat(client, "\x03Woh\x01, \x04woh\x01, \x05woh\x01! You aren't \x04Bonbon\x01!");
    PrintToChat(client, "\x01I wouldn't hold dat \x05Bonbon\x04 G3SG1\x01 if I were you.");
    PrintToChat(client, "\x01You wouldn't be able to handle it's \x05awesomeness");

    KeyHintText(client, "Something feels wrong...\nBetter drop that gun");

    if (hCheckTimers[client] != INVALID_HANDLE)
        CloseHandle(hCheckTimers[client]);

    iClientExplodeTime[client] = 5;
    hCheckTimers[client] = CreateTimer(1.5,
                                       Timer_Lol,
                                       GetClientUserId(client),
                                       TIMER_REPEAT);
}

public Action:Timer_Lol(Handle:timer, any:userid)
{
    new client = GetClientOfUserId(userid);
    if (!client)
    {
        for (new i = 1; i <= MaxClients; i++)
        {
            if (hCheckTimers[client] != INVALID_HANDLE &&
                !IsClientInGame(client))
                hCheckTimers[client] = INVALID_HANDLE;
        }

        return Plugin_Stop;
    }

    if (GetPlayerWeaponSlot(client, 0) != iSnipe || iSnipe < 1)
    {
        PrintToChat(client, "\x05Phewph. \x01That was close. You should be more careful of \x04awesome \x03overload");
        //SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", fOldSpeed[client]);
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

        new Handle:message = StartMessageOne("Fade", client);

        BfWriteShort(message, 1536);
        BfWriteShort(message, 1536);
        BfWriteShort(message, (0x0001 | 0x0010));
        BfWriteByte(message, 0);
        BfWriteByte(message, 0);
        BfWriteByte(message, 0);
        BfWriteByte(message, 0);
        EndMessage();

        hCheckTimers[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    switch (--iClientExplodeTime[client])
    {
        case 4:
        {
            new Handle:userMessage = StartMessageOne("Fade", client);

            BfWriteShort(userMessage, 1250); // Fade duration
            BfWriteShort(userMessage, 2500); // Fade hold time
            BfWriteShort(userMessage, (0x0002 | 0x0010)); // What to do
            BfWriteByte(userMessage, 0); // Color R
            BfWriteByte(userMessage, 255); // Color G
            BfWriteByte(userMessage, 0); // Color B
            BfWriteByte(userMessage, 150); // Color Alpha
            EndMessage();

            new Handle:kv = CreateKeyValues("Stuff", "title", "You feel as if you should drop it...");
            PrintToChat(client, "\x01You start feeling kinda \x05queezy\x01. Better \x03drop that gun");

            KvSetColor(kv, "color", 255, 0, 0, 255);
            KvSetNum(kv, "level", 1);
            KvSetNum(kv, "time", 10);

            CreateDialog(client, kv, DialogType_Msg);
            CloseHandle(kv);
        }

        case 3:
        {
            new Handle:panel = CreatePanel();
            SetPanelTitle(panel, "Awesome Overload Incoming...");

            DrawPanelText(panel, "Seriously, I wouldn't hold that");
            DrawPanelText(panel, "Bad things might happen");

            SendPanelToClient(panel, client, EmptyMenuSelect, 6);
            CloseHandle(panel);

            fOldSpeed[client] = GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue");

            PrintToChat(client, "\x01You feel your world \x05slow down\x01... Better \x03drop that gun");
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", SLOW_SPEED);
        }

        case 2:
        {
            decl Float:force[3];
            PrintCenterText(client, "I'm warning you\nDrop It!");

            for (new i = 0; i < 3; i++)
                force[i] = GetRandomFloat(-1.0, 1.0) * VEC_PUNCH_FORCE_FIRST;

            SetEntDataVector(client, m_vecPunchAngle, force);
            PrintToChat(client, "\x01Your head begins to \x05spin\x01. Begging you to \x03drop the gun");
        }

        case 1:
        {
            decl Float:force[3];
            PrintHintText(client, "All right then...");

            for (new i = 0; i < 3; i++)
                force[i] = GetRandomFloat(-1.0, 1.0) * VEC_PUNCH_FORCE_SECOND;

            SetEntDataVector(client, m_vecPunchAngle, force);
            PrintToChat(client, "\x01Your head pounds \x05harder\x01. Listen to your body! \x03Drop the gun!");
        }

        case 0:
        {
            PrintToChatAll("\x03OH \x04NO\x01! \x05%N\x01 exploded due to an \x03awesome \x04overload\x01 while holding the \x04Bonbon \x05G3SG1", client);

            decl Float:loc[3];
            GetClientEyePosition(client, loc);
            loc[2] -= 15.0;

            new iExplosion = CreateEntityByName("env_explosion");
            DispatchKeyValueVector(iExplosion, "Origin", loc);

            DispatchKeyValue(iExplosion, "iMagnitude", "0");
            DispatchKeyValue(iExplosion, "iRadiusOverride", "0");

            AcceptEntityInput(iExplosion, "Explode");
            AcceptEntityInput(iExplosion, "Kill");

            SlapPlayer(client, GetClientHealth(client) + 100);

            hCheckTimers[client] = INVALID_HANDLE;
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

public EmptyMenuSelect(Handle:menu, MenuAction:action, param1, param2)
{
    /* pass */
}

stock KeyHintText(client, const String:message[], any:...)
{
    decl String:formatted[256];
    VFormat(formatted, sizeof(formatted), message, 3);

    new Handle:hBuffer = StartMessageOne("KeyHintText", client);
    BfWriteByte(hBuffer, 1);
    BfWriteString(hBuffer, formatted);
    EndMessage();  
}
