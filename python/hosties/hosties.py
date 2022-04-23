'''
add an effect to the player in LR if EST, SM, and Mani aren't installed (Maybe like the effect I used in bclasses for the ghost)
'''

### Eventscripts Imports ###

import es

### Eventscripts Libraries ###

import gamethread
import playerlib
import popuplib
import langlib

### General Python Modules ###

import os
import random
import sys
import time

### Hosties Related Imports ###

import hosties as HOSTIES
from data.mapcoords import map_points as mapcoords

### Native tools (still supported?) ###

try:
	import nativetools

except ImportError:
	nativetools = None

### Globals ###

info = es.AddonInfo() 
info['name']        = "Hosties" 
info['version']     = "3.3.6q"
info['author']      = "Bonbon AKA: Bonbon367" 
info['url']         = "http://addons.eventscripts.com/addons/view/hosties" 
info['description'] = "Hosties Server Control by Bonbon, Original script by STK#Sebastian"

es.ServerVar('hosties_version', info['version'], info['description']).makepublic()
menu_lang = 'en'

sv_options = {
	'hosties_min_players_for_lr': 2,
	'hosties_announce_rebel_killed': 1,
	'hosties_announce_turn_into_rebel': 1,
	'hosties_max_innocent_kills_per_3_seconds': 3,
	'hosties_too_high_kps_punishment': 'kick',
	'hosties_unrestricted_ct_weapons': 'm4a1,deagle,famas,aug,tmp,knife,vesthelm,vest,nvgs',
	'hosties_unrestricted_t_weapons': 'm4a1,deagle,famas,aug,tmp,knife,vesthelm,vest,nvgs',
	'hosties_t_start_weapons': 'deagle,knife',
	'hosties_ct_start_weapons': 'deagle,m4a1',
	'hosties_beacon_on_lr': 1,
	'hosties_allow_to_kill_for_jumping_on_head': 1,
	'hosties_strip_weapons_on_round_end': 0,
	'hosties_rebel_color': '255,0,0,255',
	'hosties_announce_lr_available': 0,
	'hosties_announce_ct_hurt_t': 0,
	'hosties_rebel_on_hurt': 0,
	'hosties_show_rules_on_join': 1,
	'hosties_end_round_at_round_end_time': 1,
	'hosties_change_lr_colors': 0,
	'hosties_round_swap_teams': 0,
	'hosties_teleport_to_designated_areas_for_lr': 1,
	'hosties_enabled_lrs': 'Race,CF,KF,S4S,GT',
	'hosties_make_ct_accept_lr_with_rebel': 1,
	'hosties_silent_commands': 1,
	'hosties_stop_double_drop': 1,
	'hosties_commands': '!lr,!rules,!checkplayers,!commands,!hosties,!control,!checkguns,!wspoint,!setpoints,!teamtime',
	'hosties_admin_commands': '!hostiesadmin,!banteam,!makerebel,!stoplr',
	'hosties_enable_chicken_fight_won': 1,
	'hosties_control_command_time': 5,
	'hosties_controller_color': '255,128,0,0',
	'hosties_simon_says_completed_color': '255,0,255,0',
	'hosties_control_allow_simon': 1,
	'hosties_enable_noblock': 1,
	'hosties_menu_lang': 'en',
	'hosties_must_accept_lr': 0,
	'hosties_warning_weapon': 'weapon_p228',
	'hosties_warning_weapon_damage': 1,
	'hosties_lr_required_ts': 3,
	'hosties_warning_damage_regenerate': 0,
	'hosties_enable_s4s_single_shot': 1,
	'hosties_announce_attacked_with_gun': 1,
	'hosties_stop_kf_shoot': 1,
	'hosties_t_to_ct_ratio': 0,
	'hosties_noblock_on_round_start': 0,
	'hosties_guntoss_show_distance': 1,
	'hosties_admins': 'STEAM_0:0:11089864',
	'hosties_mute_dead': 1,
	'hosties_max_lrs': 2,
	'hosties_control_allow_lastreaction': 1,
	'hosties_voteteamban_minimum_votes': 3,
	'hosties_voteteamban_ban_time': 60,
	'hosties_voteteamban_vote_ratio': 0.5,
	'hosties_voteteamban_immune_file': 'addons/eventscripts/hosties/admin/immune.txt',
	'hosties_gunplant_show_last_owner': 1,
	'hosties_mute_on_round_start': 30,
	'hosties_mute_immune': 'STEAM_0:0:0000000000,STEAM_0:1:111111111',
	'hosties_enable_rebel_system': 1,
	'hosties_auto_assign_only': 0,
}

sv = es.ServerVar

### Constants ###

FILEPATH = es.getAddonPath('hosties') + '/'
HASH = ''.join([chr(x) for x in random.sample(range(48, 58) + range(65, 91) + range(97, 122), 16)])

def setExists():
	global HASEST, HASMANI, HASSM
	HASEST = not str(es.ServerVar('est_version')) == '0'
	HASMANI = not str(es.ServerVar('mani_admin_plugin_version')) == '0'
	HASSM = not str(es.ServerVar('sourcemod_version')) == '0'

EVENTS = [
	'player_' + x for x in ['hurt', 'activate', 'disconnect', 'death', 'shoot', 'connect', 'falldamage', 'blind', 
	'jump']] + ['bomb_' + x for x in ['planted', 'beingplant', 'defused', 'begindefuse', 'exploded', 'dropped', 'pickup']] + ['es_map_start',
	'hegrenade_detonate', 'flashbang_detonate', 'smokegrenade_detonate', 'grenade_bounce', 'weapon_fire', 'round_start', 
	'round_end', 'es_player_validated', 'item_pickup', 'weapon_zoom', 'hostage_follows', 'hostage_hurt', 'hostage_killed', 'hostage_rescued',
	'server_cvar'
]

WEAPONTYPES = {
	'pistols': 'glock,usp,p228,fiveseven,deagle,elite',
	'smgs': 'mac10,ump45,p90,mp5navy,tmp',
	'shotguns': 'm3,xm1014',
	'rifles': 'famas,aug,m4a1,sg552,ak47,galil',
	'snipers': 'sg550,awp,scout,g3sg1',
	'machineguns': 'm249',
	'c4': 'c4',
	'grenades': 'flashbang,hegrenade,smokegrenade',
	'knife': 'knife',
	'armor': 'vesthelm,vest,defuser,nvgs'
}

### Loads ###

text = langlib.Strings(FILEPATH + 'data/hosties.ini')

