#include maps\mp\gametypes_zm\_globallogic_score;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	if ( getdvarint( "sv_maxclients" ) <= 8 )
	{
		return;
	}

	// don't allocate stats to pers, unless they get read
	SAFE_REPLACEFUNC( "maps/mp/gametypes_zm/_globallogic_score", "getpersstat", ::getpersstat_override );
	SAFE_REPLACEFUNC( "maps/mp/gametypes_zm/_globallogic_score", "initpersstat", ::initpersstat_override );
	SAFE_REPLACEFUNC( "maps/mp/gametypes_zm/_globallogic_score", "incpersstat", ::incpersstat_override );
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_stats", "update_global_counters_on_match_end", ::noop );

	// don't allocate to an unused array
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_weapons", "include_zombie_weapon", ::include_zombie_weapon_override );

	// don't allocate createfx since csc does it anyway
	SAFE_REPLACEFUNC( "maps/mp/createfx/" + getdvar( "mapname" ) + "_fx", "main", ::noop );

	// investigate weaponobjectwaters if necessary

	// don't allocate unused hudelems
	SAFE_REPLACEFUNC( "maps/mp/gametypes_zm/_hud_message", "onplayerconnect", ::noop );

	// reduce average variables allocated by manually freeing str_team before calling the builtin if it wasn't needed
	SAFE_REPLACEFUNC( "common_scripts/utility", "get_players", ::get_players_override );

	// fix bots not spawning as spectators when hotjoining
	//SAFE_REPLACEFUNC( "maps/mp/gametypes_zm/_zm_gametype", "hide_gump_loading_for_hotjoiners", ::hide_gump_loading_for_hotjoiners_override );

	// fix revive trigger leaks
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_laststand", "revive_trigger_spawn", ::revive_trigger_spawn_override );

	// fix massive waste of variables
	// each perk a buy has at once spawns like 20 child variables
	// 18 players with each 9 perks on Origins is probably enough to fill the variable limit by itself
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_perks", "give_perk", ::give_perk_override );
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_pers_upgrades_functions", "pers_upgrade_perk_lose_save", ::pers_upgrade_perk_lose_save_override );
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_perks", "lose_random_perk", ::lose_random_perk_override );

	// fix minor variable leak due to not using the correct free function for the variable allocator
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_powerups", "full_ammo_move_hud", ::full_ammo_move_hud_override );

	// use dodamage instead of delete for actors(not corpses, corpses are fine to delete)
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_ai_faller", "zombie_faller_delete", ::zombie_faller_delete_override );
	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_ai_faller", "zombie_faller_delete", ::zombie_faller_delete_override );

	SAFE_REPLACEFUNC( "maps/mp/zombies/_zm_utility", "track_players_intersection_tracker", ::track_players_intersection_tracker_override );

	SAFE_REPLACEFUNC( "maps/mp/" + getdvar( "mapname" ) + "_achievement", "init", ::noop );

	level thread on_player_connect();
}

init()
{
	wait 5;
	level.onplayerdisconnect_original = level.onplayerdisconnect;
	level.onplayerdisconnect = ::onplayerdisconnect;
}

onplayerdisconnect()
{
	// fix revive trigger ent leak
	if ( isdefined( self.revivetrigger ) )
	{
		self.revivetrigger delete();
	}

	// fix ent leak on Tranzit
	if ( isdefined( self.jetsound_ent ) )
	{
		self.jetsound_ent delete();
	}
	self [[ level.onplayerdisconnect_original ]]();
}

noop()
{

}

sq_give_player_all_perks()
{
	machines = getentarray( "zombie_vending", "targetname" );
	perks = [];

	for ( i = 0; i < machines.size; i++ )
	{
		if ( machines[i].script_noteworthy == "specialty_weapupgrade" )
			continue;

		perks[perks.size] = machines[i].script_noteworthy;
	}

	foreach ( perk in perks )
	{
		if ( isdefined( self.perk_purchased ) && self.perk_purchased == perk )
			continue;

		if ( self hasperk( perk ) || self maps\mp\zombies\_zm_perks::has_perk_paused( perk ) )
			continue;

		self maps\mp\zombies\_zm_perks::give_perk( perk, 0 );
		wait 0.25;
	}

	//self._retain_perks = 1;
	//self thread watch_for_respawn();
}

