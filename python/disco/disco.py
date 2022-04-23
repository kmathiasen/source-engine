import es, gamethread, random, effectlib, playerlib, services, os.path, cPickle, popuplib, re

### Globals ###

info = es.AddonInfo() 

info['name']        = "Disco" 
info['version']     = "3.0.1b" 
info['author']      = "Bonbon AKA: Bonbon367" 
info['url']         = "http://addons.eventscripts.com/addons/view/disco" 
info['description'] = "Disco script by Bonbon"

es.ServerVar('disco_version', info['version'], info['description']).makepublic()

COLORS = [(255, 0, 0), (0, 0, 255), (0, 255, 0), (255, 0, 255), (255, 255, 0), (0, 255, 255)]
FILEPATH = es.getAddonPath('disco') + '/'

options = {
	'disco_length_min': 50,
	'disco_length_max': 350,
	'disco_x_spin': 10,
	'disco_y_spin': 10,
	'disco_z_spin': 10,
	'disco_admins': 'STEAM_0:0:11089864,STEAM_0:0:000000,STEAM_0:1:1111111111,mani_admins,STEAM_ID_LAN',
	'disco_fog_change_time': 2,
	'disco_fog_start_unit': 150,
	'disco_fog_end_unit': 1000,
	'disco_enable_fog': 1,
	'disco_above_head_amount': 40,
	'disco_on_map_end': 0,
	'disco_on_map_start': 1,
}
sv = es.ServerVar

### Loads ###

def load():
	if not es.exists('clientcommand', 'disco'):
		es.regclientcmd('disco', 'disco/disco_player')

	if not es.exists('saycommand', '!disco'):
		es.regsaycmd('!disco', 'disco/disco_player')

	if not es.exists('command', 'disco'):
		es.regcmd('disco', 'disco/disco_server')

	if not es.exists('command', 'disco_addsound'):
		es.regcmd('disco_addsound', 'disco/disco_addsound')

	for option in options:
		sv(option).set(options[option])

	if os.path.isfile(FILEPATH + 'disco.cfg'):
		es.server.cmd('es_xmexec ../addons/eventscripts/disco/disco.cfg')

	discoMenu = popuplib.easymenu('Disco Menu', '_popup_choice', discoMenuSelect)
	for option in ['Start', 'Stop', 'Save Location', 'Delete Location', 'Commands']:
		discoMenu.addoption(option, option)

	commandMenu = popuplib.easymenu('Disco Commands', '_popup_choice', commandMenuSelect)
	commandMenu.setdescription('Syntax: disco <command> <args>')

	for command, args in [['stop', 'disco stop'], ['loc', 'disco loc <x> <y> <z>'], ['head', 'disco head'], ['view', 'disco view'], ['time', 'disco time <seconds> [x] [y] [z]'], ['sound', 'disco sound <sound> [x] [y] [z]'], ['menu', 'disco menu'], ['Save Location (menu)', 'If selected while standing, it will take the location above your head, if crouching it will take your feet position']]:
		commandMenu.addoption(args, command)

	disco.setupAuth()
	es.addons.registerSayFilter(locations.hookText)
	add_downloads()

	if str(sv('eventscripts_currentmap')) == '0' and int(sv('disco_on_map_start')):
		disco.firstRound = 0

def unload():
	if es.exists('clientcommand', 'disco'):
		es.unregclientcmd('disco')

	if es.exists('saycommand', '!disco'):
		es.unregsaycmd('!disco')

	es.addons.unregisterSayFilter(locations.hookText)
	disco.stopDisco()

### Classes ###

# 66209 Damnit, what was this for again? Oh yeah, m_fFlags