def load():
	global menu_lang
	if not es.exists('command', 'hosties_rule'):
		es.regcmd('hosties_rule', 'hosties/hosties_rule')

	if not es.exists('command', 'hosties_addpunishment'):
		es.regcmd('hosties_addpunishment', 'hosties/hosties_addpun')

	if not es.exists('command', 'hosties_add_menu_punishment'):
		es.regcmd('hosties_add_menu_punishment', 'hosties/add_menu_punishment')

	if not es.exists('command', 'hosties_load'):
		es.regcmd('hosties_load', 'hosties/hosties_load')

	if not es.exists('command', 'hosties_unload'):
		es.regcmd('hosties_unload', 'hosties/hosties_unload')

	if not es.exists('command', 'hosties_reload'):
		es.regcmd('hosties_reload', 'hosties/hosties_reload')

	if not es.exists('command', 'hosties_loadmod'):
		es.regcmd('hosties_loadmod', 'hosties/hosties_loadmod')

	if not es.exists('command', 'hosties_unloadmod'):
		es.regcmd('hosties_unloadmod', 'hosties/hosties_unloadmod')

	if not es.exists('command', 'hosties_reloadmod'):
		es.regcmd('hosties_reloadmod', 'hosties/hosties_reloadmod')

	for option in sv_options:
		sv(option).set(sv_options[option])

	if os.path.isfile(FILEPATH + 'hosties.cfg'):
		es.server.cmd('es_xmexec ../addons/eventscripts/hosties/hosties.cfg')
	menu_lang = str(sv('hosties_menu_lang'))

	hosties_menu = popuplib.easymenu('Hosties', '_popup_choice', hosties_select)
	hosties_menu.setdescription('Type !hosties to see this menu again!')

	hosties_menu.addoption('Rules', 'Rules')
	hosties_menu.addoption('Commands', 'Commands')

	if int(sv('hosties_silent_commands')):
		for command in ['hosties', 'checkplayers', 'commands', 'lr', 'checkguns']:
			if not es.exists('saycommand', '!' + command):
				es.regsaycmd('!' + command, 'hosties/say_command')
			HM.registerCommand('!' + command, command + ' command') 

	for userid in es.getUseridList():
		HM.getPlayer(userid)
		Rb.iks[userid] = {}

	EH.registerEvents()
	es.load('hosties/admin')

	es.stringtable('downloadables', 'sound/hosties/lr.wav')
	gamethread.delayed(0, setExists)

def unload():
	EH.unregisterEvents()
	es.addons.unregisterClientCommandFilter(_restrict_weapons)

	for request in LRM.filters['client']:
		es.addons.unregisterClientCommandFilter(request)

	for request in LRM.filters['say']:
		es.addons.unregisterSayFilter(request)

	for request in LRM.funcs:
		if request in sys.modules:
			del sys.modules['hosties.lastrequests.%s'%request]

	for command in LRM.commands.keys() + map(lambda x: '!' + x, ['hosties', 'checkplayers', 'commands', 'lr', 'checkguns']):
		if es.exists('saycommand', command):
			es.unregsaycmd(command)

	for delay in ['regen lost', 'unblock', 'unmute ts in']:
		gamethread.cancelDelayed(delay)

	for t in LR.ts:
		gamethread.cancelDelayed('beacon players %s'%t)

	for mod in list(HM.mods):
		HM.unloadMod(mod)
	es.unload('hosties/admin')

### Classes ###

class HostiesPlayer(object):
	'''Controls general functions of players'''
	def __init__(self, userid):
		self.pd = {'restrict team': False, 'bantime': 0, 'banned': 0}
		self.lang = playerlib.getPlayer(userid).get('lang')
		self.userid = userid

	def checkKill(self, userid, weapon=None, t=None):
		Rb.player_death(int(userid), self.userid, weapon, False, t)

	def makeRebel(self, message=True):
		if int(sv('hosties_enable_rebel_system')):
			Rb.makeRebel(self.userid, message)

	def tell(self, langlib_key, langlib_args={}):
		es.tell(self.userid, '#multi', text(langlib_key, langlib_args, self.lang))

	def send(self, menu):
		if es.getplayersteamid(self.userid) == 'BOT':
			return

		if popuplib.active(self.userid)['count'] > 3:
			self.tell('too many menus')
			return
		popuplib.send(menu, self.userid)

	def changeTeam(self, team):
		'''Use the best way of changing a team, depending on what mods the server is running'''
		if HASEST:
			es.server.queuecmd('est_team %s %s'%(self.userid, team))
			return
		es.server.queuecmd('es_xchangeteam %s %s'%(self.userid, team))

	def mute(self, mode=True, tell=True):
		if mode and es.getplayersteamid(self.userid) in str(sv('hosties_mute_immune')).replace(' ', '').replace('"', '').split(','):
			return

		if HASSM:
			if mode:
				es.server.queuecmd('sm_mute #%s'%self.userid)
			else:
				es.server.queuecmd('sm_unmute #%s'%self.userid)

		elif nativetools:
			nativetools.mutePlayer(self.userid, mode)

		elif HASMANI:
			es.server.queuecmd('ma_mute %s %s'%(self.userid, 9 if mode else 0))

		if mode:
			if tell:
				getPlayer(self.userid).tell('player muted')

