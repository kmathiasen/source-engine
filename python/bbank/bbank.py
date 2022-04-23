import es, cPickle, os.path, playerlib, popuplib, gamethread, langlib, services
from configobj import ConfigObj

info = es.AddonInfo() 
info['name']        = "BBank" 
info['version']     = "2.0.6d" 
info['author']      = "Bonbon AKA: Bonbon367" 
info['url']         = "http://addons.eventscripts.com/addons/view/bbank" 
info['description'] = "A Bank With lots more features" 

first_round = 0
es.ServerVar('bbank_version', info['version'], 'BBank made by Bonbon AKA Bonbon367').makepublic()
round_ended = 0
map_ended = 0
_HASH = '29fbb03bc27275e40bbee95a9435c842c4ec7859e09500006ae45291'

dict_saycommands = {
	'badmin': {'block': 'admin', 'description': 'Show the admin menu'},
	'bank': {'block': 'showmenu', 'description': 'Show the main bank menu'},
	'deposit': {'block': 'deposit', 'description': 'Quick deposit command'},
	'withdraw': {'block': 'withdraw', 'description': 'Quick withdraw command'},
	'transfer': {'block': 'transfer', 'description': 'Quick transfer command'},
	'give': {'block': 'transfer', 'description': 'Quick transfer command'},
	'loan': {'block': 'loan', 'description': 'Quick loan command'},
	'repay': {'block': 'repay', 'description': 'Quick repay command'},
	'manage': {'block': 'manage', 'description': 'Admins manage individual players accounts'},
}

dict_clientcommands = {
	'cash': {'block': 'givecash', 'description': 'None'},
	'abalance': {'block': 'abalance', 'description': 'Always have x amount of cash in the bank'},
	'offlinecash': {'block': 'offlinecash', 'description': 'GTFO'},
}

sv = es.ServerVar

sv_options = {
	'bbank_tell_format': '#green[#lightgreenBBank#green]:',
	'bbank_players_in_top': 10,
	'bbank_start_cash': 5000,
	'bbank_round_until_withdraw': 2,
	'bbank_auto_deposit_on_map_end': 1,
	'bbank_tell_every_intrest': 1,
	'bbank_enable_loan': 1,
	'bbank_disabled_map_prefixes': 'fy_,aim_',
	'bbank_min_intrest_tell': 5,
	'bbank_enable_sounds': 1,
	'bbank_admins': 'STEAM_0:0:11228704,STEAM_0:0:15965938,STEAM_0:0:11089864,STEAM_0:1:5774407,STEAM_0:1:12114951',
	'bbank_max_team_changes_per_round': 1,
	'bbank_team_change_penalty': 3000,
	'bbank_max_menus': 10,
	'bbank_account_upgrade': 1,
	'bbank_tell_streak_intrest': 1,
	'bbank_menu_language': 'en',
	'bbank_auto_deposit_on_disconnect': 1,
	'bbank_save_every': 0,
}

text = None
enabled = True
filepath = es.getAddonPath('bbank') + '/'

### Loads ###

def load():
	global EH
	EH = eventHandler()

def load2():
	global text
	for option in sv_options:
		sv(option).set(sv_options[option])

	loadconfig()
	menulang = str(sv('bbank_menu_language'))

	if os.path.isfile(es.getAddonPath('bbank') + '/strings.ini'):
		text = langlib.Strings(es.getAddonPath('bbank') + '/strings.ini')

	for client_command in dict_clientcommands:
		if not es.exists('clientcommand', client_command):
			es.regclientcmd(client_command, 'bbank/%s'%dict_clientcommands[client_command]['block'], dict_clientcommands[client_command]['description'])

	for saycommand in dict_saycommands:
		for command in ['!' + saycommand, saycommand]:
			if not es.exists('saycommand', command):
				es.regsaycmd(command, 'bbank/%s'%dict_saycommands[command.replace('!', '')]['block'], dict_saycommands[command.replace('!', '')]['description'])
			if not es.exists('clientcommand', command):
				es.regclientcmd(command, 'bbank/%s'%dict_saycommands[command.replace('!', '')]['block'], dict_saycommands[command.replace('!', '')]['description'])

	depositmenu = popuplib.easymenu('Deposit', '_popup_choice', deposit_select)
	withdrawmenu = popuplib.easymenu('Withdraw', '_popup_choice', withdraw_select)
	transfermenu = popuplib.easymenu('Transfer', '_popup_choice', transfer_select)
	playerinfo = popuplib.easymenu('Player Info', '_popup_choice', pinfo_select)
	settings = popuplib.easymenu('Settings', '_popup_choice', settings_select)
	accounttype = popuplib.easymenu('Choose New Account', '_popup_choice', account_type_select)

	adminmenu = popuplib.easymenu('Admin Menu', '_popup_choice', admin_select)
	adminmenu.addoption('Give/Take Cash', text('givetake cash', {}, menulang))
	adminmenu.addoption('Reset', text('reset bbank', {}, menulang))
	adminmenu.addoption('Change Player Accounts', text('change player accounts', {}, menulang))

	confirmmenu = popuplib.easymenu('Are You Sure?', '_popup_choice', confirm_reset)
	confirmmenu2 = popuplib.easymenu('Reset Account?', '_popup_choice', confirm_reset_2)
	loanmoney = popuplib.easymenu('Loan', '_popup_choice', loan_money)
	repaymoney = popuplib.easymenu('Repay', '_popup_choice', repay_money)

	loanmenu = popuplib.easymenu('Loan Menu', '_popup_choice', loan_select)
	loanmenu.addoption('Loan', text('loan text', {}, menulang))
	loanmenu.addoption('Repay', text('repay', {}, menulang))

	for confirm_option in ('Yes', 'No'):
		confirmmenu.addoption(confirm_option, text(confirm_option, {}, menulang))
		confirmmenu2.addoption(confirm_option, text(confirm_option, {}, menulang))

	for b in ('all', 1000, 2000, 4000, 8000, 10000, 14000):
		depositmenu.addoption(b, b)
		withdrawmenu.addoption(b, b)
		loanmoney.addoption(b, b)
		repaymoney.addoption(b, b)

	mainmenu = popuplib.easymenu('BBank', '_popup_choice', main_menu_select)
	for main_options in ('Show Balance', 'Transfer', 'Deposit', 'Withdraw', 'Top', 'Player Info', 'Settings'):
		mainmenu.addoption(main_options, text(main_options, {}, menulang))

	if int(sv('bbank_enable_loan')):
		mainmenu.addoption('Loan Menu', text('Loan Menu', {}, menulang))

	for to_sub in (depositmenu, withdrawmenu, settings, transfermenu, playerinfo):
		to_sub.submenu(0, 'BBank')

	confirmmenu2.submenu(0, 'Settings')
	confirmmenu.submenu(0, 'Admin Menu')

	for settings_option in ('Auto Balance', 'Reset Account', 'Sounds', 'Appear in Top'):
		settings.addoption(settings_option, text(settings_option, {}, menulang))

	if int(sv('bbank_account_upgrade')):
		settings.addoption('Upgrade Account', text('upgrade account', {}, menulang))

	gamethread.delayed(0, es.msg, ('#multi', '%s Loaded - Made by Bonbon: AKA Bonbon367'%str(sv('bbank_tell_format'))))
	enabled_check()
	sound_check()
	check_loop()

	if int(sv('bbank_save_every')):
		saveLoop()

