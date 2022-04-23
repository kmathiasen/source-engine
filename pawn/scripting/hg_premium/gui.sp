// ###################### GLOBALS ######################

new Handle:g_hGuiEnabled;
new Handle:g_hGuiPassword = INVALID_HANDLE;

new bool:g_bGuiEnabled;

new time_offset = 0; // [seconds] The time correction ( = web server - game server) to syncrhonize the game server's clock with the web server's clock (for MySQL transactions).  Refreshed each map change.

// ###################### EVENTS ######################

public Gui_OnPluginStart()
{
    g_hGuiEnabled = CreateConVar("hg_premium_gui", "1.0", "Enables/Disables HGItems Store GUI.", FCVAR_NONE, true, 0.0, true, 1.0);
    g_hGuiPassword = CreateConVar("hg_premium_gui_password", "96240506417595566108660988", "Anti-hack gui password used to secure user accounts.  Must be numbers only and match the gui password specified on the web server.", FCVAR_PROTECTED|FCVAR_SPONLY|FCVAR_PLUGIN);
    
    RegConsoleCmd("sm_storegui", Command_Gui, "View the HGItems Store GUI");
    RegConsoleCmd("sm_viewstore", Command_Gui, "View the HGItems Store GUI");
    RegConsoleCmd("sm_viewitems", Command_Gui, "View the HGItems Store GUI");
    RegConsoleCmd("sm_showstore", Command_Gui, "View the HGItems Store GUI");
    RegConsoleCmd("sm_storeview", Command_Gui, "View the HGItems Store GUI");
    
    g_bGuiEnabled = GetConVarInt(g_hGuiEnabled) ? true : false;
}

public Gui_OnMapStart()
{
    g_bGuiEnabled = GetConVarInt(g_hGuiEnabled) ? true : false;
}

public Gui_OnDBConnect()
{
    // Determine the difference in the clocks between MySQL and the game server
    SQL_TQuery(g_hDbConn, Query_TimeStamp, "SELECT UNIX_TIMESTAMP() AS time", _, DBPrio_Low);
}

// ###################### ACTIONS ######################

public Action:Command_Gui(client, args)
{
    if (g_bGuiEnabled && IsAuthed(client))
        CreateTimer(0.1, Event_ShowGui, client);

    return Plugin_Handled;
}

public Query_TimeStamp(Handle:owner, Handle:result, const String:error[], any:data) {
	if(result == INVALID_HANDLE) {
		LogError("Failed to get timestamp from SQL server.  Error: %s", error);
		time_offset = 0;
	} else if(!SQL_FetchRow(result)) {
		time_offset = 0;
	} else {
		time_offset = SQL_FetchInt(result, 0) - GetTime();
	}
}

public Action:Event_ShowGui(Handle:timer, any:client)
{
	if (client && !IsFakeClient(client))
	{
        Gui_Show(client);
	}
}

stock Gui_Show(client)
{  
    decl String:title[64];
    decl String:steamId[64];
    decl String:ipaddr[64];
    decl String:url[256];
    decl String:key[9];
    decl String:type[9];
    decl String:token[128];
    
    GetClientAuthString2( client, steamId, sizeof(steamId) );
    GetClientIP( client, ipaddr, sizeof(ipaddr) );
    GetServerType( type, sizeof(type) ); // Gets servertype bit

    GenerateKey(key, sizeof(key)); // Encrypts a time stamp
    GenerateToken(steamId, ipaddr, token, sizeof(token)); // Encrypts and returns md5 of steamid salt and ipaddr
    
    title = "HGItems Store - www.hellsgamers.com/store";
    url = "http://hgitems.hellsgamers.com/ingame/vgui/{STEAM_ID}/{KEY}{TOKEN}{TYPE}";

    ReplaceString( url, sizeof(url), "{STEAM_ID}", steamId);
    ReplaceString( url, sizeof(url), "{TYPE}", type);
    ReplaceString( url, sizeof(url), "{KEY}", key);
    ReplaceString( url, sizeof(url), "{TOKEN}", token);

    if (g_iGame == GAMETYPE_CSGO)
    {
        Format(url, sizeof(url),
               "http://hg.bortweb.com/premium/store.php?steamid=%s&type=%s&key=%s&token=%s",
               steamId, type, key, token);

        new Handle:pb = StartMessageOne("VGUIMenu", client);

        PbSetString(pb, "name", "info");
        PbSetBool(pb, "show", true);

        new Handle:subkey;

        subkey = PbAddMessage(pb, "subkeys");
        PbSetString(subkey, "name", "type");
        PbSetString(subkey, "str", "2"); // MOTDPANEL_TYPE_URL

        subkey = PbAddMessage(pb, "subkeys");
        PbSetString(subkey, "name", "title");
        PbSetString(subkey, "str", "TESTING");

        subkey = PbAddMessage(pb, "subkeys");
        PbSetString(subkey, "name", "msg");
        PbSetString(subkey, "str", url);

        EndMessage();
   }

    PrintToConsole(client, url);
    ShowMOTDPanel( client, title, url, MOTDPANEL_TYPE_URL );
}