class Hosties(object):
	def __init__(self):
		self.players = {}
		self.mods = []

		self.rules = []
		self.ruleMenu = popuplib.easymenu('Rules', '_popup_choice', self.ruleSelect)

		self.commands = {}
		self.commandMenu = popuplib.easymenu('Commands', '_popup_choice', self.commandSelect)

		self.rounds = 0
		self.punishments = {}

	def registerCommand(self, command, langlib_string):
		if command in self.commands:
			return

		self.commands[command] = text(langlib_string, {}, str(sv('hosties_menu_lang')))
		self.commandMenu.addoption(command, command)

	def unregisterCommand(self, command):
		if not command in self.commands:
			return

		del self.commands[command]
		self.commandMenu = popuplib.easymenu('Commands', '_popup_choice', self.commandSelect)

		for command in self.commands:
			self.commandMenu.addoption(command, command)

	def addRule(self, rule):
		if rule in self.rules:
			es.dbgmsg(0, 'Hosties Error: Rule already exists!')
			return

		self.rules.append(rule)
		self.ruleMenu.addoption(rule, rule)

	def commandSelect(self, userid, choice, popupid):
		es.tell(userid, '#multi', self.commands[choice])

	def ruleSelect(self, userid, choice, popupid):
		getPlayer(userid).send('Rules')

	def getPlayer(self, userid):
		userid = int(userid)
		if not userid in self.players:
			self.players[userid] = HostiesPlayer(userid)
		return self.players[userid]

	def delPlayer(self, userid):
		userid = int(userid)
		if LR.getT(userid):
			LR.stopLR(LR.getT(userid), None, None)

		if userid in self.players:
			del self.players[userid]

	def msg(self, langlib_key, langlib_args={}):
		for userid in es.getUseridList():
			es.tell(userid, '#multi', text(langlib_key, langlib_args, self.getPlayer(userid).lang))

	def unBlockPlayers(self, players=None):
		alive = players
		if not players:
			alive = playerlib.getUseridList('#alive')

		for userid in list(alive):
			temp = True
			for userid2 in alive:
				if userid2 == userid:
					continue

				x, y, z = es.getplayerlocation(userid)
				x2, y2, z2 = es.getplayerlocation(userid2)

				if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 <= 30:
					es.setplayerprop(userid, 'CCSPlayer.baseclass.localdata.m_vecBaseVelocity', ','.join([str(random.randint(-255, 255)) for x in '123']))
					es.setplayerprop(userid2, 'CCSPlayer.baseclass.localdata.m_vecBaseVelocity', ','.join([str(random.randint(-255, 255)) for x in '123']))
					temp = False
					break

			if temp:
				alive.remove(userid)
				es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 5)

		if alive:
			gamethread.delayedname(0.5, 'unblock', self.unBlockPlayers, alive)

	def mutePlayers(self):
		if not int(sv('hosties_mute_on_round_start')):
			return

		if HASSM:
			es.server.queuecmd('sm_unmute @alive;sm_mute @t')

		elif nativetools:
			for userid in playerlib.getUseridList('#alive,#ct'):
				nativetools.mutePlayer(userid, False)

			for userid in playerlib.getUseridList('#alive,#t'):
				nativetools.mutePlayer(userid, True)

		elif HASMANI:
			es.server.queuecmd('ma_mute #all 0;ma_mute #t 9')

		immune = str(sv('hosties_mute_immune')).replace(' ', '').replace('"', '').split(',')
		for userid in es.getUseridList():
			if es.getplayersteamid(userid) in immune:
				getPlayer(userid).mute(False)

		self.msg('ts muted', {'time': int(sv('hosties_mute_on_round_start'))})
		gamethread.delayedname(int(sv('hosties_mute_on_round_start')), 'unmute ts in', self.unmutePlayers)

	def unmutePlayers(self):
		if HASSM:
			es.server.queuecmd('sm_unmute @alive')

		elif nativetools:
			for userid in playerlib.getUseridList('#alive'):
				nativetools.mutePlayer(userid, False)

		elif HASMANI:
			es.server.queuecmd('ma_mute #all 0')
		self.msg('ts unmuted')

	def roundEnd(self):
		if not int(sv('hosties_round_swap_teams')):
			return

		self.rounds += 1
		if self.rounds >= int(sv('hosties_round_swap_teams')):
			self.rounds = 0
			for userid in es.getUseridList():
				es.server.queuecmd('est_team %s %s'%(userid, 2 if es.getplayerteam(userid) == 3 else 3))
				getPlayer(userid).tell('teams changed')

	@staticmethod
	def isRestricted(weapon, team, userid, broadcastError=True):
		request = None
		t = LR.getT(userid)

		if t:
			request = LR.ts[t]['request']

		if request in LRM.unrestricted and t:
			if weapon in LRM.unrestricted[request]:
				return False

		try:
			weapon_type = filter(lambda x: weapon in WEAPONTYPES[x], WEAPONTYPES.keys())[0]

		except IndexError:
			if broadcastError:
				es.msg('#multi', '#lightgreen[Hosties]: ERROR:#default Did not find weapon "%s", please post this message at http://forums.mattie.info/cs/forums/viewtopic.php?t=25870'%weapon)
			return False

		unrestricted_weapons = (str(sv('hosties_unrestricted_ct_weapons')) if team == 3 else str(sv('hosties_unrestricted_t_weapons'))).lower().split(',')
		for uweapon in unrestricted_weapons:
			if weapon == uweapon:
				return False

			if weapon_type in uweapon:
				if '!' in uweapon:
					not_weapons = uweapon.split('!')[1].split('&')
					if weapon in not_weapons:
						return True
				return False
		return True

	def loadMod(self, mod):
		if mod in self.mods:
			es.dbgmsg(0, 'Hosties: %s already loaded!'%mod)
			return

		if not os.path.isfile(FILEPATH + 'mods/%s/%s.py'%(mod, mod)):
			es.dbgmsg(0, 'Hosties: %s does not exist!'%mod)
			return

		self.mods.append(mod)
		es.load('hosties/mods/%s'%mod)

	def unloadMod(self, mod):
		if not mod in self.mods:
			es.dbgmsg(0, 'Hosties: %s is not loaded!'%mod)
			return

		self.mods.remove(mod)
		es.unload('hosties/mods/%s'%mod)

	def reloadMod(self, mod):
		es.unloadMod(mod)
		gamethread.delayed(0, self.loadMod, mod)

HM = Hosties()

