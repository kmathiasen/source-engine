import es, playerlib, gamethread, random, usermsg, os.path, urllib, time, cPickle, popuplib, sys

try:
	if 'zombiehorror.levels' in sys.modules:
		del sys.modules['zombiehorror.levels']
	attributes = __import__('zombiehorror.levels').levels.attributes
except:
	es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultERROR: Corrupt levels.py, cannot load Zombie Horror!')
	es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultTerminating proccess, please double check your levels.py!')
	raise ImportError('[Zombie Horror]: Could not load levels.py, please syntax check')

# The only options that are in here are dictionary options that I'm too lazy to make for server vars but will be eventually
### Dict Options ###

ammo = {
	'ammo_338mag_max': 666,
	'ammo_357sig_max': 666,
	'ammo_45acp_max': 666,
	'ammo_50AE_max': 666,
	'ammo_556mm_box_max': 666,
	'ammo_556mm_max': 666,
	'ammo_57mm_max': 666,
	'ammo_762mm_max': 666,
	'ammo_9mm_max': 666,
	'ammo_buckshot_max': 666
}

#### No Config Below ###

### Addon Info ###

info = es.AddonInfo() 
info['name']        = "Zombie Horror" 
info['version']     = "1.1.6b" 
info['author']      = "Bonbon AKA: Bonbon367" 
info['url']         = "http://addons.eventscripts.com/addons/view/zombiehorror" 
info['description'] = "A cool zombie gameplay requested by Undead for better speed + performance" 

es.ServerVar('zh2_version', info['version'], 'Zombie Horror made by Bonbon AKA Bonbon367').makepublic()

### Server Vars ### 

sv = es.ServerVar
es.ServerVar('gun').set(0)

sv_options = {
	'zh_zombie_health_min': 200,
	'zh_zombie_health_max': 300,
	'zh_zombie_health_level_bonus_multiplier': 3,
	'zh_zombie_speed_min': 0.8,
	'zh_zombie_speed_max': 1.2,
	'zh_zombie_speed_level_bonus_multiplier': 0.01,
	'zh_zombie_armor_min': 50,
	'zh_zombie_armor_max': 100,
	'zh_zombie_armor_level_bonus_multiplier': 2,
	'zh_zombie_knockback_min': 5,
	'zh_zombie_knockback_max': 10,
	'zh_zombie_knockback_level_multiplier_minus': 1,
	'zh_boss_chance': 10,
	'zh_boss_model': 'humans/corpse1',
	'zh_boss_health_min': 1000,
	'zh_boss_health_max': 3333,
	'zh_boss_speed_min': 1,
	'zh_boss_speed_max': 1.75,
	'zh_boss_armor_min': 1000,
	'zh_boss_armor_max': 3333,
	'zh_boss_knockback_max': 6,
	'zh_boss_knockback_min': 3,
	'zh_boss_sound': 0,
	'zh_fog': 1,
	'zh_fog_rgb': '100,100,100',
	'zh_fog_rgb2': '150,150,150',
	'zh_zombie_models': 'zombie/classic,zombie/fast,zombie/poison,humans/charple01,humans/charple02,humans/charple03,humans/charple04',
	'zh_restricted_weapons': 'm249,g3sg1,sg550,awp,flashbang,smokegrenade',
	'zh_dissolve_on_death': 1,
	'zh_stock_zombies': 3,
	'zh_stock_multiplier': 3,
	'zh_rounds_to_win': 5,
	'zh_hud_update_time': 7,
	'zh_start_cash': 16000,
	'zh_bots': 10,
	'zh_enable_knockback': 1,
	'zh_fog_start': 200,
	'zh_fog_end': 600,
	'zh_ambiance': 0,
	'zh_ambiance_delay': 0,
	'zh_round_end_overlay_win': 0,
	'zh_round_end_overlay_lose': 0,
	'zh_round_start_overlay': 0,
	'zh_overlay_sound': 0,
	'zh_stock_add': 1,
	'zh_dead_talk': 1,
	'zh_zspawn': 1,
	'zh_excluded_dead_characters': '!@/',
	'zh_zombie_gravity_min': 0.8,
	'zh_zombie_gravity_max': 1.2,
	'zh_zombie_gravity_level_multiplier': 0.05,
	'zh_boss_gravity_min': 0.75,
	'zh_boss_gravity_max': 1,
	'zh_zombie_spawn_protection_time': 5,
	'zh_machine_gun_ammo': 100,
	'zh_headshot_only': 0,
	'zh_zombie_regen_delay': 5,
	'zh_zombie_level_regen_multiplier': 0.1,
	'zh_zombie_regen_min': 1,
	'zh_zombie_regen_max': 3,
	'zh_beacon_last_zombie': 1,
	'zh_napalm': 0,
	'zh_napalm_time': 3,
	'zh_health_kill_bonus': 3,
	'zh_stop_camp': 1,
	'zh_camp_range': 200,
	'zh_min_zombies_beacon': 3,
	'zh_camp_time': 20,
	'zh_zombie_regen_max_health': 400,
	'zh_remove_ragdolls': 1,
	'zh_camper_push': 1,
	'zh_camper_damage': 5,
	'zh_beacon_camping_zombies': 1,
	'zh_human_noblock': 1,
	'zh_ct_weapons': 'elite,sg550,ak47',
	'zh_end_map_on_win': 1,
	'zh_zombie_player_health_multiplier': 1.5,
	'zh_zombie_player_armor_multiplier': 5,
	'zh_weapon_zoom': 1,
	'zh_zoom_weapons': 'm3,xm1014',
	'zh_boss_hp_bonus': 6,
	'zh_anounce_boss_killed': 1,
	'zh_darkness': 'g',
	'zh_few_humans_hp_bonus': 2,
	'zh_start_hp_value': 200,
	'zh_per_human_hp_loss': 10,
	'zh_m249_max': 2,
	'zh_anti_rejoin_to_spawn': 1,
	'zh_auto_update': 1,
	'zh_pistol_king_kills_needed': 50,
	'zh_survivor_kills_needed': 50,
	'zh_rampage_kills_needed': 20,
	'zh_boss_killer_kills_needed': 25,
	'zh_anti_zombie_kills': 500,
	'zh_pyro_lights': 50,
	'zh_humiliator_kills': 30,
	'zh_announce_achievement_unlocked': 1,
	'zh_achievements': 1,
	'zh_enabled_achievements': 'PS,SV,RPG,BS,AZ,PY,HUM',
	'zh_players_in_top': 10,
}

### Globals ###

t_prices = {}
messages = {}
ct_models = {}
zspawn = {}
fogged = 0
temp_zombies = 0
wins = 0
checked = 0
coords = {}
bossess = []
help_menu = None
zh_command_args = {
	'add': {
		'levelmessage': [4, '<level> <message>'],
		'tgun': [4, '<gun> <cost>'],
		'humanmodel': [4, '<level> <model>']
	},
}

deadpeople = []
sounds = []