def loadconfig():
	global intrest_rates, account_types
	if not os.path.isfile(filepath + 'bbank.cfg'):
		es.dbgmsg(0, 'No bbank.cfg present under addons/eventscripts/bbank/ !')
		return
	es.server.cmd('es_xmexec ../addons/eventscripts/bbank/bbank.cfg')

	if not os.path.isfile(filepath + 'bbankaccounts.ini'):
		es.dbgmsg(0, 'No bbankaccounts.ini present under addons/eventscripts/bbank/ !')
		return
	account_types = dict(ConfigObj(filepath + 'bbankaccounts.ini'))
	[[account_types[x].__setitem__(y, float(account_types[x][y])) for y in account_types[x]] for x in account_types]

	if not os.path.isfile(filepath + 'bbankintrest.ini'):
		es.dbgmsg(0, 'No bbankintrest.ini present under addons/eventscripts/bbank/ !')
		return
	intrest_rates = dict(ConfigObj(filepath + 'bbankintrest.ini'))['intrest_rates']
	[intrest_rates.__setitem__(x, float(intrest_rates[x])) for x in intrest_rates]

def sound_check():
	if int(sv('bbank_enable_sounds')):
		es.stringtable('downloadables', 'sound/bbank/withdraw.wav')
		es.stringtable('downloadables', 'sound/bbank/deposit.wav')

def enabled_check():
	global enabled
	enabled = True
	for prefix in str(sv('bbank_disabled_map_prefixes')).split(','):
		if str(es.ServerVar('eventscripts_currentmap')).startswith(prefix):
			enabled = False
			break

def unload():
	for command in dict_clientcommands:
		if es.exists('clientcommand', command):
			es.unregclientcmd(command)

	for saycommand in dict_saycommands:
		for command in ['!' + saycommand, saycommand]:
			if es.exists('saycommand', command):
				es.unregsaycmd(command)

	bank.save_data(True)
	es.msg('#multi', '%s Unloaded - Made by Bonbon: AKA Bonbon367'%str(sv('bbank_tell_format')))

	for delay in ['check loop', 'save loop']:
		gamethread.cancelDelayed(delay)

	EH.unregisterEvents()

### Events ###

def server_cvar(ev):
	if not ev['cvarname'] == 'bbank_save_every':
		return

	if not ev['cvarvalue'].isdigit():
		es.debugmsg(0, 'BBank: Value must be an integer!')
		return

	gamethread.cancelDelayed('save loop')
	if int(ev['cvarvalue']) <= 0:
		return
	gamethread.delayedname(int(sv('bbank_save_every')), 'save loop', saveLoop)

def player_activate(ev):
	userid = int(ev['userid'])
	intrest = False

	if ev['es_steamid'] in bank.pd:
		intrest = True

	bank.add(userid)
	bank.cd[userid].pd['name'] = ev['es_username']

	if intrest:
		bank.cd[userid].intrest('player_activate', 'coming back to the server')

	bank.cd[userid].pd['team changes'] = -1

def es_map_start(ev):
	global first_round, map_ended, round_ended
	map_ended = first_round = round_ended = 0

	for userid in playerlib.getUseridList('#human'):
		bank.cd[userid].intrest('map_start', 'The map starting')

	enabled_check()
	sound_check()
	loadconfig()

def round_end(ev):
	global first_round, round_ended
	first_round += 1
	round_ended = 1
	bank.save_data()

	for userid in playerlib.getUseridList('#human'):
		bank.cd[userid].intrest('round_end', 'the round ending')
		bank.cd[userid].loan_intrest()
		bank.cd[userid].pd['team changes'] = 0

	filter = 't' if ev['winner'] == '2' else 'ct' if ev['winner'] == '3' else 'all'
	for userid in playerlib.getUseridList('#' + filter + ',#human'):
		bank.cd[userid].intrest('round_won', 'winning the round')

	for userid in playerlib.getUseridList('#alive,#human'):
		bank.cd[userid].intrest('round_survived', 'surviving the round')