class LastRequest(object):
	def __init__(self):
		self.ts = {}
		self.lrwinners = []
		self.lrlosers = []
		self.beaconed = []
		self.accepted = []

		self.lrMenu = popuplib.easymenu('Last Request', '_popup_choice', self.lrSelect)

	def lrSelect(self, userid, choice, popupid):
		if self.canLR(userid):
			choosePlayer = popuplib.easymenu('Choose Player', '_popup_choice', self.choosePlayerSelect)
			cts_in_lr = self.getCTs()

			for userid2 in filter(lambda x: x not in cts_in_lr, playerlib.getUseridList('#ct,#alive')):
				choosePlayer.addoption([choice, userid2], es.getplayername(userid2))
			getPlayer(userid).send('Choose Player')

	def alrSelect(self, userid, choice, popupid):
		if choice[2] == 'Yes':
			if choice[0] in Rb.rebels:
				Rb.rebels.remove(choice[0])

			self.accepted.append(choice[0])
			self.choosePlayerSelect(choice[0], [choice[1], userid], None)
			self.accepted.remove(choice[0])
			return
		getPlayer(choice[0]).tell('declined request', {'player': es.getplayername(userid)})

	def choosePlayerSelect(self, userid, choice, popupid):
		if self.canLR(userid):
			if not choice[0] in LRM.rfuncs or not 'start' in LRM.rfuncs[choice[0]]:
				es.msg('#multi', '#lightgreen[Hosties]: #defaultERROR: No initiate function for %s!'%choice[0])
				return

			if not es.exists('userid', choice[1]):
				getPlayer(userid).tell('target left server')
				return

			if playerlib.getPlayer(choice[1]).get('isdead'):
				getPlayer(userid).tell('target dead')
				return

			if choice[1] in self.getCTs():
				getPlayer(userid).tell('target in lr', {'player': es.getplayername(choice[1])})
				return

			if choice[0] in self.getCurrentRequests():
				getPlayer(userid).tell('one of each')
				return

			ma = False
			if int(sv('hosties_must_accept_lr')) and not userid in self.accepted:
				ma = True

			if not userid in Rb.rebels or not int(sv('hosties_make_ct_accept_lr_with_rebel')) and not ma:
				self.ts[userid] = {'request': choice[0], 'ct': choice[1]}
				if int(sv('hosties_beacon_on_lr')):
					self.beaconPlayers(userid)
				LRM.rfuncs[choice[0]]['start'](userid, choice[1])

				if int(sv('hosties_change_lr_colors')):
					playerlib.getPlayer(userid).set('color', [255, 0, 0, 255])
					playerlib.getPlayer(choice[1]).set('color', [0, 0, 255, 255])
				return

			alr = popuplib.easymenu('Accept LR', '_popup_choice', self.alrSelect)
			alr.addoption([userid, choice[0], 'Yes'], text('yes', {}, menu_lang))
			alr.addoption([userid, choice[0], 'No'], text('no', {}, menu_lang))

			es.tell(userid, '#multi', '#lightgreen[Hosties]: #defaultasking #lightgreen%s#default to accept your Last Request...'%es.getplayername(choice[1]))
			es.tell(choice[1], '#multi', text('marked as rebel' if not ma else 'accept lr', {'player': es.getplayername(userid)}, playerlib.getPlayer(choice[1]).get('lang')))
			getPlayer(choice[1]).send('Accept LR')

	def canLR(self, userid, ip=False):
		if playerlib.getPlayer(userid).get('isdead'):
			getPlayer(userid).tell('must be alive')
			return

		if not es.getplayerteam(userid) == 2:
			getPlayer(userid).tell('must be terrorist')
			return

		if not len(playerlib.getPlayerList('#t,#alive')) <= int(sv('hosties_min_players_for_lr')):
			getPlayer(userid).tell('too many ts')
			return

		if es.getplayercount(2) < int(sv('hosties_lr_required_ts')):
			getPlayer(userid).tell('not enough ts')
			return

		if len(self.ts) >= int(sv('hosties_max_lrs')) + (1 if ip else 0):
			getPlayer(userid).tell('too many lrs', {'amount': int(sv('hosties_max_lrs'))})
			return
		return True

	def initiateRequest(self, userid):
		if self.canLR(userid):
			self.lrMenu = popuplib.easymenu('Last Request', '_popup_choice', self.lrSelect)
			for request in LRM.funcs:
				self.lrMenu.addoption(request, text(request, {}, menu_lang))
			getPlayer(userid).send('Last Request')

	def beaconPlayers(self, t):
		if not HASEST and not t in self.beaconed:
			if HASMANI:
				self.beaconed.append(t)
				es.server.queuecmd('ma_beacon %s 1;ma_beacon %s 1'%(t, self.ts[t]['ct']))

			elif HASSM:
				self.beaconed.append(t)
				es.server.queuecmd('sm_beacon #%s 1;sm_beacon #%s 1'%(t, self.ts[t]['ct']))
			return
		self.beaconLoop(t, self.ts[t]['ct'])

	def beaconLoop(self, t, ct):
		if not t in self.ts:
			return

		for userid in [t, ct]:
			x, y, z = es.getplayerlocation(userid)
			es.server.queuecmd('est_effect 10 #a 0 "sprites/lgtning.vmt" %s %s %s 20 300 0.2 20 10 0 255 0 0 255 30'%(x, y, z))
			es.server.queuecmd('est_effect 10 #a 0.1 "sprites/lgtning.vmt" %s %s %s 20 300 0.3 15 10 0 255 150 150 255 30'%(x, y, z))
			es.emitsound('player', userid, 'buttons/blip2.wav', 0.8, 0.6)

		gamethread.cancelDelayed('beacon players %s'%t)
		gamethread.delayedname(1, 'beacon players %s'%t, self.beaconLoop, (t, ct))

	def getCurrentRequests(self):
		return map(lambda x: self.ts[x]['request'], self.ts)

	def getPartner(self, userid):
		if userid in self.ts:
			return self.ts[userid]['ct']

		for t in self.ts:
			if self.ts[t]['ct'] == userid:
				return t
		return None

	def getT(self, userid):
		if userid in self.ts:
			return userid

		for t in self.ts:
			if self.ts[t]['ct'] == userid:
				return t

	def getCTs(self):
		return map(lambda x: self.ts[x]['ct'], self.ts)

	def stopLR(self, t, winner, messagekey, messageargs={}):
		if t in self.beaconed and not HASEST:
			self.beaconed.remove(t)
			if HASMANI:
				es.server.queuecmd('ma_beacon %s 0;ma_beacon %s 0'%(t, self.ts[t]['ct']))

			elif HASSM:
				es.server.queuecmd('sm_beacon #%s 0;sm_beacon #%s 0;es_msg Unbeaconed'%(t, self.ts[t]['ct']))

		if not t:
			for each in self.ts.keys():
				self.stopLR(each, None, None)

			del self.lrwinners[:]
			del self.lrlosers[:]

			self.ts.clear()
			return

		if messagekey:
			HM.msg(messagekey, messageargs)

		request = self.ts[t]['request']
		if 'end' in LRM.rfuncs[request]:
			LRM.rfuncs[request]['end']()

		if winner:
			self.lrwinners.append(winner)
			self.lrlosers.append(self.getPartner(winner))

		for userid in [t, self.ts[t]['ct']]:
			if not userid:
				continue

			if not es.exists('userid', userid):
				continue

			player = playerlib.getPlayer(userid)
			if player.get('isdead'):
				continue
			player.set('color', [255, 255, 255, 255])
		del self.ts[t]

	def playerDeath(self, userid):
		if not self.getPartner(userid):
			return
		self.stopLR(self.getT(userid), None, None)

LR = LastRequest()

class LastRequestManager(object):
	def __init__(self):
		self.funcs = {}
		self.rfuncs = {}
		self.commands = {}
		self.overrides = {}
		self.unrestricted = {}

		self.filters = {'client': {}, 'say': {}}

	def loadLastRequest(self, request):
		if request in self.funcs:
			es.dbgmsg(0, 'Hosties Error: %s is already loaded!'%request)
			return

		if not os.path.isfile(FILEPATH + '/lastrequests/%s/%s.py'%(request, request)):
			es.dbgmsg(0, 'Hosties Error: No %s.py under ./cstrike/addons/eventscripts/hosties/lastrequests/%s !'%(request, request))
			return

		if not os.path.isfile(FILEPATH + '/lastrequests/%s/__init__.py'%request):
			open(FILEPATH + '/lastrequests/%s/__init__.py'%request, 'a').close()

		self.funcs[request] = None
		if 'hosties.lastrequests.%s.%s'%(request, request) in sys.modules:
			del sys.modules['hosties.lastrequests.%s.%s'%(request, request)]

		gamethread.delayedname(0, 'xyzzy', es.dbgmsg, (0, 'Hosties: Failed to load %s'%request))
		self.funcs[request] = reload(__import__('hosties.lastrequests.%s.%s'%(request, request), fromlist=['hosties', 'lastrequests', request]))

		gamethread.cancelDelayed('xyzzy')
		es.dbgmsg(0, 'Hosties: Loaded %s'%request)

	def unloadLastRequest(self, request):
		if request in LR.getCurrentRequests():
			es.dbgmsg(0, 'Hosties Error: Cannot unload last request. %s is alread in progress!'%request)
			return

		if not request in self.funcs:
			es.dbgmsg(0, 'Hosties Error: %s isn\'t loaded!'%request)
			return

		if request in self.filters['client']:
			es.addons.unregisterClientCommandFilter(self.filters['client'][request])

		if request in self.filters['say']:
			es.addons.unregisterClientCommandFilter(self.filters['say'][request])

		if hasattr(self.getModule(request), 'unload'):
			getattr(self.getModule(request), 'unload')()

		del self.funcs[request]
		del sys.modules['hosties.lastrequests.%s.%s'%(request, request)]

		es.dbgmsg(0, 'Hosties: Unloaded %s'%request)

	def reloadLastRequest(self, request):
		gamethread.delayed(0, self.unloadLastRequest, request)
		gamethread.delayed(0, gamethread.delayed(0, self.loadLastRequest, request))

	def getModule(self, request):
		if not request in self.funcs:
			raise ImportError('%s is not loaded!'%request)
		return self.funcs[request]

	def returnClientCommand(self, userid, args):
		for request in LR.getCurrentRequests():
			if request in self.filters['client']:
				val = self.filters['client'][request](userid, args)
				if not val:
					return False
		return True