### Loads ###
def load():
	global help_menu, sounds, AC

	for type in ammo:
		es.server.queuecmd('%s %s'%(type, ammo[type]))

	for a in sv_options:
		es.ServerVar(a).set(sv_options[a])

	if not str(sv('zh_ambiance')) == '0':
		ambiance_loop()

	if not es.exists('saycommand', '!zspawn'):
		es.regsaycmd('!zspawn', 'zombiehorror/do_zspawn')

	if not es.exists('clientcommand', 'zoom_toggle'):
		es.regclientcmd('zoom_toggle', 'zombiehorror/zoom_toggle')

	for ac_command in ['achievements', 'achievments', 'achievement', 'achievment', 'ac']:
		for command in [ac_command, '!' + ac_command]:
			if not es.exists('saycommand', command):
				es.regsaycmd(command, 'zombiehorror/ac_command')

	if not es.exists('command', 'zh'):
		es.regcmd('zh', 'zombiehorror/zh')

	if not es.exists('command', 'zh_update'):
		es.regcmd('zh_update', 'zombiehorror/update')

	es.server.queuecmd('mp_restartgame 2')

	if os.path.isfile(es.getAddonPath('zombiehorror') + '/zombiehorror.cfg'):
		es.server.cmd('es_xmexec ../addons/eventscripts/zombiehorror/zombiehorror.cfg')
	else:
		es.dbgmsg(0, 'Zombie Horror: Config not found')

	set_pythonvars()
	AC = Achievements()

	for a in range(1, 10):
		if a < 5:
			sounds.append('npc/zombie/moan_loop' + str(a))
		if a < 4:
			sounds.append('npc/zombie/zombie_die' + str(a))
			sounds.append('npc/zombie/zombie_alert' + str(a))
		if sounds < 7:
			sounds.append('npc/zombie/zombie_pain' + str(a))
		sounds.append('npc/zombie/zombie_voice_idle' + str(a))

	for userid in playerlib.getUseridList('#human'):
		pd = {}
		if es.getplayersteamid(userid) in AC.pi:
			pd = AC.pi[es.getplayersteamid(userid)]
		AC.pd[userid] = AchievementPlayer(userid, pd)

	add_downloads()
	zh_fog_start()
	knife_bot()
	add_bots()

def unload():
	if es.getUseridList():
		es.server.queuecmd('es_xfire %s env_fog_controller kill'%es.getUseridList()[0])

	for loop in ['update_hud', 'ambiance_loop', 'heal_loop', 'beacon_loop', 'camp_loop', 'check_quota', 'advert_loop', 'update_loop']:
		gamethread.cancelDelayed(loop)

	if es.exists('saycommand', '!zspawn'):
		es.unregsaycmd('!zspawn')
	es.addons.unregisterClientCommandFilter(zh_buy_filter)

	if es.exists('clientcommand', 'zoom_toggle'):
		es.unregclientcmd('zoom_toggle')

	for userid in es.getUseridList():
		gamethread.cancelDelayed('check_weapon_%s'%userid)

	kick_bots()
	es.lightstyle(0, 'g')
	es.server.queuecmd('exec server.cfg')

	for ac_command in ['achievements', 'achievments', 'achievement', 'achievment', 'ac']:
		for command in [ac_command, '!' + ac_command]:
			if es.exists('saycommand', command):
				es.unregsaycmd(command)

#### Events ###

def player_spawn(ev):
	userid = ev['userid']
	Player(userid).check_model()
	Player(userid).set_attributes(1)
	Player(userid).check_team()
	Player(userid).stop_spawn()
	Player(userid).start_spawn_protection()
	Player(userid).stop_camp()
	Player(userid).health_bonus()

	if playerlib.getPlayer(userid).get('primary') == 'weapon_m249':
		if int(sv('zh_machine_gun_ammo')):
			gamethread.delayed(0, playerlib.getPlayer(userid).set, ('ammo', [1, int(sv('zh_machine_gun_ammo'))]))

	Player(userid).noblock()
	if not random.randint(0, 10):
		zh_fog_start()

def player_death(ev):
	userid = int(ev['userid'])
	if not ev['es_attackersteamid'] == 'BOT':
		AC.pd[int(ev['attacker'])].player_death(userid, ev['weapon'])

	if not ev['es_steamid'] == 'BOT':
		AC.pd[userid].player_dead()

	p = Player(userid)
	p.dissolve()
	p.check_respawn()
	p.play_sound()
	p.stop_spawn_protection()
	p.stop_camp()

	ap = Player(ev['attacker'])
	ap.heal()
	ap.check_boss(userid, ev['weapon'])
	ap.check_height(userid)

	deadpeople.append(ev['es_steamid'])

def es_map_start(ev):
	global wins, fogged, checked
	wins = fogged = checked = 0

	add_downloads()
	knife_bot()

	es.server.queuecmd('es_xmexec ../addons/eventscripts/zombiehorror/zombiehorror.cfg')
	gamethread.delayed(0, check_map_config, str(es.ServerVar('eventscripts_currentmap')))

def item_pickup(ev):
	Player(ev['userid']).check_restrict(ev['item'])
	Player(ev['userid']).allowed_m249(1, 1)

	if ev['item'] == 'c4':
		es.server.queuecmd('es_xfire %s weapon_c4 kill'%ev['userid'])

def player_hurt(ev):
	if ev['userid'] == '0':
		return

	p = Player(ev['userid'])
	if not ev['attacker'] == '0':
		pa = Player(ev['attacker'])
		pa.check_restrict(ev['weapon'])
		pa.stop_spawn_protection()
	p.knockback(ev['attacker'], int(ev['dmg_health']))

	if not random.randint(0, 7):
		Player(ev['userid']).play_sound()

	if int(sv('zh_headshot_only')):
		if not int(ev['hitgroup']) == 1 and not ev['weapon'] in ['weapon_knife', 'weapon_hegrenade']:
			es.setplayerprop(ev['userid'], es.getplayerprop(ev['userid'], 'CBasePlayer.m_iHealth') + int(ev['dmg_health']))

	if ev['weapon'] == 'hegrenade':
		p.napalm()

	if not ev['attacker'] == '0':
		if not ev['es_attackersteamid'] == 'BOT':
			AC.pd[int(ev['attacker'])].player_hurt(int(ev['userid']), ev['weapon'])

def round_start(ev):
	global temp_zombies, checked, bossess, deadpeople
	set_pythonvars()
	temp_zombies = es.getplayercount(3) * int(sv('zh_stock_zombies')) + int(wins * float(sv('zh_stock_multiplier'))) + int(sv('zh_stock_add'))

	for userid in es.getUseridList():
		Player(userid).overlay(1)

	if wins == rounds_to_win and not str(sv('zh_boss_sound')) == '0':
		for userid in es.getUseridList():
			es.cexec(userid, 'play %s'%str(sv('zh_boss_sound')))

	knife_bot()
	if checked:
		add_bots()
	checked += 1

	if es.getUseridList():
		es.server.queuecmd('es_xfire %s hostage_entity kill'%es.getUseridList()[0])

	gamethread.cancelDelayed('camp_loop')
	gamethread.cancelDelayed('beacon_loop')

	camp_loop()
	beacon_loop()

	bossess = []
	deadpeople = []

	es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultIs active. Visit our site at #lightgreenzombie-horror.com')
	es.lightstyle(0, str(sv('zh_darkness')))

