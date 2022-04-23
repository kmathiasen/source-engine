import es, popuplib, playerlib, gamethread, usermsg
import hosties.hosties as hosties

### Constants ###

sv = es.ServerVar

### Loads ###

def load():
	if not es.exists('saycommand', '!control'):
		es.regsaycmd('!control', 'hosties/mods/control/control_command')
	hosties.HM.registerCommand('!control', 'control command')

	CTRL.issueMenu.settitle(hosties.text('Issue Command', {}, hosties.menu_lang))
	CTRL.controlMenu.settitle(hosties.text('control', {}, hosties.menu_lang))

	addSounds()

def unload():
	for delay in ['play sound', 'control time up', 'spin check', 'crouch check']:
		gamethread.cancelDelayed(delay)

	if es.exists('saycommand', '!control'):
		es.unregsaycmd('!control')

### Classes ###

class Control(object):
	'''Allows players to play "Simon Says"
		NOTE: This was also made a while ago, RECODE D:'''

	def __init__(self):
		self.controller = None
		self.pd = {}
		self.say_times = {'rotate': 2.3, 'simon_says': 1.1, 'jump': 0.5, 'crouch': 0.6, 'lastrequest': 1.1, 'firstrequest': 1.1}
		self.is_order = False

		self.simon_says = False
		self.lastreaction = False
		self.firstreaction = False

		self.issueMenu = popuplib.easymenu('Issue Command', '_popup_choice', self.issueSelect)
		for option in ['Rotate 180 Degrees', 'Jump', 'Crouch', 'Crouch Jump']:
			self.issueMenu.addoption(option, hosties.text(option, {}, hosties.menu_lang))

		self.controlMenu = popuplib.easymenu('Control', '_popup_choice', self.controlSelect)
		for option in ['Become Controller', 'Stop Controlling', 'Issue Command']:
			self.controlMenu.addoption(option, hosties.text(option, {}, hosties.menu_lang))

	def controlSelect(self, userid, choice, popupid):
		if choice == 'Issue Command':
			if not userid == CTRL.controller:
				hosties.getPlayer(userid).tell('not controller')
				return
			hosties.getPlayer(userid).send('Issue Command')

		elif choice == 'Become Controller':
			self.takeControl(userid)

		elif choice == 'Stop Controlling':
			self.stopControl(userid)

	def issueSelect(self, userid, choice, popupid):
		issueMenu2 = popuplib.easymenu('Simon Says', '_popup_choice', self.issueSelect2)
		if int(sv('hosties_control_allow_lastreaction')):
			issueMenu2.addoption([choice, 'First Reaction'], hosties.text('first reaction', {}, hosties.menu_lang))
			issueMenu2.addoption([choice, 'Last Reaction'], hosties.text('last reaction', {}, hosties.menu_lang))

		if int(sv('hosties_control_allow_simon')):
			issueMenu2.addoption([choice, 'With Simon'], hosties.text('With Simon', {}, hosties.menu_lang))

		issueMenu2.addoption([choice, 'Without Simon'], hosties.text('Without Simon', {}, hosties.menu_lang))
		hosties.getPlayer(userid).send('Simon Says')

	def issueSelect2(self, userid, choice, popupid):
		self.issueOrder(userid, choice[0], choice[1] == 'With Simon', choice[1] == 'Last Reaction', choice[1] == 'First Reaction')

	def takeControl(self, userid):
		if self.controller:
			hosties.getPlayer(userid).tell('already controller')
			return

		if not es.getplayerteam(userid) == 3:
			hosties.getPlayer(userid).tell('must be ct')
			return

		if playerlib.getPlayer(userid).get('isdead'):
			hosties.getPlayer(userid).tell('must be alive')
			return

		if hosties.LR.ts:
			hosties.getPlayer(userid).tell('no control during lr')
			return

		if not len(filter(lambda x: x not in hosties.Rb.rebels, playerlib.getUseridList('#t,#alive'))):
			hosties.getPlayer(userid).tell('no non rebellers')
			return

		self.controller = userid
		playerlib.getPlayer(userid).set('color', str(sv('hosties_controller_color')).split(','))

		for userid2 in es.getUseridList():
			hosties.getPlayer(userid2).tell('now controller', {'player': es.getplayername(userid)})

	def stopControl(self, userid):
		if not self.controller == userid:
			hosties.getPlayer(userid).tell('not controller')
			return

		self.stopControlling()
		for userid2 in es.getUseridList():
			hosties.getPlayer(userid2).tell('no longer controller', {'player': es.getplayername(userid)})

	def issueOrder(self, userid, order, simon_says, lastreaction, firstreaction):
		if not len(filter(lambda x: x not in hosties.Rb.rebels, playerlib.getUseridList('#t,#alive'))):
			hosties.getPlayer(userid).tell('no non rebellers')
			return

		if self.is_order:
			hosties.getPlayer(userid).tell('order in progress')
			return

		if not userid == self.controller:
			hosties.getPlayer(userid).tell('not controller')
			return

		if playerlib.getPlayer(userid).get('isdead'):
			hosties.getPlayer(userid).tell('must be alive')
			return

		self.simon_says = simon_says
		self.lastreaction = lastreaction
		self.firstreaction = firstreaction

		sound = ''
		orderMessage = ''

		if simon_says:
			sound += 'simon_says,'
			orderMessage += 'Simon Says'

		if lastreaction:
			sound += 'lastreaction,'
			orderMessage += 'Last Reaction'

		if firstreaction:
			sound += 'firstreaction,'
			orderMessage += 'First Reaction'

		sound += {'Rotate 180 Degrees': 'rotate', 'Jump': 'jump', 'Crouch': 'crouch', 'Crouch Jump': 'crouch,jump'}[order]
		orderMessage += order

		for userid2 in es.getUseridList():
			es.centertell(userid2, orderMessage)
			usermsg.hudhint(userid2, orderMessage)

			es.tell(userid, '#multi', '#lightgreen[Hosties]: #default' + orderMessage)
			delay = -self.say_times[sound.split(',')[0]]

			for s in sound.split(','):
				delay += self.say_times[s]
				gamethread.delayedname(delay, 'play sound', es.cexec, (userid2, 'play hosties/%s.wav'%s))

			if es.getplayerteam(userid2) == 2 and not playerlib.getPlayer(userid2).get('isdead'):
				self.pd[userid2] = {'crouched': False, 'spun': False, 'spin_angles': playerlib.getPlayer(userid2).get('viewangle'), 'jumped': False}

		if simon_says or lastreaction or firstreaction:
			if order == 'Rotate 180 Degrees':
				self.spinCheckLoop(int(sv('hosties_control_command_time')))

			elif order == 'Crouch':
				self.crouchCheckLoop(int(sv('hosties_control_command_time')))

		self.is_order = order
		gamethread.delayedname(int(sv('hosties_control_command_time')), 'control time up', self.endOrder)
		es.msg('#multi', '#lightgreen[Hosties]: #defaultAll terrorists have #lightgreen%s#default seconds to #lightgreen%s!'%(int(sv('hosties_control_command_time')), order))

	def endOrder(self):
		hosties.getPlayer(self.controller).send('Issue Command')
		gamethread.cancelDelayed('control time up')

		message = 'Order has been finished, everyone that did not finish task has been turned into a rebel!' if self.simon_says else 'Order is finished'
		es.msg('#multi', '#lightgreen[Hosties]: #default' + message)

		order = {'Rotate 180 Degrees': 'spun', 'Jump': 'jumped', 'Crouch': 'crouched', 'Crouch Jump': 'jumped', None: None}[self.is_order]
		if self.simon_says:
			for userid in self.pd:
				playerlib.getPlayer(userid).set('color', [255, 255, 255, 255])
				if not self.pd[userid][order]:
					es.tell(userid, '#multi', hosties.text('now rebel', {}, playerlib.getPlayer(userid).get('lang')), ' for not completing the orders')
					hosties.getPlayer(userid).makeRebel(False)

		self.pd.clear()
		self.simon_says = False

		if self.lastreaction:
			for userid in self.pd:
				if not self.pd[userid][order]:
					hosties.HM.msg('didnt do order', {'player': es.getplayername(userid)})

		self.lastreaction = False
		self.firstreaction = False
		self.is_order = False

	def spinCheckLoop(self, time_left):
		time_left -= 0.1
		if time_left >= 0:
			gamethread.delayedname(0.1, 'spin check', self.spinCheckLoop, time_left)
			for userid in playerlib.getUseridList('#t,#alive'):
				if userid in self.pd:
					if not userid in hosties.Rb.rebels and not self.pd[userid]['spun']:
						x, y, z = playerlib.getPlayer(userid).get('viewangle')
						x2, y2, z2 = self.pd[userid]['spin_angles']

						y = y if y >= 0 else -y + 180
						y2 = y2 if y2 >= 0 else -y + 180

						if 160 <= abs(y - y2) >= 200:
							if self.firstreaction:
								self.firstReaction(userid)
								return

							self.pd[userid]['spun'] = True
							if self.lastreaction:
								if self.checkLastReaction(userid, 'spun'):
									return

							hosties.getPlayer(userid).tell('task completed')
							playerlib.getPlayer(userid).set('color', str(sv('hosties_simon_says_completed_color')).split(','))
							self.checkOver()

	def firstReaction(self, userid):
		self.endOrder()
		hosties.HM.msg('fooled by first reaction', {'player': es.getplayername(userid)})
		hosties.getPlayer(userid).makeRebel(False)

	def checkLastReaction(self, userid, key):
		if len(filter(lambda x: self.pd[x][key], self.pd)) == len(self.pd) - 1:
			for userid in self.pd:
				if not self.pd[userid][key]:
					break

			self.endOrder()
			hosties.HM.msg('last reaction person', {'player': es.getplayername(userid)})

			hosties.getPlayer(userid).makeRebel(False)
			return True
		return False

	def crouchCheckLoop(self, time_left):
		time_left -= 0.03
		if time_left > 0:
			for userid in playerlib.getUseridList('#t,#alive'):
				if not userid in hosties.Rb.rebels and not self.pd[userid]['crouched']:
					if es.getplayerprop(userid, 'CBasePlayer.localdata.m_Local.m_bDucked') % 2:
						if self.firstreaction:
							self.firstReaction(userid)
							return

						self.pd[userid]['crouched'] = True
						if self.lastreaction:
							if self.checkLastReaction(userid, 'crouched'):
								return

						playerlib.getPlayer(userid).set('color', str(sv('hosties_simon_says_completed_color')).split(','))
						self.checkOver()
			gamethread.delayedname(0.03, 'crouch check', self.crouchCheckLoop, time_left)

	def stopControlling(self):
		if es.exists('userid', self.controller):
			if not playerlib.getPlayer(self.controller).get('isdead'):
				playerlib.getPlayer(self.controller).set('color', [255, 255, 255, 255])

		self.controller = None
		self.is_order = False

		for delay in ['play sound', 'spin check', 'crouch check', 'control time up']:
			gamethread.cancelDelayed(delay)

	def player_jump(self, userid):
		if self.is_order:
			if 'Jump' in self.is_order:
				if es.getplayerteam(userid) == 2:
					if not self.pd[userid]['jumped']:
						if self.firstreaction:
							self.firstReaction(userid)
							return

						self.pd[userid]['jumped'] = True
						if self.lastreaction:
							if self.checkLastReaction(userid, 'jumped'):
								return

						if 'Crouch' in self.is_order and not es.getplayerprop(userid, 'CBasePlayer.localdata.m_Local.m_bDucked') % 2:
							hosties.getPlayer(userid).tell('must be crouch jumping')
							return

						playerlib.getPlayer(userid).set('color', str(sv('hosties_simon_says_completed_color')).split(','))
						self.checkOver()

	def checkOver(self):
		if not len(filter(lambda x: not self.pd[x][{'Rotate 180 Degrees': 'spun', 'Jump': 'jumped', 'Crouch': 'crouched', 'Crouch Jump': 'jumped'}[self.is_order]], self.pd.keys())):
			self.endOrder()

	def playerDeath(self, userid):
		if userid == self.controller:
			self.stopControl(userid)

	def stop(self):
		if self.controller:
			self.stopControl(self.controller)

CTRL = Control()

### Events ###

def player_jump(ev):
	CTRL.player_jump(int(ev['userid']))

def player_death(ev):
	CTRL.playerDeath(int(ev['userid']))

def round_end(ev):
	CTRL.stop()

def round_start(ev):
	CTRL.stop()

def es_map_start(ev):
	addSounds()

### Commands ###

def control_command():
	userid = es.getcmduserid()
	if not es.getplayerteam(userid) == 3:
		hosties.getPlayer(userid).tell('must be ct')
		return
	hosties.getPlayer(userid).send('Control')

### Misc ###

def addSounds():
	for sound in ['crouch', 'firstreaction', 'jump', 'lastreaction', 'rotate', 'simon_says', 'lr']:
		es.stringtable('downloadables', 'sound/hosties/%s.wav'%sound)
