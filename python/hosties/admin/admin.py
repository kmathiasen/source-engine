import hosties.hosties as hosties, es, services, re, popuplib, cPickle, os.path, time, playerlib

### Globals ###

sv = es.ServerVar

### Loads ###

def load():
	for command in ['hostiesadmin', 'teamtime', 'stoplr', 'banteam', 'makerebel']:
		if not es.exists('saycommand', '!' + command):
			es.regsaycmd('!' + command, 'hosties/admin/say_command')

	if not es.exists('command', 'banteam'):
		es.regcmd('banteam', 'hosties/admin/banteam_console_command')

	admin.setupAuth()
	for userid in es.getUseridList():
		steamid = es.getplayersteamid(userid)
		if steamid in admin.banned:
			hosties.getPlayer(userid).pd = admin.banned[steamid]

def unload():
	for command in ['!hostiesadmin', '!teamtime', '!stoplr', '!banteam', '!makerebel']:
		if es.exists('saycommand', command):
			es.unregsaycmd(command)

### Classes ###

class HostiesAdmin(object):
	def __init__(self):
		self.players = {}
		self.admins = []
		self.banned = self.getBanned()

		self.adminMenu = popuplib.easymenu('Hosties Admin', '_popup_choice', self.adminMenuSelect)
		for option in ['Stop LR', 'Ban Player From Team', 'Make Player Rebel', 'Spawn and Tele to Death Loc', 'Remove Ban', 'Toggle LRs', 'Toggle Mods', 'Commands', 'Unmake Player Rebel']:
			self.adminMenu.addoption(option, option)

		self.commandMenu = popuplib.easymenu('Hosties Admin Commands', '_popup_choice', self.commandMenuSelect)
		for command in ['hostiesadmin', 'stoplr', 'banteam', 'makerebel']:
			self.commandMenu.addoption(command, '!' + command)

		self.lastrequests = []
		self.toggleLastRequestsMenu = popuplib.easymenu('Hosties Toggle Last Request', '_popup_choice', self.toggleLastRequestsMenuSelect)

		for request in os.listdir(hosties.FILEPATH + 'lastrequests/'):
			if not '.' in request:
				self.lastrequests.append(request)
				self.toggleLastRequestsMenu.addoption(request, hosties.text(request, {}, hosties.menu_lang))

		self.mods = []
		self.toggleModsMenu = popuplib.easymenu('Hosties Toggle Mods', '_popup_choice', self.toggleModsMenuSelect)

		for mod in os.listdir(hosties.FILEPATH + 'mods/'):
			if not '.' in mod:
				self.mods.append(mod)
				self.toggleModsMenu.addoption(mod, mod)

	### Data ###

	@staticmethod
	def getBanned():
		data = {}
		if os.path.isfile(hosties.FILEPATH + 'admin/banned.db'):
			oFile = open(hosties.FILEPATH + 'admin/banned.db')
			data = cPickle.load(oFile)
			oFile.close()
		return data

	def saveData(self):
		for steamid in self.banned.keys():
			if time.time() - self.banned[steamid]['banned'] >= self.banned[steamid]['bantime']:
				del self.banned[steamid]

		iFile = open(hosties.FILEPATH + 'admin/banned.db', 'w')
		cPickle.dump(self.banned, iFile)
		iFile.close()

	### Auth ###

	def isAuthed(self, userid):
		if self.hasAuth(userid) or es.getplayersteamid(userid) in self.admins:
			return True

	def setupAuth(self):
		if services.isRegistered('auth'):
			auth_service = services.use('auth')
			auth_service.registerCapability('hosties_admin', auth_service.ADMIN)
			self.hasAuth = lambda x: auth_service.isUseridAuthorized(x, 'hosties_admin')

		else:
			self.hasAuth = lambda x: False
		self.getAdmins()

	def getAdmins(self):
		self.admins = str(sv('hosties_admins')).replace(' ', '').replace('"', '').split(',')
		if 'mani_admins' in self.admins:
			self.admins += self.getManiAdmins()

	@staticmethod
	def getManiAdmins():
		clientsPath = hosties.FILEPATH.replace('addons/eventscripts/hosties/', 'cfg/mani_admin_plugin/clients.txt')
		if not os.path.isfile(clientsPath):
			return []

		oFile = open(clientsPath)
		admins = map(lambda x: x.upper(), re.findall('(STEAM_0:[0-1]:\d+)', oFile.read(), re.IGNORECASE))
		oFile.close()
 
		return admins

	### Popups ###

	def adminMenuSelect(self, userid, choice, popupid):
		if choice == 'Stop LR':
			if not hosties.LR.ts:
				hosties.getPlayer(userid).tell('no lr in progress')
				return
			hosties.LR.stopLR(None, None, 'lr stopped')

		elif choice == 'Ban Player From Team':
			selectPlayerMenu = popuplib.easymenu('Ban Player From Team', '_popup_choice', self.selectPlayerMenuSelect)
			for userid2 in es.getUseridList():
				selectPlayerMenu.addoption(userid2, es.getplayername(userid2))
			hosties.getPlayer(userid).send('Ban Player From Team')

		elif choice == 'Make Player Rebel':
			selectPlayerForRebelMenu = popuplib.easymenu('Select Player To Make Rebel', '_popup_choice', self.selectPlayerForRebelMenuSelect)
			for userid2 in filter(lambda x: x not in hosties.Rb.rebels, playerlib.getUseridList('#t,#alive')):
				selectPlayerForRebelMenu.addoption(userid2, es.getplayername(userid2))
			hosties.getPlayer(userid).send('Select Player To Make Rebel')

		elif choice == 'Commands':
			hosties.getPlayer(userid).send('Hosties Admin Commands')

		elif choice == 'Spawn and Tele to Death Loc':
			selectSpawnPlayerMenu = popuplib.easymenu('Select Player To Respawn', '_popup_choice', self.selectSpawnPlayerMenuSelect)
			for userid2 in playerlib.getUseridList('#dead,#t'):
				if not userid2 in self.players:
					continue
				selectSpawnPlayerMenu.addoption(userid2, es.getplayername(userid2))
			hosties.getPlayer(userid).send('Select Player To Respawn')

		elif choice == 'Remove Ban':
			selectBanRemoveMenu = popuplib.easymenu('Select Ban To Remove', '_popup_choice', self.selectBanRemoveMenuSelect)
			for steamid in self.banned:
				selectBanRemoveMenu.addoption(steamid, self.banned[steamid]['name'])
			hosties.getPlayer(userid).send('Select Ban To Remove')

		elif choice == 'Toggle LRs':
			self.refreshLRMenu()
			hosties.getPlayer(userid).send('Hosties Toggle Last Request')

		elif choice == 'Toggle Mods':
			self.refreshModsMenu()
			hosties.getPlayer(userid).send('Hosties Toggle Mods')

		elif choice == 'Unmake Player Rebel':
			selectPlayerForUnrebelMenu = popuplib.easymenu('Select Player To Unmake Rebel', '_popup_choice', self.selectPlayerForUnrebelMenuSelect)
			for userid2 in hosties.Rb.rebels:
				selectPlayerForUnrebelMenu.addoption(userid2, es.getplayername(userid2))
			hosties.getPlayer(userid).send('Select Player To Unmake Rebel')

	def selectPlayerForUnrebelMenuSelect(self, userid, choice, popupid):
		if choice in hosties.Rb.rebels:
			hosties.Rb.rebels.remove(choice)
			playerlib.getPlayer(choice).set('color', [255, 255, 255, 255])
			hosties.getPlayer(choice).tell('unmake player rebel', {'player': es.getplayername(choice)})

	def commandMenuSelect(self, userid, choice, popupid):
		hosties.getPlayer(userid).tell(choice + ' command')

	def selectPlayerMenuSelect(self, userid, choice, popupid):
		if not es.exists('userid', choice):
			hosties.getPlayer(userid).tell('target left server')
			return

		selectTeamMenu = popuplib.easymenu('Select Team To Ban', '_popup_choice', self.selectTeamMenuSelect)
		selectTeamMenu.addoption([choice, '2'], 'T')
		selectTeamMenu.addoption([choice, '3'], 'CT')
		hosties.getPlayer(userid).send('Select Team To Ban')

	def selectTeamMenuSelect(self, userid, choice, popupid):
		team = choice[1]
		choice = choice[0]

		if not es.exists('userid', choice):
			hosties.getPlayer(userid).tell('target left server')
			return

		selectTimeMenu = popuplib.easymenu('Select Time To Ban', '_popup_choice', self.selectTimeMenuSelect)
		selectTimeMenu.addoption([choice, 0, team], 'Unban')
		selectTimeMenu.addoption([choice, 94608000, team], 'Permanent')

		for bantime in [1, 10, 30, 60, 120, 180, 360, 500, 720, 1000, 1240, 42]:
			hours, minutes = divmod(bantime, 60)
			selectTimeMenu.addoption([choice, bantime * 60, team], '%iH %02iM'%(hours, minutes))
		hosties.getPlayer(userid).send('Select Time To Ban')

	def selectTimeMenuSelect(self, userid, choice, popupid, reason=None):
		team = choice[2]
		bantime = choice[1]
		choice = choice[0]

		if not es.exists('userid', choice):
			if userid:
				hosties.getPlayer(userid).tell('target left server')
			return

		steamid = es.getplayersteamid(choice)
		name = es.getplayername(choice)
		self.banPlayer(steamid, name, bantime, reason, team, userid)

	def banPlayer(self, steamid, name, bantime, reason, team, userid=None):
		target = es.getuserid(steamid)
		team = str(team)

		teamname = 'Terrorist' if team == '2' else 'Counter-Terrorist'
		if target and name <> 'None':
			name = es.getplayername(target)

		if bantime == 0:
			if target:
				hosties.getPlayer(target).pd = {'restrict team': False, 'banned': 0, 'bantime': 0}

			del self.banned[steamid]
			return

		self.banned[steamid] = {'restrict team': team, 'banned': time.time(), 'bantime': bantime, 'reason': str(reason), 'name': name}
		self.saveData()

		minutes, seconds = divmod(bantime, 60)
		hours, minutes = divmod(minutes, 60)

		if target:
			hosties.getPlayer(target).pd = self.banned[steamid]
			message = hosties.text('team ban menu format', {'time': '%i:%02i:00'%(hours, minutes), 'reason': self.formatString(str(reason)), 'team': teamname}, playerlib.getPlayer(target).get('lang'))
			es.menu(0, target, message)

			if es.getplayerteam(target) == int(team):
				es.server.queuecmd('es_xchangeteam %s %s'%(target, 2 if team == '3' else 3))

		if userid:
			hosties.getPlayer(userid).tell('player banned from team', {'player': name, 'team': teamname})

	def selectPlayerForRebelMenuSelect(self, userid, choice, popupid):
		if choice in hosties.Rb.rebels:
			hosties.getPlayer(userid).tell('player already a rebel', {'player': es.getplayername(choice)})
			return

		if not choice or not es.exists('userid', choice):
			hosties.getPlayer(userid).tell('player does not exist')
			return

		if not es.getplayerteam(choice) == 2:
			hosties.getPlayer(userid).tell('target must be t')
			return

		if playerlib.getPlayer(choice).get('isdead'):
			hosties.getPlayer(userid).tell('target must be alive')
			return
		hosties.getPlayer(choice).makeRebel()

	def selectSpawnPlayerMenuSelect(self, userid, choice, popupid):
		if not choice in self.players:
			hosties.getPlayer(userid).tell('player does not exist')
			return

		if hosties.HASEST:
			es.server.queuecmd('est_spawn %s'%choice)

		elif hosties.HASSM:
			es.server.queuecmd('sm_spawn #%s'%choice)
		es.delayed(0, 'es_xsetpos %s %s'%(choice, self.players[choice]))

	def selectBanRemoveMenuSelect(self, userid, choice, popupid):
		target = None
		if es.getuserid(choice):
			target = es.getuserid(choice)
		self.removeBan(userid, choice, None, target)

	def toggleLastRequestsMenuSelect(self, userid, choice, popupid):
		if choice in hosties.LRM.funcs:
			hosties.LRM.unloadLastRequest(choice)
			hosties.getPlayer(userid).tell('unloaded', {'request': hosties.text(choice, {}, hosties.menu_lang)})
			return

		hosties.LRM.loadLastRequest(choice)
		hosties.getPlayer(userid).tell('loaded', {'request': hosties.text(choice, {}, hosties.menu_lang)})

	def toggleModsMenuSelect(self, userid, choice, popupid):
		if choice in hosties.HM.mods:
			hosties.HM.unloadMod(choice)
			hosties.getPlayer(userid).tell('unloaded', {'request': choice})
			return

		hosties.HM.loadMod(choice)
		hosties.getPlayer(userid).tell('loaded', {'request': choice})

	### Misc ###

	@staticmethod
	def formatString(string):
		words = string.split(' ')
		formatted = ['Reason: ']

		for word in words:
			if len(formatted[-1] + word) > 30:
				formatted[-1] += '\n'
				formatted.append('   ' + word)
				continue
			formatted[-1] += ' ' + word
		return ' '.join(formatted)[9:]

	def removeBan(self, userid, steamid, name, target=None):
		if not name and target:
			name = es.getplayername(target)

		if not steamid in self.banned:
			if userid:
				hosties.getPlayer(userid).tell('player not banned', {'player': name})
			return

		if not name:
			name = self.banned[steamid]['name']

		if target:
			hosties.getPlayer(target).pd = {'restrict team': False, 'banned': 0, 'bantime': 0}

		if userid:
			hosties.getPlayer(userid).tell('player unbanned', {'player': name})
		del self.banned[steamid]

	def refreshLRMenu(self):
		for lastrequest in self.lastrequests:
			if not lastrequest in hosties.LRM.funcs:
				self.toggleLastRequestsMenu.setoption(lastrequest, hosties.text(lastrequest, {}, hosties.menu_lang))
				continue
			self.toggleLastRequestsMenu.setoption(lastrequest, hosties.text(lastrequest, {}, hosties.menu_lang) + ' - Loaded')

	def refreshModsMenu(self):
		for mod in self.mods:
			if not mod in hosties.HM.mods:
				self.toggleModsMenu.setoption(mod, mod)
				continue
			self.toggleModsMenu.setoption(mod, mod + ' - Loaded')