def round_freeze_end(ev):
	if 0 < wins < rounds_to_win and not boss_level():
		es.msg('#multi', '#lightgreenWARNING: #defaultQuarantine level #lightgreen%s#default has been breeched! KILL ON SIGHT!'%wins)

	elif wins == rounds_to_win:
		for userid in es.getUseridList():
			usermsg.shake(userid, 40, 5.5)
		es.msg('#multi', '#lightgreenWARNING: #defaultQuarantine level #lightgreen%s#default has been breeched! ZOMBIES HAVE EVOLVED!'%wins)

	elif wins > rounds_to_win:
		if es.getUseridList():
			es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultCongratulations on defeating all the zombies, The game will end in #lightgreen5#default seconds')
			gamethread.delayed(5, es.server.queuecmd, 'es_entcreate %s game_end;es_fire %s game_end endgame'%(es.getUseridList()[0], es.getUseridList()[0]))

	for userid in es.getUseridList():
		Player(userid).stop_camp()

def round_end(ev):
	global wins
	set_pythonvars()

	if es.getplayercount(3) > 0:
		wins = max(0, wins + (1 if not len(playerlib.getPlayerList('#bot,#alive')) else -1))
		if wins > rounds_to_win:
			if int(sv('zh_end_map_on_win')):
				es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultCongratulations on defeating all the zombies, The game will end in #lightgreen5#default seconds')
				gamethread.delayed(5, es.server.queuecmd, 'es_entcreate %s game_end;es_fire %s game_end endgame'%(es.getUseridList()[0], es.getUseridList()[0]))
			else:
				es.msg('#multi', '#lightgreen[Zombie Horror]: #defaultCongratulations on defeating all the zombies, too bad you missed the babies')
				wins = 0

		for userid in es.getUseridList():
			Player(userid).overlay(2 if not len(playerlib.getPlayerList('#bot,#alive')) else 3)

		if int(sv('zh_achievements')):
			for userid in playerlib.getUseridList('#human'):
				AC.pd[userid].pd['Rampage'] = 0
				AC.pd[userid].save_data()
			AC.save_data()
	else:
		es.msg('Not enough players to start')

def player_team(ev):
	Player(ev['userid']).check_team()

def player_activate(ev):
	Player(ev['userid']).start_spawn()
	Player(ev['userid']).stop_camp()

	steamid = ev['es_steamid']
	if not steamid == 'BOT':
		pd = {}
		if steamid in AC.pi:
			pd = AC.pi[steamid]
		AC.pd[int(ev['userid'])] = AchievementPlayer(int(ev['userid']), pd)

def player_disconnect(ev):
	userid = int(ev['userid'])
	Player(str(userid)).stop_spawn()

	if userid in coords:
		del coords[userid]

	if not userid in AC.pd:
		return

	if not es.getplayersteamid(userid) == 'BOT':
		AC.pd[userid].save_data()
		del AC.pd[userid]

def player_say(ev):
	text = ev['text']
	userid = ev['userid']

	if es.getplayerprop(ev['userid'], 'CBasePlayer.pl.deadflag') and int(sv('zh_dead_talk')) and not text[0] in str(sv('zh_excluded_dead_characters')):
		message = '\1*DEAD* \3%s \1: %s'%(es.getplayername(userid), text)
		index = playerlib.getPlayer(userid).attributes['index']

		for alive_players in playerlib.getUseridList('#alive'):
			usermsg.saytext2(alive_players, index, message)

### Classes ###

class AchievementPlayer(object):
	def __init__(self, userid, pd={}):
		self.userid = userid
		self.steamid = es.getplayersteamid(userid)
		self.pd = pd
		self.cvars = AC.cvars

		self.check_keys()

	def check_keys(self):
		default = {
			'name': es.getplayername(self.userid), 
			'locked': filter(lambda x: AC.abrs[x] in str(sv('zh_enabled_achievements')), self.cvars.keys()), 
			'unlocked': [],
		}

		if not self.pd:
			self.pd = default

		for key in default:
			if not key in self.pd:
				self.pd[key] = default[key]

		for var in default['locked']:
			if not var in self.pd:
				self.pd[var] = 0

	def player_death(self, victim, weapon):
		check = ''
		locked = self.pd['locked']

		if 'Pistol King' in locked:
			if not weapon in ['glock', 'usp', 'p228', 'deagle', 'elite', 'fiveseven']:
				self.pd['Pistol King'] = 0
			else:
				self.pd['Pistol King'] += 1
				check += 'Pistol King,'

		if 'Survivor' in locked:
			self.pd['Survivor'] += 1
			check += 'Survivor,'

		if 'Humiliator' in locked:
			if weapon == 'knife':
				self.pd['Humiliator'] += 1
				check += 'Humiliator,'

		if 'Anti-Zombie' in locked:
			self.pd['Anti-Zombie'] += 1
			check += 'Anti-Zombie,'

		if 'Boss Slayer' in locked:
			if victim in bossess:
				self.pd['Boss Slayer'] += 1
				check += 'Boss Slayer,'

		if 'Rampage' in locked:
			self.pd['Rampage'] += 1
			check += 'Rampage,'

		if check:
			for to_check in check.split(',')[0:-1]:
				if self.pd[to_check] >= int(sv('zh_' + self.cvars[to_check])):
					AC.achieve(self.userid, to_check)

	def player_hurt(self, victim, weapon):
		locked = self.pd['locked']

		if victim == self.userid:
			return

		if self.pd['Pistol King']:
			if 'Pistol King' in locked:
				if not weapon in ['glock', 'usp', 'p228', 'deagle', 'elite', 'fiveseven']:
					self.pd['Pistol King'] = 0

		if 'Pyro' in locked:
			if weapon == 'hegrenade':
				if int(sv('zh_napalm')):
					self.pd['Pyro'] += 1
					if self.pd['Pyro'] >= int(sv('zh_pyro_lights')):
						AC.achieve(self.userid, 'Pyro')

	def player_dead(self):
		for reset in ['Survivor']:
			self.pd[reset] = 0

	def save_data(self):
		AC.pi[self.steamid] = self.pd

