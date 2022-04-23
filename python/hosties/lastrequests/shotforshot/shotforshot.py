import hosties.hosties as hosties, es, gamethread, playerlib

sv = es.ServerVar

class ShotForShot(hosties.RegisterLastRequest):
	def __init__(self):
		super(ShotForShot, self).__init__('shotforshot')
		self.shots_fired = {'t': 0, 'ct': 0}

		self.t = None
		self.ct = None
		self.noisy = False

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerOverRide('player_hurt')

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('s4s', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('s4s start')

		for userid in [self.t, self.ct]:
			playerlib.getPlayer(userid).set('health', 100)
			secondary = str(playerlib.getPlayer(userid).get('secondary'))

			if secondary == '0':
				es.server.queuecmd('es_xgive %s weapon_deagle'%userid)
				continue

			if secondary == 'weapon_deagle':
				es.sexec(userid, 'use weapon_deagle')
				continue

			es.sexec(userid, 'use ' + secondary)
			es.cexec(userid, 'drop')

			es.server.queuecmd('es_xgive %s weapon_deagle'%userid)
			gamethread.delayed(0, playerlib.getPlayer(userid).set, ('ammo', ['secondary', 50]))
			gamethread.delayed(0, es.sexec, (userid, 'use weapon_deagle'))

		if int(sv('hosties_enable_s4s_single_shot')):
			self.shots_fired['t'] = 0
			self.shots_fired['ct'] = 0

			self.noisy = True
			es.doblock('corelib/noisy_on')

		m = str(es.ServerVar('eventscripts_currentmap'))
		if not int(sv('hosties_teleport_to_designated_areas_for_lr')):
			return

		if not m in hosties.mapcoords:
			return

		if not 's4s' in hosties.mapcoords[m]:
			return

		for userid in [self.t, self.ct]:
			hosties.getPlayer(userid).tell('prepare to teleport')
			for message in enumerate([3, 2, 1]):
				gamethread.delayed(message[0] + 1, es.centertell, (userid, message[1]))

		es.msg(5)
		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.t, ' '.join(map(str, hosties.mapcoords[m]['s4s'][0])))))
		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.ct, ' '.join(map(str, hosties.mapcoords[m]['s4s'][1])))))

	def doubleShots(self, userid):
		hosties.HM.msg('double shot', {'player': es.getplayername(userid)})
		if int(userid) == self.t:
			hosties.getPlayer(userid).makeRebel()

		self.stopLR(self.t, self.t if userid == self.ct else self.ct, None)
		if self.noisy:
			self.noisy = False
			es.server.queuecmd('refcount decrement eventscripts_noisy')

	def end(self):
		self.shots_fired = {'t': 0, 'ct': 0}
		if self.noisy:
			self.noisy = False
			es.server.queuecmd('refcount decrement eventscripts_noisy')

		self.t = None
		self.ct = None

	def playerDeath(self, userid, attacker, weapon):
		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == 'deagle':
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()
				return self.stopLR(self.t, None, 's4s gun', {'player': es.getplayername(attacker)})
			return self.stopLR(self.t, attacker, 'won s4s', {'player': es.getplayername(attacker)})
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

	def player_hurt(self, userid, attacker, weapon):
		if playerlib.getPlayer(userid).get('isdead'):
			return

		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == 'deagle':
				self.stopLR(self.t, userid, 's4s gun', {'player': es.getplayername(attacker)})
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()

S4S = ShotForShot()

def player_hurt(ev):
	S4S.player_hurt(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def player_death(ev):
	S4S.playerDeath(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def weapon_fire(ev):
	if not S4S.noisy:
		return

	if not ev['userid'] in map(str, [S4S.t, S4S.ct]):
		return

	if not ev['weapon'] == 'deagle':
		return

	S4S.shots_fired[{'2': 't', '3': 'ct'}[ev['es_userteam']]] += 1
	if S4S.shots_fired['t'] - S4S.shots_fired['ct'] > 1 or S4S.shots_fired['ct'] - S4S.shots_fired['t'] > 1:
		S4S.doubleShots(ev['userid'])
		return
	hosties.HM.msg('shot taken', {'player': ev['es_username']})
