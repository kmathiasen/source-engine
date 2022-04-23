import hosties.hosties as hosties, es, playerlib, gamethread, effectlib, usermsg

sv = es.ServerVar

class GunToss(hosties.RegisterLastRequest):
	def __init__(self):
		super(GunToss, self).__init__('guntoss')
		self.t = None
		self.ct = None

		self.posLoop = False
		self.isLR = False
		self.drops = {}
		self.startPositions = {}
		self.indexes = []

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.registerClientCommandFilter(self.checkDrop)

	def setLR(self):
		self.isLR = True

	def start(self, t, ct):
		self.t = t
		self.ct = ct
		self.indexes = []

		hosties.HM.msg('gt', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('gt rules')

		for userid in [self.t, self.ct]:
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
			gamethread.delayed(0, es.sexec, (userid, 'use weapon_deagle'))

		gamethread.delayed(0.25, self.setLR)
		m = str(sv('eventscripts_currentmap'))

		if not int(sv('hosties_teleport_to_designated_areas_for_lr')):
			return

		if not m in hosties.mapcoords:
			return

		if not 'gt' in hosties.mapcoords:
			return

		for userid in [self.t, self.ct]:
			hosties.getPlayer(userid).tell('prepare to teleport')
			for message in enumerate([3, 2, 1]):
				gamethread.delayed(message[0] + 1, es.centertell, (userid, message[1]))

		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.t, ' '.join(map(str, hosties.mapcoords[m]['gt'][0])))))
		gamethread.delayed(3, es.server.queuecmd, ('es_xsetpos %s %s'%(self.ct, ' '.join(map(str, hosties.mapcoords[m]['gt'][1])))))

	def end(self):
		self.drops.clear()
		self.startPositions.clear()

		gamethread.cancelDelayed('deagle loop')
		gamethread.cancelDelayed('pos loop')

		self.posLoop = False
		self.isLR = False

		self.t = None
		self.ct = None

		for index in self.indexes:
			if not index in es.createentitylist('weapon_deagle'):
				continue

			es.setindexprop(index, 'CBaseEntity.m_nRenderMode', es.getindexprop(index, 'CBaseEntity.m_nRenderMode') | 1)
			es.setindexprop(index, 'CBaseEntity.m_nRenderFX', es.getindexprop(index, 'CBaseEntity.m_nRenderFX') | 256)
			es.setindexprop(index, 'CBaseEntity.m_clrRender', -65281L)
		self.indexes = []

	def showDistanceLoop(self):
		gamethread.delayedname(0.5, 'pos loop', self.showDistanceLoop)
		if not self.startPositions:
			return

		format = 'Deagle Distances:'
		for userid in self.startPositions:
			x, y, z = self.drops[userid]
			if x == 0 and y == 0 and z == 0:
				continue

			x2, y2, z2 = self.startPositions[userid]
			format += '\n%s: %s'%(es.getplayername(userid), int(((x - x2) ** 2 + (y - y2) ** 2 + (z - z2) ** 2) ** 0.5))

		if format == 'Deagle Distances:':
			return

		if not int(sv('hosties_guntoss_show_distance')):
			return

		for userid in es.getUseridList():
			usermsg.hudhint(userid, format)

	def checkDrop(self, userid, args):
		if not self.isLR:
			return True

		if not args[0].lower() == 'drop':
			return True

		if not userid in [self.t, self.ct]:
			return True

		if not playerlib.getPlayer(userid).get('weapon') == 'weapon_deagle':
			return True

		if userid in self.drops and not self.drops[userid] == [0, 0, 0]:
			if int(sv('hosties_stop_double_drop')):
				hosties.getPlayer(userid).tell('already thrown')
				return False

		if not self.posLoop:
			self.posLoop = True
			self.showDistanceLoop()

		self.startPositions[userid] = es.getplayerlocation(userid)
		self.drops[userid] = [0, 0, 0]

		team = es.getplayerteam(userid)
		self.setEffects(userid, playerlib.getPlayer(userid).get('weaponindex', 'deagle'), 255 if team == 2 else 0, 255 if team == 3 else 0)
		return True

	def setEffects(self, userid, index, red, blue): # Changing color stolen from playerlib
		self.effectLoop(userid, index, red, blue, 7.5)
		color = red + (blue << 16) + (255 << 24)

		if color >= 2 ** 31: 
			color -= 2 ** 32
		self.indexes.append(index)

		es.setindexprop(index, 'CBaseEntity.m_nRenderMode', es.getindexprop(index, 'CBaseEntity.m_nRenderMode') | 1)
		es.setindexprop(index, 'CBaseEntity.m_nRenderFX', es.getindexprop(index, 'CBaseEntity.m_nRenderFX') | 256)
		es.setindexprop(index, 'CBaseEntity.m_clrRender', color)

	def effectLoop(self, userid, index, red, blue, etime):
		if type(etime) == float:
			etime -= 0.5
			if etime <= 0:
				etime = None

		gamethread.delayedname(0.5, 'deagle loop', self.effectLoop, (userid, index, red, blue, etime))
		if not etime is None:
			if es.getindexprop(index, 'CDEagle.baseclass.baseclass.m_iState') == 0:
				if not es.getindexprop(index, 'CDEagle.baseclass.baseclass.baseclass.baseclass.baseclass.m_vecOrigin') == '0,0,0':
					x, y, z = map(float, es.getindexprop(index, 'CDEagle.baseclass.baseclass.baseclass.baseclass.baseclass.m_vecOrigin').split(','))
					if not [x, y, z] == self.drops[userid]:
						self.drops[userid] = [x, y, z]

		if self.drops[userid]:
			x, y, z = self.drops[userid]
			effectlib.drawLine([x, y, z], [x, y, z + 30], seconds=0.5, red=red, green=0, blue=blue)

	def player_death(self, userid, attacker, weapon):
		if attacker in [self.t, self.ct] and userid in [self.t, self.ct]:
			self.stopLR(self.t, attacker, None)
			return
		hosties.getPlayer(attacker).checkKill(userid, weapon, self.t)

GT = GunToss()

def player_death(ev):
	GT.player_death(int(ev['userid']), int(ev['attacker']), ev['weapon'])