class Achievements(object):
	def __init__(self):
		self.pd = {}
		self.pi = {}
		self.unlocked = {}

		if os.path.isfile(es.getAddonPath('zombiehorror') + '/players.db'):
			pa = open(es.getAddonPath('zombiehorror') + '/players.db')
			self.pi = cPickle.load(pa)
			pa.close()

		self.descriptions = {
			'Pistol King': 'Get %s kills in a row with a pistol (Without using other guns)'%int(sv('zh_pistol_king_kills_needed')),
			'Survivor': 'Get %s kills in a row, without dieing'%int(sv('zh_survivor_kills_needed')),
			'Rampage': 'Kill %s zombies in one round'%int(sv('zh_rampage_kills_needed')),
			'Boss Slayer': 'Kill %s bosses'%int(sv('zh_boss_killer_kills_needed')),
			'Anti-Zombie': 'Kill %s zombies'%int(sv('zh_anti_zombie_kills')),
			'Pyro': 'Light %s zombies on fire'%int(sv('zh_pyro_lights')),
			'Humiliator': 'Kill %s zombies with a knife'%int(sv('zh_humiliator_kills')),
		}

		self.cvars = {
			'Pistol King': 'pistol_king_kills_needed',
			'Survivor': 'survivor_kills_needed',
			'Rampage': 'rampage_kills_needed',
			'Boss Slayer': 'boss_killer_kills_needed',
			'Anti-Zombie': 'anti_zombie_kills',
			'Pyro': 'pyro_lights',
			'Humiliator': 'humiliator_kills',
		}

		self.abrs = {
			'Pistol King': 'PK',
			'Survivor': 'SV',
			'Rampage': 'RPG',
			'Boss Slayer': 'BS',
			'Anti-Zombie': 'AZ',
			'Pyro': 'PY',
			'Humiliator': 'HUM',
		}

		ac_main_menu = popuplib.easymenu('Main Menu', '_popup_choice', self.ac_main_select)
		ac_main_menu.addoption('Achievements', 'Achievements')
		ac_main_menu.addoption('Top Achievers', 'Top Achievers')
		ac_main_menu.addoption('Player Stats', 'Player Stats')

	def ac_main_select(self, userid, choice, popupid):
		if choice == 'Achievements':
			self.make_ac_menu(userid)

		elif choice == 'Top Achievers':

			players_in_top = int(sv('zh_players_in_top')) + 1
			top = sorted(self.unlocked, key=lambda x: self.unlocked[x]['unlocked'], reverse=True)

			topmenu = popuplib.easymenu('Top', '_popup_choice', self.top_select)
			for steamid in top:
				players_in_top -= 1
				if players_in_top <= 0:
					break

				topmenu.addoption(steamid, self.unlocked[steamid]['name'])

			popuplib.send('Top', userid)

		elif choice == 'Player Stats':
			psmenu = popuplib.easymenu('Player Stats', '_popup_choice', self.ps_select)
			for userid2 in playerlib.getUseridList('#human'):
				psmenu.addoption(userid2, es.getplayername(userid2))
			popuplib.send('Player Stats', userid)

	def top_select(self, userid, choice, popupid):
		unlocked_menu = popuplib.easymenu('Unlocked', '_popup_choice', self.unlocked_select)
		for unlocked in self.unlocked[choice]['unlocked']:
			unlocked_menu.addoption(unlocked, unlocked)
		popuplib.send('Unlocked', userid)

	def unlocked_select(self, userid, choice, popupid):
		popuplib.send('Top', userid)

	def ps_select(self, userid, choice, popupid):
		self.make_ac_menu(choice, userid)

	def make_ac_menu(self, userid, send_userid=None):
		if not es.exists('userid', userid):
			es.tell(send_userid, '#multi', '#lightgreen[Zombie Horror]: #defaultuserid no longer exists')
			return

		if not send_userid:
			send_userid = userid

		unlocked = self.pd[userid].pd['unlocked']
		locked = self.pd[userid].pd['locked']

		ac_menu = popuplib.easymenu('Achievements', '_popup_choice', self.ac_select)
		for ac in unlocked:
			ac_menu.addoption(ac, '[Unlocked] %s'%ac)

		for ac in locked:
			ac_menu.addoption(ac, '[Locked]: %s'%ac)
		popuplib.send('Achievements', send_userid)

	def ac_select(self, userid, choice, popupid):
		ac_stat_menu = popuplib.easymenu('Status', '_popup_choice', self.ac_stat_select)
		ac_stat_menu.addoption(['Description', choice], 'Description')
		ac_stat_menu.addoption(choice, 'Status')
		popuplib.send('Status', userid)

	def ac_stat_select(self, userid, choice, popupid):
		if choice[0] == 'Description':
			es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #default' + self.descriptions[choice[1]])
			return
		es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: %s/%s'%(self.pd[userid].pd[choice], sv('zh_' + self.cvars[choice])))

	def achieve(self, userid, ac_name):
		self.pd[userid].pd['locked'].remove(ac_name)
		self.pd[userid].pd['unlocked'].append(ac_name)

		es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultYou have unlocked the #lightgreen%s#default achievement!'%ac_name)
		if int(sv('zh_announce_achievement_unlocked')):
			es.msg('#multi', '#lightgreen[Zombie Horror]: %s#default has unlocked the #lightgreen%s#default achievement!'%(es.getplayername(userid), ac_name))

		steamid = es.getplayersteamid(userid)
		if not steamid in self.unlocked:
			self.unlocked[steamid] = {'unlocked': [], 'name': es.getplayername(userid)}
		self.unlocked[steamid]['unlocked'].append(ac_name)

		self.save_data()

	def save_data(self):
		pa = open(es.getAddonPath('zombiehorror') + '/players.db', 'w')
		cPickle.dump(self.pi, pa)
		pa.close()