def player_death(ev):
	bank.cd[int(ev['userid'])].pd['streak'] = 0
	a = int(ev['attacker'])

	if not a:
		return

	if not a in bank.cd:
		return

	bank.cd[a].pd['streak'] += 1
	if bank.cd[a].pd['streak'] >= 3:
		bank.cd[a].intrest('streak', 'getting a kill streak of %s'%bank.cd[a].pd['streak'] if int(sv('bbank_tell_streak_intrest')) else None)

def player_spawn(ev):
	userid = int(ev['userid'])
	if not userid in bank.cd:
		return
	bank.cd[userid].intrest('player_spawn', 'spawning')

	bank.cd[userid].p = playerlib.getPlayer(userid)
	gamethread.delayed(0.1, bank.cd[userid].abalance)

	if not int(sv('bbank_tell_every_intrest')) and bank.cd[userid].pd['intrest'] >= int(sv('bbank_min_intrest_tell')):
		es.tell(userid, '#multi', text('gain intrest', {'tell_format': bank.tell_format, 'amount': bank.cd[userid].pd['intrest']}, bank.cd[userid].lang))
	bank.cd[userid].pd['intrest'] = 0

def est_map_end(ev):
	global map_ended
	map_ended = True
	if int(sv('bbank_auto_deposit_on_map_end')):
		for userid in playerlib.getUseridList('#human'):
			es.cexec(userid, 'deposit all')

	for userid in playerlib.getUseridList('#human'):
		bank.cd[userid].intrest('map_change', 'map change')

def bomb_defused(ev):
	bank.cd[int(ev['userid'])].intrest('bomb_defuse', 'defusing the bomb')

def bomb_planted(ev):
	bank.cd[int(ev['userid'])].intrest('bomb_plant', 'planting the bomb')

def bomb_exploded(ev):
	bank.cd[int(ev['userid'])].intrest('bomb_explode', 'the bomb exploding')

def hostage_rescued(ev):
	bank.cd[int(ev['userid'])].intrest('hostage_rescue', 'rescuing a hostage')

def round_start(ev):
	global round_ended
	round_ended = False
	for a in playerlib.getUseridList('#human'):
		bank.cd[a].pd['withdraws'] = 0
		bank.cd[a].pd['loans'] = account_types[bank.cd[a].pd['type']]['max_loans']

def player_team(ev):
	if not int(ev['userid']) in bank.cd:
		return

	if int(sv('bbank_max_team_changes_per_round')):
		if not first_round:
			if not ((ev['team'] in ['2', '3'] and ev['oldteam'] in ['2', '3'])):
				bank.cd[int(ev['userid'])].team_change()

### Classes ###

event_funcs = {}

class eventHandler(object):
	def __init__(self):
		self.events = ['player_' + x for x in ['activate', 'spawn', 'team', 'death']] + ['bomb_defused', 'bomb_planted', 'bomb_exploded', 'hostage_rescued']
		self.bbank = self.getModule()
		for event in self.events:
			es.addons.unregisterForEvent(self.bbank, event)
			es.addons.registerForEvent(self.bbank, event, self.__getattr__(event))
			event_funcs[event] = globals()[event]

	class fireEvent(object):
		def __init__(self, name):
			self.name = name

		def __call__(self, ev):
			if ev['es_steamid'] == 'BOT':
				return
			event_funcs[self.name](ev)

	def __getattr__(self, name):
		return self.fireEvent(name)

	def getModule(self):
		for module in es.addons.EventListeners['player_spawn']:
			if hasattr(module, '_HASH'):
				if getattr(module, '_HASH') == '29fbb03bc27275e40bbee95a9435c842c4ec7859e09500006ae45291':
					return module

	def unregisterEvents(self):
		for event in self.events:
			es.addons.unregisterForEvent(self.bbank, event)