LRM = LastRequestManager()

class RegisterLastRequest(object):
	'''Register a new last request to the server'''
	def __init__(self, request):
		if not request in LRM.funcs:
			raise AttributeError('no last request %s!'%request)
		self.request = request

	def _checkArgs(self, callback, argcount_check=True):
		'''Make sure that the function passed will not raise an error!'''
		if not callable(callback):
			raise TypeError('%s is not callable!'%callback.__class__.__name__)

		if argcount_check:
			if callback.__class__.__name__ == 'function':
				argc = callback.func_code.co_argcount
				if not argc == 2:
					raise TypeError('callback must take exactly 2 args, %s given!'%argc)

			elif callback.__class__.__name__ == 'instancemethod':
				argc = callback.im_func.func_code.co_argcount
				if not argc == 3:
					raise TypeError('callback must take exactly 2 args, %s given!'%argc)

		if not self.request in LRM.rfuncs:
			LRM.rfuncs[self.request] = {}
		return True

	def registerStartFunction(self, callback):
		'''Give the script a starting function, so it knows when it's called'''
		if not self._checkArgs(callback):
			return
		LRM.rfuncs[self.request]['start'] = callback

	def registerEndFunction(self, callback):
		'''Incase the main hosties script ends the LR, notify the script'''
		if not self._checkArgs(callback, False):
			return
		LRM.rfuncs[self.request]['end'] = callback

	def registerSayCommand(self, command, langlib_string, callback):
		'''NOTE: Made before cmdlib'''
		if command in LRM.commands:
			return

		if not es.exists('saycommand', command):
			es.regsaycmd(command, 'hosties/lr_command')

		HM.registerCommand(command, langlib_string)
		LRM.commands[command] = callback

	def unregisterSayCommand(self, command):
		'''NOTE: Made before cmdlib'''
		if not command in LRM.commands:
			return

		if es.exists('saycommand', command):
			es.unregsaycmd(command)

		HM.unregisterCommand(command)
		del LRM.commands[command]

	def registerOverRide(self, event):
		'''In case the script wants some events to not end the last request'''
		if not event in LRM.overrides:
			LRM.overrides[event] = []

		if self.request in LRM.overrides[event]:
			return
		LRM.overrides[event].append(self.request)

	'''Unrestricts a certain weapon for the specific last request'''
	def unrestrictWeapon(self, weapon):
		if not self.request in LRM.unrestricted:
			LRM.unrestricted[self.request] = []

		if weapon in LRM.unrestricted[self.request]:
			return
		LRM.unrestricted[self.request].append(weapon)

	def registerClientCommandFilter(self, callback):
		'''NOTE: Made before cmdlib'''
		LRM.filters['client'][self.request] = callback

	def __getattr__(self, item):
		'''In case the script wants to use any functions from the LastRequest instance'''
		if hasattr(LR, item):
			return getattr(LR, item)
		raise AttributeError('LastRequest instance has no attribute %s!'%item)

class EventHandler(object):
	'''Used to only call events to a last request if it's loaded, and to stop overridden events'''
	class FireEvent(object):
		def __init__(self, event, exists=True):
			self.event = event
			self.exists = exists

		def __call__(self, ev):
			if self.exists:
				getattr(HOSTIES, self.event)(ev)

			for request in LR.getCurrentRequests():
				module = LRM.getModule(request)
				if hasattr(module, self.event):
					getattr(module, self.event)(ev)

	def registerEvents(self):
		for event in EVENTS:
			if not hasattr(HOSTIES, event):
				es.addons.registerForEvent(HOSTIES, event, self.FireEvent(event, False))
				continue

			es.addons.unregisterForEvent(HOSTIES, event)
			es.addons.registerForEvent(HOSTIES, event, self.FireEvent(event))

	def unregisterEvents(self):
		for event in EVENTS:
			es.addons.unregisterForEvent(HOSTIES, event)

EH = EventHandler()