class Player:
	def __init__(self, userid):
		self.userid = userid
		self.steamid = es.getplayersteamid(userid)

	def dissolve(self):
		if dissolve_on_death:
			if not es.getplayerprop(self.userid, 'CBasePlayer.pl.deadflag'):
				es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', 0)
				es.server.queuecmd('es_xfire %s !self ignite'%self.userid)

			es.server.queuecmd('es_give %s env_entity_dissolver'%self.userid)
			es.server.queuecmd('es_xfire %s env_entity_dissolver AddOutput "target cs_ragdoll"'%self.userid)
			es.server.queuecmd('es_xfire %s env_entity_dissolver AddOutput "magnitude 1"'%self.userid)
			es.server.queuecmd('es_xfire %s env_entity_dissolver AddOutput "dissolvetype %s"'%(self.userid, random.randint(0, 3)))
			es.server.queuecmd('es_xfire %s env_entity_dissolver Dissolve'%self.userid)
			gamethread.delayed(1, es.server.queuecmd, 'es_xfire %s env_entity_dissolver kill'%self.userid)

		if remove_ragdolls:
			gamethread.cancelDelayed('remove_ragdolls')
			gamethread.delayedname(0.5, 'remove_ragdolls', es.server.queuecmd, 'es_xfire %s cs_ragdoll kill'%self.userid)

	def check_restrict(self, weapon):
		if self.steamid == 'BOT' and not 'knife' in weapon:
			es.server.queuecmd('es_xgive %s player_weaponstrip'%self.userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip StripWeaponsAndSuit'%self.userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip kill'%self.userid)
			es.server.queuecmd('es_xgive %s weapon_knife'%self.userid)

		elif weapon.replace('weapon_', '') in str(sv('zh_restricted_weapons')):
			handle = es.getplayerhandle(self.userid)
			for index in es.createentitylist('weapon_%s'%weapon.replace('weapon_', '')):
				if handle == int(es.getindexprop(index, "CBaseEntity.m_hOwnerEntity")):
					es.server.queuecmd('es_xremove %s'%index)
					es.tell(self.userid, '#multi', '#greenSorry, the #lightgreen%s #greenis restricted'%(weapon.replace('weapon_', '')))
					es.sexec(self.userid, 'lastinv')
					break

	def check_respawn(self):
		global temp_zombies
		if self.steamid == 'BOT':
			if temp_zombies > 0:
				temp_zombies -= 1
				es.server.queuecmd('est_spawn %s'%self.userid)

	def set_attributes(self, model):
		if self.steamid == 'BOT':
			if not wins in attributes:
				if random.randint(1, 100) > float(sv('zh_boss_chance')) or wins < rounds_to_win:
					self.set_attributes_norm()
				else:
					bossess.append(int(self.userid))
					playerlib.getPlayer(self.userid).set('model', random.choice(str(sv('zh_boss_model')).split(',')))
					es.server.queuecmd('est_setgravity %s %s'%(self.userid, random_value(float(sv('zh_boss_gravity_min')), float(sv('zh_boss_gravity_max')))))

					es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', random_value(float(sv('zh_boss_health_min')), int(sv('zh_boss_health_max'))))
					es.setplayerprop(self.userid, 'CBasePlayer.localdata.m_flLaggedMovementValue', random_value(float(sv('zh_boss_speed_min')), float(sv('zh_boss_speed_max'))))
					es.setplayerprop(self.userid, 'CCSPlayer.m_ArmorValue', random_value(int(sv('zh_boss_armor_min')), int(sv('zh_boss_armor_max'))))
				es.setplayerprop(self.userid, 'CCSPlayer.m_iAccount', 0)
			else:
				atrs = attributes[wins]
				if random.randint(0, 100) < atrs['chance']:
					if atrs['boss']:
						bossess.append(int(self.userid))

					playerlib.getPlayer(self.userid).set('model', random.choice(atrs['model'].split(',')))
					es.server.queuecmd('est_setgravity %s %s'%(self.userid, random_value(atrs['min_gravity'], atrs['max_gravity'])))

					es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', random_value(atrs['min_health'], atrs['max_health']))
					es.setplayerprop(self.userid, 'CBasePlayer.localdata.m_flLaggedMovementValue', random_value(atrs['min_speed'], atrs['max_speed']))
					es.setplayerprop(self.userid, 'CCSPlayer.m_ArmorValue', random_value(atrs['min_armor'], atrs['max_armor']))
				else:
					self.set_attributes_norm()
		else:
			if int(sv('zh_start_cash')):
				es.setplayerprop(self.userid, 'CCSPlayer.m_iAccount', int(sv('zh_start_cash')))

	def set_attributes_norm(self):
		playerlib.getPlayer(self.userid).set('model', random.choice(zombie_models))
		es.server.queuecmd('est_setgravity %s %s'%(self.userid, random_value(gravity_min, gravity_max) - (wins * gravity_multiplier)))

		es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', random_value(health_min, health_max) + (wins * health_multiplier) + (float(sv('zh_zombie_player_health_multiplier')) * es.getplayercount()))
		es.setplayerprop(self.userid, 'CBasePlayer.localdata.m_flLaggedMovementValue', random_value(speed_min, speed_max) + (wins * speed_multiplier))
		es.setplayerprop(self.userid, 'CCSPlayer.m_ArmorValue', random_value(armor_min, armor_max) + (wins * armor_multiplier) + (float(sv('zh_zombie_player_armor_multiplier')) * es.getplayercount()))

	def hud(self):
		humans = 0
		zombies = 0

		for userid in playerlib.getUseridList('#human,#alive'):
			humans += 1

		for userid in playerlib.getUseridList('#bot,#alive'):
			zombies += 1
		usermsg.hudhint(self.userid, '!!! Zombie Horror !!!\nHumans: %s\nZombies: %s\nDifficulty: %s\nReserve: %s'%(humans, zombies, messages[wins], temp_zombies))

	def play_sound(self):
		if self.steamid == 'BOT':
			sound = random.choice(sounds)
			es.emitsound('player', self.userid, sound + '.wav', 0.75, 0.4)
			gamethread.delayed(3, es.stopsound, (self.userid, sound + '.wav'))

	def check_team(self):
		if es.exists('userid', self.userid):
			if self.steamid == 'BOT':
				if not es.getplayerteam(self.userid) == 2:
					es.server.queuecmd('est_team %s 2'%self.userid)
				return

			if es.getplayerteam(self.userid) == 2:
				es.server.queuecmd('est_team %s 3'%self.userid)
				es.tell(self.userid, '#multi', '#lightgreen[Zombie Horror]: #defaultOnly #lightgreenZombies #defaultcan be on the #lightgreenTerrorists')

	def knockback(self, attacker, damage):
		if self.steamid == 'BOT':
			if enable_knockback:
				if int(attacker) and not int(self.userid) == int(attacker):
					if not wins in attributes:
						knockback = random_value(knockback_min if wins < rounds_to_win else float(sv('zh_boss_knockback_min')), knockback_max if wins < rounds_to_win else float(sv('zh_boss_knockback_max')))
						knockback *= int(damage)
						knockback -= knockback_minus * wins if wins < rounds_to_win else 0
					else:
						atrs = attributes[wins]
						knockback = random_value(atrs['min_knockback'], atrs['max_knockback'])
						knockback *= int(damage)

					x, y, z = playerlib.getPlayer(attacker).get('viewvector')
					es.setplayerprop(self.userid, 'CBasePlayer.localdata.m_vecBaseVelocity', '%s,%s,%s'%(x * knockback, y * knockback, z * knockback))

	def overlay(self, reason):
		if not self.steamid == 'BOT':
			overlays = {1: str(sv('zh_round_start_overlay')), 2: str(sv('zh_round_end_overlay_win')), 3: str(sv('zh_round_end_overlay_lose'))}
			if not overlays[reason] == '0':
				es.cexec(self.userid, 'r_screenoverlay %s'%overlays[reason])
				if not str(sv('zh_overlay_sound')) == '0':
					es.cexec(self.userid, 'play %s'%str(sv('zh_overlay_sound')))

	def stop_spawn(self):
		if str(self.userid) in zspawn:
			del zspawn[str(self.userid)]

	def start_spawn(self):
		zspawn[str(self.userid)] = 1

	def start_spawn_protection(self):
		if float(sv('zh_zombie_spawn_protection_time')):
			if self.steamid == 'BOT':
				es.server.queuecmd('est_god %s 1'%self.userid)
				gamethread.delayedname(float(sv('zh_zombie_spawn_protection_time')), 'spawn_protection_%s'%self.userid, self.stop_spawn_protection)

	def stop_spawn_protection(self):
		if self.steamid == 'BOT':
			if float(sv('zh_zombie_spawn_protection_time')):
				es.server.queuecmd('est_god %s 0'%self.userid)

	def napalm(self):
		if self.steamid == 'BOT':
			if int(sv('zh_napalm')):
				self.burn(float(sv('zh_napalm_time')))

	def burn(self, time):
		es.server.queuecmd('es_xfire %s !self ignite'%self.userid)
		gamethread.delayed(float(sv('zh_napalm_time')), self.extinguish)

	def extinguish(self): # WE ALL WUB YOU, FREDDUKES :D
		napalmlist = es.createentitylist('entityflame')
		handle = es.getplayerhandle(self.userid)

		for flame_entity in napalmlist:
			string = es.getindexprop(flame_entity, 'CEntityFlame.m_hEntAttached')
			if string == handle:
				es.setindexprop(flame_entity, 'CEntityFlame.m_flLifetime', 0)
				break

	def heal(self):
		if float(sv('zh_health_kill_bonus')):
			if not self.steamid == 'BOT':
				es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', es.getplayerprop(self.userid, 'CBasePlayer.m_iHealth') + int(sv('zh_health_kill_bonus')))

	def stop_camp(self):
		coords[int(self.userid)] = {'time': 0, 'location': (0, 0, 0)}

	def check_punish(self):
		time = coords[int(self.userid)]['time']
		if not self.steamid == 'BOT':
			if time * 2 > camp_time:
				es.tell(self.userid, '#multi', '#lightgreen[Zombie Horror]: #defaultPlease stop camping, especially if you\'re in a high area, it\'s extremely cheap')
				if int(sv('zh_camper_push')):
					es.setplayerprop(self.userid, 'CCSPlayer.baseclass.localdata.m_vecBaseVelocity', '%s,%s,%s'%(random.randint(-250, 250), random.randint(-250, 250), random.randint(-250, 250)))

				if es.getplayerprop(self.userid, 'CBasePlayer.m_iHealth') > camper_damage:
					if camper_damage:
						es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', es.getplayerprop(self.userid, 'CBasePlayer.m_iHealth') - camper_damage)
				else:
					es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', 0)
					es.server.queuecmd('es_xfire %s !self ignite'%self.userid)
		else:
			if time * 2 > camp_time:
				if int(sv('zh_beacon_camping_zombies')):
					x, y, z = es.getplayerlocation(self.userid)
					es.emitsound('player', self.userid, 'buttons/blip1.wav', 1, 0.9)

					es.server.queuecmd('est_effect 10 #a 0 "sprites/lgtning.vmt" %s %s %s 20 650 0.2 20 10 0 255 0 0 255 30'%(x, y, z))
					es.server.queuecmd('est_effect 10 #a 0.1 "sprites/lgtning.vmt" %s %s %s 20 650 0.3 15 10 0 255 150 150 255 30'%(x, y, z))

			if time % 10:
				self.stop_spawn_protection()

	def noblock(self):
		if not self.steamid == 'BOT':
			if int(sv('zh_human_noblock')):
				es.setplayerprop(self.userid, 'CBaseEntity.m_CollisionGroup', 2)

	def check_boss(self, boss, weapon):
		if int(boss) in bossess:
			bossess.remove(int(boss))
			self.boss_killed(weapon)

	def boss_killed(self, weapon):
		if int(sv('zh_boss_hp_bonus')):
			es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', es.getplayerprop(self.userid, 'CBasePlayer.m_iHealth') + int(sv('zh_boss_hp_bonus')))
		if int(sv('zh_anounce_boss_killed')):
			es.msg('#multi', '#lightgreen[Zombie Horror]: %s#default killed a boss with a #lightgreen%s!'%(es.getplayername(self.userid), weapon.replace('weapon_', '')))

	def health_bonus(self):
		if not self.steamid == 'BOT':
			if int(sv('zh_few_humans_hp_bonus')):
				if es.getplayercount(3) <= int(sv('zh_few_humans_hp_bonus')):
					es.setplayerprop(self.userid, 'CBasePlayer.m_iHealth', max(100, int(sv('zh_start_hp_value')) - (int(sv('zh_per_human_hp_loss')) * es.getplayercount(3))))

	def check_height(self, victim):
		if not self.steamid == 'BOT':
			if es.getplayerlocation(self.userid)[2] - es.getplayerlocation(victim)[2] >= 125:
				coords[int(self.userid)]['time'] += 4 + ((es.getplayerlocation(self.userid)[2] - es.getplayerlocation(victim)[2]) / 100.0)
				es.toptext(self.userid, 10, '#' + random.choice(['red', 'blue', 'green', 'yellow', 'purple', 'pink', 'orange']), '[Zombie Horror] -- Camping Kill detected, Suggest you move')

	def allowed_m249(self, remove=0, minus=0):
		if max_m249:
			if len(filter(lambda x: playerlib.getPlayer(x).get('primary') == 'weapon_m249', es.getUseridList())) - minus >= int(sv('zh_m249_max')):
				es.tell(self.userid, '#multi', '#lightgreen[Zombie Horror]: #defaultSorry, the server has reached the max of #lightgreen%s#default m249s'%nt(sv('zh_m249_max')))
				if remove:
					for index in es.createentitylist('weapon_m249'):
						if int(es.getplayerhandle(self.userid)) == int(es.getindexprop(index, "CBaseEntity.m_hOwnerEntity")):
							es.server.queuecmd('es_xremove %s'%index)
							break
				return False
		return True

	def check_model(self):
		if wins in ct_models:
			playerlib.getPlayer(self.userid).set('model', ct_models[wins])

