import hosties.hosties as hosties, es, gamethread, playerlib, random, popuplib

sv = es.ServerVar

def unload():
	for delay in ['view loop', 'check idle']:
		gamethread.cancelDelayed(delay)
	es.addons.unregisterClientCommandFilter(_cc_filter)

class RussianRoulette(hosties.RegisterLastRequest):
	def __init__(self):
		super(RussianRoulette, self).__init__('russianroulette')

		self.t = None
		self.ct = None
		self.last = None

		self.shots_fired = 0
		self.noisy = False

		popuplib.easymenu('Retry Location', '_popup_choice', self.retryLocation).addoption('Retry Location', 'Retry Location')
		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerOverRide('player_hurt')

	def retryLocation(self, userid, choice, popupid):
		if not userid == self.t:
			return
		self.start(self.t, self.ct)

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		[es.set('hosties_' + x, 0) for x in 'xyz']
		x, y, z = playerlib.getPlayer(t).get('viewangle')
		es.server.queuecmd('es_xsetang %s 90 %s 0'%(t, y))

		es.server.queuecmd('est_getviewcoord %s hosties_x hosties_y hosties_z'%t)
		gamethread.delayed(0, self.checkValidCoords)

	def checkValidCoords(self):
		x, y, z = [float(sv('hosties_' + w)) for w in 'xyz']
		x2, y2, z2 = es.getplayerlocation(self.t)

		if (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5 <= 100:
			hosties.getPlayer(self.t).tell('not enough space roulette')
			gamethread.delayed(1, popuplib.send, ('Retry Location', self.t))
			return
		self.validRequest()

	def validRequest(self):
		hosties.HM.msg('roulette', {'t': es.getplayername(self.t), 'ct': es.getplayername(self.ct)})
		hosties.HM.msg('roulette start')

		for userid in [self.t, self.ct]:
			playerlib.getPlayer(userid).set('health', 1124)
			playerlib.getPlayer(userid).set('freeze', 1)

			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)
		es.delayed(0, 'es_xfire %s player_weaponstrip kill'%userid)

		x, y, z = playerlib.getPlayer(self.t).get('viewvector')
		x2, y2, z2 = es.getplayerlocation(self.t)

		es.server.queuecmd('es_xsetpos %s %s %s %s'%(self.ct, x2 + (x * 75), y2 + (y * 75), z2))
		es.delayed(0.1, 'es_xgive %s weapon_deagle'%random.choice([self.t, self.ct]))

		es.doblock('corelib/noisy_on')
		self.noisy = True

		self.setViewLoop()

	def setViewLoop(self):
		return
		if not self.t:
			return

		for userid in [(self.t, self.ct), (self.ct, self.t)]:
			playerlib.getPlayer(userid[0]).set('viewplayer', userid[1])
		gamethread.delayedname(0.4, 'view loop', self.setViewLoop)

	def end(self):
		self.shots_fired = 0
		self.last = None

		for userid in [self.t, self.ct]:
			if not userid or not es.exists('userid', userid):
				continue

			player = playerlib.getPlayer(userid)
			if player.get('isdead'):
				continue

			player.set('health', 100)
			player.set('freeze', 0)

		self.t = None
		self.ct = None

		if self.noisy:
			es.doblock('corelib/noisy_off')
			self.noisy = False

		for userid in playerlib.getUseridList('#human'):
			if popuplib.isqueued('Retry Location', userid):
				popuplib.close('Retry Location', userid)

		for delay in ['view loop']:
			gamethread.cancelDelayed(delay)

	def fireWeapon(self, userid, weapon):
		userid = int(userid)
		if not userid in [self.t, self.ct]:
			return
		self.last = userid

		if not random.randint(0, 6 - self.shots_fired):
			victim = self.t if userid == self.ct else self.ct
			es.ForceServerCommand('damage %s %s 32 %s'%(victim, es.getplayerprop(victim, 'CBasePlayer.m_iHealth'), userid))
			return self.stopLR(self.t, userid, 'won rr', {'player': es.getplayername(userid)})

		self.shots_fired += 1

		es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
		es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)
		es.server.queuecmd('es_xfire %s player_weaponstrip kill'%userid)

		nextOwner = self.t if userid == self.ct else self.ct
		es.delayed(0.1, 'es_xgive %s weapon_deagle;es_xgive %s weapon_knife'%(nextOwner, nextOwner))
		es.delayed(0.14, 'playerset ammo %s 2 %s'%(nextOwner, 7 - self.shots_fired))

	def playerDeath(self, userid, attacker, weapon):
		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			return
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

	def playerHurt(self, userid, attacker, weapon):
		if playerlib.getPlayer(userid).get('isdead'):
			return

		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == 'deagle':
				self.stopLR(self.t, userid, 'rr gun', {'player': es.getplayername(attacker)})
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()
				return
			playerlib.getPlayer(userid).set('health', 1124)

RR = RussianRoulette()

def player_hurt(ev):
	RR.playerHurt(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def player_death(ev):
	RR.playerDeath(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def weapon_fire(ev):
	RR.fireWeapon(ev['userid'], ev['weapon'])

def round_end(ev):
	if RR.noisy:
		es.doblock('corelib/noisy_off')
		RR.noisy = False

def _cc_filter(userid, args):
	if not args[0].lower() == 'drop':
		return True

	if userid in [RR.t, RR.ct]:
		return False
	return True

RR.registerClientCommandFilter(_cc_filter)