class PlayersBank(object):
	def __init__(self, steamid, values={}):
		self.userid = es.getuserid(steamid)
		self.steamid = steamid
		self.pd = values
		self.tell_format = str(sv('bbank_tell_format'))
		self.p = playerlib.getPlayer(self.userid)
		self.lang = self.p.get('lang')

		self.check_keys()

	def check_keys(self):
		keys = {
			'cash': int(sv('bbank_start_cash')), 
			'name': es.getplayername(self.userid), 
			'withdraws': 0,
			'abalance': 0,
			'intrest': 0,
			'type': 'Default',
			'loans': account_types['Default']['max_loans'],
			'loan_amount': 0,
			'Sounds': int(sv('bbank_enable_sounds')),
			'team changes': 0,
			'streak': 0,
			'appear in top': True,
		}

		if not self.pd:
			es.tell(self.userid, '#multi', text('create', {'tell_format': self.tell_format}, self.lang))

		for key in keys:
			if not key in self.pd:
				self.pd[key] = keys[key]

	def deposit(self, amount):
		amount = abs(int(amount))
		tokens = {'tell_format': self.tell_format, 'amount': amount, 'balance': self.pd['cash']}

		if not enabled:
			es.tell(self.userid, '#multi', text('disabled', tokens, self.lang))
			return

		if round_ended and not map_ended:
			es.tell(self.userid, '#multi', '%sWHAT NAO!?'%self.tell_format)
			return

		if self.p.get('cash') < amount:
			amount = self.p.get('cash')
			self.deposit(amount)
			return

		if self.pd['loan_amount']:
			amount = min(self.pd['loan_amount'], amount)
			es.cexec(self.userid, 'repay %s'%amount)
			return

		if self.pd['cash'] + amount > account_types[self.pd['type']]['max_balance'] and not account_types[self.pd['type']]['max_balance'] == 0:
			es.tell(self.userid, '#multi', text('max balance', tokens, self.lang))
			return
		amount = amount if self.pd['cash'] + amount <= account_types[self.pd['type']]['max_balance'] or account_types[self.pd['type']]['max_balance'] == 0 else account_types[self.pd['type']]['max_balance'] - self.pd['cash']

		self.pd['cash'] += amount
		tokens['balance'] = self.pd['cash']
		self.p.set('cash', self.p.get('cash') - amount)
		es.tell(self.userid, '#multi', text('deposit', tokens, self.lang))

		if self.pd['Sounds']:
			es.cexec(self.userid, 'play bbank/deposit')

	def transfer(self, target_userid, target_steamid, amount):
		amount = int(abs(amount))
		tokens = {'tell_format': self.tell_format, 'player': es.getplayername(target_userid), 'amount': amount, 'giver': es.getplayername(self.userid), 'target': es.getplayername(target_userid)}

		if target_steamid == 'BOT':
			return

		if amount <= 0 or amount > self.pd['cash']:
			return

		if bank.cd[target_userid].pd['cash'] + amount > account_types[bank.cd[target_userid].pd['type']]['max_balance']:
			es.tell(self.userid, '#multi', text('transfer max balance', tokens, self.lang))
			return

		self.pd['cash'] -= amount
		bank.cd[target_userid].pd['cash'] += amount

		es.tell(target_userid, '#multi', text('transfer recieve', tokens, playerlib.getPlayer(target_userid).get('lang')))
		es.tell(self.userid, '#multi', text('transfer send', tokens, self.lang))

	def withdraw(self, amount):
		tokens = {'tell_format': self.tell_format, 'amount': amount, 'rounds': int(sv('bbank_round_until_withdraw')) - first_round}

		if self.pd['cash'] < amount:
			amount = self.pd['cash']
			self.withdraw(amount)
			return

		if first_round < int(sv('bbank_round_until_withdraw')) and int(sv('bbank_round_until_withdraw')):
			es.tell(self.userid, '#multi', text('first round withdraw', tokens, self.lang))
			return

		if self.pd['withdraws'] >= account_types[self.pd['type']]['max_withdraws'] and account_types[self.pd['type']]['max_withdraws']:
			es.tell(self.userid, '#multi', text('no withdraws', tokens, self.lang))
			return

		if self.p.get('cash') + amount > 16000:
			es.tell(self.userid, '#multi', text('cant withdraw', tokens, self.lang))
			return

		self.pd['cash'] -= amount
		self.p.set('cash', self.p.get('cash') + amount)
		self.pd['withdraws'] += 1
		tokens['balance'] = self.pd['cash']
		es.tell(self.userid, '#multi', text('withdraw', tokens, self.lang))

		if self.pd['Sounds']:
			es.cexec(self.userid, 'play bbank/withdraw')

	def intrest(self, event, message):
		amount = int(self.pd['cash'] * (intrest_rates[event] * account_types[self.pd['type']]['intrest_multiplier'] * (self.pd['streak'] if event == 'streak' else 1)))
		tokens = {'tell_format': self.tell_format, 'amount': amount, 'reason': message}

		if not 'intrest' in self.pd:
			return

		if amount > account_types[self.pd['type']]['max_intrest_per_event']:
			return

		if self.pd['cash'] + amount > account_types[self.pd['type']]['intrest_cap']:
			return

		self.pd['cash'] += amount
		if self.pd['cash'] * (intrest_rates[event] * account_types[self.pd['type']]['intrest_multiplier']) <= 5:
			return

		if not int(sv('bbank_tell_every_intrest')):
			self.pd['intrest'] += amount
			return

		if message and amount >= int(sv('bbank_min_intrest_tell')):
			es.tell(self.userid, '#multi', text('intrest', tokens, self.lang))

	def abalance(self):
		if self.pd['abalance']:
			if first_round >= int(sv('bbank_round_until_withdraw')) or not int(sv('bbank_round_until_withdraw')):
				if self.p.get('cash') > self.pd['abalance']:
					self.deposit(self.p.get('cash') - self.pd['abalance'])
				elif self.p.get('cash') < self.pd['abalance']:
					self.withdraw(self.pd['abalance'] - self.p.get('cash'))

	def loan(self, amount):
		tokens = {'tell_format': self.tell_format, 'amount': amount, 'loan': self.pd['loan_amount'], 'rounds': int(sv('bbank_round_until_withdraw')) - first_round}

		if first_round < int(sv('bbank_round_until_withdraw')) and int(sv('bbank_round_until_withdraw')):
			es.tell(self.userid, '#multi', text('first round withdraw', tokens, self.lang))
			return

		if not self.pd['loans']:
			es.tell(self.userid, '#multi', text('max loan', tokens, self.lang))
			return

		if self.pd['loan_amount'] > account_types[self.pd['type']]['max_loan_total_amount']:
			tokens['amount'] = account_types[self.pd['type']]['max_loan_total_amount']
			es.tell(self.userid, '#multi', text('cant loan', tokens, self.lang))
			return

		if amount <= 0:
			es.tell(self.userid, '#multi', text('invalid loan value', tokens, self.lang))
			return

		if self.p.get('cash') + amount > 16000:
			es.tell(self.userid, '#multi', text('too much money', tokens, self.lang))
			return

		self.pd['loan_amount'] += amount
		self.pd['loans'] -= 1
		es.tell(self.userid, '#multi', text('loan', tokens, self.lang))
		self.p.set('cash', self.p.get('cash') + amount)

	def loan_intrest(self):
		if self.pd['loan_amount']:
			if self.pd['loan_amount'] <= account_types[self.pd['type']]['loan_intrest_cap']:
				self.pd['loan_amount'] += int(self.pd['loan_amount'] * (account_types[self.pd['type']]['loan_intrest_percent'] / 100.0))
				es.tell(self.userid, '#multi', text('loan intrest', {'tell_format': self.tell_format, 'amount': self.pd['loan_amount'] * (account_types[self.pd['type']]['loan_intrest_percent'] / 100.0)}, self.lang))

	def repay(self, amount):
		amount = min(self.pd['loan_amount'], self.p.get('cash'))
		tokens = {'tell_format': self.tell_format, 'amount': amount, 'loan': self.pd['loan_amount'] - amount}

		if self.pd['loan_amount'] - amount < 0:
			amount = self.pd['loan_amount']
			self.repay(amount)
			return

		if amount <= 0:
			es.tell(self.userid, '#multi', text('invalid loan value', tokens, self.lang))
			return

		if self.p.get('cash') - amount < 0:
			amount = self.p.get('cash')
			self.repay(amount)
			return

		self.pd['loan_amount'] -= amount
		es.tell(self.userid, '#multi', text('loan payback', tokens, self.lang))
		self.p.set('cash', self.p.get('cash') - amount)

	def toggleAppear(self):
		self.pd['appear in top'] = False if self.pd['appear in top'] else True
		es.tell(self.userid, '#multi', text('appear in topd', {'tell_format': self.tell_format, 'value': 'now' if self.pd['appear in top'] else 'not'}, self.lang))

	def team_change(self):
		self.pd['team changes'] += 1
		if self.pd['team changes'] > int(sv('bbank_max_team_changes_per_round')):
			self.pd['cash'] -= int(sv('bbank_team_change_penalty'))
			es.tell(self.userid, '#multi', text('team change penalty', {'tell_format': self.tell_format, 'penalty': int(sv('bbank_team_change_penalty'))}, self.lang))