### Functions ###

def set_pythonvars():
	global health_min, health_max, speed_min, speed_max, zombie_models, health_multiplier, speed_multiplier, armor_min, armor_max, armor_multiplier, gravity_min, gravity_max, gravity_multiplier
	global enable_knockback, knockback_min, knockback_max, knockback_minus, max_m249, camp_time, camper_damage, rounds_to_win, dissolve_on_death, remove_ragdolls
	zombie_models = str(sv('zh_zombie_models')).split(',')
	health_min, health_max, health_multiplier = tuple(int(sv('zh_zombie_health_' + x)) for x in ['min', 'max', 'level_bonus_multiplier'])
	speed_min, speed_max, speed_multiplier = tuple(float(sv('zh_zombie_speed_' + x)) for x in ['min', 'max', 'level_bonus_multiplier'])
	armor_min, armor_max, armor_multiplier = tuple(int(sv('zh_zombie_armor_' + x)) for x in ['min', 'max', 'level_bonus_multiplier'])
	gravity_min, gravity_max, gravity_multiplier = tuple(float(sv('zh_zombie_gravity_' + x)) for x in ['min', 'max', 'level_bonus_multiplier'])
	enable_knockback = int(sv('zh_enable_knockback'))
	knockback_min, knockback_max, knockback_minus = tuple(float(sv('zh_zombie_knockback_' + x)) for x in ['min', 'max', 'level_multiplier_minus'])
	max_m249, camp_time, camper_damage, rounds_to_win, dissolve_on_death, remove_ragdolls = tuple(int(sv('zh_' + x)) for x in [
		'm249_max', 'camp_time', 'camper_damage', 'rounds_to_win', 'dissolve_on_death', 'remove_ragdolls'
	])

def add_downloads():
	if os.path.isfile(es.getAddonPath('zombiehorror') + '/downloads.cfg'):
		for a in return_downloads():
			es.stringtable('downloadables', a)