admin = HostiesAdmin()

### Events ###

def player_activate(ev):
	userid = int(ev['userid'])
	steamid = ev['es_steamid']

	if steamid in admin.banned:
		hosties.getPlayer(userid).pd = admin.banned[steamid]

def player_death(ev):
	userid = int(ev['userid'])
	handle = es.getplayerhandle(userid)

	for i in es.createentitylist('cs_ragdoll'):
		if es.getindexprop(i, 'CCSRagdoll.m_hPlayer') == handle:
			admin.players[userid] = es.getindexprop(i, 'CCSRagdoll.m_vecOrigin').replace(',', ' ')

def player_disconnect(ev):
	userid = int(ev['userid'])
	if userid in admin.players:
		del admin.players[userid]

### Commands ###

def say_command():
	userid = es.getcmduserid()
	command = es.getargv(0).replace('"', '').lower()

	if command == '!teamtime':
		steamid = es.getplayersteamid(userid)
		if not steamid in admin.banned:
			hosties.getPlayer(userid).tell('not banned')
			return

		bantime = admin.banned[steamid]['bantime'] - (time.time() - admin.banned[steamid]['banned'])
		if bantime <= 0:
			del admin.banned[steamid]
			hosties.getPlayer(userid).pd = {'restrict team': False, 'banned': 0, 'bantime': 0}
			hosties.getPlayer(userid).tell('not banned')

		minutes, seconds = divmod(bantime, 60)
		hours, minutes = divmod(minutes, 60)

		hosties.getPlayer(userid).tell('time left on team', {'time': '%i:%02i:%02i'%(hours, minutes, seconds)})
		return

	if not admin.isAuthed(userid):
		hosties.getPlayer(userid).tell('not authorized')
		return

	if not command in str(sv('hosties_admin_commands')):
		hosties.getPlayer(userid).tell('disabled command')
		return

	args = es.getargs()
	if not args:
		args = ''

	args = args.split(' ')
	if command == '!banteam':
		if args == ['']:
			admin.adminMenuSelect(userid, 'Ban Player From Team', None)
			return

		if 0 < len(args) < 3:
			hosties.getPlayer(userid).tell('banteam args')
			return

		tuserid, team, bantime = args[0:3]
		tuserid = es.getuserid(tuserid)

		if not tuserid:
			hosties.getPlayer(userid).tell('player does not exist')
			return

		if not team.lower() in ['t', 'ct']:
			hosties.getPlayer(userid).tell('invalid team')
			return

		team = '2' if team.lower() == 't' else '3'
		try:
			bantime = int(bantime) * 60
		except ValueError:
			es.tell(userid, '#multi', '#lightgreen[Team Ban]: #defaultTime argument must be an integer')
			return

		reason = None
		if len(args) > 3:
			reason = ' '.join(args[3:])

		admin.selectTimeMenuSelect(userid, [tuserid, bantime * 60, team], None, reason)
		hosties.getPlayer(userid).tell('user banned', {'player': es.getplayername(tuserid), 'minutes': bantime, 'team': 'T' if team == '2' else 'CT'})

	elif command == '!stoplr':
		admin.adminMenuSelect(userid, 'Stop LR', None)

	elif command == '!makerebel':
		if args == ['']:
			admin.adminMenuSelect(userid, 'Make Player Rebel', None)
			return

		tuserid = es.getuserid(args[0])
		admin.selectPlayerForRebelMenuSelect(userid, tuserid, None)

	elif command == '!hostiesadmin':
		hosties.getPlayer(userid).send('Hosties Admin')

def banteam_console_command():
	args = es.getargs()
	if not args:
		args = ''

	args = args.replace('\n', '').replace('\r', '').split(' ')
	if len(args) < 3:
		es.dbgmsg(0, 'Hosties: Invalid Syntax, banteam <steamid> <team> <minutes> [reason]')
		return

	target, team, bantime = args[0:3]
	target = re.findall('(STEAM_0:[0-1]:\d+)', target, re.IGNORECASE)

	if not target:
		es.dbgmsg(0, 'Hosties: First argument must be a steamid')
		return

	if not team.lower() in ['t', 'ct']:
		es.dbgmsg(0, hosties.text('invalid team', {}, hosties.menu_lang))
		return

	team = '2' if team.lower() == 't' else '3'
	try:
		bantime = int(bantime) * 60

	except ValueError:
		es.dbgmsg(0, 'Hosties: Time argument must be an integer')
		return

	reason = None
	if len(args) > 3:
		reason = ' '.join(args[3:])

	admin.banPlayer(target[0], 'None', bantime, reason, team)
	es.dbgmsg(0, 'Hosties: Player banned')
