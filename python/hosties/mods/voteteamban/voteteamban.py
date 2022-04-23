import es, popuplib, os.path, re, gamethread
import hosties.hosties as hosties
import hosties.admin.admin as admin

sv = es.ServerVar

### Loads ###

def load():
	if not es.exists('saycommand', '!voteteamban'):
		es.regsaycmd('!voteteamban', 'hosties/mods/voteteamban/voteteamban_command')
	hosties.HM.registerCommand('!voteteamban', 'voteteamban command')

def unload():
	if es.exists('saycommand', '!voteteamban'):
		es.unregsaycmd('!voteteamban')

	for steamid in vote.players:
		gamethread.cancelDelayed('teamban remove %s'%steamid)
	gamethread.cancelDelayed('voteteamban prune')

### Classes ###

class VoteManager(object):
	def __init__(self):
		self.players = {}
		self.immune = self.getImmune()

	@staticmethod
	def getImmune():
		oFilePath = hosties.FILEPATH.replace('addons/eventscripts/hosties/', '') + str(sv('hosties_voteteamban_immune_file'))
		if not os.path.isfile(oFilePath):
			return []

		oFile = open(oFilePath)
		contents = oFile.read()
		oFile.close()
		
		return map(lambda x: x.upper(), re.findall('(STEAM_0:[0-1]:\d+)', contents, re.IGNORECASE))

	@staticmethod
	def getNeeded():
		return max(int(sv('hosties_voteteamban_minimum_votes')), int(es.getplayercount() * float(sv('hosties_voteteamban_vote_ratio'))))

	### Player Management ###

	def playerRejoin(self, steamid):
		self.players[steamid]['against'] = 0
		for player in self.players:
			if steamid in self.players[player]['for']:
				self.players[steamid]['against'] += 1

	def removePlayer(self, steamid):
		for player in self.players:
			if steamid in self.players[player]['for']:
				self.players[player]['for'].remove(steamid)
		del self.players[steamid]

	def prunePlayers(self):
		steamids = self.players.keys()
		for steamid in self.players:
			for for_steamid in list(self.players[steamid]['for']):
				if not for_steamid in steamids:
					self.players[steamid]['for'].remove(for_steamid)

	### Popups ###
	def sendPopup(self, userid):
		selectPlayerMenu = popuplib.easymenu('Select VTB Player', '_popup_choice', self.selectPlayerMenuSelect)
		for tuserid in es.getUseridList():
			if tuserid == userid:
				continue

			tsteamid = es.getplayersteamid(tuserid)
			if tsteamid in self.immune:
				continue

			if tsteamid in admin.admin.banned:
				continue
			selectPlayerMenu.addoption(tuserid, '%s [%s]'%(es.getplayername(tuserid), self.players.get(tsteamid, {}).get('against', 0)))
		hosties.getPlayer(userid).send('Select VTB Player')

	def selectPlayerMenuSelect(self, userid, choice, popupid):
		steamid = es.getplayersteamid(userid)
		csteamid = es.getplayersteamid(choice)

		if not es.exists('userid', choice):
			hosties.getPlayer(userid).tell('target left server')
			return

		if not steamid in self.players:
			self.players[steamid] = {'for': [], 'against': 0}

		if csteamid in self.players[steamid]['for']:
			hosties.getPlayer(userid).tell('already voted against', {'player': es.getplayername(choice)})
			return

		self.players[steamid]['for'].append(csteamid)
		if not csteamid in self.players:
			self.players[csteamid] = {'for': [], 'against': 0}

		self.players[csteamid]['against'] += 1
		hosties.HM.msg('voted to ban', {'votes': self.players[csteamid]['against'], 'needed': self.getNeeded(), 'voter': es.getplayername(userid), 'player': es.getplayername(choice)})

		if self.players[csteamid]['against'] >= self.getNeeded():
			hosties.HM.msg('voteteamban banned', {'player': es.getplayername(choice)})
			admin.admin.selectTimeMenuSelect(0, [choice, int(sv('hosties_voteteamban_ban_time')) * 60, 3], None, 'Vote Team Banned')
			self.players[csteamid]['against'] = 0

vote = VoteManager()

### Events ###

def player_activate(ev):
	steamid = ev['es_steamid']
	if steamid in vote.players:
		vote.playerRejoin(steamid)
		gamethread.cancelDelayed('teamban remove %s'%steamid)

def player_disconnect(ev):
	steamid = ev['es_steamid']
	if steamid in vote.players:
		for for_steamid in vote.players[steamid]['for']:
			vote.players[for_steamid]['against'] -= 1
		del vote.players[steamid]['for'][:]

		if not vote.players[steamid]['against']:
			del vote.players[steamid]
			return
		gamethread.delayedname(300, 'teamban remove %s'%steamid, vote.removePlayer, steamid)

def round_start(ev):
	gamethread.delayedname(5, 'voteteamban prune', vote.prunePlayers)

### Commands ###

def voteteamban_command():
	vote.sendPopup(es.getcmduserid())
