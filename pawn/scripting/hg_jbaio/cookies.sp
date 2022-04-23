#define COOKIE_GHOST_ENABLED            1 << 0
#define COOKIE_GHOST_THIRDPERSON        1 << 1
#define COOKIE_GHOST_NOHUDHINT          1 << 2
#define COOKIE_GHOST_DONT_SHOW_MENU     1 << 3
#define COOKIE_GHOST_HIDE_GHOSTS        1 << 4
#define COOKIE_TRADE_CHAT_ENABLED       1 << 5
#define COOKIE_DEAD_DM_ENABLED          1 << 6

new g_iClientCookieFlags[MAXPLAYERS + 1];
new Handle:g_hClientFlagCookie = INVALID_HANDLE;

/* ----- Events ----- */

stock Cookies_OnPluginStart()
{
    g_hClientFlagCookie = RegClientCookie("hgjb_flagcookie", "Various player settings", CookieAccess_Private);
}

stock Cookies_OnClientPutInServer(client)
{
    g_iClientCookieFlags[client] = 0;

    if (!IsFakeClient(client))
    {
        CreateTimer(0.5, Timer_CheckCookies, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    }
}

/* ----- Functions ----- */

public SetClientCookieFlag(client, flag)
{
    decl String:sCookie[LEN_INTSTRING];
    g_iClientCookieFlags[client] |= flag;

    IntToString(g_iClientCookieFlags[client], sCookie, sizeof(sCookie));
    SetClientCookie(client, g_hClientFlagCookie, sCookie);
}

public UnsetClientCookieFlag(client, flag)
{
    decl String:sCookie[LEN_INTSTRING];
    g_iClientCookieFlags[client] &= ~flag;

    IntToString(g_iClientCookieFlags[client], sCookie, sizeof(sCookie));
    SetClientCookie(client, g_hClientFlagCookie, sCookie);
}

public bool:IsClientCookieFlagSet(client, flag)
{
    return (g_iClientCookieFlags[client] & flag) > 0;
}

/* ----- Timers ----- */

public Action:Timer_CheckCookies(Handle:Timer, any:userid)
{
    new client = GetClientOfUserId(userid);

    if (client > 0)
    {
        if (AreClientCookiesCached(client))
        {
            decl String:sCookie[LEN_INTSTRING];

            GetClientCookie(client, g_hClientFlagCookie, sCookie, sizeof(sCookie));
            g_iClientCookieFlags[client] = StringToInt(sCookie);

            OnClientCookiesLegitCached(client);
            return Plugin_Stop;
        }

    }

    else
        return Plugin_Stop;

    return Plugin_Continue;
}
