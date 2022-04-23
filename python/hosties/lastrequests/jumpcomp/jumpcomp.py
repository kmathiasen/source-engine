import hosties.hosties as hosties, es, playerlib, gamethread, effectlib, math, usermsg, popuplib

class JumpComp(hosties.RegisterLastRequest):
	def __init__(self):
		super(JumpComp, self).__init__('jumpcomp')
		self.t = None
		self.ct = None

		self.lines = []
		self.jumped = {}
		self.endloc = {}

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)

	def end(self):
		for userid in [self.t, self.ct]:
			gamethread.cancelDelayed('jump %s'%userid)
			if not userid:
				continue

			if not es.exists('userid', userid):
				continue

			if playerlib.getPlayer(userid).get('isdead'):
				continue
			es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 0)

		self.jumped.clear()
		self.endloc.clear()

		self.t = self.ct = None
		for delay in ['Jump Comp Effect', 'resend menu jump']:
			gamethread.cancelDelayed(delay)

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		chooseLocationMenu = popuplib.easymenu('Choose Jump Location', '_popup_choice', self.chooseLocationMenuSelect)
		chooseLocationMenu.addoption('Select Location', 'Select Location')

		popuplib.send('Choose Jump Location', t)
		self.sendMenuLoop()

	def sendMenuLoop(self):
		if self.lines:
			return

		if not self.t:
			return

		if not popuplib.isqueued('Choose Jump Location', self.t):
			popuplib.send('Choose Jump Location', self.t)
		gamethread.delayedname(3, 'resend menu jump', self.sendMenuLoop)

	def chooseLocationMenuSelect(self, userid, choice, popupid):
		if not userid == self.t:
			return

		hosties.HM.msg('JC1', {'t': es.getplayername(self.t), 'ct': es.getplayername(self.ct)})
		hosties.HM.msg('JC2')
		hosties.HM.msg('JC3')

		xv, yv, zv = playerlib.getPlayer(self.t).get('viewvector')
		xa, ya, za = playerlib.getPlayer(self.t).get('viewangle')
		xp, yp, zp = es.getplayerlocation(self.t)

		xa = 70 * (math.cos(math.radians(ya - 90)))
		ya = 70 * (math.sin(math.radians(ya - 90)))

		xl1, yl1, zl1 = [p + (v * 50) for p, v in zip([xp, yp, zp], [xv, yv, 0.1])]
		xl2, yl2, zl2 = [p + (v * 100) for p, v in zip([xp, yp, zp], [xv, yv, 0.05])]
		self.lines = [[xl1 - xa, yl1 - ya, zl1], [xl1 + xa, yl1 + ya, zl1], [xl2 - xa, yl2 - ya, zl2], [xl2 + xa, yl2 + ya, zl2]]

		for userid in [self.t, self.ct]:
			es.setplayerprop(userid, 'CBaseEntity.m_CollisionGroup', 2)

		es.server.queuecmd('es_xsetpos %s %s %s %s'%(self.ct, xp, yp, zp))
		self.effectLoop()

	def effectLoop(self):
		l = self.lines
		effectlib.drawLine(l[0], l[1], seconds=5, green=0, blue=0)
		effectlib.drawLine(l[2], l[3], seconds=5, red=0, green=0)

		for userid in self.jumped:
			x, y, z = self.endloc[userid]
			effectlib.drawLine([x, y, z], [x, y, z + 50], seconds=5, red = 0 if es.getplayerteam(userid) == 3 else 255, green=0, blue = 0 if es.getplayerteam(userid) == 2 else 255)
		gamethread.delayedname(5, 'Jump Comp Effect', self.effectLoop)

	def playerJump(self, userid):
		x, y, z = es.getplayerlocation(userid)
		if not userid in [self.t, self.ct]:
			return

		if userid in self.jumped:
			return

		if not self.lines:
			return

		x2, y2, z2 = self.lines[0]
		x3, y3, z3 = self.lines[1]
		x4, y4, z4 = self.lines[2]
		x5, y5, z5 = self.lines[3]

		m = (y5 - y4) / (x5 - x4)
		m2 = -1.0 / m

		b1 = y4 - (m * x4)
		b2 = y2 - (m * x2)

		b3 = y3 - (m2 * x3)
		b4 = y2 - (m2 * x2)

		if (y > (m * x) + b1 and y < (m * x) + b2) or (y < (m * x) + b1 and y > (m * x) + b2):
			if (y < (m2 * x) + b3 and y > (m2 * x) + b4) or (y > (m2 * x) + b3 and y < (m2 * x) + b4):
				usermsg.hudhint(userid, 'Jump Distance: 0m')
				gamethread.delayedname(0.1, 'jump %s'%userid, self.jumpLoop, (userid, es.getplayerlocation(userid)))

	def stopJump(self, userid, distance, record=True):
		if not record:
			es.tell(userid, '#multi', '#lightgreen[Hosties]: #defaultPlease redo your jump, and avoid water and going backwards!')
			return

		self.jumped[userid] = distance
		self.endloc[userid] = es.getplayerlocation(userid)

		if len(self.jumped) == 2:
			winner = self.t if self.jumped[self.t] > self.jumped[self.ct] else self.ct
			self.stopLR(self.t, winner, 'won jc', {'player': es.getplayername(winner), 'distance': '%1.2f'%(self.jumped[winner] / 78.740157600000003)})

	def jumpLoop(self, userid, start):
		if not es.exists('userid', userid) or playerlib.getPlayer(userid).get('isdead'):
			return

		x, y, z = start
		x2, y2, z2 = es.getplayerlocation(userid)
		x3, y3, z3 = self.lines[0]
		x4, y4, z4 = self.lines[2]

		distance = (((x - x2) ** 2) + ((y - y2) ** 2)) ** 0.5
		if ((((x2 - x3) ** 2) + ((y2 - y3) ** 2)) ** 0.5) < ((((x2 - x4) ** 2) + ((y2 - y4) ** 2)) ** 0.5):
			distance = -distance
		usermsg.hudhint(userid, 'Jump Distance: %1.2fm'%(distance / 78.740157600000003))

		if es.getplayerprop(userid, 'CBasePlayer.m_fFlags') & 1:
			if distance <= 0:
				self.stopJump(userid, None, False)
				return

			self.stopJump(userid, distance)
			return

		if es.getplayerprop(userid, 'CBasePlayer.localdata.m_nWaterLevel'):
			self.stopJump(userid, None, False)
			return
		gamethread.delayedname(0.1, 'jump %s'%userid, self.jumpLoop, (userid, start))

JC = JumpComp()

def player_jump(ev):
	JC.playerJump(int(ev['userid']))
