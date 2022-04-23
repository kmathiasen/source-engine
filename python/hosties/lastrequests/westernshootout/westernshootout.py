import hosties.hosties as hosties, es, gamethread, popuplib, playerlib, math

sv = es.ServerVar

def unload():
	WS.unregisterSayCommand('!wspoint')

class WesternShootout(hosties.RegisterLastRequest):
	def __init__(self):
		super(WesternShootout, self).__init__('westernshootout')
		self.t = None
		self.ct = None

		self.w1 = 0
		self.w2 = 0
		self.startingpoint = []
		self.done = []
		self.w3 = 0
		self.w4 = 0

		self.choosePoint = popuplib.easymenu('Choose WS Starting Point', '_popup_choice', self.choosePointSelect)
		self.choosePoint.settitle(hosties.text('Choose WS', {}, hosties.menu_lang))
		self.choosePoint.addoption('Choose Point', hosties.text('Choose Point', {}, hosties.menu_lang))

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerSayCommand('!wspoint', 'wspoint', self.selectPoint)
		self.registerOverRide('player_hurt')

	def choosePointSelect(self, userid, choice, popupid):
		if not hosties.HASEST:
			self.startWS()
			return

		for s in ['x', 'y', 'z']:
			sv(s).set(0)

		es.server.queuecmd('est_getviewcoord %s x y z'%userid)
		gamethread.delayed(0.06, self.checkFirstCoords)

	def checkFirstCoords(self):
		playerlib.getPlayer(self.t).set('freeze', 1)

		x, y, z = playerlib.getPlayer(self.t).get('viewangle')
		x2, y2, z2 = [float(sv(w)) for w in ['x', 'y', 'z']]
		x3, y3, z3 = es.getplayerlocation(self.t)

		for s in ['x', 'y', 'z']:
			sv(s).set(0)

		self.w1 = x, y, z
		self.w3 = math.sqrt((x2 - x3) ** 2 + (y2 - y3) ** 2)

		for a in [0, 0.03, 0.06, 0.09, 0.12, 0.15, 0.18, 0.21, 0.24, 0.27]:
			gamethread.delayed(a, es.server.queuecmd, ('es_xsetang %s %s %s %s'%(self.t, x, y + 180, z)))
		gamethread.delayed(0.15, self.checkSecondCoords)

	def checkSecondCoords(self):
		for s in ['x', 'y', 'z']:
			sv(s).set(0)

		es.server.queuecmd('est_getviewcoord %s x y z'%self.t)
		gamethread.delayed(0.15, self.checkThirdCoords)

	def checkThirdCoords(self):
		userid = self.t
		playerlib.getPlayer(userid).set('noclip', 0)

		self.startingpoint = es.getplayerlocation(userid)
		x2, y2, z2 = [float(sv(w)) for w in ['x', 'y', 'z']]
		x3, y3, z3 = es.getplayerlocation(userid)

		self.w2 = playerlib.getPlayer(userid).get('viewangle')
		self.w4 = math.sqrt((x2 - x3) ** 2 + (y2 - y3) ** 2)

		if self.w3 <= 550 or self.w4 <= 550:
			player = hosties.getPlayer(userid)
			player.tell('not enough room')
			player.tell('not enough room2')
			player.tell('not enough room3', {'d1': self.w3, 'd2': self.w4})

			self.w1 = self.w2 = self.w3 = self.w4 = 0
			popuplib.send('Choose WS Starting Point', userid)
			return

		self.startWS()

	def startWS(self):
		for userid in [self.t, self.ct]:
			x, y, z = self.startingpoint

			es.server.queuecmd('es_xsetpos %s %s %s %s'%(userid, x, y, z))

			es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 2)
			gamethread.delayed(15, es.setplayerprop, (userid, 'CBaseEntity.m_CollisionGroup', 0))

			playerlib.getPlayer(userid).set('freeze', 1)
			gamethread.delayed(3, playerlib.getPlayer(userid).set, ('noclip', 0))

			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)

			gamethread.delayed(3, es.server.queuecmd, 'es_xgive %s weapon_deagle;es_xgive %s weapon_knife'%(userid, userid))
			playerlib.getPlayer(userid).set('health', 100)
		es.server.queuecmd('es_fire %s player_weaponstrip kill'%userid)

		hosties.HM.msg('ws message 1')
		hosties.HM.msg('ws message 2')

		for message in enumerate([3, 2, 1, 'GO!']):
			gamethread.delayed(message[0], es.centermsg, message[1])
		gamethread.delayed(3, self.checkLoop)

	def checkLoop(self):
		gamethread.delayedname(0.1, 'ws loop', self.checkLoop)
		x, y, z = self.startingpoint

		for userid in [self.t, self.ct]:
			if not userid in self.done:
				x2, y2, z2 = es.getplayerlocation(userid)
				x3, y3, z3 = self.w1 if userid == self.t else self.w2
				if math.sqrt((x - x2) ** 2 + (y - y2) ** 2) >= 500:
					self.done.append(userid)
					hosties.HM.msg('paces taken', {'player': es.getplayername(userid)})
				es.server.queuecmd('es_xsetang %s %s %s %s'%(userid, x3, y3, z3))

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('WS', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.getPlayer(t).tell('ws start')

		popuplib.send('Choose WS Starting Point', self.t)

	def end(self):
		self.w1 = self.w2 = self.w3 = self.w4 = 0
		self.startingpoint = self.done = []
		self.t = self.ct = None

		gamethread.cancelDelayed('ws loop')

	def selectPoint(self, userid):
		player_say({'text': '!wspoint', 'userid': userid})

	def player_death(self, userid, attacker, weapon):
		if attacker in [self.t, self.ct] and userid in [self.t, self.ct]:
			if self.w4:
				self.stopLR(self.t, attacker, 'won ws', {'player': es.getplayername(attacker)})
				return
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

	def player_hurt(self, userid, attacker, weapon):
		if playerlib.getPlayer(userid).get('isdead'):
			return

		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == 'deagle':
				self.stopLR(self.t, userid, 'ws gun', {'player': es.getplayername(attacker)})
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()

def player_say(ev):
	userid = int(ev['userid'])
	if not ev['text'] == '!wspoint':
		return

	if not userid == WS.t:
		es.tell(userid, '#multi', hosties.text('not in ws', {}, playerlib.getPlayer(userid).get('lang')))
		return

	if WS.w1:
		es.tell(userid, '#multi', hosties.text('chosen all spawns', {}, playerlib.getPlayer(userid).get('lang')))
		return
	hosties.getPlayer(userid).send('Choose WS Starting Point', userid)

def player_hurt(ev):
	WS.player_hurt(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def player_death(ev):
	WS.player_death(int(ev['userid']), int(ev['attacker']), ev['weapon'])

WS = WesternShootout()
