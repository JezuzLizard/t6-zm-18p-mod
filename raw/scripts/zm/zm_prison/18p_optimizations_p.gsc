#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zm_alcatraz_distance_tracking;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	replacefunc( getfunction( "maps/mp/zombies/_zm_afterlife", "afterlife_zapped" ), ::afterlife_zapped_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_brutus", "brutus_cleanup_at_end_of_grief_round" ), ::brutus_cleanup_at_end_of_grief_round_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_brutus", "brutus_stuck_teleport" ), ::brutus_stuck_teleport_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_ai_brutus", "brutus_afterlife_teleport" ), ::brutus_afterlife_teleport_override );
	replacefunc( getfunction( "maps/mp/zm_alcatraz_distance_tracking", "delete_zombie_noone_looking" ), ::delete_zombie_noone_looking_override );
}

afterlife_zapped_override()
{
	self endon( "death" );
	self endon( "zapped" );

	if ( self.ai_state == "find_flesh" )
	{
		self.zapped = 1;
		n_ideal_dist_sq = 490000;
		n_min_dist_sq = 10000;
		a_nodes = getanynodearray( self.origin, 1200 );
		a_nodes = arraycombine( a_nodes, getanynodearray( self.origin + vectorscale( ( 0, 0, 1 ), 120.0 ), 1200 ), 0, 0 );
		a_nodes = arraycombine( a_nodes, getanynodearray( self.origin - vectorscale( ( 0, 0, 1 ), 120.0 ), 1200 ), 0, 0 );
		a_nodes = array_randomize( a_nodes );
		nd_target = undefined;

		for ( i = 0; i < a_nodes.size; i++ )
		{
			if ( distance2dsquared( a_nodes[i].origin, self.origin ) > n_ideal_dist_sq )
			{
				if ( a_nodes[i] is_valid_teleport_node() )
				{
					nd_target = a_nodes[i];
					break;
				}
			}
		}

		if ( !isdefined( nd_target ) )
		{
			for ( i = 0; i < a_nodes.size; i++ )
			{
				if ( distance2dsquared( a_nodes[i].origin, self.origin ) > n_min_dist_sq )
				{
					if ( a_nodes[i] is_valid_teleport_node() )
					{
						nd_target = a_nodes[i];
						break;
					}
				}
			}
		}

		if ( isdefined( nd_target ) )
		{
			v_fx_offset = vectorscale( ( 0, 0, 1 ), 40.0 );
			playfx( level._effect["afterlife_teleport"], self.origin );
			playsoundatposition( "zmb_afterlife_zombie_warp_out", self.origin );
			self hide();
			linker = spawn( "script_model", self.origin + v_fx_offset );
			linker setmodel( "tag_origin" );
			playfxontag( level._effect["teleport_ball"], linker, "tag_origin" );
			linker thread linker_delete_watch( self );
			self linkto( linker );
			linker moveto( nd_target.origin + v_fx_offset, 1 );
			linker waittill( "movedone" );
			linker delete();
			playfx( level._effect["afterlife_teleport"], self.origin );
			playsoundatposition( "zmb_afterlife_zombie_warp_in", self.origin );
			self show();
		}
		else
		{
/#
			iprintln( "Could not teleport" );
#/
			playfx( level._effect["afterlife_teleport"], self.origin );
			playsoundatposition( "zmb_afterlife_zombie_warp_out", self.origin );
			level.zombie_total++;
			self dodamage( self.health + 666, self.origin );
			return;
		}

		self.zapped = undefined;
		self.ignoreall = 1;
		self notify( "stop_find_flesh" );
		self thread maps\mp\zombies\_zm_afterlife::afterlife_zapped_fx();

		for ( i = 0; i < 3; i++ )
		{
			self animscripted( self.origin, self.angles, "zm_afterlife_stun" );
			self maps\mp\animscripts\shared::donotetracks( "stunned" );
		}

		self.ignoreall = 0;
		self thread maps\mp\zombies\_zm_ai_basic::find_flesh();
	}
}

brutus_cleanup_at_end_of_grief_round_override()
{
	self endon( "death" );
	self endon( "brutus_cleanup" );
	level waittill_any( "keep_griefing", "game_module_ended" );
	self delete();
	self notify( "brutus_cleanup" );
}

brutus_stuck_teleport_override()
{
	self endon( "death" );
	align_struct = spawn( "script_model", self.origin );
	align_struct.angles = self.angles;
	align_struct setmodel( "tag_origin" );

	if ( !level.brutus_in_grief && ( self istouching( level.e_gondola.t_ride ) || isdefined( self.force_gondola_teleport ) && self.force_gondola_teleport ) )
	{
		self.force_gondola_teleport = 0;
		align_struct linkto( level.e_gondola );
		self linkto( align_struct );
	}

	self.not_interruptable = 1;
	playfxontag( level._effect["brutus_spawn"], align_struct, "tag_origin" );
	self animscripted( self.origin, self.angles, "zm_taunt" );
	self maps\mp\animscripts\zm_shared::donotetracks( "taunt_anim" );
	self.not_interruptable = 0;
	self ghost();
	self notify( "brutus_cleanup" );
	self notify( "brutus_teleporting" );

	if ( isdefined( align_struct ) )
		align_struct delete();

	if ( isdefined( self.sndbrutusmusicent ) )
	{
		self.sndbrutusmusicent delete();
		self.sndbrutusmusicent = undefined;
	}

	if ( isdefined( level.brutus_respawn_after_despawn ) && level.brutus_respawn_after_despawn )
	{
		b_no_current_valid_targets = are_all_targets_invalid();
		level thread respawn_brutus( self.health, self.has_helmet, self.helmet_hits, self.explosive_dmg_taken, self.force_zone, b_no_current_valid_targets );
	}

	level.brutus_count--;
	self dodamage( self.health + 666, self.origin );
}

brutus_afterlife_teleport_override()
{
	playfx( level._effect["afterlife_teleport"], self.origin );
	self hide();
	wait 0.1;
	self notify( "brutus_cleanup" );

	if ( isdefined( self.sndbrutusmusicent ) )
	{
		self.sndbrutusmusicent delete();
		self.sndbrutusmusicent = undefined;
	}

	level thread respawn_brutus( self.health, self.has_helmet, self.helmet_hits, self.explosive_dmg_taken, self.force_zone );
	level.brutus_count--;
	self dodamage( self.health + 666, self.origin );
}

delete_zombie_noone_looking_override( how_close, how_high )
{
	self endon( "death" );

	if ( !isdefined( how_close ) )
		how_close = 1500;

	if ( !isdefined( how_high ) )
		how_close = 600;

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
	}
}