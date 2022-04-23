import hosties.hosties as hosties, playerlib, gamethread, es, popuplib, effectlib, random, usermsg, math

### Start Config ###

TIME = 30 # How long until the hot potatoe kills whoever has it
SIDES = 16 # How many sides the arena has, must be a multiple of four or else it wil look nothing like a circle. A square doesn't seem to work too well.

### End Config ###

THETA = 180 - (360.0 / SIDES)
DIAMETER = 168.56 - ((SIDES / 4) * math.cos(math.radians(THETA)) * 168.56)

class HotPotatoe(hosties.RegisterLastRequest):
	def __init__(self):
		super(HotPotatoe, self).__init__('hotpotatoe')
		self.t = None
		self.ct = None

		self.deagle = None
		self.lastOwner = None
		self.setup = False

		self.spawns = []
		self.center = []
		self.chosen = []
		self.indexes = set()

		self.selectCenterPointMenu = popuplib.easymenu('Select Center Point', '_popup_choice', self.centerPointSelect)
		self.selectCenterPointMenu.addoption('Choose Point', 'Choose Point')
		self.selectCenterPointMenu.submenu(0, 'Select Center Point')

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerClientCommandFilter(self._cc_filter)

	def centerPointSelect(self, userid, choice, popupid):
		if not userid == self.t:
			return

		self.center = es.getplayerlocation(userid)
		self.effectLoop()

		addSpawnLocationMenu = popuplib.easymenu('Add Spawn Location', '_popup_choice', self.addSpawnLocationSelect)
		addSpawnLocationMenu.addoption('Add Location', 'Add Location')
		addSpawnLocationMenu.submenu(0, 'Add Spawn Location')

		popuplib.send('Add Spawn Location', userid)
		hosties.HM.msg('hp2', {'t': es.getplayername(userid)})

	def addSpawnLocationSelect(self, userid, choice, popupid):
		x, y, z = es.getplayerlocation(userid)
		x2, y2, z2 = self.center

		if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 > ((DIAMETER / 2) - 10):
			hosties.getPlayer(userid).tell('hp not in range')
			popuplib.send('Add Spawn Location', userid)
			return

		if not self.spawns:
			self.spawns.append([x, y, z])
			popuplib.send('Add Spawn Location', userid)
			return

		x2, y2, z2 = self.spawns[0]
		if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 < 50:
			hosties.getPlayer(userid).tell('hp not enough space')
			popuplib.send('Add Spawn Location', userid)
			return

		self.spawns.append([x, y, z])
		self.sendPlayerSelection()

	def sendPlayerSelection(self):
		players = popuplib.easymenu('Add Player', '_popup_choice', self.addPlayer)
		players.addoption('Enough Players', 'Enough Players')
		players.submenu(0, 'Add Player')

		for userid in filter(lambda x: x not in self.chosen, playerlib.getUseridList('#alive,#ct')):
			players.addoption(userid, es.getplayername(userid))
		popuplib.send('Add Player', self.t)

	def addPlayer(self, userid, choice, popupid):
		if choice == 'Enough Players':
			self.setupGrid()
			return
		popuplib.send('Add Player', userid)

		x, y, z = es.getplayerlocation(userid)
		for loc in self.spawns:
			x2, y2, z2 = loc
			if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 <= 50:
				hosties.getPlayer(userid).tell('hp not enough space')
				return

		x2, y2, z2 = self.center
		if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 > ((DIAMETER / 2) - 10):
			hosties.getPlayer(userid).tell('hp not in range')
			return

		self.spawns.append([x, y, z])
		hosties.HM.msg('hp3', {'player': es.getplayername(choice)})
		self.chosen.append(choice)

	def effectLoop(self):
		if not self.center:
			return

		gamethread.delayedname(0.5, 'effect loop', self.effectLoop)
		effectlib.drawCircle(self.center, DIAMETER / 2, seconds=0.5, red=0, green=0, blue=255)

		for spawn in self.spawns:
			effectlib.drawCircle(spawn, 50, seconds=0.5, red=0, green=255, blue=0)

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		self.deagle = None
		self.setup = False
		self.chosen = [self.t, self.ct]

		popuplib.send('Select Center Point', t)
		hosties.HM.msg('hp1', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})

	def setupGrid(self):
		hosties.HM.msg('hp4')
		hosties.HM.msg('hp5')
		hosties.HM.msg('hp6')

		x, y, z = self.center
		location = [[x - (DIAMETER / 2), y - 84.26]]

		for a in xrange(SIDES):
			t = THETA * a
			radians = math.radians(t)

			x = (DIAMETER * math.cos(radians))
			y = (DIAMETER * math.sin(radians))

			lastx, lasty = location[-1]
			location.append([lastx + x, lasty + y])

		delay = -0.03
		angle = -THETA
		index = 0

		for x, y in location:
			delay += 0.03
			angle += THETA
			index += 1

			es.server.queuecmd('es_fire %s wall_%s kill'%(self.t, index))
			es.delayed(delay, 'es_prop_dynamic_create %s props_lab/blastdoor001c.mdl;es_entsetname %s wall_%s;es_fire %s wall_%s addoutput "origin %s";es_fire %s wall_%s addoutput "angles 0 %s 0"'%(self.t, self.t, index, self.t, index, ' '.join(map(str, [x, y, z])), self.t, index, angle))
		gamethread.delayed(delay + 0.03, self.gridSetupComplete)

	def gridSetupComplete(self):
		entities = es.createentitylist()
		for i in entities.keys():
			if not entities[i]['classname'].startswith('weapon_'):
				continue

			if es.getindexprop(i, 'CBaseEntity.m_hOwnerEntity') > 0:
				continue

			x, y, z = map(float, es.getindexprop(i, 'CBaseEntity.m_vecOrigin').split(','))
			x2, y2, z2 = self.center

			if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 <= DIAMETER / 2:
				es.server.queuecmd('es_xremove %s'%i)

		for userid in self.chosen:
			loc = random.choice(self.spawns)
			self.spawns.remove(loc)

			player = playerlib.getPlayer(userid)
			player.set('freeze', 1)
			player.set('health', 100)

			es.server.queuecmd('es_xsetpos %s %s %s %s'%((userid,) + tuple(loc)))
			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)

		es.delayed(0, 'es_xfire %s player_weaponstrip kill'%userid)
		self.countDownLoop(TIME + 1)

		self.setup = True
		gamethread.delayed(0, self.giveDeagle)

	def timeUp(self):
		owner = es.getindexprop(self.deagle, 'CBaseEntity.m_hOwnerEntity')
		if owner == -1:
			owner = es.getplayerhandle(self.lastOwner)

		for userid in self.chosen:
			if es.getplayerhandle(userid) == owner:
				es.server.queuecmd('damage %s 100'%userid)
				self.stopLR(self.t, None, None)
				hosties.HM.msg('hp lost', {'loser': es.getplayername(userid)})

	def countDownLoop(self, timeleft):
		timeleft -= 1
		if timeleft <= 0:
			self.timeUp()
			return

		owner = es.getindexprop(self.deagle, 'CBaseEntity.m_hOwnerEntity')
		for userid in self.chosen:
			if es.getplayerhandle(userid) == owner:
				owner = es.getplayername(userid)
				break

		if type(owner) == int:
			owner = 'No one'
		format = 'Timeleft: %s\nOwner: %s'%(timeleft, owner)

		for userid in es.getUseridList():
			usermsg.hudhint(userid, format)
		gamethread.delayedname(1, 'count down loop', self.countDownLoop, timeleft)

	def giveDeagle(self):
		userid = random.choice(self.chosen)
		deagles = es.createentitylist('weapon_deagle').keys()

		es.server.queuecmd('es_xgive %s weapon_deagle'%userid)
		gamethread.delayed(0, self.findIndex, (deagles, userid))

		self.lastOwner = userid
		gamethread.delayedname(2, 'do damage', self.doDamage, userid)

	def findIndex(self, deagles, userid):
		for i in es.createentitylist('weapon_deagle').keys():
			if not i in deagles:
				self.deagle = i
				break

		es.setplayerprop(userid, 'CBasePlayer.localdata.m_iAmmo.001', 0)
		es.setindexprop(self.deagle, 'CBaseCombatWeapon.LocalWeaponData.m_iClip1', 0)

		for userid in self.chosen:
			playerlib.getPlayer(userid).set('freeze', 0)

	def end(self):
		self.t = None
		self.ct = None

		self.deagle = None
		self.setup = False

		self.spawns = []
		self.center = []
		self.chosen = []

		for delay in ['effect loop', 'count down loop', 'check owned', 'do damage']:
			gamethread.cancelDelayed(delay)

		userid = es.getuserid()
		if userid:
			for i in xrange(1, 18):
				es.server.queuecmd('es_xfire %s wall_%s kill'%(userid, i))

		prop_physics_multiplayer = es.createentitylist('prop_physics_multiplayer').keys()
		for index in self.indexes:
			if not index in prop_physics_multiplayer:
				continue
			es.server.queuecmd('es_xremove %s'%index)
		self.indexes.clear()

	def playerDeath(self, userid, attacker, weapon):
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)
		for popup in ['Select Center Point', 'Add Spawn Location', 'Add Player']:
			if popuplib.isqueued(popup, userid):
				popuplib.close(popup, userid)

	def _cc_filter(self, userid, args):
		if not userid in self.chosen:
			return True

		if not args[0].lower() == 'drop':
			return True

		if not self.setup:
			hosties.getPlayer(userid).tell('hp not set up')
			return False

		gamethread.cancelDelayed('check owned')
		gamethread.delayedname(3, 'check owned', self.checkOwned, userid)
		return True

	def checkOwned(self, userid):
		if es.getindexprop(self.deagle, 'CBaseEntity.m_hOwnerEntity') > 0:
			return

		origin = es.getindexprop(self.deagle, 'CDEagle.baseclass.baseclass.baseclass.baseclass.m_vecOrigin')
		if not es.getindexprop(self.deagle, 'CDEagle.baseclass.baseclass.m_iState') == 0 or origin == '0,0,0':
			gamethread.delayedname(0.1, 'check owned', self.checkOwned, userid)
			return

		x, y, z = map(float, origin.split(','))
		x2, y2, z2 = self.center

		if (((x - x2) ** 2) + ((y - y2) ** 2)) >= DIAMETER / 2:
			x3, y3, z3 = es.getplayerlocation(userid)
			es.server.queuecmd('es_xsetpos %s %s %s %s'%(userid, x, y, z))
			es.delayed(0.2, 'es_xsetpos %s %s %s %s'%(userid, x3, y3, z3))
			return
		es.server.queuecmd('es_xsetpos %s %s'%(userid, es.getindexprop(self.deagle, origin.replace(',', ' '))))

	def pickupDeagle(self, userid):
		if not self.deagle:
			return

		handle = es.getplayerhandle(userid)
		for i in es.createentitylist('weapon_deagle'):
			if es.getindexprop(i, 'CBaseEntity.m_hOwnerEntity') == handle:
				break
			i = None

		if not i:
			return

		if not i == self.deagle:
			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)
			es.delayed(0, 'es_xfire %s player_weaponstrip kill'%userid)

		gamethread.cancelDelayed('check owned')
		gamethread.cancelDelayed('do damage')

		self.lastOwner = userid
		gamethread.delayedname(2, 'do damage', self.doDamage, userid)

	def doDamage(self, userid):
		handle = es.getplayerhandle(userid)
		for i in es.createentitylist('weapon_deagle'):
			if es.getindexprop(i, 'CBaseEntity.m_hOwnerEntity') == handle:
				es.server.queuecmd('damage %s 20'%userid)
				break
		gamethread.delayedname(2, 'do damage', self.doDamage, userid)

HP = HotPotatoe()

def player_death(ev):
	HP.playerDeath(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def item_pickup(ev):
	if not ev['item'] == 'deagle':
		return

	if int(ev['userid']) in HP.chosen:
		HP.pickupDeagle(int(ev['userid']))
