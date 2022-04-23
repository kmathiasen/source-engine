import es, playerlib, gamethread
import hosties.hosties as hosties

class DodgeBall(hosties.RegisterLastRequest):
	def __init__(self):
		super(DodgeBall, self).__init__('dodgeball')
		self.t = None
		self.ct = None

		self.registerStartFunction(self.start)
		self.registerEndFunction(self.end)
		self.unrestrictWeapon('flashbang')

	def start(self, t, ct):
		self.t = t
		self.ct = ct

		hosties.HM.msg('dodgeball 1', {'t': es.getplayername(t), 'ct': es.getplayername(ct)})
		hosties.HM.msg('dodgeball 2')

		for userid in [t, ct]:
			playerlib.getPlayer(userid).set('health', 1)
			playerlib.getPlayer(userid).set('armor', 0)

			if not playerlib.getPlayer(userid).get('fb'):
				es.server.queuecmd('es_xgive %s weapon_flashbang;es_sexec %s use weapon_flashbang'%(userid, userid))
				gamethread.delayed(0, self.checkHas, userid)

	def end(self):
		for userid in [self.t, self.ct]:
			if not es.exists('userid', userid):
				continue

			player = playerlib.getPlayer(userid)
			if not player.get('isdead'):
				player.set('health', 100)

		self.t = None
		self.ct = None

	def checkHas(self, userid):
		if not playerlib.getPlayer(userid).get('fb'):
			es.server.queuecmd('es_xgive %s weapon_flashbang;es_sexec %s use weapon_flashbang'%(userid, userid))
			gamethread.delayed(0, self.checkHas, userid)

	def flashBangDetonated(self, userid):
		if int(userid) in [self.t, self.ct]:
			es.server.queuecmd('es_xgive %s weapon_flashbang;es_sexec %s use weapon_flashbang'%(userid, userid))

	def playerBlinded(self, userid):
		es.setplayerprop(userid, 'CCSPlayer.m_flFlashMaxAlpha', 0)
		es.setplayerprop(userid, 'CCSPlayer.m_flFlashDuration', 0)

	def playerHurt(self, userid, attacker, weapon):
		userid, attacker = int(userid), int(attacker)
		if userid in [self.t, self.ct] and attacker in [self.t, self.ct]:
			if not weapon == 'flashbang':
				self.stopLR(self.t, userid, 'dodgeball weapon used', {'player': es.getplayername(attacker)})
				if attacker == self.t:
					hosties.getPlayer(attacker).makeRebel()

dodgeball = DodgeBall()

def flashbang_detonate(ev):
	dodgeball.flashBangDetonated(ev['userid'])

def player_blind(ev):
	dodgeball.playerBlinded(ev['userid'])

def player_hurt(ev):
	dodgeball.playerHurt(ev['userid'], ev['attacker'], ev['weapon'])
