import es, playerlib, popuplib, usermsg
import hosties.hosties as hosties

### Loads ###

def load():
	if not es.exists('saycommand', '!lastowner'):
		es.regsaycmd('!lastowner', 'hosties/mods/gunplant/lastowner_command')

	es.addons.registerClientCommandFilter(weapons._cc_filter)
	hosties.HM.registerCommand('!lastowner', 'lastowner command')

def unload():
	if es.exists('saycommand', '!lastowner'):
		es.unregsaycmd('!lastowner')
	es.addons.unregisterClientCommandFilter(weapons._cc_filter)

### Classes ###

class WeaponOwners(object):
	def __init__(self):
		self.weapons = {}

	def _cc_filter(self, userid, args):
		if not args[0].lower() == 'drop':
			return True

		if es.getplayerteam(userid) == 2:
			return True

		weapon = playerlib.getPlayer(userid).get('weapon')
		index = self.getIndex(userid, weapon)

		self.weapons[index] = userid
		return True

	def getIndex(self, userid, weapon):
		handle = es.getplayerhandle(userid)
		for index in es.createentitylist('weapon_%s'%str(weapon).replace('weapon_', '')):
			if es.getindexprop(index, 'CBaseEntity.m_hOwnerEntity') == handle:
				return index

	def itemPickup(self, userid, item):
		if item in ['c4', 'flashbang', 'hegrenade', 'smokegrenade', 'knife', 'nvgs', 'defuser', 'vest', 'vesthelm']:
			return

		index = self.getIndex(userid, item)
		if not index in self.weapons:
			return

		lastowner = self.weapons[index]
		if not es.exists('userid', lastowner):
			return

		if int(es.ServerVar('hosties_gunplant_show_last_owner')):
			usermsg.hudhint(userid, 'Last CT Owner: %s'%es.getplayername(lastowner))

weapons = WeaponOwners()

### Events ###

def round_start(ev):
	weapons.weapons.clear()

def item_pickup(ev):
	weapons.itemPickup(ev['userid'], ev['item'])

### Commands ###

def lastowner_command():
	userid = es.getcmduserid()
	args = es.getargs()

	if args:
		target = es.getuserid(args.replace('\r', '').replace('\n', ''))
		if not target:
			hosties.getPlayer(userid).tell('player does not exist')
			return

		player = playerlib.getPlayer(target)
		primary = weapons.getIndex(target, player.get('primary'))
		secondary = weapons.getIndex(target, player.get('secondary'))

		format = ''
		if primary in weapons.weapons:
			lastowner = weapons.weapons[primary]
			if es.exists('userid', lastowner):
				format += '%s: %s'%(player.get('primary'), es.getplayername(lastowner))

		if secondary in weapons.weapons:
			lastowner = weapons.weapons[secondary]
			if es.exists('userid', lastowner):
				if primary:
					format += '\n'
				format += '%s: %s'%(player.get('secondary'), es.getplayername(lastowner))

		if format:
			usermsg.hudhint(userid, format)
		else:
			hosties.getPlayer(userid).tell('gunplant weapons not owned', {'player': es.getplayername(target)})
		return

	selectPlayerMenu = popuplib.easymenu('Select Last Owned Weapon', '_popup_choice', selectPlayerMenuSelect)
	for player in playerlib.getPlayerList('#t,#alive'):
		if player.get('primary') or player.get('secondary'):
			selectPlayerMenu.addoption(int(player), player.get('name'))
	hosties.getPlayer(userid).send('Select Last Owned Weapon', userid)

### Popups ###

def selectPlayerMenuSelect(userid, choice, popupid):
	es.sexec(userid, 'say !lastowner %s'%choice)
