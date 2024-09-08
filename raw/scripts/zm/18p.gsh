#define _weaponobjects maps\mp\gametypes_zm\_weaponobjects

#define SAFE_REPLACEFUNC( file, func_str, to ) \
	func = getfunction( file, func_str ); \
	if ( func ) \
		replacefunc( func, to );