class Bank(object):
	def __init__(self):
		self.cd = {}
		self.pd = {}
		self.rounds = 0
		self.tell_format = str(sv('bbank_tell_format'))

		player_db = es.getAddonPath('bbank') + '/player_info.db'
		if os.path.isfile(player_db):
			players_cash = open(player_db)
			self.pd = cPickle.load(players_cash)
			players_cash.close()

		for userid in playerlib.getUseridList('#human'):
			self.add(userid)

	def add(self, userid):
		steamid = es.getplayersteamid(userid)
		if not steamid == 'BOT':
			values = {}
			if steamid in self.pd:
				values = self.pd[steamid]
			self.cd[userid] = PlayersBank(steamid, values)

	def update(self):
		for pb in self.cd:
			self.pd[self.cd[pb].steamid] = self.cd[pb].pd

	def save_data(self, force=False):
		if es.getuserid() or force:
			self.rounds += 1
			if self.rounds > 1 or force:
				self.update()
				self.rounds = 0

				player_db = open(es.getAddonPath('bbank') + '/player_info.db', 'w')
				cPickle.dump(self.pd, player_db)
				player_db.close()

	def issueCommand(self, userid, amount, amount_eq, argc, func, menu):
		if argc >= 2:
			if not amount.isdigit() and not amount == 'all':
				es.tell(userid, '#multi', text('non integer', {'tell_format': self.tell_format}, self.cd[userid].lang))
				return

			amount = amount_eq(amount)
			func(amount)
			return

		if menu_check(userid):
			popuplib.send(menu, userid)

### Commands ###

def showmenu():
	userid = es.getcmduserid()
	if menu_check(userid):
		popuplib.send('BBank', userid)

def deposit():
	userid = es.getcmduserid()
	bank.issueCommand(userid, es.getargv(1).lower().split('.')[0], lambda x: bank.cd[userid].p.get('cash') if x == 'all' else x, es.getargc(), bank.cd[userid].deposit, 'Deposit')

def withdraw():
	userid = es.getcmduserid()
	bank.issueCommand(userid, es.getargv(1).lower().split('.')[0], lambda x: abs(int(x)) if x.isdigit() else (16000 - bank.cd[userid].p.get('cash')), es.getargc(), bank.cd[userid].withdraw, 'Withdraw')

def loan():
	userid = es.getcmduserid()
	bank.issueCommand(userid, es.getargv(1).lower().split('.')[0], lambda x: abs(int(x)) if x.isdigit() else (16000 - bank.cd[userid].p.get('cash')), es.getargc(), bank.cd[userid].loan, 'Loan')

def repay():
	userid = es.getcmduserid()
	bank.issueCommand(userid, es.getargv(1).lower().split('.')[0], lambda x: abs(int(x)) if x.isdigit() else bank.cd[userid].p.get('cash'), es.getargc(), bank.cd[userid].repay, 'Repay')

def admin():
	userid = es.getcmduserid()
	if not is_authed(userid):
		es.tell(userid, '#multi', text('not authorized', {'tell_format': bank.tell_format}, bank.cd[userid].lang))
		return

	if menu_check(userid):
		popuplib.send('Admin Menu', userid)