class Rebel(object): 
	'''Controls rebel status of players
		NOTE: This was made a while ago, must recode D:'''

	def __init__(self):
		self.rebels = []
		self.ik = {}
		self.iks = {}
		self.kps = {}
		self.on_heads = {}
		self.pfk = {}
		self.trounds = {}

	def makeRebel(self, userid, message=True):
		'''Sets a player to be a rebel'''
		self.rebels.append(userid)
		playerlib.getPlayer(userid).set('color', str(sv('hosties_rebel_color')).split(','))

		if int(sv('hosties_announce_turn_into_rebel')) and message:
			HM.msg('rebel', {'player': es.getplayername(userid)})

		if not str(sv('hosties_rebel_color')) == '0':
			playerlib.getPlayer(userid).set('color', str(sv('hosties_rebel_color')).split(','))

		if userid in LR.ts:
			LR.stopLR(userid, None, None)

	def player_death(self, userid, attacker, weapon, override=True, t=None):
		if userid == attacker:
			return

		if userid in LR.lrlosers and attacker in LR.lrwinners:
			LR.lrwinners.remove(attacker)
			LR.lrlosers.remove(userid)
			return

		tokens = {'t': es.getplayername(attacker if es.getplayerteam(attacker) == 2 else userid), 'ct': es.getplayername(attacker if es.getplayerteam(attacker) == 3 else userid), 'player': es.getplayername(attacker)}
		if LR.ts and override:
			return

		if t:
			attacker_t = LR.getT(attacker)
			if attacker_t and t <> attacker_t:
				return

		if es.getplayerteam(attacker) == 2:
			if attacker in self.rebels:
				return

			if attacker in self.on_heads:
				if self.on_heads[attacker] == userid:
					del self.on_heads[attacker]
					if weapon == 'knife':
						for userid2 in es.getUseridList():
							player = getPlayer(userid2)
							player.tell('killed for head1', tokens)
							player.tell('killed for head2', tokens)
						return
			self.makeRebel(attacker)

		if userid in self.rebels:
			HM.msg('killed a rebel', {'ct': es.getplayername(attacker)})
			return

		# Doesn't work, weapon is returned as 0 because they're dead.
		if self.check_rebel(userid):
			if int(sv('hosties_announce_rebel_killed')):
				if not attacker:
					return

				HM.msg('killed with gun', tokens)
				return

		if not userid in self.rebels:
			if es.getplayerteam(attacker) == 3:
				if attacker in LR.lrwinners:
					LR.lrwinners.remove(attacker)
					return
				self.ik[attacker] = self.ik[attacker] + 1 if attacker in self.ik else 1

				if self.ik[attacker] in self.pfk:
					self.punish(attacker, self.pfk[self.ik[attacker]])

				self.kps[attacker] = self.kps[attacker] + 1 if attacker in self.kps else 1
				gamethread.delayed(1.5, self.makeZero, attacker)

				if self.kps[attacker] >= int(sv('hosties_max_innocent_kills_per_3_seconds')):
					self.punish(attacker, str(sv('hosties_too_high_kps_punishment')))

				if not attacker in self.iks:
					self.iks[attacker] = {}
				self.iks[attacker][userid] = self.iks[attacker][userid] + 1 if userid in self.iks[attacker] else 1

				if self.iks[attacker][userid] in HM.punishments:
					pmenu = popuplib.easymenu('Punishment Menu', '_popup_choice', pmenu_select)
					pmenu.settitle(text('Punishment Menu', {}, menu_lang))

					for option in HM.punishments[self.iks[attacker][userid]].split(','):
						pmenu.addoption([attacker, option], option)
					getPlayer(userid).send('Punishment Menu')

		elif es.getplayerteam(attacker) == 3:
			self.iks[attacker][userid] = 0

	def checkDead(self, userid):
		if not playerlib.getPlayer(userid).get('isdead'):
			es.server.queuecmd('damage %s 2'%userid)

	def punish(self, userid, o):
		o = o.replace('\r', '')
		if o == 'slay':
			playerlib.getPlayer(userid).set('health', 1)
			es.server.queuecmd('es_xfire %s !self ignite')
			gamethread.delayed(0.1, self.checkDead, userid)

		elif o == 'kick':
			es.server.queuecmd('kickid %s Don\'t line up and kill hosties!'%userid)
			tokens = {'player': es.getplayername(userid), 'steamid': es.getplayersteamid(userid), 'ip': playerlib.getPlayer(userid).get('ip')}

			for userid2 in es.getUseridList():
				getPlayer(userid2).tell('line up kick', tokens)
			return

		elif o.startswith('takehp'):
			playerlib.getPlayer(userid).set('health', max(playerlib.getPlayer(userid).get('health') - int(o[6:]), 1))

		elif o == 'stripweapons':
			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_fire %s player_weaponstrip strip'%userid)
			es.server.queuecmd('es_fire %s player_weaponstrip kill;es_delayed 0 es_xgive %s weapon_knife;es_delayed 2 es_xgive %s weapon_deagle;es_delayed 2.05 playerset clip %s 2 0'%(userid, userid, userid, userid))

		elif o.startswith('maket'):
			self.trounds[es.getplayersteamid(userid)] = int(o[5:])
			getPlayer(userid).changeTeam(2)
			getPlayer(userid).tell('rounds as t', {'rounds': o[5:]})

		elif o.startswith('ban'):
			es.server.queuecmd('banid %s %s'%(o[3:], es.getplayersteamid(userid)))
			es.server.queuecmd('writeid')
			es.server.queuecmd('kickid %s You have been banned for %s minutes for lining up and killing hosties!'%(userid, o[3:]))
		getPlayer(userid).tell('dont kill innocent')

	def makeZero(self, userid):
		self.kps[userid] = 0

	def check_rebel(self, userid):
		if es.getplayerteam(userid) == 2:
			if not str(playerlib.getPlayer(userid).get('primary')) == '0':
				return True

			if not str(playerlib.getPlayer(userid).get('secondary')) == '0':
				return True
		return False

	def checkOnHead(self, userid):
		if int(sv('hosties_allow_to_kill_for_jumping_on_head')):
			if es.getplayerteam(userid) == 3:
				groundEntity = es.getplayerprop(userid, 'CBasePlayer.localdata.m_hGroundEntity')
				for userid2 in playerlib.getUseridList('#t,#alive'):
					if es.getplayerhandle(userid2) == groundEntity:
						self.on_heads[userid2] = userid
						break

	def add_punishment(self, args):
		if not args[0].isdigit():
			es.dbgmsg(0, 'Invalid amount of kills for hosties_addpunishment!')
			return

		if int(args[0]) in self.pfk:
			es.dbgmsg(0, 'Already a punishment for %s kills!'%args[0])
			return

		self.pfk[int(args[0])] = args[1]

Rb = Rebel()

### Events ###

def es_map_start(ev):
	es.stringtable('downloadables', 'sound/hosties/lr.wav')
	gamethread.cancelDelayed('end round')

def player_team(ev):
	userid = ev['userid']
	if ev['es_steamid'] in Rb.trounds:
		if ev['team'] == '3':
			getPlayer(userid).changeTeam(2)
			es.server.queuecmd('es_xsetpos %s '%(userid + '%s %s %s'%return_random_t_spawn()))
			getPlayer(userid).tell('rounds as t', {'rounds': Rb.trounds[ev['es_steamid']]})

def player_hurt(ev):
	userid, attacker = int(ev['userid']), int(ev['attacker'])
	if userid == attacker:
		return

	if playerlib.getPlayer(userid).get('isdead'):
		return

	if userid in Rb.rebels:
		return

	if LR.getT(userid) and LR.getT(attacker) and LR.ts[LR.getT(userid)]['request'] in LRM.overrides['player_hurt']:
		return

	if ev['weapon'] in ['flashbang', 'smokegrenade']:
		return

	if ev['weapon'] == str(sv('hosties_warning_weapon')):
		if es.getplayerteam(attacker) == 3:
			getPlayer(userid).tell('warning shot', {'player': es.getplayername(attacker)})
			playerlib.getPlayer(userid).set('health', playerlib.getPlayer(userid).get('health') + int(ev['dmg_health']) - int(sv('hosties_warning_weapon_damage')))

			if int(sv('hosties_warning_damage_regenerate')):
				gamethread.delayedname(int(sv('hosties_warning_damage_regenerate')), 'regen lost', check_regen, userid)
			return

	if attacker in LR.lrwinners and userid in LR.lrlosers:
		return

	if Rb.check_rebel(userid):
		if int(sv('hosties_announce_attacked_with_gun')):
			if not attacker:
				return

			HM.msg('attacked with gun', {'t': es.getplayername(userid), 'ct': es.getplayername(attacker)})
			return

	if es.getplayerteam(attacker) == 3 and es.getplayerteam(userid) == 2:
		if str(sv('hosties_announce_ct_hurt_t'))  == '0':
			return

		if str(sv('hosties_announce_ct_hurt_t')) == 'tell':
			getPlayer(userid).tell('tell t attacked', {'player': es.getplayername(attacker)})
		else:
			HM.msg('innocent attack', {'t': es.getplayername(userid), 'ct': es.getplayername(attacker)})

	if attacker in Rb.rebels:
		return

	if int(sv('hosties_rebel_on_hurt')):
		if es.getplayerteam(userid) == 3 and es.getplayerteam(attacker) == 2:
			if attacker in LR.ts and not userid == LR.ts[attacker]['ct']:
				LR.stopLR(attacker, None, None)
				getPlayer(attacker).makeRebel()

			elif not attacker in LR.ts:
				if attacker in Rb.on_heads:
					return
				getPlayer(attacker).makeRebel()

