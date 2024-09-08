#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zm_transit_distance_tracking;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	replacefunc( getfunction( "maps/mp/zm_transit_distance_tracking", "delete_zombie_noone_looking" ), ::delete_zombie_noone_looking_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_screecher", "zombie_pathing_home" ), ::zombie_pathing_home_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_screecher", "screecher_runaway" ), ::screecher_runaway_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_screecher", "screecher_distance_tracking" ), ::screecher_distance_tracking_override );
}

delete_zombie_noone_looking_override( how_close )
{
	self endon( "death" );

	if ( !isdefined( how_close ) )
		how_close = 1000;

	distance_squared_check = how_close * how_close;
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

		if ( distancesquared( self.origin, players[i].origin ) < distance_squared_check )
			self.player_close++;
	}

	wait 0.1;

	if ( self.inview == 0 && self.player_close == 0 )
	{
		if ( !isdefined( self.animname ) || isdefined( self.animname ) && self.animname != "zombie" )
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
		self dodamage( self.health + 666, self.origin );
		recalc_zombie_array();
	}
}

zombie_pathing_home_override()
{
	self endon( "death" );
	self endon( "zombie_acquire_enemy" );
	level endon( "intermission" );
	self setgoalpos( self.startinglocation );
	self waittill( "goal" );
	playfx( level._effect["screecher_spawn_b"], self.origin, ( 0, 0, 1 ) );
	self.no_powerups = 1;
	self setfreecameralockonallowed( 0 );
	self animscripted( self.origin, self.angles, "zm_burrow" );
	self playsound( "zmb_screecher_dig" );
	maps\mp\animscripts\zm_shared::donotetracks( "burrow_anim" );
	self dodamage( self.health + 666, self.origin );
}

screecher_runaway_override()
{
	self endon( "death" );
/#
	screecher_print( "runaway" );
#/
	self notify( "stop_find_flesh" );
	self notify( "zombie_acquire_enemy" );
	self notify( "runaway" );
	self.state = "runaway";
	self.ignoreall = 1;
	self setgoalpos( self.startinglocation );
	self waittill( "goal" );
	playfx( level._effect["screecher_spawn_b"], self.origin, ( 0, 0, 1 ) );
	self.no_powerups = 1;
	self setfreecameralockonallowed( 0 );
	self animscripted( self.origin, self.angles, "zm_burrow" );
	self playsound( "zmb_screecher_dig" );
	maps\mp\animscripts\zm_shared::donotetracks( "burrow_anim" );
	self dodamage( self.health + 666, self.origin );
}

screecher_distance_tracking_override()
{
	self endon( "death" );

	while ( true )
	{
		can_delete = 1;
		players = get_players();

		foreach ( player in players )
		{
			if ( player.sessionstate == "spectator" )
				continue;

			dist_sq = distancesquared( self.origin, player.origin );

			if ( dist_sq >= 4000000 )
				continue;

			can_see = player maps\mp\zombies\_zm_utility::is_player_looking_at( self.origin, 0.9, 0 );

			if ( can_see || dist_sq < 1000000 )
			{
				can_delete = 0;
				break;
			}
		}

		if ( can_delete )
		{
			self notify( "zombie_delete" );

			if ( isdefined( self.anchor ) )
				self.anchor delete();

			self dodamage( self.health + 666, self.origin );
		}

		wait 0.1;
	}
}

getwatcherforweapon( weapname )
{
	if ( !isdefined( self ) )
		return undefined;

	if ( !isplayer( self ) )
		return undefined;

	return _weaponobjects::getweaponobjectwatcherbyweapon( weapname );
}