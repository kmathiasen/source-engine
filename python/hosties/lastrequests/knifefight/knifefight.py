import hosties.hosties as hosties, es, playerlib, gamethread

class KnifeFight(hosties.RegisterLastRequest):
	def __init__(self):
		super(KnifeFight, self).__init__('knifefight')
		self.t = None
		self.ct = None

		self.registerStartFunction(self.start)
		self.registerOverRide('player_hurt')

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('KF', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('KF2')

		for userid in [self.t, self.ct]:
			playerlib.getPlayer(userid).set('health', 100)
			es.server.queuecmd('es_xgive %s player_weaponstrip'%userid)
			es.server.queuecmd('es_xfire %s player_weaponstrip strip'%userid)
			es.server.queuecmd('es_delayed 0 es_give %s weapon_knife'%userid)

		gamethread.delayed(0, es.server.queuecmd, 'es_delayed 0 es_fire %s player_weaponstrip kill'%userid)
		if not int(sv('hosties_teleport_to_designated_areas_for_lr')):
			return

		m = str(es.ServerVar('eventscripts_currentmap'))
		if not m in hosties.mapcoords:
			return

		if not 'kf' in hosties.mapcoords[m]:
			return

		for userid in [self.t, self.ct]:
			hosties.getPlayer(userid).tell('prepare to teleport')
			for message in enumerate([3, 2, 1]):
				gamethread.delayed(message[0] + 1, es.centertell, (userid, message[1]))

		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.t, ' '.join(map(str, hosties.mapcoords[m]['kf'][0])))))
		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.ct, ' '.join(map(str, hosties.mapcoords[m]['kf'][1])))))

	def checkDone(self, attacker, userid, weapon):
		if not attacker in [self.t, self.ct] and not userid in [self.t, self.ct]:
			hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)
			return

		if not attacker in [self.t, self.ct] or not userid in [self.t, self.ct]:
			hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)
			return

		if not weapon == 'knife':
			if not attacker == self.t:
				return self.stopLR(self.t, None, 'gun used', {'player': es.getplayername(attacker)})
			return [self.stopLR(self.t, None, 'gun used', {'player': es.getplayername(attacker)}), hosties.HM.getPlayer(self.t).makeRebel()]

		if attacker == self.t:
			if userid == self.ct:
				return self.stopLR(self.t, self.t, 'won kf', {'player': es.getplayername(attacker)})
			return [self.stopLR(self.t, None, None), hosties.HM.getPlayer(self.t).makeRebel()]

		if userid == self.t:
			self.stopLR(self.t, self.ct, 'won kf', {'player': es.getplayername(attacker)})

	def player_hurt(self, attacker, userid, weapon):
		if playerlib.getPlayer(userid).get('isdead'):
			return

		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if weapon == 'knife':
				return

			self.stopLR(self.t, userid, 'gun used', {'player': es.getplayername(attacker)})
			if attacker == self.t:
				hosties.getPlayer(attacker).makeRebel()

KF = KnifeFight()

def player_death(ev):
	KF.checkDone(int(ev['attacker']), int(ev['userid']), ev['weapon'])

def player_hurt(ev):
	KF.player_hurt(int(ev['attacker']), int(ev['userid']), ev['weapon'])
