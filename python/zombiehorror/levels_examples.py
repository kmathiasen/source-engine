# This is an example of how a levels.py would look
# This is if you want to have custom levels with custom models ect
# You can even have multiple boss levels!
# If you want it to be a boss level, change 'boss': 0 to 'boss': 1

attributes = {
	0: {
		'min_health': 100,
		'max_health': 200,
		'health_per_human': 1, # How much extra HP per human zombies will get
		'min_speed': 0.8,
		'max_speed': 1,
		'min_armor': 100,
		'max_armor': 200,
		'min_gravity': 0.8,
		'max_gravity': 1,
		'min_knockback': 2,
		'max_knockback': 5,
		'model': 'player/cow/cow/cow.mdl', # You have to use the exact path after models/
		'chance': 100,
		'boss': 0 # If 1, the zombies will act as bots, and you'll get a bonus for killing them, and it will be considered a boss level
	},
	1: {
		'min_health': 100,
		'max_health': 200,
		'health_per_human': 2,
		'min_speed': 0.8,
		'max_speed': 1,
		'min_armor': 100,
		'max_armor': 200,
		'min_gravity': 0.8,
		'max_gravity': 1,
		'min_knockback': 2,
		'max_knockback': 5,
		'model': 'player/cow/cow/cow.mdl',
		'chance': 50, # There's only a  50% chance that zombies will have these attributes
		'boss': 0
	}
}