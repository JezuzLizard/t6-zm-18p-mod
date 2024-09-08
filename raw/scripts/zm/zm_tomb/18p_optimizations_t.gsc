#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zm_tomb_distance_tracking;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	replacefunc( getfunction( "maps/mp/zm_tomb_capture_zones", "delete_zombie_for_capture_event" ), ::delete_zombie_for_capture_event_override );
	replacefunc( getfunction( "maps/mp/zm_tomb_distance_tracking", "delete_zombie_noone_looking" ), ::delete_zombie_noone_looking_override );
}

delete_zombie_for_capture_event_override()
{
	if ( isdefined( self ) )
	{
		playfx( level._effect["tesla_elec_kill"], self.origin );
		self ghost();
	}

	wait_network_frame();

	if ( isdefined( self ) )
		self dodamage( self.health + 666, self.origin );
}

delete_zombie_noone_looking_override( how_close, how_high )
{
	self endon( "death" );

	if ( !isdefined( how_close ) )
		how_close = 1500;

	if ( !isdefined( how_high ) )
		how_high = 600;

	distance_squared_check = how_close * how_close;
	too_far_dist = distance_squared_check * 3;

	if ( isdefined( level.zombie_tracking_too_far_dist ) )
		too_far_dist = level.zombie_tracking_too_far_dist * level.zombie_tracking_too_far_dist;

	self.inview = 0;
	self.player_close = 0;
	n_distance_squared = 0;
	n_height_difference = 0;
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

		n_modifier = 1.0;

		if ( isdefined( players[i].b_in_tunnels ) && players[i].b_in_tunnels )
			n_modifier = 2.25;

		n_distance_squared = distancesquared( self.origin, players[i].origin );
		n_height_difference = abs( self.origin[2] - players[i].origin[2] );

		if ( n_distance_squared < distance_squared_check * n_modifier && n_height_difference < how_high )
			self.player_close++;
	}

	if ( self.inview == 0 && self.player_close == 0 )
	{
		if ( !isdefined( self.animname ) || self.animname != "zombie" && self.animname != "mechz_zombie" )
			return;

		if ( isdefined( self.electrified ) && self.electrified == 1 )
			return;

		if ( isdefined( self.in_the_ground ) && self.in_the_ground == 1 )
			return;

		zombies = getaiarray( "axis" );

		if ( ( !isdefined( self.damagemod ) || self.damagemod == "MOD_UNKNOWN" ) && self.health < self.maxhealth )
		{
			if ( !( isdefined( self.exclude_distance_cleanup_adding_to_total ) && self.exclude_distance_cleanup_adding_to_total ) && !( isdefined( self.isscreecher ) && self.isscreecher ) )
			{
				level.zombie_total++;
				level.zombie_respawned_health[level.zombie_respawned_health.size] = self.health;
			}
		}
		else if ( zombies.size + level.zombie_total > 24 || zombies.size + level.zombie_total <= 24 && self.health >= self.maxhealth )
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

		if ( isdefined( self.is_mechz ) && self.is_mechz )
		{
			self notify( "mechz_cleanup" );
			level.mechz_left_to_spawn++;
			wait_network_frame();
			level notify( "spawn_mechz" );
		}

		self delete();
		recalc_zombie_array();
	}
}