def player_activate(ev):
	userid = ev['userid']
	if int(sv('hosties_show_rules_on_join')):
		getPlayer(userid).send('Hosties')

	HM.getPlayer(userid)
	Rb.iks[int(userid)] = {}

	if int(sv('hosties_mute_dead')):
		getPlayer(userid).mute()

def player_disconnect(ev):
	userid = int(ev['userid'])
	for dictOBJ in [Rb.iks, Rb.ik, Rb.kps, Rb.on_heads]:
		if userid in dictOBJ:
			del dictOBJ[userid]
	HM.delPlayer(userid)

def player_death(ev):
	userid = int(ev['userid'])
	Rb.player_death(userid, int(ev['attacker']), ev['weapon'])
	gamethread.delayed(0, LR.playerDeath, userid)

	if len(playerlib.getPlayerList('#t,#alive')) == int(sv('hosties_min_players_for_lr')) and ev['es_userteam'] == '2':
		if int(sv('hosties_announce_lr_available')):
			for userid2 in es.getUseridList():
				getPlayer(userid2).tell('lr available')
				es.cexec(userid2, 'play hosties/lr.wav')

	if int(sv('hosties_mute_dead')):
		getPlayer(userid).mute()

def player_jump(ev):
	for i in [0.4, 0.6, 0.8]:
		gamethread.delayed(i, Rb.checkOnHead, int(ev['userid']))

def round_start(ev):
	gamethread.delayed(0.1, LR.stopLR, (None, None, None))
	for userid in es.getUseridList():
		playerlib.getPlayer(userid).set('color', [255, 255, 255, 255])
	del Rb.rebels[:]

	if int(sv('hosties_end_round_at_round_end_time')):
		gamethread.cancelDelayed('end round')
		gamethread.delayedname(float(sv('mp_roundtime')) * 60, 'end round', endRound)

	if int(sv('hosties_noblock_on_round_start')):
		for userid in es.getUseridList():
			es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 2)
			playerlib.getPlayer(userid).set('color', [255, 255, 255, 255])
		gamethread.delayedname(int(sv('hosties_noblock_on_round_start')), 'unblock', HM.unBlockPlayers)
	gamethread.delayed(0, HM.mutePlayers)

def round_end(ev):
	for userid in es.getUseridList():
		if popuplib.isqueued('Punishment Menu', userid):
			popuplib.close('Punishement Menu', userid)

	for delay in ['unblock', 'unmute ts in', 'end round']:
		gamethread.cancelDelayed(delay)

	for steamid in Rb.trounds.keys():
		Rb.trounds[steamid] -= 1
		if Rb.trounds[steamid] <= 0:
			del Rb.trounds[steamid]
			if es.getuserid(steamid):
				getPlayer(es.getuserid(steamid)).tell('can go t')

	Rb.ik.clear()
	Rb.on_heads.clear()

	HM.roundEnd()
	gamethread.delayed(0.1, LR.stopLR, (None, None, None))

def say_command():
	player_say({'userid': str(es.getcmduserid()), 'text': str('!' + es.getargv(0).replace('!', '')).replace('"', '')})

def player_say(ev):
	stext = ev['text'].lower()
	if stext in sv_options['hosties_commands']:
		userid = int(ev['userid'])
		if not stext in str(sv('hosties_commands')):
			getPlayer(userid).tell('disabled command')
			return

		if stext == '!lr':
			LR.initiateRequest(userid)

		elif stext == '!rules':
			getPlayer(userid).send('Rules')

		elif stext == '!checkplayers':
			playermenu = popuplib.easymenu('Check Players', '_popup_choice', lambda *a: None)
			for userid2 in playerlib.getUseridList('#t,#alive'):
				playermenu.addoption(userid, ('[Rebel]' if userid2 in Rb.rebels else '[Non Rebel]') + ' %s'%es.getplayername(userid2))
			getPlayer(userid).send('Check Players')

		elif stext == '!commands':
			getPlayer(userid).send('Commands')

		elif stext == '!hosties':
			getPlayer(userid).send('Hosties')

		elif stext == '!checkguns':
			gunmenu = popuplib.easymenu('Player Guns', '_popup_choice', gunmenu_select)
			for p in playerlib.getPlayerList('#t,#alive'):
				gunmenu.addoption(int(p), '%s [P: %s, S: %s]'%(p.get('name'), 'No' if str(p.get('primary')) == '0' else 'Yes', 'No' if str(p.get('secondary')) == '0' else 'Yes'))
			getPlayer(userid).send('Player Guns')

def player_spawn(ev):
	userid = ev['userid']
	if int(sv('hosties_strip_weapons_on_round_end')):
		es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
		es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)
		es.server.queuecmd('es_delayed 0 es_fire %s player_weaponstrip kill'%userid)

	if es.getplayerteam(userid) == 2:
		for weapon in str(sv('hosties_t_start_weapons')).split(','):
			gamethread.delayed(0, es.server.queuecmd, 'es_xgive %s weapon_%s'%(userid, weapon))

	elif es.getplayerteam(userid) == 3:
		if not str(sv('hosties_warning_weapon')) == '0':
			getPlayer(userid).tell('warning weapon name', {'weapon': str(sv('hosties_warning_weapon'))})

		for weapon in str(sv('hosties_ct_start_weapons')).split(','):
			gamethread.delayed(0, es.server.queuecmd, ('es_xgive %s weapon_%s'%(userid, weapon)))

	if int(sv('hosties_enable_noblock')):
		es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 2)

def item_pickup(ev):
	userid = ev['userid']
	weapon = ev['item']

	if HM.isRestricted(weapon, es.getplayerteam(userid), int(userid)):
		handle = es.getplayerhandle(userid)
		for index in es.createentitylist('weapon_%s'%weapon):
			if handle == es.getindexprop(index, 'CBaseEntity.m_hOwnerEntity'):
				es.server.queuecmd('es_xremove %s'%index)
				getPlayer(userid).tell('restricted weapon', {'weapon': weapon})
				es.cexec(userid, 'lastinv')
				break