def givecash():
	userid = es.getcmduserid()
	amount = int(es.getargv(1))
	tokens = {'tell_format': bank.tell_format, 'amount': amount}
	cd = bank.cd[userid]

	if not is_authed(userid):
		es.tell(userid, '#multi', text('not authorized', tokens, cd.lang))
		return

	if not 'target' in bank.cd[userid].pd:
		es.tell(userid, '#multi', text('select a target', tokens, cd.lang))
		return
	target = cd.pd['target']

	if bank.cd[target].pd['cash'] + amount < 0:
		es.tell(userid, '#multi', text('cant take cash', tokens, cd.lang))
		return

	bank.cd[target].pd['cash'] += amount
	es.tell(target, '#multi', text(('give cash' if amount > 0 else 'take cash'), tokens, bank.cd[target].lang))
	del cd.pd['target']

def transfer():
	userid = es.getcmduserid()
	es.tell(userid, '#multi', '#lightgreen[BBank]: #defaultGive/Transfer temporarily disabled until exploit fixed')
	return

	target = es.getuserid(es.getargv(1))
	amount = es.getargv(2).lower()
	tokens = {'tell_format': bank.tell_format, 'amount': amount}
	cd = bank.cd[userid]

	if not amount == 'all' and not amount.split('.')[0].isdigit():
		es.tell(userid, '#multi', text('invalid amount', tokens, cd.lang))
		return

	amount = cd.pd['cash'] if amount == 'all' else int(amount.split('.')[0])
	if not target:
		es.tell(userid, '#multi', text('invalid player', tokens, cd.lang))
		return
	cd.transfer(target, bank.cd[target].p.get('steamid'), amount)

def abalance():
	userid = es.getcmduserid()
	amount = int(es.getargv(1))
	tokens = {'tell_format': bank.tell_format, 'amount': amount}

	if amount < 0 or amount > 16000:
		es.tell(userid, '#multi', text('invalid abalance', tokens, bank.cd[userid].lang))
		return

	bank.cd[userid].pd['abalance'] = amount
	es.tell(userid, '#multi', text('abalance', tokens, bank.cd[userid].lang))

def manage():
	userid = es.getcmduserid()
	tokens = {'tell_format': bank.tell_format}

	if not is_authed(userid):
		es.tell(userid, '#multi', text('not authorized', tokens, bank.cd[userid].lang))
		return

	if not es.getargs():
		es.tell(userid, '#multi', text('not enough args', tokens, bank.cd[userid].lang))
		return

	args = es.getargs()
	admininfo = popuplib.easymenu('Manage Players Accounts', '_popup_choice', admininfo_select)

	for steamid in bank.pd:
		if args == steamid or args.lower() in bank.pd[steamid]['name'].lower():
			admininfo.addoption(steamid, bank.pd[steamid]['name'])
	popuplib.send('Manage Players Accounts', userid)

def offlinecash():
	userid = es.getcmduserid()
	tokens = {'tell_format': bank.tell_format, 'amount': es.getargs().split(' ')[0]}

	if not es.getargs() or not es.getargs().split(' ')[0].isdigit():
		es.tell(userid, '#multi', text('invalid amount', tokens, bank.cd[userid].lang))
		return
	amount = int(es.getargs().split(' ')[0])

	if not 'target' in bank.cd[userid].pd:
		es.tell(userid, '#multi', text('select a target', tokens, cd.lang))
		return
	target = cd.pd['target']
	tokens['steamid'] = target

	if not is_authed(userid):
		es.tell(userid, '#multi', text('not authorized', tokens, bank.cd[userid].lang))
		return

	bank.pd[target]['cash'] += amount
	es.tell(userid, '#multi', text('admin give offline cash', tokens, bank.cd[userid].lang))

### Menus ###

def main_menu_select(userid, choice, popupid):
	if choice == 'Transfer':
		transfermenu = popuplib.easymenu('Transfer', '_popup_choice', transfer_select)
		for userid2 in playerlib.getUseridList('#human'):
			transfermenu.addoption(userid2, playerlib.getPlayer(userid2).attributes['name'])

	elif choice == 'Show Balance':
		es.tell(userid, '#multi', text('querry balance', {'tell_format': bank.tell_format, 'amount': bank.cd[userid].pd['cash'], 'loan': bank.cd[userid].pd['loan_amount']}, bank.cd[userid].lang))

	elif choice == 'Top':
		t___t = int(sv('bbank_players_in_top'))
		top = popuplib.easymenu('Top', '_popup_choice', top_select)
		b = {}
		bank.update()

		for l in bank.pd:
			b[l] = bank.pd[l]['cash']

		d = sorted(b.iteritems(), key=lambda (k, v): (v, k), reverse=True)
		for e in d:
			if 'appear in top' in bank.pd[e[0]]:
				if not bank.pd[e[0]]['appear in top']:
					continue

			t___t -= 1
			if t___t >= 0:
				top.addoption(e[0], '%s: %s'%(bank.pd[e[0]]['name'], bank.pd[e[0]]['cash']))

	elif choice == 'Player Info':
		playerinfo = popuplib.easymenu('Player Info', '_popup_choice', pinfo_select)
		for userid2 in playerlib.getUseridList('#human'):
			playerinfo.addoption(userid2, bank.cd[userid2].p.get('name'))

	if menu_check(userid) and not choice == 'Show Balance':
		popuplib.send(choice, userid)

def deposit_select(userid, choice, popupid):
	bank.cd[userid].deposit(bank.cd[userid].p.get('cash') if choice == 'all' else choice)

def withdraw_select(userid, choice, popupid):
	bank.cd[userid].withdraw((16000 - bank.cd[userid].p.get('cash')) if choice == 'all' else choice)

def loan_select(userid, choice, popupid):
	if menu_check(userid):
		popuplib.send(choice, userid)