stock GenerateToken(String:steamId[], String:ipaddr[], String:output[], maxlen)
{
    decl String:word[125];
    decl String:hex[125];
    decl String:md5[64];
    decl String:gui_password[33];
    decl String:salt[5];
    salt = "h(.%";
    
    GetConVarString(g_hGuiPassword, gui_password, sizeof(gui_password));
    
    FormatEx(word, sizeof(word), "%s%s%s", steamId, salt, ipaddr);
    EncodeRC4(word, gui_password, hex, sizeof(hex), strlen(word));
    
    MD5String(hex, md5, sizeof(md5));
    strcopy(output, maxlen, md5);

    return;
}

stock GetServerType(String:output[], maxlen) {
    new servertype;    
    decl String:type[9];

    new Handle:hType = FindConVar("hg_premium_server_type");
    servertype = GetConVarInt(hType);

    FormatEx(type, sizeof(type), "%i", servertype);

    strcopy(output, maxlen, type);

    return;
}

stock GenerateKey(String:output[], maxlen) {
	new time, write_length;
	decl String:word[5];
	decl String:hex[9];
	decl String:gui_password[33];
	
	GetConVarString(g_hGuiPassword, gui_password, sizeof(gui_password));

	time = GetTime() + time_offset;
	FormatEx(word, sizeof(word), "%c%c%c%c", time & 0xff, (time >> 8) & 0xff, (time >> 16) & 0xff, time >> 24);
	write_length = EncodeRC4(word, gui_password, hex, sizeof(hex), 4);
	strcopy(output, maxlen, hex);

	return write_length;
}

stock EncodeRC4(const String:input[], const String:pwd[], String:output[], maxlen, str_len = 0) {
	decl pwd_len,i,j,a,k;
	decl key[256];
	decl box[256];
	decl tmp;
	new write_length;
	pwd_len = strlen(pwd);
	if(str_len == 0) {
		str_len = strlen(input);
	}
	if(pwd_len > 0 && str_len > 0) {
		for(i=0;i<256;i++) {
			key[i] = pwd[i%pwd_len];
			box[i]=i;
		}
		i=0;
		j=0;
		for(;i<256;i++) {
			j = (j + box[i] + key[i]) & 0xff;
			tmp = box[i];
			box[i] = box[j];
			box[j] = tmp;
		}
		i=0;
		j=0;
		a=0;
		output[0] = '\0';
		for(;i<str_len;i++)	{
			a = (a + 1) & 0xff;
			j = (j + box[a]) & 0xff;
			tmp = box[a];
			box[a] = box[j];
			box[j] = tmp;
			k = box[((box[a] + box[j]) & 0xff)];
			write_length = Format(output, maxlen, "%s%02x", output, input[i] ^ k);
		}
		return write_length;
	} else {
		return -1;
	}
}