def zh_fog_start():
	if int(sv('zh_fog')):
		if es.getUseridList():
			userid = es.getUseridList()[0]
			r, g, b = str(sv('zh_fog_rgb')).split(',')
			r2, g2, b2 = str(sv('zh_fog_rgb2')).split(',')
			global fogged
			if userid and not fogged:
				fogged = 1
				es.server.queuecmd('es_xgive %s env_fog_controller'%userid)
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogdir %s %s %s\"'%(userid, 0, 0, 0))
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogstart %s\"'%(userid, int(sv('zh_fog_start'))))
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogend %s\"'%(userid, int(sv('zh_fog_end'))))
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogblend 1"'%userid)
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogcolor %s %s %s\"'%(userid, r, g, b))
				es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogcolor2 %s %s %s\"'%(userid, r2, g2, b2))
				es.server.queuecmd('es_xfire %s env_fog_controller turnon'%userid)
	if not str(sv('zh_skybox')) == '0':
		es.server.queuecmd('sv_skyname %s'%str(sv('zh_skybox')))

def knife_bot():
	es.server.queuecmd('bot_knives_only 1')
	es.server.queuecmd('bot_join_after_player 0')
	es.server.queuecmd('bot_join_team t')
	es.set('mp_limitteams', 0)
	es.set('mp_autoteambalance', 0)

def add_bots():
	es.server.queuecmd('bot_quota %s'%int(sv('zh_bots')))
	change_teams()

def kick_bots():
	es.server.queuecmd('bot_kick')

def change_teams():
	for userid in es.getUseridList():
		Player(userid).check_team()

def check_map_config(map):
	if os.path.isfile(es.getAddonPath('zombiehorror') + '/configs/' + map + '.cfg'):
		es.server.queuecmd('es_xmexec ../addons/eventscripts/zombiehorror/configs/%s.cfg'%map)

### Returns ###

def random_value(low, high):
	return random.randint(int(low * 1000), int(high * 1000)) / 1000.0

def return_downloads():
	if os.path.isfile(es.getAddonPath('zombiehorror') + '/downloads.cfg'):
		a = open(es.getAddonPath('zombiehorror') + '/downloads.cfg', 'r')
		b = a.readlines()
		a.close()
		return map(lambda x: x.replace('\n', '').replace('\\', '/').replace('downloadable', ''), filter(lambda x: not x.startswith('//') and not x == '\n' and len(x) >= 10, b))
	else:
		es.dbgmsg(0, 'ERROR: No downloads.cfg found for Zombie Horror!')

def weapon_type(weapon):
	if str(weapon).lower().replace('weapon_', '') in ['usp', 'glock', 'p228', 'elite', 'deagle', 'nighthawk', 'compact', 'fiveseven', '9x19mm', 'km45', 'fn57']:
		return 'secondary'
	return 'primary'

def boss_level():
	if wins in attributes:
		if attributes[wins]['boss']:
			return 1
	return 0

### Loops ###

def update_hud():
	for userid in es.getUseridList():
		Player(userid).hud()
	gamethread.delayedname(float(sv('zh_hud_update_time')), 'update_hud', update_hud)

def ambiance_loop():
	if not str(sv('zh_ambiance_delay')) == '0':
		gamethread.delayedname(float(sv('zh_ambiance_delay')), 'ambiance_loop', ambiance_loop)
		for userid in es.getUseridList():
			es.stopsound(userid, str(sv('zh_ambiance')))
			es.playsound(userid, str(sv('zh_ambiance')), 0.9)
	else:
		es.dbgmsg(0, 'zombiehorror Fatal Error: Please change zh_ambiance_delay from 0 to a value greater!')

def heal_loop():
	if float(sv('zh_zombie_regen_delay')):
		gamethread.delayedname(float(sv('zh_zombie_regen_delay')), 'heal_loop', heal_loop)
		for player in playerlib.getPlayerList('#bot,#alive'):
			if es.getplayerprop(int(player), 'CBasePlayer.m_iHealth') < int(sv('zh_zombie_regen_max_health')):
				es.setplayerprop(int(player), 'CBasePlayer.m_iHealth', (wins * float(sv('zh_zombie_level_regen_multiplier'))) + random_value(float(sv('zh_zombie_regen_min')), float(sv('zh_zombie_regen_max'))) + es.getplayerprop(int(player), 'CBasePlayer.m_iHealth'))

def beacon_loop():
	if int(sv('zh_beacon_last_zombie')):
		gamethread.delayedname(1, 'beacon_loop', beacon_loop)
		if len(playerlib.getPlayerList('#bot,#alive')) <= int(sv('zh_min_zombies_beacon')):
			for userid in playerlib.getUseridList('#bot,#alive'):
				x, y, z = es.getplayerlocation(userid)
				es.emitsound('player', userid, 'buttons/blip1.wav', 1, 0.9)
				es.server.queuecmd('est_effect 10 #a 0 "sprites/lgtning.vmt" %s %s %s 20 450 0.2 20 10 0 255 0 0 255 30'%(x, y, z))
				es.server.queuecmd('est_effect 10 #a 0.1 "sprites/lgtning.vmt" %s %s %s 20 450 0.3 15 10 0 255 150 150 255 30'%(x, y, z))

def camp_loop():
	gamethread.delayedname(5, 'camp_loop', camp_loop)
	if int(sv('zh_stop_camp')):
		range = int(sv('zh_camp_range'))
		for player in playerlib.getPlayerList('#human,#alive'):
			if not int(player) in coords:
				Player(int(player)).stop_camp()
			x, y, z = player.get('location')
			x2, y2, z2 = coords[int(player)]['location']
			if abs(x - x2) <= range and abs(y - y2) <= range and abs(z - z2) <= range:
				coords[int(player)]['time'] += 5
			else:
				coords[int(player)]['time'] = max(0, coords[int(player)]['time'] - 45)
			coords[int(player)]['location'] = player.get('location')
			Player(int(player)).check_punish()

def bot_check_loop():
	gamethread.delayedname(15, 'check_quota', bot_check_loop)
	if not es.getplayercount(2) == int(sv('zh_bots')):
		add_bots()

def advert_loop():
	gamethread.delayedname(120, 'advert_loop', advert_loop)
	color = '#' + random.choice(['red', 'blue', 'green', 'yellow', 'purple', 'pink', 'orange'])
	for userid in es.getUseridList():
		es.toptext(userid, 10, color, '[Zombie Horror]: Visit our forums at www.zombie-horror.com!')

def update_loop():
	gamethread.delayedname(30000, 'update_loop', update_loop)
	if len(playerlib.getPlayerList('#human')) == 0:
		update()

### Filters ###

def zh_buy_filter(userid, args):
	if args[0].lower() == 'buy':
		if args[1].lower() in str(sv('zh_restricted_weapons')):
			es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultSorry, the #lightgreen%s#default is restricted'%args[1])
			return False
		if args[1].lower() == 'm249':
			if Player(userid).allowed_m249():
				if int(sv('zh_machine_gun_ammo')):
					gamethread.delayed(0, playerlib.getPlayer(userid).set, ('ammo', [1, int(sv('zh_machine_gun_ammo'))]))
			else:
				return False
		if args[1].lower() in str(sv('zh_ct_weapons')):
			if es.getplayerprop(userid, 'CCSPlayer.m_bInBuyZone') and playerlib.getPlayer(userid).get('cash') >= t_prices[args[1].lower()]:
				es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultPurchased #lightgreen%s'%args[1])
				es.server.queuecmd('es_xgive %s weapon_%s'%(userid, args[1]))
				if weapon_type(args[1].lower()) == weapon_type(playerlib.getPlayer(userid).get('secondary')) or weapon_type(args[1].lower()) == weapon_type(playerlib.getPlayer(userid).get('primary')):
					es.sexec(userid, 'use weapon_%s'%playerlib.getPlayer(userid).get(weapon_type(args[1].lower())))
					es.cexec(userid, 'drop')
	return True

