import hosties.hosties as hosties, playerlib, gamethread, es

sv = es.ServerVar

class ChickenFight(hosties.RegisterLastRequest):
	def __init__(self):
		super(ChickenFight, self).__init__('chickenfight')

		self.t = None
		self.ct = None

		self.noblock = []

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)

	def end(self):
		self.t = self.ct = None
		gamethread.cancelDelayed('Jump Check Loop')

		for userid in self.noblock:
			if not es.exists('userid', userid):
				continue

			if not playerlib.getPlayer(userid).get('isdead'):
				es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 2)
		del self.noblock[:]

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('CF1', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('CF2')

		if int(sv('hosties_enable_chicken_fight_won')):
			self.jumpCheckLoop()

		for userid in [t, ct]:
			if es.getplayerprop(userid, 'CBaseEntity.m_CollisionGroup') == 2:
				self.noblock.append(userid)
				es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 5)

	def jumpCheckLoop(self):
		gamethread.delayedname(0.05, 'Jump Check Loop', self.jumpCheckLoop)
		for userid in [self.t, self.ct]:
			if self.checkOnHead(userid):
				break

	def checkOnHead(self, userid):
		if userid in [self.t, self.ct]:
			if es.getplayerprop(userid, 'CBasePlayer.localdata.m_hGroundEntity') == es.getplayerhandle(self.t if userid == self.ct else self.ct):
				self.stopLR(self.t, userid, 'lost chicken fight', {'player': es.getplayername(self.ct if userid == self.t else self.t)})
				return True

	def player_death(self, userid, attacker, weapon):
		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			return
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

CF = ChickenFight()

def player_death(ev):
	CF.player_death(int(ev['userid']), int(ev['attacker']), ev['weapon'])
