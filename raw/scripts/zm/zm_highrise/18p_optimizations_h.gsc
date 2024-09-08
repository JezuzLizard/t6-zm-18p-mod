#include maps\mp\zombies\_zm_ai_leaper;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zm_highrise_distance_tracking;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	// replace delete calls with dodamage
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_leaper", "leaper_traverse_watcher" ), ::leaper_traverse_watcher_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_leaper", "leaper_playable_area_failsafe" ), ::leaper_playable_area_failsafe_override );
	replacefunc( getfunction( "maps/mp/zm_highrise_distance_tracking", "delete_zombie_noone_looking" ), ::delete_zombie_noone_looking_override );
	replacefunc( getfunction( "maps/mp/zm_highrise_elevators", "watch_for_elevator_during_faller_spawn" ), ::watch_for_elevator_during_faller_spawn_override );
	replacefunc( getfunction( "maps/mp/zm_highrise", "elevator_traverse_watcher" ), ::elevator_traverse_watcher_override );
}

leaper_traverse_watcher_override()
{
	self endon( "death" );

	while ( true )
	{
		if ( is_true( self.is_traversing ) )
		{
			self.elevator_parent = undefined;

			if ( is_true( self maps\mp\zm_highrise_elevators::object_is_on_elevator() ) )
			{
				if ( isdefined( self.elevator_parent ) )
				{
					if ( is_true( self.elevator_parent.is_moving ) )
					{
						playfx( level._effect["zomb_gib"], self.origin );
						self leaper_cleanup();
						self dodamage( self.health + 666, self.origin );
						return;
					}
				}
			}
		}

		wait 0.2;
	}
}

leaper_playable_area_failsafe_override()
{
	self endon( "death" );
	self.leaper_failsafe_start_time = gettime();
	playable_area = getentarray( "player_volume", "script_noteworthy" );
	b_outside_playable_space_this_frame = 0;
	self.leaper_outside_playable_space_time = -2;

	while ( true )
	{
		b_outside_playable_last_check = b_outside_playable_space_this_frame;
		b_outside_playable_space_this_frame = is_leaper_outside_playable_space( playable_area );
		n_current_time = gettime();

		if ( b_outside_playable_space_this_frame && !b_outside_playable_last_check )
			self.leaper_outside_playable_space_time = n_current_time;
		else if ( !b_outside_playable_space_this_frame )
			self.leaper_outside_playable_space = -1;

		b_leaper_has_been_alive_long_enough = n_current_time - self.leaper_failsafe_start_time > 3000;
		b_leaper_is_in_scripted_state = self isinscriptedstate();
		b_leaper_has_been_out_of_playable_space_long_enough_to_delete = b_outside_playable_space_this_frame && n_current_time - self.leaper_outside_playable_space_time > 2000;
		b_can_delete = b_leaper_has_been_alive_long_enough && !b_leaper_is_in_scripted_state && b_leaper_has_been_out_of_playable_space_long_enough_to_delete;

		if ( b_can_delete )
		{
			playsoundatposition( "zmb_vocals_leaper_fall", self.origin );
			self leaper_cleanup();
/#
			str_traversal_data = "";

			if ( isdefined( self.traversestartnode ) )
				str_traversal_data = " Last traversal used = " + self.traversestartnode.animscript + " at " + self.traversestartnode.origin;

			iprintln( "leaper at " + self.origin + " with spawn point " + self.spawn_point.origin + " out of play space. DELETING!" + str_traversal_data );
#/
			self dodamage( self.health + 666, self.origin );
			return;
		}

		wait 1;
	}
}

delete_zombie_noone_looking_override( how_close, how_high )
{
	self endon( "death" );

	if ( !isdefined( how_close ) )
		how_close = 1000;

	if ( !isdefined( how_high ) )
		how_high = 500;

	distance_squared_check = how_close * how_close;
	height_squared_check = how_high * how_high;
	too_far_dist = distance_squared_check * 3;

	if ( isdefined( level.zombie_tracking_too_far_dist ) )
		too_far_dist = level.zombie_tracking_too_far_dist * level.zombie_tracking_too_far_dist;

	self.inview = 0;
	self.player_close = 0;
	players = get_players();

	for ( i = 0; i < players.size; i++ )
	{
		if ( players[i].sessionstate == "spectator" )
			continue;

		if ( isdefined( level.only_track_targeted_players ) )
		{
			if ( !isdefined( self.favoriteenemy ) || self.favoriteenemy != players[i] )
				continue;
		}

		can_be_seen = self player_can_see_me( players[i] );

		if ( can_be_seen && distancesquared( self.origin, players[i].origin ) < too_far_dist )
			self.inview++;

		if ( distancesquared( self.origin, players[i].origin ) < distance_squared_check && abs( self.origin[2] - players[i].origin[2] ) < how_high )
			self.player_close++;
	}

	wait 0.1;

	if ( self.inview == 0 && self.player_close == 0 )
	{
		if ( !isdefined( self.animname ) || isdefined( self.animname ) && self.animname != "zombie" )
			return;

		if ( isdefined( self.electrified ) && self.electrified == 1 )
			return;

		zombies = getaiarray( "axis" );

		if ( zombies.size + level.zombie_total > 24 || zombies.size + level.zombie_total <= 24 && self.health >= self.maxhealth )
		{
			if ( !( isdefined( self.exclude_distance_cleanup_adding_to_total ) && self.exclude_distance_cleanup_adding_to_total ) && !( isdefined( self.isscreecher ) && self.isscreecher ) )
			{
				level.zombie_total++;

				if ( self.health < level.zombie_health )
					level.zombie_respawned_health[level.zombie_respawned_health.size] = self.health;
			}
		}

		self maps\mp\zombies\_zm_spawner::reset_attack_spot();
		self notify( "zombie_delete" );
		self dodamage( self.health + 666, self.origin );
	}
}

watch_for_elevator_during_faller_spawn_override()
{
	self endon( "death" );
	self endon( "risen" );
	self endon( "spawn_anim" );

	while ( true )
	{
		should_gib = 0;

		foreach ( elevator in level.elevators )
		{
			if ( self istouching( elevator.body ) )
				should_gib = 1;
		}

		if ( should_gib )
		{
			playfx( level._effect["zomb_gib"], self.origin );

			if ( !( isdefined( self.has_been_damaged_by_player ) && self.has_been_damaged_by_player ) && !( isdefined( self.is_leaper ) && self.is_leaper ) )
				level.zombie_total++;

			if ( isdefined( self.is_leaper ) && self.is_leaper )
			{
				self maps\mp\zombies\_zm_ai_leaper::leaper_cleanup();
			}
			self dodamage( self.health + 100, self.origin );
			break;
		}

		wait 0.1;
	}
}

elevator_traverse_watcher_override()
{
	self endon( "death" );

	while ( true )
	{
		if ( is_true( self.is_traversing ) )
		{
			self.elevator_parent = undefined;

			if ( is_true( self maps\mp\zm_highrise_elevators::object_is_on_elevator() ) )
			{
				if ( isdefined( self.elevator_parent ) )
				{
					if ( is_true( self.elevator_parent.is_moving ) )
					{
						playfx( level._effect["zomb_gib"], self.origin );

						if ( !is_true( self.has_been_damaged_by_player ) )
							level.zombie_total++;

						self dodamage( self.health + 666, self.origin );
						return;
					}
				}
			}
		}

		wait 0.2;
	}
}