stock MD5String(const String:str[], String:output[], maxlen)
{
    decl x[2];
    decl buf[4];
    decl input[64];
    new i, ii;
    
    new len = strlen(str);
    
    // MD5Init
    x[0] = x[1] = 0;
    buf[0] = 0x67452301;
    buf[1] = 0xefcdab89;
    buf[2] = 0x98badcfe;
    buf[3] = 0x10325476;
    
    // MD5Update
    new in[16];

    in[14] = x[0];
    in[15] = x[1];
    
    new mdi = (x[0] >>> 3) & 0x3F;
    
    if ((x[0] + (len << 3)) < x[0])
    {
        x[1] += 1;
    }
    
    x[0] += len << 3;
    x[1] += len >>> 29;
    
    new c = 0;
    while (len--)
    {
        input[mdi] = str[c];
        mdi += 1;
        c += 1;
        
        if (mdi == 0x40)
        {
            for (i = 0, ii = 0; i < 16; ++i, ii += 4)
            {
                in[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];
            }
            // Transform
            MD5Transform(buf, in);
            
            mdi = 0;
        }
    }
    
    // MD5Final
    new padding[64] = {
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    new inx[16];
    inx[14] = x[0];
    inx[15] = x[1];
    
    mdi = (x[0] >>> 3) & 0x3F;
    
    len = (mdi < 56) ? (56 - mdi) : (120 - mdi);
    in[14] = x[0];
    in[15] = x[1];
    
    mdi = (x[0] >>> 3) & 0x3F;
    
    if ((x[0] + (len << 3)) < x[0])
    {
        x[1] += 1;
    }
    
    x[0] += len << 3;
    x[1] += len >>> 29;
    
    c = 0;
    while (len--)
    {
        input[mdi] = padding[c];
        mdi += 1;
        c += 1;
        
        if (mdi == 0x40)
        {
            for (i = 0, ii = 0; i < 16; ++i, ii += 4)
            {
                in[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];
            }
            // Transform
            MD5Transform(buf, in);
            
            mdi = 0;
        }
    }
    
    for (i = 0, ii = 0; i < 14; ++i, ii += 4)
    {
        inx[i] = (input[ii + 3] << 24) | (input[ii + 2] << 16) | (input[ii + 1] << 8) | input[ii];
    }
    MD5Transform(buf, inx);
    
    new digest[16];
    for (i = 0, ii = 0; i < 4; ++i, ii += 4)
    {
        digest[ii] = (buf[i]) & 0xFF;
        digest[ii + 1] = (buf[i] >>> 8) & 0xFF;
        digest[ii + 2] = (buf[i] >>> 16) & 0xFF;
        digest[ii + 3] = (buf[i] >>> 24) & 0xFF;
    }
    
    FormatEx(output, maxlen, "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
        digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]);
}