def loan_money(userid, choice, popupid):
	es.cexec(userid, 'loan %s'%choice)

def repay_money(userid, choice, popupid):
	es.cexec(userid, 'repay %s'%choice)

def transfer_select(userid, choice, popupid):
	transfermenu2 = popuplib.easymenu('Transfer Amount', '_popup_choice', transfer_select2)
	for a in ('all', 1000, 2000, 4000, 8000, 16000, 20000, 40000):
		transfermenu2.addoption((choice, a), a)

	if menu_check(userid):
		popuplib.send('Transfer Amount', userid)

def transfer_select2(userid, choice, popupid):
	target_steamid = es.getplayersteamid(choice[0])

	steamid = playerlib.getPlayer(userid).get('steamid')
	amount = bank.cd[userid].pd['cash'] if choice[1] == 'all' else choice[1]

	if bank.cd[userid].pd['cash'] >= amount:
		bank.cd[userid].transfer(choice[0], es.getplayersteamid(choice[0]), amount)
		return

	es.tell(userid, '#multi', text('cant transfer', {'tell_format': bank.tell_format, 'amount': amount}, bank.cd[userid].lang))

def top_select(userid, choice, popupid):
	es.tell(userid, '#multi', '%sSteamID - %s Cash - %s, Last Known Name - %s'%(bank.tell_format, choice, bank.pd[choice]['cash'], bank.pd[choice]['name']))

def admin_select(userid, choice, popupid):
	if choice == 'Give/Take Cash':
		admintake = popuplib.easymenu('Give/Take Cash', '_popup_choice', admingive_select)
		for userid2 in playerlib.getUseridList('#human'):
			admintake.addoption(userid2, playerlib.getPlayer(userid2).attributes['name'])

		if menu_check(userid):
			popuplib.send('Give/Take Cash', userid)

	elif choice == 'Reset':
		if menu_check(userid):
			popuplib.send('Are You Sure?', userid)

	elif choice == 'Change Player Accounts':
		accounttype = popuplib.easymenu('Change Account Types', '_popup_choice', account_type_select)
		for userid2 in playerlib.getUseridList('#human'):
			accounttype.addoption(userid2, playerlib.getPlayer(userid2).attributes['name'])

		if menu_check(userid):
			popuplib.send('Change Account Types', userid)

def admingive_select(userid, choice, popupid):
	es.escinputbox(30, userid, '|-BBank Give/Take Cash-|', 'Please Input a value to Give/Take', 'cash')
	bank.cd[userid].pd['target'] = choice
	es.tell(userid, '#multi', text('input value', {'tell_format': bank.tell_format}, bank.cd[userid].lang))

def pinfo_select(userid, choice, popupid):
	player_info = popuplib.easymenu('Players Info', '_popup_choice', pinfo_select)
	player_info.addoption(choice, 'Steamid: %s'%bank.cd[choice].steamid)
	player_info.addoption(choice, 'Cash: %s'%bank.cd[choice].pd['cash'])
	player_info.addoption(choice, 'Name: %s'%bank.cd[choice].pd['name'])
	popuplib.send('Players Info', userid)

def confirm_reset(userid, choice, popupid):
	if choice == 'Yes':
		bank.pd.clear()
		return
	es.tell(userid, '#multi', text('reseting anyways', {'tell_format': bank.tell_format}, bank.cd[userid].lang))

def settings_select(userid, choice, popupid):
	tokens = {'tell_format': bank.tell_format, 'toggle': ('off' if bank.cd[userid].pd['Sounds'] else 'on')}
	if choice == 'Auto Balance':
		es.escinputbox(30, userid, '|-BBank Auto Balance-|', 'Please Input a value to auto have', 'abalance')
		es.tell(userid, '#multi', text('input abalance amount', tokens, bank.cd[userid].lang))

	elif choice == 'Reset Account':
		if menu_check(userid):
			popuplib.send('Reset Account?', userid)

	elif choice == 'Sounds':
		if not int(sv('bbank_enable_sounds')):
			es.tell(userid, '#multi', text('sound off', tokens, bank.cd[userid].lang))
			return

		bank.cd[userid].pd['Sounds'] = 0 if bank.cd[userid].pd['Sounds'] else 1
		es.tell(userid, '#multi', text('sound toggle', tokens, bank.cd[userid].lang))

	elif choice == 'Upgrade Account':
		order = sorted(account_types, key=lambda x: account_types[x]['max_balance'])
		if order[-1] == bank.cd[userid].pd['type']:
			es.tell(userid, '#multi', text('already highest account', tokens, bank.cd[userid].lang))
			return

		if menu_check(userid):
			confirm_upgrade = popuplib.easymenu('Confirm Upgrade', '_popup_choice', confirm_upgrade_select)
			confirm_upgrade.settitle('Upgrade to ' + order[order.index(bank.cd[userid].pd['type']) + 1])
			confirm_upgrade.addoption('Yes', 'Yes')
			confirm_upgrade.addoption('No', 'No')
			popuplib.send('Confirm Upgrade', userid)

	elif choice == 'Appear in Top':
		bank.cd[userid].toggleAppear()

def confirm_upgrade_select(userid, choice, popupid):
	if choice == 'No':
		return

	order = sorted(account_types, key=lambda x: account_types[x]['max_balance'])
	pd = bank.cd[userid].pd
	newacc = order[order.index(pd['type']) + 1]
	tokens = {'tell_format': bank.tell_format, 'amount': account_types[newacc]['upgrade_cost'], 'type': newacc}

	if pd['cash'] < account_types[newacc]['upgrade_cost']:
		es.tell(userid, '#multi', text('not enough to upgrade', tokens, bank.cd[userid].lang))
		return

	pd['type'] = newacc
	pd['cash'] -= account_types[newacc]['upgrade_cost']
	es.tell(userid, '#multi', text('upgraded account', tokens, bank.cd[userid].lang))