watch_for_respawn()
{
	self endon( "disconnect" );
	self waittill_either( "spawned_player", "player_revived" );
	wait_network_frame();
	self sq_give_player_all_perks();
	self setmaxhealth( level.zombie_vars["zombie_perk_juggernaut_health"] );
}

on_player_connect()
{
	first = true;
	for ( ;; )
	{
		level waittill( "connected", player );

		// delete unneeded variables/entities when the first player connects
		if ( first )
		{
			//arrayRemoveValue( level.createfxexploders, undefined );
			// sp does this, but mp/zm don't???
			level.struct = undefined;
			first = false;
		}

		player thread onplayerspawned();

		player.yuge_array = [];
		player.yuge_array[ 65535 ] = true;
	}
}

onplayerspawned()
{
	for ( ;; )
	{
		self waittill( "spawned_player" );
		wait 10;
		if ( self.sessionstate == "spectator" )
		{
			continue;
		}
		self sq_give_player_all_perks();
	}
}

initpersstat_override( dataname, record_stats, init_to_stat_value )
{
	// if ( !isdefined( self.pers[dataname] ) )
	// 	self.pers[dataname] = 0;

	if ( !isdefined( record_stats ) || record_stats == 1 )
		recordplayerstats( self, dataname, int( self.pers[dataname] ) );

	if ( isdefined( init_to_stat_value ) && init_to_stat_value == 1 )
		self.pers[dataname] = self getdstat( "PlayerStatsList", dataname, "StatValue" );
}

getpersstat_override( dataname )
{
	if ( !isdefined( self.pers[ dataname ] ) )
	{
		self.pers[ dataname ] = 0;
	}
	return self.pers[dataname];
}

incpersstat_override( dataname, increment, record_stats, includegametype )
{
	pixbeginevent( "incPersStat" );
	if ( !isdefined( self.pers[ dataname ] ) )
	{
		self.pers[ dataname ] = 0;
	}
	self.pers[dataname] = self.pers[dataname] + increment;

	if ( isdefined( includegametype ) && includegametype )
		self addplayerstatwithgametype( dataname, increment );
	else
		self addplayerstat( dataname, increment );

	if ( !isdefined( record_stats ) || record_stats == 1 )
		self thread threadedrecordplayerstats( dataname );

	pixendevent();
}

include_zombie_weapon_override( weapon_name, in_box, collector, weighting_func )
{
	if ( !isdefined( level.zombie_include_weapons ) )
		level.zombie_include_weapons = [];

	if ( !isdefined( in_box ) )
		in_box = 1;

/#
	println( "ZM >> Including weapon - " + weapon_name );
#/
	level.zombie_include_weapons[weapon_name] = in_box;
	precacheitem( weapon_name );

	// don't allocate these as they are unused
	// if ( !isdefined( weighting_func ) )
	// 	level.weapon_weighting_funcs[weapon_name] = ::default_weighting_func;
	// else
	// 	level.weapon_weighting_funcs[weapon_name] = weighting_func;
}

get_players_override( str_team )
{
	if ( isdefined( str_team ) )
	{
		return getplayers( str_team );
	}

	str_team = undefined;
	return getplayers();
}