### Client/Say Commands

def do_zspawn():
	userid = es.getcmduserid()
	if not int(sv('zh_zspawn')):
		es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultSorry, zspawn is disabled!')
		return

	if str(userid) in zspawn:
		if not es.getplayersteamid(userid) in deadpeople or not int(sv('zh_anti_rejoin_to_spawn')):
			deadpeople.append(es.getplayersteamid(userid))
			es.server.queuecmd('est_spawn %s'%userid)
	else:
		es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultYou can only spawn as soon as you join!')

def ac_command():
	if not int(sv('zh_achievements')):
		es.tell(userid, '#multi', '#lightgreen[Zombie Horror]: #defaultSorry, achievements are disabled on this server!')
		return

	if popuplib.active(es.getcmduserid())['count'] > 3:
		es.tell(es.getcmduserid(), '#multi', '#lightgreen[Zombie Horror]: #defaultYou can only have a maximum of #lightgreen3#default menus open at a time!')

	popuplib.send('Main Menu', es.getcmduserid())

def zoom_toggle():
	userid = es.getcmduserid()
	if int(sv('zh_weapon_zoom')):
		es.server.queuecmd('est_getgun gun %s'%userid)
		gamethread.delayed(0, gamethread.delayed, (0, zoom_toggle2, userid))

def zoom_toggle2(userid):
	if str(es.ServerVar('gun')).replace('weapon_', '') in str(sv('zh_zoom_weapons')) and not es.getplayerprop(userid, 'CBasePlayer.pl.deadflag'):
		es.setplayerprop(userid, 'CCSPlayer.baseclass.m_iFOV', 90 if es.getplayerprop(userid, 'CCSPlayer.baseclass.m_iFOV') == 60 else 60)
	else:
		es.setplayerprop(userid, 'CCSPlayer.baseclass.m_iFOV', 90)

def zh():
	args = es.getargs()
	if args:
		args = args.lower().replace('"', '').split(' ')
		if len(args) >= 2:
			if args[0] in zh_command_args:
				if args[1] in zh_command_args[args[0]]:
					if len(args) >= zh_command_args[args[0]][args[1]][0]:
						if args[0] == 'add':
							if args[1] == 'levelmessage':
								try:
									int(args[2])
								except:
									es.dbgmsg(0, 'Zombie Horror Error: Non integer amount for zh %s %s, %s'%(args[0], args[1], args[2]))
									return
								messages[int(args[2])] = ' '.join(args[3:])
							elif args[1] == 'tgun':
								try:
									int(args[3])
								except:
									es.dbgmsg(0, 'Zombie Horror Error: Non integer amount for zh add tgun %s, %s'%(args[2], args[3]))
									return
								t_prices[args[2]] = int(args[3])
							elif args[1] == 'humanmodel':
								try:
									int(args[2])
								except:
									es.dbgmsg(0, 'Zombie Horror Error: Non integer amount for zh %s %s, %s'%(args[0], args[1], args[2]))
									return
								ct_models[int(args[2])] = args[3]
					else:
						es.dbgmsg(0, 'Zombie Horror Error: Not enough arguments for zh %s %s'%(args[0], args[1]))
						es.dbgmsg(0, 'Zombie Horror Syntax: zh %s %s %s'%(args[0], args[1], zh_command_args[args[0]][args[1]][1]))
				else:
					es.dbgmsg(0, 'Zombie Horror Error: Invalid subcommand for zh %s, %s'%(args[0], args[1]))
					es.dbgmsg(0, 'Zombie Horror Syntax: Valid commands are %s'%', '.join(zh_command_args[args[0]].keys()))
			else:
				es.dbgmsg(0, 'Zombie Horror Error: Invalid subcommand for zh, %s'%args[0])
				es.dbgmsg(0, 'Zombie Horror Syntax: Valid commands are %s'%', '.join(zh_command_args.keys()))
		else:
			es.dbgmsg(0, 'Zombie Horror Error: No subcommand present, cannot continue!')
			es.dbgmsg(0, 'Zombie Horror Syntax: Valid subcommands are %s'%', '.join(zh_command_args.keys()))

def update():
	if True:
		return
	if int(sv('zh_auto_update')):
		verinfo = urllib.urlopen('http://addons.eventscripts.com/addons/chklatestver/zombiehorror')
		zh_path = es.getAddonPath('zombiehorror').replace('\\','/')
		for line in verinfo:
			vernumber = line
		if vernumber > info['version']:
			try:
				newpy = urllib.urlopen('http://zombie-horror.com/forums/zombiehorror/zombiehorror.txt')
			except:
				es.dbgmsg(0, '[Zombie Horror]: Could not update zombiehorror.py at this time!')
				return
			newpylines = newpy.readlines()
			if not len(newpylines) > 600:
				es.dbgmsg(0, '[Zombie Horror]: Could not update zombiehorror.py at this time!')
				return
			oldpy = open(zh_path + '/zombiehorror.py','w')
			for line in newpylines:
				oldpy.writelines('%s' %line)
			oldpy.writelines('##- Zombie Horror Auto-Updated at %s -##' %time.asctime())
			try:
				newcfg = urllib.urlopen('http://zombie-horror.com/forums/zombiehorror/zombiehorror.cfg')
			except:
				es.dbgmsg(0, '[Zombie Horror]: Could not update zombiehorror.cfg at this time!')
				return

			newcfglines = map(lambda x: x.replace('\n', '').replace('\r', ''), newcfg.readlines())
			if not len(newcfglines) > 200:
				es.dbgmsg(0, '[Zombie Horror]: Could not update zombiehorror.cfg at this time!')
				return

			oldcfg = open(zh_path + '/zombiehorror.cfg','a+')
			oldcfglines = map(lambda x: x.replace('\n', '').replace('\r', ''), oldcfg.readlines())

			for line in newcfglines:
				if not line in oldcfglines:
					oldcfg.writelines('\n%s' %line)

			oldcfg.writelines('\n// Zombie Horror Auto-Updated at %s //\n' %time.asctime())
			es.dbgmsg(0,'[Zombie Horror]: Zombie Horror updated successfully.')

			es.server.queuecmd('es_xunload zombiehorror')
			gamethread.delayed(1, es.server.queuecmd, 'es_load zombiehorror')
			return
		es.dbgmsg(0, '[Zombie Horror]: Already up to date!')

### Call Functions ###

gamethread.delayed(0, update_hud)
gamethread.delayed(0, camp_loop)
gamethread.delayed(0, heal_loop)
gamethread.delayed(0, beacon_loop)
gamethread.delayed(0, advert_loop)
gamethread.delayed(0, bot_check_loop)
gamethread.delayedname(30000, 'update_loop', update_loop)
es.addons.registerClientCommandFilter(zh_buy_filter) 
