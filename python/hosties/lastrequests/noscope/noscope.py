import hosties.hosties as hosties, es, playerlib, popuplib

class NoScope(hosties.RegisterLastRequest):
	def __init__(self):
		super(NoScope, self).__init__('noscope')
		self.t = None
		self.ct = None
		self.weapon = None

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerOverRide('player_hurt')

		self.unrestrictWeapon('awp')
		self.unrestrictWeapon('scout')

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		chooseWeaponMenu = popuplib.easymenu('Select Sniper', '_popup_choice', self.chooseWeaponMenuSelect)
		chooseWeaponMenu.addoption('awp', 'AWP')
		chooseWeaponMenu.addoption('scout', 'Scout')
		popuplib.send('Select Sniper', t)

	def chooseWeaponMenuSelect(self, userid, choice, popupid):
		self.weapon = choice
		for userid in [self.t, self.ct]:
			player = playerlib.getPlayer(userid)
			primary = str(player.get('primary'))

			if not '0' in primary:
				primary = 'weapon_' + primary if not 'weapon_' in primary else primary
				es.sexec(userid, 'use %s'%primary)
				es.cexec(userid, 'drop')

			player.set('health', 100)
			es.server.queuecmd('es_xgive %s weapon_%s;playerset ammo %s 1 60'%(userid, choice, userid))

		hosties.HM.msg('no scope', {'t': es.getplayername(self.t), 'ct': es.getplayername(self.ct)})
		if not int(sv('hosties_teleport_to_designated_areas_for_lr')):
			return

		m = str(es.ServerVar('eventscripts_currentmap'))
		if not m in hosties.mapcoords:
			return

		if not 's4s' in hosties.mapcoords[m]:
			return

		for userid in [self.t, self.ct]:
			hosties.getPlayer(userid).tell('prepare to teleport')
			for message in enumerate([3, 2, 1]):
				gamethread.delayed(message[0] + 1, es.centertell, (userid, message[1]))

		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.t, ' '.join(map(str, hosties.mapcoords[m]['s4s'][0])))))
		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.ct, ' '.join(map(str, hosties.mapcoords[m]['s4s'][1])))))

	def end(self):
		self.t = None
		self.ct = None
		self.weapon = None

	def weaponZoom(self, userid):
		if not userid in [self.t, self.ct]:
			return

		es.setplayerprop(userid, 'CBasePlayer.m_iFov', 0) # Might be 90... dunno, D: D D D::::::::::::::
		hosties.getPlayer(userid).tell('cant zoom')

	def playerDeath(self, userid, attacker, weapon):
		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == self.weapon:
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()
				return self.stopLR(self.t, None, 'noscope gun', {'player': es.getplayername(attacker)})
			return self.stopLR(self.t, attacker, 'won noscope', {'player': es.getplayername(attacker)})
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

	def playerHurt(self, userid, attacker, weapon):
		if playerlib.getPlayer(userid).get('isdead'):
			return

		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == self.weapon:
				self.stopLR(self.t, userid, 'noscope gun', {'player': es.getplayername(attacker)})
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()

noscope = NoScope()

def weapon_zoom(ev):
	noscope.weaponZoom(int(ev['userid']))

def player_hurt(ev):
	noscope.playerHurt(int(ev['userid']), int(ev['attacker']), ev['weapon'])

def player_death(ev):
	noscope.playerDeath(int(ev['userid']), int(ev['attacker']), ev['weapon'])