class Disco(object):
	def __init__(self):
		self.sounds = {}
		self.admins = []
		self.origin = []

		self.index = None
		self.isDisco = False
		self.firstRound = 2

	### Authorization ###

	def isAuthed(self, userid):
		if self.hasAuth(userid) or es.getplayersteamid(userid) in self.admins:
			return True

	def setupAuth(self):
		if services.isRegistered('auth'):
			auth_service = services.use('auth')
			auth_service.registerCapability('disco_admin', auth_service.ADMIN)
			self.hasAuth = lambda x: auth_service.isUseridAuthorized(x, 'disco_admin')

		else:
			self.hasAuth = lambda x: False

		self.admins = str(sv('disco_admins')).split(',')
		if 'mani_admins' in self.admins:
			self.admins += self.getManiAdmins()

	@staticmethod
	def getManiAdmins():
		clientsPath = FILEPATH.replace('addons/eventscripts/disco/', 'cfg/mani_admin_plugin/clients.txt')
		if not os.path.isfile(clientsPath):
			return []

		oFile = open(clientsPath)
		admins = map(lambda x: x.upper(), re.findall('(STEAM_0:[0-1]:\d+)', oFile.read(), re.IGNORECASE))
		oFile.close()
 
		return admins

	### Command Stuff ###

	def getSound(self):
		if not self.sounds:
			return None
		return random.choice(self.sounds.keys())

	def runDisco(self, args, userid=None):
		command = args[0].lower()
		if command == 'menu':
			popuplib.send('Disco Menu', userid)
			return

		elif command == 'stop':
			if not self.isDisco:
				self.debugMessage(userid, 'There is no disco running!')
				return

			self.stopDisco()
			return

		if self.isDisco:
			self.debugMessage(userid, 'There is already a disco running!')
			return

		x, y, z = None, None, None
		disco_time = None
		sound = self.getSound()

		if command == 'head':
			x, y, z = es.getplayerlocation(userid)
			z += int(sv('disco_above_head_amount')) + 80

		elif command == 'loc':
			if len(args) < 4:
				self.debugMessage(userid, 'Invalid format, disco loc <x> <y> <z>')
				return

			x, y, z = args[1:]
			for w in [x, y, z]:
				try:
					float(w)

				except ValueError:
					self.debugMessage(userid, 'All values must be numbers!')
					return
			x, y, z = map(float, [x, y, z])

		elif command == 'time':
			if not len(args) in [2, 5]:
				self.debugMessage(userid, 'Invalid format, disco time <time> [x] [y] [z]')
				return

			for val in args[1:]:
				try:
					float(val)
				except ValueError:
					self.debugMessage(userid, 'All values must be numbers!')
					return

			disco_time = float(args[1])
			if len(args) == 5:
				x, y, z = map(float, args[2:])

		elif command == 'sound':
			if not len(args) in [2, 5]:
				self.debugMessage(userid, 'Invalid format, disco sound <sound> [x] [y] [z]')
				return

			if not userid:
				if not len(args) == 5:
					es.dbgmsg(0, 'Disco - disco sound <sound> <x> <y> <z>')
					return

			if userid:
				x, y, z = es.getplayerlocation(userid)
				z += 10

			if len(args) == 5:
				for val in args[2:]:
					try:
						float(val)
					except ValueError:
						self.debugMessage(userid, 'All values besides sound must be integers!')
				x, y, z = map(float, args[2:])
			disco_sound = args[1]

		if not userid:
			userid = es.getuserid()

		self.index = es.createentitylist('prop_dynamic').keys()
		es.server.queuecmd('es_xprop_dynamic_create %s roller_spikes.mdl'%userid)

		gamethread.delayed(0.05, self.ballSpawned, (x, y, z, disco_time, sound, userid))
		self.isDisco = True

	def ballSpawned(self, x, y, z, disco_time, sound, userid):
		self.origin = [x, y, z]
		for index in es.createentitylist('prop_dynamic'):
			if not index in self.index:
				self.index = index
				break

		if x is None:
			self.origin = map(float, es.getindexprop(self.index, 'CBaseEntity.m_vecOrigin').split(','))

		else:
			es.setindexprop(self.index, 'CBaseEntity.m_vecOrigin', ','.join(map(str, [x, y, z])))

		self.length_min = float(sv('disco_length_min'))
		self.length_max = float(sv('disco_length_max'))

		self.createFog()
		self.spinLoop()
		self.laserLoop()

		if disco_time:
			gamethread.delayedname(disco_time, 'timed stop', self.stopDisco)

		if sound:
			for userid in es.getUseridList():
				es.cexec(userid, 'play %s'%sound)

			soundtime = self.sounds[sound]
			if soundtime:
				gamethread.delayedname(soundtime, 'disco change sound', self.changeSound, sound)

	def changeSound(self, lastsound):
		sound = 0
		if len(self.sounds) == 1:
			sound = lastsound

		while not sound:
			moo = self.getSound()
			if moo <> lastsound:
				sound = moo

		for userid in es.getUseridList():
			es.cexec(userid, 'play %s'%sound)

		soundtime = self.sounds[sound]
		if soundtime:
			gamethread.delayedname(soundtime, 'disco change sound', self.changeSound, sound)

	def createFog(self):
		userid = es.getuserid()
		es.server.queuecmd('es_xgive %s env_fog_controller'%userid)
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogdir 100 100 100"'%userid)
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogstart %s"'%(userid, int(sv('disco_fog_start_unit'))))
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogend %s"'%(userid, int(sv('disco_fog_end_unit'))))
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogblend 1"'%userid)
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogcolor 100 100 100"'%userid)
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput "fogcolor2 150 150 150"'%userid)
		es.server.queuecmd('es_xfire %s env_fog_controller turnon'%userid)

		change_time = float(sv('disco_fog_change_time'))
		gamethread.delayedname(change_time, 'change fog color', self.fogLoop, change_time)

	def fogLoop(self, change_time):
		gamethread.delayedname(change_time, 'change fog color', self.fogLoop, change_time)
		userid = es.getuserid()

		es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogcolor %s %s %s\"'%((userid,) + random.choice(COLORS)))
		es.server.queuecmd('es_xfire %s env_fog_controller addoutput \"fogcolor2 %s %s %s\"'%((userid,) + random.choice(COLORS)))

	def spinLoop(self):
		x, y, z = map(float, es.getindexprop(self.index, 'CBaseEntity.m_angRotation').split(','))
		x += float(sv('disco_x_spin'))
		y += float(sv('disco_y_spin'))
		z += float(sv('disco_z_spin'))

		es.setindexprop(self.index, 'CBaseEntity.m_angRotation', ','.join(map(str, [x, y, z])))
		gamethread.delayedname(0.1, 'spin loop', self.spinLoop)

	def laserLoop(self):
		r, g, b = random.choice(COLORS)
		x, y, z = self.origin

		x2 = x + random.randint(self.length_min, self.length_max) * random.choice([-1, 1])
		y2 = y + random.randint(self.length_min, self.length_max) * random.choice([-1, 1])
		z2 = z + random.randint(self.length_min, self.length_max) * random.choice([-1, 1])
		x3, y3, z3 = es.getplayerlocation(random.choice(playerlib.getUseridList('#alive')))

		if random.randint(0, 3):
			effectlib.drawLine([x, y, z], [x2, y2, z2], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
			effectlib.drawLine([x, y, z], [x2 + 5, y2 + 5, z2], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
			effectlib.drawLine([x, y, z], [x2 + 5, y2, z2], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
		else:
			effectlib.drawLine([x, y, z], [x3, y3, z3], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
			effectlib.drawLine([x, y, z], [x3 + 5, y3 + 5, z3], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
			effectlib.drawLine([x, y, z], [x3 + 5, y3, z3], "materials/sprites/laser.vmt", "materials/sprites/halo01.vmt", random.randint(1, 10) / 10.0, random.randint(1, 10), random.randint(1, 25), r, g, b, 255, 10, 0, 0, 0, 0)
		gamethread.delayedname(random.randint(1, 5) / 25.0, 'laser loop', self.laserLoop)

	def debugMessage(self, userid, message):
		if userid:
			es.tell(userid, '#multi', '#lightgreen[Disco]: #default' + message)
		else:
			es.dbgmsg(0, 'Disco - ' + message)

	def stopDisco(self):
		if not self.isDisco:
			return

		for loop in ['change fog color', 'spin loop', 'laser loop', 'timed stop', 'disco change sound']:
			gamethread.cancelDelayed(loop)

		if self.index in es.createentitylist():
			es.server.queuecmd('es_xremove %i'%self.index)

		self.origin = []
		self.index = None
		self.isDisco = False

		userid = es.getuserid()
		if userid:
			es.server.queuecmd('es_xfire %s env_fog_controller turnoff'%userid)
			es.server.queuecmd('es_xfire %s env_fog_controller kill'%userid)

		for userid in es.getUseridList():
			es.cexec(userid, 'play cow.wav;echo stop posting the cow error on the forums...')

disco = Disco()

class DiscoLocations(object):
	def __init__(self):
		self.coords = self.getCoords()
		self.choosing = {}

		self.getCoords()

	@staticmethod
	def getCoords():
		if os.path.isfile(FILEPATH + 'coords.db'):
			oFile = open(FILEPATH + 'coords.db')
			coords = cPickle.load(oFile)
			oFile.close()

			return coords
		return {}

	def playerDisconnect(self, userid):
		userid = int(userid)
		if userid in self.choosing:
			del self.choosing[userid]

	def selectLocation(self, userid):
		x, y, z = es.getplayerlocation(userid)
		self.choosing[userid] = [x, y, z + (0 if (es.getplayerprop(userid, 'CBasePlayer.localdata.m_Local.m_bDucked') % 2) else (80 + int(sv('disco_above_head_amount'))))]
		es.tell(userid, '#multi', '#lightgreen[Disco]: #defaultPlease enter a name for this location in chat box')

	def hookText(self, userid, text, teamonly):
		if not userid in self.choosing:
			return userid, text, teamonly

		text = text.replace('"', '').replace('\r', '').replace('\n', '')[0:32]
		mapname = str(sv('eventscripts_currentmap'))

		if not mapname in self.coords:
			self.coords[mapname] = {}

		self.coords[mapname][text] = self.choosing[userid]
		self.saveCoords()
		es.tell(userid, '#multi', '#lightgreen[Disco]: #defaultLocation added under the name #lightgreen%s'%text)

		del self.choosing[userid]
		return None, None, None

	def saveCoords(self):
		iFile = open(FILEPATH + 'coords.db', 'w')
		cPickle.dump(self.coords, iFile)
		iFile.close()

locations = DiscoLocations()

### Events ###

def es_map_start(ev):
	add_downloads()
	if int(sv('disco_on_map_start')):
		disco.firstRound = 0

def round_start(ev):
	disco.stopDisco()
	if disco.firstRound > 0:
		return

	if len(filter(lambda x: es.getplayersteamid(x) <> 'BOT', es.getUseridList())):
		disco.firstRound += 1
		disco_from_map()

def round_end(ev):
	disco.stopDisco()

def player_disconnect(ev):
	locations.playerDisconnect(ev['userid'])

def est_map_end(ev):
	if not es.getuserid():
		return

	if int(sv('disco_on_map_end')):
		disco_from_map()

def player_spawn(ev):
	if disco.firstRound > 0:
		return

	if ev['es_steamid'] == 'BOT':
		return

	if ev['es_userteam'] == '0':
		return

	if len(filter(lambda x: es.getplayersteamid(x) == 'BOT', es.getUseridList())):
		if es.getplayercount(3 if ev['es_userteam'] == '2' else 2) > 0:
			return

	disco.firstRound += 1
	disco_from_map()

### Commands ###

def disco_player():
	userid = es.getcmduserid()
	args = es.getargs()

	if args:
		args = args.split(' ')

	if not disco.isAuthed(userid):
		es.tell(userid, '#multi', '#lightgreen[Disco]: #defaultYou are not authorized to run this command!')
		return

	if not args:
		popuplib.send('Disco Menu', userid)
		return

	if not args[0].lower() in ['stop', 'loc', 'sound', 'menu', 'time', 'head', 'view']:
		es.tell(userid, '#multi', '#lightgreen[Disco]: #defaultInvalid command, for a list of available commands type disco menu')
		return
	disco.runDisco(args, userid)

def disco_server():
	args = es.getargs()
	if args:
		args = args.split(' ')

	if not args or not args[0].lower() in ['loc', 'sound', 'time', 'stop']:
		es.dbgmsg(0, 'Disco -- Invalid syntax, valid commands are:')
		for syntax in ['loc <x> <y> <z>', 'sound <sound> [x] [y] [z]', 'time <time> [x] [y] [z]', 'stop']:
			es.dbgmsg(0, '   ' + syntax)
		return

	if not es.getuserid():
		es.dbgmsg(0, 'Disco -- There are no players on the server!')
		return
	disco.runDisco(args)

def disco_addsound():
	args = es.getargs()
	if not args:
		es.dbgmsg(0, 'Disco -- Invalid syntax, disco_addsound <sound> [length]')
		return

	args = map(lambda x: x.replace('\r', '').replace('\n', ''), args.split(' '))
	soundtime = 0

	if len(args) > 1:
		if args[1].isdigit():
			soundtime = int(args[1])
	disco.sounds[args[0]] = soundtime

### Popups ###

def discoMenuSelect(userid, choice, popupid):
	if choice == 'Start':
		selectMapLocMenu = popuplib.easymenu('Choose Saved Location', '_popup_choice', selectMapLocMenuSelect)
		mapname = str(es.ServerVar('eventscripts_currentmap'))

		if mapname in locations.coords:
			for locname in locations.coords[mapname]:
				selectMapLocMenu.addoption(locname, locname)
		popuplib.send('Choose Saved Location', userid)

	elif choice == 'Stop':
		es.cexec(userid, 'disco stop')

	elif choice == 'Save Location':
		locations.selectLocation(userid)

	elif choice == 'Delete Location':
		mapMenu = popuplib.easymenu('Disco Maps', '_popup_choice', mapMenuSelect)
		for mapname in locations.coords:
			mapMenu.addoption(mapname, mapname)
		popuplib.send('Disco Maps', userid)

	elif choice == 'Commands':
		popuplib.send('Disco Commands', userid)

def selectMapLocMenuSelect(userid, choice, popupid):
	es.cexec(userid, 'disco loc %s %s %s'%tuple(locations.coords[str(es.ServerVar('eventscripts_currentmap'))][choice]))

def commandMenuSelect(userid, choice, popupid):
	es.tell(userid, '#multi', '#lightgreen[Disco]: #default' + choice)

def mapMenuSelect(userid, choice, popupid):
	deleteCoordMenu = popuplib.easymenu('Delete Coords - %s'%choice, '_popup_choice', deleteCoordMenuSelect)
	for coordName in locations.coords[choice]:
		deleteCoordMenu.addoption([choice, coordName], coordName)
	popuplib.send('Delete Coords - %s'%choice, userid)

def deleteCoordMenuSelect(userid, choice, popupid):
	mapName, coordName = choice
	if coordName in locations.coords[mapName]:
		del locations.coords[mapName][coordName]
		es.tell(userid, '#multi', '#lightgreen[Disco]: #defaultRemoved coord name #lightgreen%s#default from map #lightgreen%s'%(coordName, mapName))

### Misc ###

def add_downloads():
	for sound in disco.sounds:
		if sound and not sound == '0':
			es.stringtable('downloadables', 'sound/' + sound)

def disco_from_map():
	mapname = str(sv('eventscripts_currentmap'))
	if mapname in locations.coords:
		x, y, z = locations.coords[mapname][random.choice(locations.coords[mapname].keys())]
		es.server.queuecmd('disco loc %s %s %s'%(x, y, z))