def confirm_reset_2(userid, choice, popupid):
	if choice == 'Yes':
		bank.cd[userid].pd['cash'] = 0

def account_type_select(userid, choice, popupid):
	accounttypemenu2 = popuplib.easymenu('Choose New Account', '_popup_choice', account_type_select2)
	for a in account_types:
		accounttypemenu2.addoption([choice, a], a)

	if menu_check(userid):
		popuplib.send('Choose New Account', userid)

def account_type_select2(userid, choice, popupid):
	tokens = {'tell_format': bank.tell_format, 'type': choice[1]}

	steamid = bank.cd[userid].steamid
	target_steamid = es.getplayersteamid(choice[0])
	type = choice[1]

	if not es.exists('userid', choice[0]):
		es.tell(userid, '#multi', text('player no exist', tokens, bank.cd[userid].lang))
		return
	tokens['target'] = es.getplayername(choice[0])

	bank.cd[choice[0]].pd['type'] = choice[1]
	es.tell(userid, '#multi', text('admin change account', tokens, bank.cd[userid].lang))
	es.tell(choice[0], '#multi', text('change account', tokens, bank.cd[choice[0]].lang))

def admininfo_select(userid, choice, popupid):
	select_option = popuplib.easymenu('Select Action', '_popup_choice', admin_option_select)
	select_option.addoption(['Reset Account', choice], 'Reset Account')
	select_option.addoption(['Give/Take Cash', choice], 'Give/Take Cash')
	select_option.addoption(['Show Balance', choice], 'Show Balance')
	select_option.addoption(['Show Account Type', choice], 'Show Account Type')
	popuplib.send('Select Action', userid)

def admin_option_select(userid, choice, popupid):
	tokens = {'tell_format': bank.tell_format, 'player': bank.pd[choice[1]]['name'], 'amount': bank.pd[choice[1]]['cash'], 'type': bank.pd[choice[1]]['type']}

	if choice[0] == 'Reset Account':
		es.tell(userid, '#multi', text('account deleted', tokens, bank.cd[userid].lang))
		for key in ['cash', 'withdraws', 'abalance', 'intrest', 'loan_amount', 'team changes', 'streak']:
			bank.cd[userid].pd[key] = 0

	elif choice[0] == 'Give/Take Cash':
		bank.cd[userid].pd['target'] = choice[1]
		es.tell(userid, '#multi', text('input value', tokens, bank.cd[userid].lang))
		es.escinputbox(30, userid, '|-BBank Give/Take-|', 'Please Input a value to Give/Take', 'offlinecash')

	elif choice[0] == 'Show Balance':
		es.tell(userid, '#multi', text('admin show balance', tokens, bank.cd[userid].lang))

	elif choice[0] == 'Show Account Type':
		es.tell(userid, '#multi', text('admin show account type', tokens, bank.cd[userid].lang))

players_cash = {}

### Misc Functions ###

def menu_check(userid):
	if popuplib.active(userid)['count'] <= int(sv('bbank_max_menus')):
		return True
	es.tell(userid, '#multi', '%s Maximum Popups Exceeded, server crashing nub'%str(sv('bbank_tell_format')))

def check_loop():
	gamethread.delayedname(1, 'check loop', check_loop)
	if int(sv('bbank_auto_deposit_on_disconnect')):
		for userid in playerlib.getUseridList('#human'):
			players_cash[userid] = es.getplayerprop(userid, 'CCSPlayer.m_iAccount')

		for userid in players_cash.keys():
			if not es.exists('userid', userid) and userid in bank.cd:
				bank.cd[userid].pd['cash'] += players_cash[userid]
				del bank.cd[userid]
				del players_cash[userid]

def saveLoop():
	gamethread.delayedname(int(sv('bbank_save_every')), 'save loop', saveLoop)
	bank.save_data()

def is_authed(userid):
	if isAuthed(userid) or es.getplayersteamid(userid) in str(sv('bbank_admins')).replace(' ', '') or (es.getplayersteamid(userid) in return_admins() and 'mani_admins' in str(sv('bbank_admins'))):
		return True
	es.tell(userid, '#green', 'You are not authorized to run the command badmin!')

def return_admins():
	if os.path.isfile(es.getAddonPath('bbank').replace('addons/eventscripts/bbank', 'cfg/mani_admin_plugin/clients.txt')):
		admins = []
		a = open(es.getAddonPath('bbank').replace('addons/eventscripts/bbank', 'cfg/mani_admin_plugin/clients.txt'), 'r')
		b = a.readlines()
		a.close()
		c = []

		for a in b:
			a = a.replace('\t', '').replace(' ', '')
			if not a.startswith('//'):
				c.append(a)

		for a in c:
			if a.lower().startswith('"steam""steam_0:'):
				admins.append(a.lower().replace('"steam""', '').replace('"', '').replace('\n', '').upper())

		return admins

def setup_auth(): # Thanks, SD
	global isAuthed
	isAuthed = lambda x: False
	if services.isRegistered('auth'):
		auth_service = services.use('auth')
		auth_service.registerCapability('bbank_admin', auth_service.ADMIN)
		isAuthed = lambda x: auth_service.isUseridAuthorized(x, 'bbank_admin')
setup_auth()

load2()
bank = Bank()