stock MD5Transform_FF(&a, &b, &c, &d, x, s, ac)
{
    a += (((b) & (c)) | ((~b) & (d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

stock MD5Transform_GG(&a, &b, &c, &d, x, s, ac)
{
    a += (((b) & (d)) | ((c) & (~d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

stock MD5Transform_HH(&a, &b, &c, &d, x, s, ac)
{
    a += ((b) ^ (c) ^ (d)) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

stock MD5Transform_II(&a, &b, &c, &d, x, s, ac)
{
    a += ((c) ^ ((b) | (~d))) + x + ac;
    a = (((a) << (s)) | ((a) >>> (32-(s))));
    a += b;
}

stock MD5Transform(buf[], in[])
{
    new a = buf[0];
    new b = buf[1];
    new c = buf[2];
    new d = buf[3];
    
    MD5Transform_FF(a, b, c, d, in[0], 7, 0xd76aa478);
    MD5Transform_FF(d, a, b, c, in[1], 12, 0xe8c7b756);
    MD5Transform_FF(c, d, a, b, in[2], 17, 0x242070db);
    MD5Transform_FF(b, c, d, a, in[3], 22, 0xc1bdceee);
    MD5Transform_FF(a, b, c, d, in[4], 7, 0xf57c0faf);
    MD5Transform_FF(d, a, b, c, in[5], 12, 0x4787c62a);
    MD5Transform_FF(c, d, a, b, in[6], 17, 0xa8304613);
    MD5Transform_FF(b, c, d, a, in[7], 22, 0xfd469501);
    MD5Transform_FF(a, b, c, d, in[8], 7, 0x698098d8);
    MD5Transform_FF(d, a, b, c, in[9], 12, 0x8b44f7af);
    MD5Transform_FF(c, d, a, b, in[10], 17, 0xffff5bb1);
    MD5Transform_FF(b, c, d, a, in[11], 22, 0x895cd7be);
    MD5Transform_FF(a, b, c, d, in[12], 7, 0x6b901122);
    MD5Transform_FF(d, a, b, c, in[13], 12, 0xfd987193);
    MD5Transform_FF(c, d, a, b, in[14], 17, 0xa679438e);
    MD5Transform_FF(b, c, d, a, in[15], 22, 0x49b40821);
    
    MD5Transform_GG(a, b, c, d, in[1], 5, 0xf61e2562);
    MD5Transform_GG(d, a, b, c, in[6], 9, 0xc040b340);
    MD5Transform_GG(c, d, a, b, in[11], 14, 0x265e5a51);
    MD5Transform_GG(b, c, d, a, in[0], 20, 0xe9b6c7aa);
    MD5Transform_GG(a, b, c, d, in[5], 5, 0xd62f105d);
    MD5Transform_GG(d, a, b, c, in[10], 9, 0x02441453);
    MD5Transform_GG(c, d, a, b, in[15], 14, 0xd8a1e681);
    MD5Transform_GG(b, c, d, a, in[4], 20, 0xe7d3fbc8);
    MD5Transform_GG(a, b, c, d, in[9], 5, 0x21e1cde6);
    MD5Transform_GG(d, a, b, c, in[14], 9, 0xc33707d6);
    MD5Transform_GG(c, d, a, b, in[3], 14, 0xf4d50d87);
    MD5Transform_GG(b, c, d, a, in[8], 20, 0x455a14ed);
    MD5Transform_GG(a, b, c, d, in[13], 5, 0xa9e3e905);
    MD5Transform_GG(d, a, b, c, in[2], 9, 0xfcefa3f8);
    MD5Transform_GG(c, d, a, b, in[7], 14, 0x676f02d9);
    MD5Transform_GG(b, c, d, a, in[12], 20, 0x8d2a4c8a);
    
    MD5Transform_HH(a, b, c, d, in[5], 4, 0xfffa3942);
    MD5Transform_HH(d, a, b, c, in[8], 11, 0x8771f681);
    MD5Transform_HH(c, d, a, b, in[11], 16, 0x6d9d6122);
    MD5Transform_HH(b, c, d, a, in[14], 23, 0xfde5380c);
    MD5Transform_HH(a, b, c, d, in[1], 4, 0xa4beea44);
    MD5Transform_HH(d, a, b, c, in[4], 11, 0x4bdecfa9);
    MD5Transform_HH(c, d, a, b, in[7], 16, 0xf6bb4b60);
    MD5Transform_HH(b, c, d, a, in[10], 23, 0xbebfbc70);
    MD5Transform_HH(a, b, c, d, in[13], 4, 0x289b7ec6);
    MD5Transform_HH(d, a, b, c, in[0], 11, 0xeaa127fa);
    MD5Transform_HH(c, d, a, b, in[3], 16, 0xd4ef3085);
    MD5Transform_HH(b, c, d, a, in[6], 23, 0x04881d05);
    MD5Transform_HH(a, b, c, d, in[9], 4, 0xd9d4d039);
    MD5Transform_HH(d, a, b, c, in[12], 11, 0xe6db99e5);
    MD5Transform_HH(c, d, a, b, in[15], 16, 0x1fa27cf8);
    MD5Transform_HH(b, c, d, a, in[2], 23, 0xc4ac5665);

    MD5Transform_II(a, b, c, d, in[0], 6, 0xf4292244);
    MD5Transform_II(d, a, b, c, in[7], 10, 0x432aff97);
    MD5Transform_II(c, d, a, b, in[14], 15, 0xab9423a7);
    MD5Transform_II(b, c, d, a, in[5], 21, 0xfc93a039);
    MD5Transform_II(a, b, c, d, in[12], 6, 0x655b59c3);
    MD5Transform_II(d, a, b, c, in[3], 10, 0x8f0ccc92);
    MD5Transform_II(c, d, a, b, in[10], 15, 0xffeff47d);
    MD5Transform_II(b, c, d, a, in[1], 21, 0x85845dd1);
    MD5Transform_II(a, b, c, d, in[8], 6, 0x6fa87e4f);
    MD5Transform_II(d, a, b, c, in[15], 10, 0xfe2ce6e0);
    MD5Transform_II(c, d, a, b, in[6], 15, 0xa3014314);
    MD5Transform_II(b, c, d, a, in[13], 21, 0x4e0811a1);
    MD5Transform_II(a, b, c, d, in[4], 6, 0xf7537e82);
    MD5Transform_II(d, a, b, c, in[11], 10, 0xbd3af235);
    MD5Transform_II(c, d, a, b, in[2], 15, 0x2ad7d2bb);
    MD5Transform_II(b, c, d, a, in[9], 21, 0xeb86d391);
    
    buf[0] += a;
    buf[1] += b;
    buf[2] += c;
    buf[3] += d;
}
