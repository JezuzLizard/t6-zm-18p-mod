#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zm_buried_distance_tracking;

#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );

main()
{
	replacefunc( getfunction( "maps/mp/zombies/_zm_weap_time_bomb", "_restore_player_perks_and_weapons" ), ::_restore_player_perks_and_weapons_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_weap_time_bomb", "restore_player_to_initial_loadout" ), ::restore_player_to_initial_loadout_override );
	replacefunc( getfunction( "maps/mp/zombies/_zm_weap_time_bomb", "get_player_perk_list" ), ::get_player_perk_list_override );
	replacefunc( getfunction( "maps/mp/_zm_weap_time_bomb", "_time_bomb_save_internal" ), ::_time_bomb_save_internal_override );
	replacefunc( getfunction( "maps/mp/zm_buried_classic", "give_player_minigame_loadout" ), ::give_player_minigame_loadout_override );
}

_restore_player_perks_and_weapons_override( s_temp )
{
	if ( isdefined( s_temp.is_spectator ) && s_temp.is_spectator )
		self restore_player_to_initial_loadout_override( s_temp );
	else if ( isdefined( s_temp.is_last_stand ) && s_temp.is_last_stand )
	{
		self.stored_weapon_info = s_temp.stored_weapon_info;
		assert( isdefined( level.zombie_last_stand_ammo_return ), "time bomb attempting to give player back weapons taken by last stand, but level.zombie_last_stand_ammo_return is undefined!" );
		self [[ level.zombie_last_stand_ammo_return ]]();
	}
	else
	{
		a_current_perks = self get_player_perk_list_override();

	// don't use notifies to remove a perk from a player
	if ( isdefined( self.perks_active ) )
	{
		foreach ( perk in a_current_perks )
		{
			if ( !isdefined( self.perks_active[ perk ] ) )
			{
				continue;
			}

			self.perks_active[ perk ] = true;
		}
	}

		wait_network_frame();

		if ( get_players().size == 1 )
		{
			if ( isinarray( s_temp.perks_all, "specialty_quickrevive" ) && isdefined( level.solo_lives_given ) && level.solo_lives_given > 0 && level.solo_lives_given < 3 && isdefined( self.lives ) && self.lives == 1 )
				level.solo_lives_given--;
		}

		if ( isdefined( s_temp.perks_active ) )
		{
			for ( i = 0; i < s_temp.perks_active.size; i++ )
			{
				if ( get_players().size == 1 && s_temp.perks_active[i] == "specialty_quickrevive" )
				{
					if ( isdefined( level.solo_lives_given ) && level.solo_lives_given == 3 && isdefined( self.lives ) && self.lives == 0 )
						continue;
				}

				self maps\mp\zombies\_zm_perks::give_perk( s_temp.perks_active[i] );
				wait_network_frame();

				if ( isdefined( s_temp.perks_disabled ) && isdefined( s_temp.perks_disabled[s_temp.perks_active[i]] ) && s_temp.perks_disabled[s_temp.perks_active[i]] )
				{
					self maps\mp\zombies\_zm_perks::perk_pause( s_temp.perks_active[i] );
					wait_network_frame();
				}
			}
		}

		self.disabled_perks = s_temp.perks_disabled;
		self.num_perks = s_temp.perk_count;
		self.lives = s_temp.lives_remaining;
		self takeallweapons();
		self set_player_melee_weapon( level.zombie_melee_weapon_player_init );

		for ( i = 0; i < s_temp.weapons.array.size; i++ )
		{
			str_weapon_temp = s_temp.weapons.array[i];
			n_ammo_reserve = s_temp.weapons.ammo_reserve[i];
			n_ammo_clip = s_temp.weapons.ammo_clip[i];
			n_type = s_temp.weapons.type[i];

			if ( !is_temporary_zombie_weapon( str_weapon_temp ) && str_weapon_temp != "time_bomb_zm" )
			{
				if ( isdefined( level.zombie_weapons[str_weapon_temp] ) && isdefined( level.zombie_weapons[str_weapon_temp].vox ) )
					self maps\mp\zombies\_zm_weapons::weapon_give( str_weapon_temp, issubstr( str_weapon_temp, "upgrade" ) );
				else
					self giveweapon( str_weapon_temp, 0, self maps\mp\zombies\_zm_weapons::get_pack_a_punch_weapon_options( str_weapon_temp ) );

				if ( n_type == 1 )
					self setweaponammofuel( str_weapon_temp, n_ammo_clip );
				else if ( n_type == 2 )
					self setweaponoverheating( 0, n_ammo_clip, str_weapon_temp );
				else if ( isdefined( n_ammo_clip ) )
					self setweaponammoclip( str_weapon_temp, n_ammo_clip );

				self setweaponammostock( str_weapon_temp, n_ammo_reserve );
			}
		}

		if ( s_temp.weapons.primary == "none" || s_temp.weapons.primary == "time_bomb_zm" )
		{
			for ( i = 0; i < s_temp.weapons.array.size; i++ )
			{
				str_weapon_type = weapontype( s_temp.weapons.array[i] );

				if ( !is_player_equipment( str_weapon_type ) && str_weapon_type == "bullet" || str_weapon_type == "projectile" )
				{
					str_weapon_temp = s_temp.weapons.array[i];
					break;
				}
			}

			self switchtoweapon( str_weapon_temp );
		}
		else
			self switchtoweapon( s_temp.weapons.primary );

		self maps\mp\zombies\_zm_equipment::equipment_take( self.current_equipment );

		if ( isdefined( self.deployed_equipment ) && isinarray( self.deployed_equipment, s_temp.current_equipment ) )
			self maps\mp\zombies\_zm_equipment::equipment_take( s_temp.current_equipment );

		if ( isdefined( s_temp.current_equipment ) )
		{
			self.do_not_display_equipment_pickup_hint = 1;
			self maps\mp\zombies\_zm_equipment::equipment_give( s_temp.current_equipment );
			self.do_not_display_equipment_pickup_hint = undefined;
		}

		if ( isinarray( s_temp.weapons.array, "time_bomb_zm" ) )
		{
			wait_network_frame();
			self.time_bomb_detonator_only = 1;
			self swap_weapon_to_detonator();
		}
	}

	self ent_flag_set( "time_bomb_restore_thread_done" );
}

get_player_perk_list_override()
{
	a_perks = [];

	if ( isdefined( self.disabled_perks ) && isarray( self.disabled_perks ) )
	{
		a_keys = getarraykeys( self.disabled_perks );

		for ( i = 0; i < a_keys.size; i++ )
		{
			if ( self.disabled_perks[a_keys[i]] )
				a_perks[a_perks.size] = a_keys[i];
		}
	}

	if ( isdefined( self.perks_active ) )
	{
		active_perks = getarraykeys( self.perks_active );

		if ( isdefined( active_perks ) && isarray( active_perks ) )
			a_perks = arraycombine( active_perks, a_perks, 0, 0 );
	}

	return a_perks;
}

restore_player_to_initial_loadout_override( s_temp )
{
	self takeallweapons();
	assert( isdefined( level.start_weapon ), "time bomb attempting to restore a spectator, but level.start_weapon isn't defined!" );
	self maps\mp\zombies\_zm_weapons::weapon_give( level.start_weapon );
	assert( isdefined( level.zombie_lethal_grenade_player_init ), "time bomb attempting to restore a spectator, but level.zombie_lethal_grenade_player_init isn't defined!" );
	self set_player_lethal_grenade( level.zombie_lethal_grenade_player_init );
	self giveweapon( level.zombie_lethal_grenade_player_init );
	self setweaponammoclip( level.zombie_lethal_grenade_player_init, 2 );
	assert( isdefined( level.zombie_melee_weapon_player_init ), "time bomb attempting to restore a spectator, but level.zombie_melee_weapon_player_init isn't defined!" );
	self giveweapon( level.zombie_melee_weapon_player_init );
	a_current_perks = self get_player_perk_list_override();

	// don't use notifies to remove a perk from a player
	if ( isdefined( self.perks_active ) )
	{
		foreach ( perk in a_current_perks )
		{
			if ( !isdefined( self.perks_active[ perk ] ) )
			{
				continue;
			}

			self.perks_active[ perk ] = true;
		}
	}

	if ( isdefined( s_temp ) && s_temp.points_current < 1500 && self.score < 1500 && level.round_number > 6 || self.score < 1500 && level.round_number > 6 )
		self.score = 1500;
}

give_player_minigame_loadout_override()
{
	self.dontspeak = 1;
	self takeallweapons();
	self maps\mp\zombies\_zm_weapons::weapon_give( "ak74u_zm", 0 );
	self give_start_weapon( 0 );
	self giveweapon( "knife_zm" );

	if ( self hasweapon( self get_player_lethal_grenade() ) )
		self getweaponammoclip( self get_player_lethal_grenade() );
	else
		self giveweapon( self get_player_lethal_grenade() );

	self setweaponammoclip( self get_player_lethal_grenade(), 2 );
	a_current_perks = self getperks();

	// don't use notifies to remove a perk from a player
	if ( isdefined( self.perks_active ) )
	{
		foreach ( perk in a_current_perks )
		{
			if ( !isdefined( self.perks_active[ perk ] ) )
			{
				continue;
			}

			self.perks_active[ perk ] = true;
		}
	}

	self.dontspeak = undefined;
}

_time_bomb_save_internal_override( save_struct )
{
	if ( !isdefined( save_struct ) && !isdefined( self.time_bomb_save_data ) )
		self.time_bomb_save_data = spawnstruct();

	if ( !self ent_flag_exist( "time_bomb_restore_thread_done" ) )
		self ent_flag_init( "time_bomb_restore_thread_done" );

	self ent_flag_clear( "time_bomb_restore_thread_done" );
	s_temp = spawnstruct();
	s_temp.weapons = spawnstruct();

	if ( isdefined( save_struct ) )
		s_temp.n_time_id = save_struct.n_time_id;
	else
		s_temp.n_time_id = level.time_bomb_save_data.n_time_id;

	s_temp.player_origin = self.origin;
	s_temp.player_angles = self getplayerangles();
	s_temp.player_stance = self getstance();
	s_temp.is_last_stand = self maps\mp\zombies\_zm_laststand::player_is_in_laststand();
	s_temp.stored_weapon_info = self.stored_weapon_info;
	s_temp.is_spectator = self is_spectator();
	s_temp.weapons.array = self getweaponslist();
	s_temp.weapons.ammo_reserve = [];
	s_temp.weapons.ammo_clip = [];
	s_temp.weapons.type = [];
	s_temp.weapons.primary = self getcurrentweapon();

	if ( s_temp.weapons.primary == "none" || s_temp.weapons.primary == "time_bomb_zm" )
		self thread _save_time_bomb_weapon_after_switch( save_struct );

	for ( i = 0; i < s_temp.weapons.array.size; i++ )
	{
		str_weapon_temp = s_temp.weapons.array[i];
		s_temp.weapons.ammo_reserve[i] = self getweaponammostock( str_weapon_temp );

		if ( weaponfuellife( str_weapon_temp ) > 0 )
		{
			n_ammo_amount = self getweaponammofuel( str_weapon_temp );
			n_type = 1;
		}
		else if ( self isweaponoverheating( 1, str_weapon_temp ) > 0 )
		{
			n_ammo_amount = self isweaponoverheating( 1, str_weapon_temp );
			n_type = 2;
		}
		else
		{
			n_ammo_amount = self getweaponammoclip( str_weapon_temp );
			n_type = 0;
		}

		s_temp.weapons.type[i] = n_type;
		s_temp.weapons.ammo_clip[i] = n_ammo_amount;
	}

	s_temp.current_equipment = self.current_equipment;
	s_temp.perks_all = self get_player_perk_list();
	s_temp.perks_disabled = self.disabled_perks;
	s_temp.perk_count = self.num_perks;
	s_temp.lives_remaining = self.lives;

	if ( isdefined( self.perks_active ) )
		s_temp.perks_active = getarraykeys( self.perks_active );

	s_temp.points_current = self.score;

	if ( is_weapon_locker_available_in_game() )
		s_temp.weapon_locker_data = self maps\mp\zombies\_zm_weapon_locker::wl_get_stored_weapondata();

	s_temp.account_value = self.account_value;
	s_temp.save_ready = 1;

	if ( isdefined( save_struct ) )
		save_struct.player_saves[self getentitynumber()] = s_temp;
	else
		self.time_bomb_save_data = s_temp;
}