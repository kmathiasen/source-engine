import hosties.hosties as hosties, es, popuplib, math, effectlib, random, gamethread, playerlib

### Start Config ###

# Color of the ending circle
ENDRED = 0
ENDGREEN = 0
ENDBLUE = 255

# Color of the starting circles
STARTRED = 0
STARTGREEN = 0
STARTBLUE = 255

### End Config ###

def unload():
	race.unregisterSayCommand('!setpoints')

class Race(hosties.RegisterLastRequest):
	def __init__(self):
		super(Race, self).__init__('race')
		self.t = None
		self.ct = None

		self.points = {1: [], 2: [], 3: []}

		self.selectSpawn1 = popuplib.easymenu('Choose First Spawn Point', '_popup_choice', self.spawnPointSelect1)
		self.selectSpawn1.settitle(hosties.text('Choose Spawn Point 1', {}, hosties.menu_lang))
		self.selectSpawn1.addoption('Select First Spawn Point', hosties.text('Add Starting Point', {}, hosties.menu_lang))

		self.selectSpawn2 = popuplib.easymenu('Choose Second Spawn Point', '_popup_choice', self.spawnPointSelect2)
		self.selectSpawn2.settitle(hosties.text('Choose Spawn 2', {}, hosties.menu_lang))
		self.selectSpawn2.addoption('Select Second Spawn Point', hosties.text('Add Starting Point', {}, hosties.menu_lang))

		self.selectEndPoint = popuplib.easymenu('Choose End Point', '_popup_choice', self.endPointSelect)
		self.selectEndPoint.settitle(hosties.text('Choose End Point', {}, hosties.menu_lang))
		self.selectEndPoint.addoption('Select End Point', hosties.text('Choose Ending Point', {}, hosties.menu_lang))

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerSayCommand('!setpoints', 'setpoints', self.setPointsCommand)

	def start(self, t, ct):
		self.t = t
		self.ct = ct
		self.points = {1: [], 2: [], 3: []}

		hosties.HM.msg('race 1', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('race 2', {'t': es.getplayername(t)})
		popuplib.send('Choose First Spawn Point', self.t)

	def end(self):
		self.t = None
		self.ct = None

		for delay in ['effect_loop', 'race message', 'check race won']:
			gamethread.cancelDelayed(delay)
		self.points = {1: [], 2: [], 3: []}

	def spawnPointSelect1(self, userid, choice, popupid):
		if self.canLR(userid, True):
			self.points[1] = es.getplayerlocation(userid)
			self.showEffects()
			popuplib.send('Choose Second Spawn Point', userid)

	def spawnPointSelect2(self, userid, choice, popupid):
		if self.canLR(userid, True):
			x, y, z = es.getplayerlocation(userid)
			x2, y2, z2 = self.points[1]
			distance = math.sqrt(((x - x2) ** 2) + (y - y2) ** 2)

			if distance >= 50 or distance <= 25 or abs(z - z2) >= 30:
				es.tell(userid, '#multi', hosties.text('invalid race spacing', {'x': int(abs(x - x2)), 'y': int(abs(y - y2))}, playerlib.getPlayer(userid).get('lang')))
				popuplib.send('Choose Second Spawn Point', userid)
				return

			self.points[2] = [x, y, z]
			popuplib.send('Choose End Point', userid)

	def endPointSelect(self, userid, choice, popupid):
		if self.canLR(userid, True):
			x, y, z = es.getplayerlocation(userid)
			x2, y2, z2 = self.points[1]

			if math.sqrt((x - x2) ** 2 + (y - y2) ** 2) <= 400:
				es.tell(userid, '#multi', hosties.text('race locations too close', {}, playerlib.getPlayer(userid).get('lang')))
				popuplib.send('Choose End Point', userid)
				return

			self.points[3] = [x, y, z]
			self.startRace()

	def startRace(self):
		hosties.HM.msg('race start')

		points = [self.points[1], self.points[2]]
		t_start = random.choice(points)
		points.remove(t_start)
		ct_start = points[0]

		es.server.queuecmd('es_xsetpos %s %s'%(self.t, ' '.join(map(str, t_start))))
		es.server.queuecmd('es_xsetpos %s %s'%(self.ct, ' '.join(map(str, ct_start))))

		playerlib.getPlayer(self.t).set('freeze', 1)
		playerlib.getPlayer(self.ct).set('freeze', 1)

		gamethread.delayed(3, playerlib.getPlayer(self.t).set, ('noclip', 0))
		gamethread.delayed(3, playerlib.getPlayer(self.ct).set, ('noclip', 0))

		for message in enumerate(['3', '2', '1', 'GO!']):
			gamethread.delayedname(message[0], 'race message', es.centermsg, message[1])

		gamethread.delayedname(3, 'check race won', self.checkWonLoop)

	def checkWonLoop(self):
		gamethread.delayedname(0.05, 'check race won', self.checkWonLoop)
		x, y, z = self.points[3]

		for userid in [self.t, self.ct]:
			x2, y2, z2 = es.getplayerlocation(userid)
			if math.sqrt((x - x2) ** 2 + (y - y2) ** 2) <= 50 and abs(z - z2) <= 50:
				self.stopLR(self.t, userid, 'won race', {'player': es.getplayername(userid)})
				break

	def showEffects(self):
		gamethread.delayedname(0.5, 'effect_loop', self.showEffects)
		a, b, c = [self.points[x] for x in [1, 2, 3]]
		if a:
			effectlib.drawCircle(a, 25, seconds=0.5, red=STARTRED, green=STARTGREEN, blue=STARTBLUE)

		if b:
			effectlib.drawCircle(b, 25, seconds=0.5, red=STARTRED, green=STARTGREEN, blue=STARTBLUE)

		if c:
			effectlib.drawCircle(c, 50, seconds=0.5, red=ENDRED, green=ENDGREEN, blue=ENDBLUE)

	def setPointsCommand(self, userid):
		player_say({'text': '!setpoints', 'userid': userid})

def player_say(ev):
	userid = ev['userid']
	if ev['text'].lower() == '!setpoints':
		if not int(userid) == race.t:
			es.tell(userid, '#multi', hosties.text('not in race', {}, playerlib.getPlayer(userid).get('lang')))
			return

		if not race.points[1]:
			hosties.getPlayer(userid).send('Choose First Spawn Point')

		elif not race.points[2]:
			hosties.getPlayer(userid).send('Choose Second Spawn Point')

		elif not race.points[3]:
			hosties.getPlayer(userid).send('Choose End Point')

		else:
			es.tell(userid, '#multi', hosties.text('chosen all spawns', {}, playerlib.getPlayer(userid).get('lang')))

def player_death(ev):
	if ev['attacker'] == '0':
		if int(ev['userid']) in [race.t, race.ct]:
			race.stopLR(race.t, None, None)
		return
	hosties.getPlayer(ev['attacker']).checkKill(ev['userid'], ev['weapon'], race.t)

race = Race()