hide_gump_loading_for_hotjoiners_override()
{
	self endon( "disconnect" );
	self.rebuild_barrier_reward = 1;
	self.is_hotjoining = 1;
	num = self getsnapshotackindex();

	while ( ( num == self getsnapshotackindex() ) && !self istestclient() )
		wait 0.25;

	wait 0.5;
	self maps\mp\zombies\_zm::spawnspectator();
	self.is_hotjoining = 0;
	self.is_hotjoin = 1;

	if ( is_true( level.intermission ) || is_true( level.host_ended_game ) )
	{
		setclientsysstate( "levelNotify", "zi", self );
		self setclientthirdperson( 0 );
		self resetfov();
		self.health = 100;
		self thread [[ level.custom_intermission ]]();
	}
}

revive_trigger_spawn_override()
{
	// idk if this happens but they should've checked for it
	if ( isdefined( self.revivetrigger ) )
	{
		self.revivetrigger delete();
	}
	if ( isdefined( level.revive_trigger_spawn_override_link ) )
		[[ level.revive_trigger_spawn_override_link ]]( self );
	else
	{
		radius = getdvarint( #"revive_trigger_radius" );
		self.revivetrigger = spawn( "trigger_radius", ( 0, 0, 0 ), 0, radius, radius );
		self.revivetrigger sethintstring( "" );
		self.revivetrigger setcursorhint( "HINT_NOICON" );
		self.revivetrigger setmovingplatformenabled( 1 );
		self.revivetrigger enablelinkto();
		self.revivetrigger.origin = self.origin;
		self.revivetrigger linkto( self );
		self.revivetrigger.beingrevived = 0;
		self.revivetrigger.createtime = gettime();
	}

	self thread revive_trigger_think();
}

revive_trigger_think()
{
	self endon( "disconnect" );
	self endon( "zombified" );
	self endon( "stop_revive_trigger" );

	while ( true )
	{
		wait 0.1;
		self.revivetrigger sethintstring( "" );
		players = get_players();

		for ( i = 0; i < players.size; i++ )
		{
			d = 0;
			d = self depthinwater();

			if ( players[i] can_revive( self ) || d > 20 )
			{
				self.revivetrigger setrevivehintstring( &"ZOMBIE_BUTTON_TO_REVIVE_PLAYER", self.team );
				break;
			}
		}

		for ( i = 0; i < players.size; i++ )
		{
			reviver = players[i];

			if ( self == reviver || !reviver is_reviving( self ) )
				continue;

			gun = reviver getcurrentweapon();
			assert( isdefined( gun ) );

			if ( gun == level.revive_tool )
				continue;

			reviver giveweapon( level.revive_tool );
			reviver switchtoweapon( level.revive_tool );
			reviver setweaponammostock( level.revive_tool, 1 );
			revive_success = reviver revive_do_revive( self, gun );
			reviver revive_give_back_weapons( gun );

			if ( isplayer( self ) )
				self allowjump( 1 );

			self.laststand = undefined;

			if ( revive_success )
			{
				if ( isplayer( self ) )
					maps\mp\zombies\_zm_chugabud::player_revived_cleanup_chugabud_corpse();

				self thread revive_success( reviver );
				self cleanup_suicide_hud();
				return;
			}
		}
	}
}

remote_revive_watch()
{
	self endon( "disconnect" );
	self endon( "zombified" );
	self endon( "player_revived" );
	keep_checking = 1;

	while ( keep_checking )
	{
		self waittill( "remote_revive", reviver );

		if ( reviver.team == self.team )
			keep_checking = 0;
	}

	self maps\mp\zombies\_zm_laststand::remote_revive( reviver );
}

give_perk_override( perk, bought )
{
	self setperk( perk );
	self.num_perks++;

	if ( isdefined( bought ) && bought )
	{
		self maps\mp\zombies\_zm_audio::playerexert( "burp" );

		if ( isdefined( level.remove_perk_vo_delay ) && level.remove_perk_vo_delay )
			self maps\mp\zombies\_zm_audio::perk_vox( perk );
		else
			self delay_thread( 1.5, maps\mp\zombies\_zm_audio::perk_vox, perk );

		self setblur( 4, 0.1 );
		wait 0.1;
		self setblur( 0, 0.1 );
		self notify( "perk_bought", perk );
	}

	self maps\mp\zombies\_zm_perks::perk_set_max_health_if_jugg( perk, 1, 0 );

	if ( !( isdefined( level.disable_deadshot_clientfield ) && level.disable_deadshot_clientfield ) )
	{
		if ( perk == "specialty_deadshot" )
			self setclientfieldtoplayer( "deadshot_perk", 1 );
		else if ( perk == "specialty_deadshot_upgrade" )
			self setclientfieldtoplayer( "deadshot_perk", 1 );
	}

	if ( perk == "specialty_scavenger" )
		self.hasperkspecialtytombstone = 1;

	players = get_players();

	if ( maps\mp\zombies\_zm_perks::use_solo_revive() && perk == "specialty_quickrevive" )
	{
		self.lives = 1;

		if ( !isdefined( level.solo_lives_given ) )
			level.solo_lives_given = 0;

		if ( isdefined( level.solo_game_free_player_quickrevive ) )
			level.solo_game_free_player_quickrevive = undefined;
		else
			level.solo_lives_given++;

		if ( level.solo_lives_given >= 3 )
			flag_set( "solo_revive" );

		self thread solo_revive_buy_trigger_move( perk );
	}

	if ( perk == "specialty_finalstand" )
	{
		self.lives = 1;
		self.hasperkspecialtychugabud = 1;
		self notify( "perk_chugabud_activated" );
	}

	if ( isdefined( level._custom_perks[perk] ) && isdefined( level._custom_perks[perk].player_thread_give ) )
		self thread [[ level._custom_perks[perk].player_thread_give ]]();

	self set_perk_clientfield( perk, 1 );
	maps\mp\_demo::bookmark( "zm_player_perk", gettime(), self );
	self maps\mp\zombies\_zm_stats::increment_client_stat( "perks_drank" );
	self maps\mp\zombies\_zm_stats::increment_client_stat( perk + "_drank" );
	self maps\mp\zombies\_zm_stats::increment_player_stat( perk + "_drank" );
	self maps\mp\zombies\_zm_stats::increment_player_stat( "perks_drank" );

	// unbounded array that is only used for a single achievement on Tranzit
	// if ( !isdefined( self.perk_history ) )
	// 	self.perk_history = [];
	// self.perk_history = add_to_array( self.perk_history, perk, 0 );

	if ( !isdefined( self.perks_active ) )
		self.perks_active = [];

	self.perks_active[perk] = false;
	self notify( "perk_acquired" );
	self thread perk_think_override();
}

perk_think_override()
{
	if ( !isdefined( self.perk_think_thread_spawned ) )
	{
		self.perk_think_thread_spawned = true;
	}
	else
	{
		return;
	}

	self endon( "disconnect" );
/#
	if ( getdvarint( #"zombie_cheat" ) >= 5 )
	{
		if ( isdefined( self.perk_hud[perk] ) )
			return;
	}
#/

	for ( ;; )
	{
		wait 0.05;
		waittillframeend;

		if ( !isdefined( self.perks_active ) || self.perks_active.size <= 0 )
		{
			continue;
		}

		perk_keys = getarraykeys( self.perks_active );
		foreach ( key in perk_keys )
		{
			script_taken = self.perks_active[ key ];
			if ( key == "specialty_scavenger" )
			{
				script_taken = !isdefined( self.hasperkspecialtytombstone );
			}

			if ( self.name == "JezuzLizard" )
			{
				iprintln( "perk: " + key + " |valid:" + is_player_valid( self ) + " |script_taken: " + script_taken );
			}
			if ( is_player_valid( self ) && !script_taken )
			{
				continue;
			}

			do_retain = true;
			if ( maps\mp\zombies\_zm_perks::use_solo_revive() && key == "specialty_quickrevive" )
				do_retain = false;

			if ( do_retain )
			{
				if ( isdefined( self._retain_perks ) && self._retain_perks )
					continue;
				else if ( isdefined( self._retain_perks_array ) && ( isdefined( self._retain_perks_array[ key ] ) && self._retain_perks_array[ key ] ) )
					continue;
			}

			self unsetperk( key );
			self.num_perks--;

			switch ( key )
			{
				case "specialty_armorvest":
					self setmaxhealth( 100 );
					break;
				case "specialty_additionalprimaryweapon":
					if ( is_true( script_taken ) )
						self maps\mp\zombies\_zm::take_additionalprimaryweapon();
					break;
				case "specialty_deadshot":
					if ( !( isdefined( level.disable_deadshot_clientfield ) && level.disable_deadshot_clientfield ) )
						self setclientfieldtoplayer( "deadshot_perk", 0 );
					break;
				case "specialty_deadshot_upgrade":
					if ( !( isdefined( level.disable_deadshot_clientfield ) && level.disable_deadshot_clientfield ) )
						self setclientfieldtoplayer( "deadshot_perk", 0 );
					break;
			}

			if ( isdefined( level._custom_perks[ key ] ) && isdefined( level._custom_perks[ key ].player_thread_take ) )
				self thread [[ level._custom_perks[ key ].player_thread_take ]]();

			self set_perk_clientfield( key, 0 );
			self.perk_purchased = undefined;

			if ( isdefined( level.perk_lost_func ) )
				self [[ level.perk_lost_func ]]( key );

			self.perks_active[ key ] = undefined;

			self notify( "perk_lost" );
		}
	}
}

pers_upgrade_perk_lose_save_override()
{
	if ( maps\mp\zombies\_zm_pers_upgrades::is_pers_system_active() )
	{
		if ( isdefined( self.perks_active ) )
		{
			self.a_saved_perks = [];
			keys = getarraykeys( self.perks_active );
			foreach ( perk in keys )
			{
				self.a_saved_perks[ self.a_saved_perks.size ] = perk;
			}
		}
		else
			self.a_saved_perks = self get_perk_array( 0 );

		self.a_saved_primaries = self getweaponslistprimaries();
		self.a_saved_primaries_weapons = [];
		index = 0;

		foreach ( weapon in self.a_saved_primaries )
		{
			self.a_saved_primaries_weapons[index] = maps\mp\zombies\_zm_weapons::get_player_weapondata( self, weapon );
			index++;
		}
	}
}

lose_random_perk_override()
{
	vending_triggers = getentarray( "zombie_vending", "targetname" );
	perks = [];

	for ( i = 0; i < vending_triggers.size; i++ )
	{
		perk = vending_triggers[i].script_noteworthy;

		if ( isdefined( self.perk_purchased ) && self.perk_purchased == perk )
			continue;

		if ( self hasperk( perk ) || self has_perk_paused( perk ) )
			perks[perks.size] = perk;
	}

	if ( perks.size > 0 )
	{
		perks = array_randomize( perks );
		perk = perks[0];
		self.perks_active[ perk ] = true;

		if ( maps\mp\zombies\_zm_perks::use_solo_revive() && perk == "specialty_quickrevive" )
			self.lives--;
	}
}

full_ammo_move_hud_override( player_team )
{
	players = get_players( player_team );
	players[0] playsoundtoteam( "zmb_full_ammo", player_team );
	wait 0.5;
	move_fade_time = 1.5;
	self fadeovertime( move_fade_time );
	self moveovertime( move_fade_time );
	self.y = 270;
	self.alpha = 0;
	wait( move_fade_time );
	self destroyelem();
}

zombie_faller_delete_override()
{
	level.zombie_total++;
	self maps\mp\zombies\_zm_spawner::reset_attack_spot();

	if ( isdefined( self.zombie_faller_location ) )
	{
		self.zombie_faller_location.is_enabled = 1;
		self.zombie_faller_location = undefined;
	}

	self dodamage( self.health + 666, self.origin );
}

track_players_intersection_tracker_override()
{
	return;
}