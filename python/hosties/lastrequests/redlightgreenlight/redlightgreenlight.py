import es, playerlib, gamethread, effectlib, usermsg, random, math, popuplib
import hosties.hosties as hosties

class RedLightGreenLight(hosties.RegisterLastRequest):
	def __init__(self):
		super(RedLightGreenLight, self).__init__('redlightgreenlight')

		self.corners = []
		self.t = None
		self.ct = None
		self.radians = None
		self.slope = None
		self.pslope = None
		self.winslope = None
		self.canJump = True
		self.stopped = 0

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('rlgl 1', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('rlgl 2')
		hosties.HM.msg('rlgl 3')

		xa, ya, za = playerlib.getPlayer(t).get('viewangle')
		xp, yp, zp = es.getplayerlocation(t)

		self.radians = ((ya - 90) / 180.0) * 3.141592654
		x_plus = 200 * math.cos(self.radians)
		y_plus = 200 * math.sin(self.radians)

		self.corners.append([xp - x_plus, yp - y_plus, zp])
		self.corners.append([xp + x_plus, yp + y_plus, zp])
		self.effectLoop()

		chooseEndLocationMenu = popuplib.easymenu('RLGL Select End Point', '_popup_choice', self.chooseEndLocationMenuSelect)
		chooseEndLocationMenu.addoption('Select Location', 'Select Location')

		popuplib.send('RLGL Select End Point', t)
		self.sendMenuLoop()

	def end(self):
		self.t = None
		self.ct = None

		self.radians = None
		self.slope = None
		self.pslope = None
		self.winslope = None
		self.distance = None
		self.windistance = None
		self.canJump = True
		self.stopped = 0

		del self.corners[:]
		for delay in ['rlgl effect loop', 'change light', 'rlgl check won', 'check outside loop', 'rlgl send menu']:
			gamethread.cancelDelayed(delay)

	def sendMenuLoop(self):
		if not self.t or len(self.corners) == 4:
			return

		if not popuplib.isqueued('RLGL Select End Point', self.t):
			popuplib.send('RLGL Select End Point', self.t)
		gamethread.delayedname(3, 'rlgl send menu', self.sendMenuLoop)

	def effectLoop(self):
		c = self.corners
		for i, pair in enumerate([c[:2], c[2:]] + zip(c[:2], c[2:])):
			if not pair:
				continue
			effectlib.drawLine(pair[0], pair[1], seconds=0.13, red=(self.stopped) * 255, blue=(0 if i in [0, 1] else 1) * 255, green=(0 if self.stopped else 255) * (0 if i in [2, 3] else 1))
		gamethread.delayedname(0.1, 'rlgl effect loop', self.effectLoop)

	def chooseEndLocationMenuSelect(self, userid, choice, popupid):
		if not userid == self.t:
			return

		x, y, z = es.getplayerlocation(userid)
		x_plus = 200 * math.cos(self.radians)
		y_plus = 200 * math.sin(self.radians)

		cx1, cy1 = self.corners[0][:2]
		cDistance = ((((x - x_plus) - cx1) ** 2) + (((y - y_plus) - cy1) ** 2)) ** 0.5

		if cDistance <= 800:
			hosties.getPlayer(self.t).tell('rlgl not far enough', {'distance': int(cDistance)})
			return

		self.corners.append([x - x_plus, y - y_plus, z])
		self.corners.append([x + x_plus, y + y_plus, z])

		cx1, cy1 = self.corners[0][:2]
		cx3, cy3 = self.corners[2][:2]
		cx4, cy4 = self.corners[3][:2]

		self.slope = (cy1 - cy3) / float(cx1 - cx3)
		self.pslope = -1 / self.slope
		self.distance = (((cx3 - cx4) ** 2) + ((cy3 - cy4) ** 2)) ** 0.5

		self.winslope = (cy3 - cy4) / float(cx3 - cx4)
		self.windistance = (((cx1 - cx3) ** 2) + ((cy1 - cy3) ** 2)) ** 0.5

		left = random.choice([self.t, self.ct])
		right = self.t if left == self.ct else self.ct

		x, y, z = self.corners[0]
		es.server.queuecmd('es_xsetpos %s %s %s %s'%(left, x + x_plus * 0.25, y + y_plus * 0.25, z + 10))
		es.server.queuecmd('es_xsetpos %s %s %s %s'%(right, x + x_plus * 0.75, y + y_plus * 0.75, z + 10))

		leftPlayer = playerlib.getPlayer(left)
		rightPlayer = playerlib.getPlayer(right)

		leftPlayer.set('freeze', 1)
		rightPlayer.set('freeze', 1)

		for delay, message in enumerate(['3', '2', '1', 'Go!']):
			gamethread.delayed(delay, es.centermsg, message)

		gamethread.delayed(3, leftPlayer.set, ('noclip', 0))
		gamethread.delayed(3, rightPlayer.set, ('noclip', 0))

		self.stopped = 0
		gamethread.delayedname(random.randint(40, 55) / 10.0, 'change light', self.changeLightLoop)

		# One day, I may actually fix this
		# gamethread.delayed(3, self.checkOutsideLoop)
		gamethread.delayed(3, self.checkWonLoop)

	def changeLightLoop(self):
		self.stopped = 0 if self.stopped else 1
		plus = 6 if self.stopped else 0

		delayTime = random.randint(10 + plus, 25 + plus) / 10.0
		gamethread.delayedname(delayTime, 'change light', self.changeLightLoop)

		if self.stopped:
			for userid in es.getUseridList():
				usermsg.hudhint(userid, 'Red Light')
				es.centertell(userid, 'Red Light')

			checkMovingWhen = 0.5
			self.canJump = False

			while checkMovingWhen < delayTime:
				gamethread.delayed(checkMovingWhen, self.checkMoving)
				checkMovingWhen += 0.1

		else:
			self.canJump = True
			for userid in es.getUseridList():
				usermsg.hudhint(userid, 'Green Light')
				es.centertell(userid, 'Green Light')

	def checkMoving(self):
		moving = []
		for userid in [self.t, self.ct]:
			if not userid:
				return

			if es.getplayersteamid(userid) == 'BOT':
				continue

			for v in es.getplayermovement(userid):
				if v:
					hosties.HM.msg('rlgl still moving', {'player': es.getplayername(userid)})
					moving.append(userid)
					break

		if len(moving) == 2:
			hosties.getPlayer(self.t).makeRebel()
			self.stopLR(self.t, None, 'rlgl both moving')
			return

		if moving:
			winner = self.t if moving[0] == self.ct else self.ct
			self.stopLR(self.t, winner, 'rlgl lost', {'player': es.getplayername(moving[0])})

	def checkWonLoop(self):
		gamethread.delayedname(0.1, 'rlgl check won', self.checkWonLoop)
		if len(self.corners) < 4:
			return

		cx3, cy3 = self.corners[2][:2]
		cx4, xy4 = self.corners[3][:2]

		for userid in [self.t, self.ct]:
			x, y, z = es.getplayerlocation(userid)
			cx1, cy1 = self.corners[0][:2]
			cx2, cy2 = self.corners[1][:2]


			pix = ((self.slope * x) + cy1 - y - (self.winslope * cx1)) / (self.slope - self.winslope)
			piy = (self.slope * (pix - x)) + y
			distance = (((pix - x) ** 2) + ((piy - y) ** 2)) ** 0.5

			if distance >= self.windistance:
				cDistance1 = (((x - cx1) ** 2) + (y - cy1) ** 2) ** 0.5
				cDistance3 = (((x - cx3) ** 2) + (y - cy3) ** 2) ** 0.5

				if cDistance1 < cDistance3:
					continue

				self.stopLR(self.t, userid, 'rlgl won', {'player': es.getplayername(userid)})
				return

	def checkOutsideLoop(self):
		gamethread.delayedname(0.5, 'check outside loop', self.checkOutsideLoop)
		for userid in [self.t, self.ct]:
			if not self.isBetweenLines(userid):
				break

	def isBetweenLines(self, userid):
		x, y, z = es.getplayerlocation(userid)
		cx1, cy1 = self.corners[0][:2]
		cx2, cy2 = self.corners[1][:2]

		pix = ((self.winslope * x) + cy1 - (self.slope * cx1) - y) / (self.winslope - self.slope)
		piy = (self.pslope * (pix - x)) + y
		d1 = (((pix - x) ** 2) + ((piy - y) ** 2)) ** 0.5

		pix2 = ((self.winslope * x) + cy2 - (self.slope * cx2) - y) / (self.winslope - self.slope)
		piy2 = (self.pslope * (pix2 - x))  + y
		d2 = (((pix2 - x) ** 2) + ((piy2 - y) ** 2)) ** 0.5

		if d1 > self.distance or d2 > self.distance:
			self.stopLR(self.t, self.t if userid == self.ct else self.ct, 'rlgl player outside', {'player': es.getplayername(userid)})
			return False
		return True

	def playerJump(self, userid):
		if userid in [self.t, self.ct] and not self.canJump:
			winner = self.t if userid == self.ct else self.ct
			self.stopLR(self.t, winner, 'rlgl lost', {'player': es.getplayername(userid)})

RLGL = RedLightGreenLight()

def player_jump(ev):
	RLGL.playerJump(int(ev['userid']))