### Commands ###

def lr_command():
	if es.getargv(0) in LRM.commands:
		LRM.commands[es.getargv(0)](es.getuserid())

def hosties_rule():
	args = es.getargs()
	if not args:
		es.dbgmsg(0, 'Need more args to add rules!')
		return
	HM.addRule(args)

def hosties_addpun():
	if es.getargs():
		if len(es.getargs().split(' ')) < 2:
			es.dbgmsg(0, 'Not enough arguments for hosties_addpunishment!')
			return
		Rb.add_punishment(es.getargs().split(' '))

def add_menu_punishment():
	if es.getargc() < 3:
		es.dbgmsg(0, 'Syntax Error: hosties_add_menu_punishment <kills> <punishments>')
		return

	args = es.getargs().split(' ')
	HM.punishments[args[0]] = args[1]

def hosties_load():
	gamethread.delayed(0, LRM.loadLastRequest, es.getargv(1))

def hosties_unload():
	gamethread.delayed(0, LRM.unloadLastRequest, es.getargv(1))

def hosties_reload():
	LRM.reloadLastRequest(es.getargv(1))

def hosties_loadmod():
	HM.loadMod(es.getargv(1))

def hosties_unloadmod():
	HM.unloadMod(es.getargv(1))

def hosties_reloadmod():
	HM.reloadMod(es.getargv(1))

def _restrict_weapons(userid, args):
	if not args:
		return True

	if args[0].lower() in ['buy', 'jointeam', 'chooseteam']:
		if len(args) == 1:
			return True

		if args[0].lower() == 'buy':
			if HM.isRestricted(args[1].lower(), es.getplayerteam(userid), userid, False):
				getPlayer(userid).tell('restricted weapon', {'weapon': args[1]})
				return False

		elif args[0].lower() in ['jointeam', 'chooseteam']:
			playerdata = getPlayer(userid).pd
			if playerdata['restrict team']:
				tryTeam = args[1].replace('"', '').replace('\n', '').replace('\r', '')
				if tryTeam in ['0', playerdata['restrict team']]:
					timeleft = playerdata['bantime'] - (time.time() - playerdata['banned'])
					if timeleft <= 0:
						getPlayer(userid).pd = {'restrict team': False, 'bantime': 0, 'banned': 0, 'reason': 'None', 'name': 'moo'}
						gamethread.delayed(0, es.cexec, (userid, '%s %s'%(args[0], args[1])))
						return False

					if tryTeam == '0':
						getPlayer(userid).tell('cant auto assign')
						return False

					minutes, seconds = divmod(timeleft, 60)
					hours, minutes = divmod(minutes, 60)

					getPlayer(userid).tell('cant join team', {'team': 'Counter-Terrorist' if playerdata['restrict team'] == '3' else 'Terrorist', 'time': '%i:%02i:%02i'%(hours, minutes, seconds)})
					getPlayer(userid).tell('type teamtime')
					return False
				return True

			if str(sv('hosties_t_to_ct_ratio')) == '0':
				return True

			cexeced = False
			if len(args) > 2:
				if args[2] == HASH:
					cexeced = True

			if int(sv('hosties_auto_assign_only')) and args[1] in '23' and not cexeced:
				args[1] = '0'

			if args[1] == '0':
				randomTeam = random.randint(2, 3)
				getPlayer(userid).tell('auto assigned')

				if _restrict_weapons(userid, ['chooseteam', str(randomTeam), HASH]):
					es.cexec(userid, 'jointeam %s %s'%(randomTeam, HASH))

				else:
					es.cexec(userid, 'jointeam %s %s'%(2 if randomTeam == 3 else 3, HASH))
				return False

			if not args[1].isdigit():
				return False

			team = int(args[1])
			if not team in [2, 3]:
				return False

			t_count = es.getplayercount(2)
			ct_count = es.getplayercount(3)

			tplus = 1 if team == 2 else -1
			ctplus = 1 if team == 3 else -1

			if es.getplayerteam(userid) < 2:
				tplus = 1 if team == 2 else 0
				ctplus = 1 if team == 3 else 0

			t_count = max(1, t_count + tplus)
			ct_count = max(1, ct_count + ctplus)

			if team == 3:
				if es.getplayersteamid(userid) in Rb.trounds:
					getPlayer(userid).tell('rounds as t', {'rounds': Rb.trounds[es.getplayersteamid(userid)]})
					return False

				if t_count < 3 or ct_count < 3:
					return True

			ratio_str = str(sv('hosties_t_to_ct_ratio')).replace(' ', '')
			if not ':' in ratio_str:
				return True

			ratio = map(int, ratio_str.split(':'))
			ratio = ratio[0] / float(ratio[1])

			newRatio = t_count / float(ct_count)
			if newRatio < ratio and team == 3:
				getPlayer(userid).tell('ratio unbalanced', {'ct': ratio_str.split(':')[1], 't': ratio_str.split(':')[0]})
				return False
			return True
	return LRM.returnClientCommand(userid, args)
es.addons.registerClientCommandFilter(_restrict_weapons)

### Popup Selects ###

def hosties_select(userid, choice, popupid):
	getPlayer(userid).send(choice)

def gunmenu_select(userid, choice, popupid):
	gunmenu = popuplib.easymenu('Current Guns', '_popup_choice', gunmenu_select)
	gunmenu.addoption(choice, 'Primary: %s'%playerlib.getPlayer(choice).get('primary'))
	gunmenu.addoption(choice, 'Secondary: %s'%playerlib.getPlayer(choice).get('secondary'))
	getPlayer(userid).send('Current Guns')

### Misc ###

def return_random_t_spawn(ct=False):
	for spawn in es.createentitylist('info_player_%sterrorist'%('counter' if ct else '')):
		x, y, z = map(float, es.getindexprop(spawn, 'CBaseEntity.m_vecOrigin').split(','))
		count = 0

		for userid in playerlib.getUseridList('#alive'):
			x2, y2, z2 = es.getplayerlocation(userid)
			if abs(x - x2) >= 30 and abs(y - y2) >= 30 and abs(z - z2) >= 30:
				count += 1

		if count == len(playerlib.getUseridList('#alive')):
			return x, y, z
	return x, y, z

def check_regen(userid):
	if not es.exists('userid', userid):
		return

	if not userid in Rb.rebels:
		if not playerlib.getPlayer(userid).get('isdead'):
			playerlib.getPlayer(userid).set('health', playerlib.getPlayer(userid).get('health') + int(sv('hosties_warning_weapon_damage')))

def getPlayer(userid):
	return HM.getPlayer(userid)

def endRound():
	es.server.queuecmd('es_flags remove cheat endround;endround;es_flags add cheat endround')
