#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <JYW>
#include <sdktools_functions>


#define Pai 3.14159265358979323846 

#define PARTICLE_MUZZLE_FLASH		"weapon_muzzle_flash_autoshotgun"
#define PARTICLE_WEAPON_TRACER		"weapon_tracers"
#define PARTICLE_WEAPON_TRACER2		"weapon_tracers_50cal"
#define PARTICLE_BLOOD		"blood_impact_red_01"
#define PARTICLE_BLOOD2		"blood_impact_headshot_01"
#define SOUND_IMPACT1		"physics/flesh/flesh_impact_bullet1.wav"
#define SOUND_IMPACT2		"physics/concrete/concrete_impact_bullet1.wav"
#define SOUND_FIRE		"weapons/50cal/50cal_shoot.wav"  
#define MODEL_GUN "models/w_models/weapons/w_minigun.mdl"
#define EnemyArraySize 300
#define PLUGIN_VERSION "1.0"

static g_flLagMovement = 0;

#define SPAWNTANKCOUNT 1200
int spawntankcountdown = 0;

bool AttackSpeedUp[MAXPLAYERS + 1];
bool InfiniteAmmo[MAXPLAYERS + 1];
bool InfiniteReserveAmmo[MAXPLAYERS + 1];
bool ReloadSpeedUp[MAXPLAYERS + 1];
bool MeleeSpeedUp[MAXPLAYERS + 1];
bool MoveSpeedUp[MAXPLAYERS + 1];
bool IsHeal[MAXPLAYERS + 1];

bool isGameLoading;

new InfectedsArray[EnemyArraySize];
new InfectedCount;

float ScanTime=0.0;

new Gun[100];
new GunOwner[100];
new GunEnemy[100];
float GunFireStopTime[100];
float GunFireTime[100];
float GunFireTotolTime[100];
new GunScanIndex[100];
float LastTime[100]; 
new miniindexs[100];


float FireIntervual=0.08; 
float FireOverHeatTime=10.0;
float FireRange=1000.0;


new bool:isminisentryavailable[MAXPLAYERS + 1];
new bool:l4d2=false;
static Handle:hRoundRespawn = INVALID_HANDLE;
static Handle:hGameConf = INVALID_HANDLE;


ConVar sv_gametypes;
ConVar mp_gamemode;
ConVar sv_hibernate_when_empty;
ConVar sv_force_unreserved;
ConVar sb_all_bot_game;
ConVar allow_all_bot_survivor_team;
ConVar sv_steamgroup_exclusive;
ConVar gamedifficulty;
ConVar z_mob_spawn_finale_size;
ConVar z_health;
ConVar z_hunter_health;
ConVar z_jockey_health;
ConVar tongue_health;
ConVar z_spitter_health;
ConVar z_charger_health;
ConVar survivor_incap_health;
ConVar survivor_ledge_grab_health;
ConVar survivor_limp_health;
ConVar first_aid_kit_use_duration;
ConVar survivor_revive_duration;
ConVar survivor_friendly_fire_factor_normal;
ConVar director_afk_timeout;
ConVar survivor_damage_speed_factor;

ConVar melee_range;


//ConVar g_hCvarGravity;
ConVar common_limit;
ConVar background_limit;
ConVar tankhp;
ConVar special_interval;
ConVar wandering_density
ConVar mob_population_density
ConVar mega_mob_size;
ConVar mob_spawn_min_size;
ConVar mob_spawn_max_size;
ConVar mob_spawn_min_interval_easy;
ConVar mob_spawn_min_interval_expert;
ConVar mob_spawn_min_interval_hard;
ConVar mob_spawn_min_interval_normal;
ConVar mob_spawn_max_interval_easy;
ConVar mob_spawn_max_interval_expert;
ConVar mob_spawn_max_interval_hard;
ConVar mob_spawn_max_interval_normal;


public Plugin:myinfo = 
{
    name = "[L4D] JYW",
    author = "JYW",
    description = "JYW's script",
    version = PLUGIN_VERSION,
    url = ""
}


public OnMapStart()
{
	g_flLagMovement = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
}

public OnPluginStart()
{

	decl String:stGame[32];
	GetGameFolderName(stGame, 32);
	if (StrEqual(stGame, "left4dead2", false)==true ) l4d2=true;
	else if (StrEqual(stGame, "left4dead", false)==true) l4d2=false;

	for(int i = 1 ; i <= MaxClients ; i ++) {
		isminisentryavailable[i] = true;
	}

    //이벤트 훅

    HookEvent("player_team", OnPlayerTeamChange, EventHookMode_Post);

    HookEvent("lunge_pounce", Event_LowHP, EventHookMode_Post);
    HookEvent("charger_pummel_start", Event_LowHP, EventHookMode_Post);
    HookEvent("tongue_grab", Event_LowHP, EventHookMode_Post);
    HookEvent("jockey_ride", Event_LowHP, EventHookMode_Post);
    HookEvent("player_ledge_grab", Event_Suicide, EventHookMode_Post);
    HookEvent("player_incapacitated", Event_Suicide, EventHookMode_Post);
	HookEvent("player_death", Event_Revive, EventHookMode_Post);
	
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("weapon_reload", Event_WeaponReload);

	HookEvent("round_start", Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_RoundEnd);
	HookEvent("mission_lost", Event_RoundEnd);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd);

	HookEvent("player_spawn",  Event_PlayerSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

    //명령어 등록 //타 sp 속 함수를 호출할 때 거기서 커맨드로 만든 후 fakeclientcommand로 입력시켜 실행
    //RegConsoleCmd("sm_speed", Menu_Base_1);
    RegConsoleCmd("sm_start", Menu_Special_1);

    //타이머 등록
    //CreateTimer(300.0, SendMessagesToPlayers, _, TIMER_REPEAT);
    CreateTimer(20.0, checkSpectators, _, TIMER_REPEAT);


	//CreateTimer(30.0, SpawnMob, _, TIMER_REPEAT);
	//CreateTimer(10.0, SpawnTank, _, TIMER_REPEAT);

    //CreateTimer(10.0, resetminisentryavailable, _, TIMER_REPEAT); //악용 & 부하 방지로 해제 250109

    //CreateTimer(5.0, regenreservedammoTimer, _, TIMER_REPEAT);
    //CreateTimer(10.0, CheckHeal, _, TIMER_REPEAT);
    CreateTimer(20.0, ErrorDeadmanCheck, _, TIMER_REPEAT);

	//게임 변수 등록

	sv_gametypes = FindConVar("sv_gametypes");
	sv_gametypes.Flags &= ~FCVAR_NOTIFY;
	mp_gamemode = FindConVar("mp_gamemode");
	mp_gamemode.Flags &= ~FCVAR_NOTIFY;
	sv_hibernate_when_empty = FindConVar("sv_hibernate_when_empty");
	sv_hibernate_when_empty.Flags &= ~FCVAR_NOTIFY;
	sv_force_unreserved = FindConVar("sv_force_unreserved");
	sv_force_unreserved.Flags &= ~FCVAR_NOTIFY;
	sb_all_bot_game = FindConVar("sb_all_bot_game");
	sb_all_bot_game.Flags &= ~FCVAR_NOTIFY;
	allow_all_bot_survivor_team = FindConVar("allow_all_bot_survivor_team");
	allow_all_bot_survivor_team.Flags &= ~FCVAR_NOTIFY;
	sv_steamgroup_exclusive = FindConVar("sv_steamgroup_exclusive");
	sv_steamgroup_exclusive.Flags &= ~FCVAR_NOTIFY;
	gamedifficulty = FindConVar("z_difficulty");
	gamedifficulty.Flags &= ~FCVAR_NOTIFY;

	z_mob_spawn_finale_size = FindConVar("z_mob_spawn_finale_size");
	z_mob_spawn_finale_size.Flags &= ~FCVAR_NOTIFY;
	z_health = FindConVar("z_health");
	z_health.Flags &= ~FCVAR_NOTIFY;
	z_hunter_health = FindConVar("z_hunter_health");
	z_hunter_health.Flags &= ~FCVAR_NOTIFY;
	z_jockey_health = FindConVar("z_jockey_health");
	z_jockey_health.Flags &= ~FCVAR_NOTIFY;
	tongue_health = FindConVar("tongue_health");
	tongue_health.Flags &= ~FCVAR_NOTIFY;
	z_spitter_health = FindConVar("z_spitter_health");
	z_spitter_health.Flags &= ~FCVAR_NOTIFY;
	z_charger_health = FindConVar("z_charger_health");
	z_charger_health.Flags &= ~FCVAR_NOTIFY;

	survivor_incap_health = FindConVar("survivor_incap_health");
	survivor_incap_health.Flags &= ~FCVAR_NOTIFY;
	survivor_ledge_grab_health = FindConVar("survivor_ledge_grab_health");
	survivor_ledge_grab_health.Flags &= ~FCVAR_NOTIFY;
	survivor_limp_health = FindConVar("survivor_limp_health");
	survivor_limp_health.Flags &= ~FCVAR_NOTIFY;

	first_aid_kit_use_duration = FindConVar("first_aid_kit_use_duration");
	first_aid_kit_use_duration.Flags &= ~FCVAR_NOTIFY;
	survivor_revive_duration = FindConVar("survivor_revive_duration");
	survivor_revive_duration.Flags &= ~FCVAR_NOTIFY;

	survivor_friendly_fire_factor_normal = FindConVar("survivor_friendly_fire_factor_normal");
	survivor_friendly_fire_factor_normal.Flags &= ~FCVAR_NOTIFY;
	director_afk_timeout = FindConVar("director_afk_timeout");
	director_afk_timeout.Flags &= ~FCVAR_NOTIFY;
	survivor_damage_speed_factor = FindConVar("survivor_damage_speed_factor");
	survivor_damage_speed_factor.Flags &= ~FCVAR_NOTIFY;
	melee_range = FindConVar("melee_range");
	melee_range.Flags &= ~FCVAR_NOTIFY;


	//g_hCvarGravity = FindConVar("sv_gravity");
	//g_hCvarGravity.Flags &= ~FCVAR_NOTIFY;

	common_limit = FindConVar("z_common_limit");
	common_limit.Flags &= ~FCVAR_NOTIFY;

	background_limit = FindConVar("z_background_limit");
	background_limit.Flags &= ~FCVAR_NOTIFY;

	tankhp = FindConVar("z_tank_health");
	tankhp.Flags &= ~FCVAR_NOTIFY;

	special_interval = FindConVar("z_special_spawn_interval");
	special_interval.Flags &= ~FCVAR_NOTIFY;

	wandering_density = FindConVar("z_wandering_density");
	wandering_density.Flags &= ~FCVAR_NOTIFY;

	mob_population_density = FindConVar("z_mob_population_density");
	mob_population_density.Flags &= ~FCVAR_NOTIFY;

	mega_mob_size = FindConVar("z_mega_mob_size");
	mega_mob_size.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_min_size = FindConVar("z_mob_spawn_min_size");
	mob_spawn_min_size.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_max_size = FindConVar("z_mob_spawn_max_size");
	mob_spawn_max_size.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_min_interval_easy = FindConVar("z_mob_spawn_min_interval_easy");
	mob_spawn_min_interval_easy.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_min_interval_expert = FindConVar("z_mob_spawn_min_interval_expert");
	mob_spawn_min_interval_expert.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_min_interval_hard = FindConVar("z_mob_spawn_min_interval_hard");
	mob_spawn_min_interval_hard.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_min_interval_normal = FindConVar("z_mob_spawn_min_interval_normal");
	mob_spawn_min_interval_normal.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_max_interval_easy = FindConVar("z_mob_spawn_max_interval_easy");
	mob_spawn_max_interval_easy.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_max_interval_expert = FindConVar("z_mob_spawn_max_interval_expert");
	mob_spawn_max_interval_expert.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_max_interval_hard = FindConVar("z_mob_spawn_max_interval_hard");
	mob_spawn_max_interval_hard.Flags &= ~FCVAR_NOTIFY;

	mob_spawn_max_interval_normal = FindConVar("z_mob_spawn_max_interval_normal");
	mob_spawn_max_interval_normal.Flags &= ~FCVAR_NOTIFY;

	//무기 설정
	initializeweapon();

	hGameConf = LoadGameConfigFile("JYW");
    StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
	hRoundRespawn = EndPrepSDKCall();


	//잠시 주석처리
	for(int i = 1 ; i <= MaxClients ; i ++) {
		setAllPlayerData(i, true);
	}

	setdifficulty(); //플러그인 시작 시 실행해야 하는 명령어 존재


}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	isGameLoading = false;
	spawntankcountdown = 0;
	setdifficulty(); //라운드마다 사람 수에 따라 실행해야 하는 명령어 존재
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	isGameLoading = true;
	spawntankcountdown = 0;
}

void OnMapEnd()
{

}

public Action:OnPlayerRunCmd(int client, int &buttons)
{
	if (IsPlayerAlive(client))
	{
		if (buttons & IN_JUMP)
		{
			if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
			{
				if (GetEntityMoveType(client) != MOVETYPE_LADDER)
				{
					buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;
}


public Action:Event_PlayerSpawn(Handle:event, const char[] name, bool dontBroadcast) { //부활 또는 입장 등 태어나면(주의: 일반 좀비 태어나도 발동)
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2){ //일반 유저 다시 태어나면	
		setProfile(client);

		setdifficulty();//입장한 것일 수도 있으니 난이도 조절

	}

}
public Action:Event_WeaponFire(Handle:event, const char[] name, bool dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client <= 0) return;
	new String:weapon[64];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && InfiniteAmmo[client])
	{
		new slot = -1;
		new clipsize = -1;
		if (StrEqual(weapon, "grenade_launcher"))
		{
				slot = 0;
				clipsize = 1;
		}
		else if (StrEqual(weapon, "pumpshotgun") || StrEqual(weapon, "shotgun_chrome"))
		{
				slot = 0;
				clipsize = 8;
		}
		else if (StrEqual(weapon, "autoshotgun") || StrEqual(weapon, "shotgun_spas"))
		{
				slot = 0;
				clipsize = 10;
		}
		else if (StrEqual(weapon, "hunting_rifle"))
		{
				slot = 0;
				clipsize = 15;
		}
		else if ( StrEqual(weapon, "sniper_scout"))
		{
				slot = 0;
				clipsize = 15;
		}
		else if (StrEqual(weapon, "sniper_awp"))
		{
				slot = 0;
				clipsize = 20;
		}
		else if (StrEqual(weapon, "sniper_military"))
		{
				slot = 0;
				clipsize = 30;
		}
		else if (StrEqual(weapon, "rifle_ak47"))
		{
				slot = 0;
				clipsize = 40;
		}
		else if (StrEqual(weapon, "smg") || StrEqual(weapon, "smg_silenced") || StrEqual(weapon, "smg_mp5"))
		{
				slot = 0;
				clipsize = 50;
		}
		else if ( StrEqual(weapon, "rifle") || StrEqual(weapon, "rifle_sg552"))
		{
				slot = 0;
				clipsize = 50;
		}
		else if (StrEqual(weapon, "rifle_desert"))
		{
				slot = 0;
				clipsize = 60;
		}
		else if (StrEqual(weapon, "rifle_m60"))
		{
				slot = 0;
				clipsize = 150;
		}
		else if (StrEqual(weapon, "pistol"))
		{
				slot = 1;
				if (GetEntProp(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_isDualWielding") > 0){
					clipsize = 30;
				}
				else {
					clipsize = 15;
				}
		}
		else if (StrEqual(weapon, "pistol_magnum"))
		{
				slot = 1;
				clipsize = 8;
		}
		else if (StrEqual(weapon, "chainsaw"))
		{
				slot = 1;
				clipsize = 30;
		}
		if ((slot == 0 || slot == 1) && InfiniteAmmo[client])
		{
			setAmmo(client, slot, clipsize+1);
		}
	}


}


void setProfile(int client)
{
		setAllPlayerData(client, false); //데이터 삭제
		AttackSpeedUp[client] = true;
		InfiniteReserveAmmo[client] = true;
		//InfiniteAmmo[client] = true;
		ReloadSpeedUp[client] = true;
		MeleeSpeedUp[client] = true;
		MoveSpeedUp[client] = true;
		IsHeal[client] = true;
		ChangeSpeed(client, 1.2);
}

void setdifficulty()
{
	int temp = 0;
	for(int i = 1 ; i <= MaxClients ; i++){
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
		{
			temp++;
		}
	}

	sv_gametypes.SetString("coop", true, false);
	mp_gamemode.SetString("coop", true, false);
	sv_hibernate_when_empty.SetInt(1, true, false);
	sv_force_unreserved.SetInt(0, true, false);
	sb_all_bot_game.SetInt(1, true, false);
	allow_all_bot_survivor_team.SetInt(1, true, false);
	sv_steamgroup_exclusive.SetInt(0, true, false);
	gamedifficulty.SetString("Normal", true, false);

	z_mob_spawn_finale_size.SetInt(0, true, false);
	z_health.SetInt(1, true, false);
	z_hunter_health.SetInt(1, true, false);
	z_jockey_health.SetInt(1, true, false);
	tongue_health.SetInt(1, true, false);
	z_spitter_health.SetInt(1, true, false);
	z_charger_health.SetInt(100, true, false);

	survivor_incap_health.SetInt(20, true, false);
	survivor_ledge_grab_health.SetInt(20, true, false);
	survivor_limp_health.SetInt(1, true, false);

	first_aid_kit_use_duration.SetFloat(0.0, true, false);
	survivor_revive_duration.SetFloat(1.0, true, false);

	survivor_friendly_fire_factor_normal.SetFloat(0.01, true, false);
	director_afk_timeout.SetInt(20, true, false);
	survivor_damage_speed_factor.SetFloat(1.0, true, false);
	melee_range.SetInt(200, true, false);

	int lWaveAmount = 17*temp;

	common_limit.SetInt(lWaveAmount, true, false);
	background_limit.SetInt(lWaveAmount, true, false);
	tankhp.SetInt(lWaveAmount*100, true, false);
	special_interval.SetInt(800/(temp+1), true, false);
	wandering_density.SetFloat(0.3, true, false);
	mob_population_density.SetFloat(0.3, true, false);
	mega_mob_size.SetInt(lWaveAmount, true, false);
	mob_spawn_min_size.SetInt(lWaveAmount-1, true, false);
	mob_spawn_max_size.SetInt(lWaveAmount, true, false);
	mob_spawn_min_interval_easy.SetInt(1, true, false);
	mob_spawn_min_interval_expert.SetInt(1, true, false);
	mob_spawn_min_interval_hard.SetInt(1, true, false);
	mob_spawn_min_interval_normal.SetInt(1, true, false);
	mob_spawn_max_interval_easy.SetInt(2, true, false);
	mob_spawn_max_interval_expert.SetInt(2, true, false);
	mob_spawn_max_interval_hard.SetInt(2, true, false);
	mob_spawn_max_interval_normal.SetInt(2, true, false);

}

void regenreservedammo(int client){
	
	
	if(client == -1) {

		for(int i = 1 ; i <= MaxClients ; i++){
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2 && InfiniteReserveAmmo[i])
			{
				new active_weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
				if(active_weapon == -1) continue;
				new String:weaponname[64];
				GetEdictClassname(active_weapon, weaponname, sizeof(weaponname));
				ReplaceString(weaponname, sizeof(weaponname), "weapon_", "", false);	
				new reservesize = -1;
				if (StrEqual(weaponname, "grenade_launcher")) reservesize = 29;
				else if (StrEqual(weaponname, "pumpshotgun") || StrEqual(weaponname, "shotgun_chrome"))	reservesize = 72;
				else if (StrEqual(weaponname, "autoshotgun") || StrEqual(weaponname, "shotgun_spas")) reservesize = 90;
				else if (StrEqual(weaponname, "hunting_rifle")) reservesize = 135;
				else if (StrEqual(weaponname, "sniper_scout")) reservesize = 105;
				else if (StrEqual(weaponname, "sniper_awp")) reservesize = 180;
				else if (StrEqual(weaponname, "sniper_military")) reservesize = 180;
				else if (StrEqual(weaponname, "rifle_ak47")) reservesize = 360;
				else if (StrEqual(weaponname, "smg") || StrEqual(weaponname, "smg_silenced") || StrEqual(weaponname, "smg_mp5")) reservesize = 650;
				else if (StrEqual(weaponname, "rifle") || StrEqual(weaponname, "rifle_sg552")) reservesize = 360;
				else if (StrEqual(weaponname, "rifle_desert")) reservesize = 360;
				else reservesize = -1;
				if(reservesize != -1){
					setReserveAmmo(i, 0, reservesize);
				}
			}
		}
	}
	else {
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && InfiniteReserveAmmo[client]) {
			new active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
			if(active_weapon == -1) return;
			new String:weaponname[64];
			GetEdictClassname(active_weapon, weaponname, sizeof(weaponname));
			ReplaceString(weaponname, sizeof(weaponname), "weapon_", "", false);	
			new reservesize = -1;
			if (StrEqual(weaponname, "grenade_launcher")) reservesize = 29;
			else if (StrEqual(weaponname, "pumpshotgun") || StrEqual(weaponname, "shotgun_chrome"))	reservesize = 72;
			else if (StrEqual(weaponname, "autoshotgun") || StrEqual(weaponname, "shotgun_spas")) reservesize = 90;
			else if (StrEqual(weaponname, "hunting_rifle")) reservesize = 135;
			else if (StrEqual(weaponname, "sniper_scout")) reservesize = 105;
			else if (StrEqual(weaponname, "sniper_awp")) reservesize = 180;
			else if (StrEqual(weaponname, "sniper_military")) reservesize = 180;
			else if (StrEqual(weaponname, "rifle_ak47")) reservesize = 360;
			else if (StrEqual(weaponname, "smg") || StrEqual(weaponname, "smg_silenced") || StrEqual(weaponname, "smg_mp5")) reservesize = 650;
			else if (StrEqual(weaponname, "rifle") || StrEqual(weaponname, "rifle_sg552")) reservesize = 360;
			else if (StrEqual(weaponname, "rifle_desert")) reservesize = 360;
			else reservesize = -1;
			if(reservesize != -1){
				setReserveAmmo(client, 0, reservesize);
			}
		}
	}
}

void Event_WeaponReload(Handle:event, const char[] name, bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", 0));
	regenreservedammo(client);
}

public Action:regenreservedammoTimer(Handle:timer)
{
	regenreservedammo(-1);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && ReloadSpeedUp[client]){

		switch (weapontype)
		{
			case L4D2WeaponType_Pistol: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_Magnum: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_Rifle: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_RifleAk47: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_RifleDesert: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_RifleM60: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_RifleSg552: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_HuntingRifle: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SniperAwp: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SniperMilitary: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SniperScout: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SMG: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SMGSilenced: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_SMGMp5: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_Autoshotgun: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_AutoshotgunSpas: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_Pumpshotgun: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_PumpshotgunChrome: speedmodifier = speedmodifier * 5.00;
			case L4D2WeaponType_GrenadeLauncher: speedmodifier = speedmodifier * 1.4;
		}
	}
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && AttackSpeedUp[client]){
		switch (weapontype)
		{
			case L4D2WeaponType_Pistol: speedmodifier = speedmodifier * 1.5;
			case L4D2WeaponType_Magnum: speedmodifier = speedmodifier * 2.0
			case L4D2WeaponType_Rifle: speedmodifier = speedmodifier * 1.2
			case L4D2WeaponType_RifleAk47: speedmodifier = speedmodifier * 1.25;
			case L4D2WeaponType_RifleDesert: speedmodifier = speedmodifier * 
			case L4D2WeaponType_RifleM60: speedmodifier = speedmodifier * 1.75;
			case L4D2WeaponType_RifleSg552: speedmodifier = speedmodifier * 1.
			case L4D2WeaponType_HuntingRifle: speedmodifier = speedmodifier * 2.5;
			case L4D2WeaponType_SniperAwp: speedmodifier = speedmodifier * 5;
			case L4D2WeaponType_SniperMilitary: speedmodifier = speedmodifier * 2;
			case L4D2WeaponType_SniperScout: speedmodifier = speedmodifier * 1.75;
			case L4D2WeaponType_SMG: speedmodifier = speedmodifier * 1.2
			case L4D2WeaponType_SMGSilenced: speedmodifier = speedmodifier * 1.2
			case L4D2WeaponType_SMGMp5: speedmodifier = speedmodifier * 1.2
			case L4D2WeaponType_Autoshotgun: speedmodifier = speedmodifier * 1.75;
			case L4D2WeaponType_AutoshotgunSpas: speedmodifier = speedmodifier * 1.75;
			case L4D2WeaponType_Pumpshotgun: speedmodifier = speedmodifier * 4;
			case L4D2WeaponType_PumpshotgunChrome: speedmodifier = speedmodifier * 4;
			case L4D2WeaponType_GrenadeLauncher: speedmodifier = speedmodifier * 1.

		}
	}
} 

public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2 && MeleeSpeedUp[client]){
		speedmodifier = speedmodifier * 1.5;
	}
}



void Event_PlayerDisconnect(Event event, char[] name, bool bDontBroadcast)
{
	setdifficulty();
}

setAllPlayerData(int client, bool active){
	
	if(active){
		AttackSpeedUp[client] = true;
		InfiniteReserveAmmo[client] = true;
		InfiniteAmmo[client] = true;
		ReloadSpeedUp[client] = true;
		MeleeSpeedUp[client] = true;
		MoveSpeedUp[client] = true;
		IsHeal[client] = true;
		ChangeSpeed(client, 1.2);
	}
	else if(!active){
		AttackSpeedUp[client] = false;
		InfiniteReserveAmmo[client] = false;
		InfiniteAmmo[client] = false;
		ReloadSpeedUp[client] = false;
		MeleeSpeedUp[client] = false;
		MoveSpeedUp[client] = false;
		IsHeal[client] = false;
		ChangeSpeed(client, 1);
	}
}

ChangeSpeed(client, Float:newspeed)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2){
		SetEntDataFloat(client, g_flLagMovement, newspeed, true);
	}
}


bool:IsValidEntRef(iEnt)
{
	if( iEnt && EntRefToEntIndex(iEnt) != INVALID_ENT_REFERENCE )
	return true;
	return false;
}


//메뉴 보여주기 & 메뉴 이벤트

public Action:Menu_Base_1(int client, int args) //메뉴를 보여준다
{
	new Handle:hPanel = CreatePanel();
	
	SetPanelTitle(hPanel, "What do you want?");
	DrawPanelItem(hPanel, "fast shoot and reload");
	DrawPanelItem(hPanel, "fast melee swing");
	DrawPanelItem(hPanel, "fast move");
	DrawPanelItem(hPanel, "fast auto health regen");
	DrawPanelItem(hPanel, "fast auto ammo regen");
	DrawPanelItem(hPanel, "nothing.");
	
	SendPanelToClient(hPanel, client, Menu_Base_1_Send, 99999); //메뉴 이벤트 연결
	CloseHandle(hPanel);
}

public Menu_Base_1_Send(Handle:menu, MenuAction:action, client, param)
{
	if(action == MenuAction_Select) {
		if(param ==1){
			AttackSpeedUp[client] = true;
			ReloadSpeedUp[client] = true;
		}
		if(param ==2){
			MeleeSpeedUp[client] = true;
		}
		if(param ==3){
			MoveSpeedUp[client] = true;
			ChangeSpeed(client, 1.2);

		}
		if(param ==4){
			IsHeal[client] = true;
		}
		if(param ==5){
			InfiniteReserveAmmo[client] = true;
		}
		if(param ==6){

		}
		if(param ==7){
			Menu_Base_1(client, -1);
		}
		if(param ==8){
			Menu_Base_1(client, -1);
		}
		if(param ==9){
			Menu_Base_1(client, -1);
		}
		if(param ==0){
			Menu_Base_1(client, -1);
			
		}

	}
}


public Action:Menu_AFk(int client, int args) //메뉴 보여준다
{
	new Handle:hPanel = CreatePanel();
	
	SetPanelTitle(hPanel, "게임에 참여하시겠습니까?");
	DrawPanelItem(hPanel, "예");
	DrawPanelItem(hPanel, "아니오");
	SendPanelToClient(hPanel, client, Menu_AFK_Send, 99999); //메뉴 이벤트 연결
	CloseHandle(hPanel);
}

public Menu_AFK_Send(Handle:menu, MenuAction:action, client, param)
{
	if(action == MenuAction_Select) {
		if(param ==1){
			//여기에 이제 입장하는 코드 필요 X, 관전(팀3)으로 이동 시 자동 이벤트 리스너에서 처리
		}

	}
}
public Action:Menu_Special_1(int client, int args) //메뉴 보여준다
{
	new Handle:hPanel = CreatePanel();
	
	SetPanelTitle(hPanel, "=====Special Command=====");
	DrawPanelItem(hPanel, "Infinite Ammo");
	DrawPanelItem(hPanel, "Health 100\%");
	DrawPanelItem(hPanel, "Random Teleport");
	DrawPanelItem(hPanel, "Spawn Tank (Max: 1)");
	DrawPanelItem(hPanel, "Spawn minigun");
	DrawPanelItem(hPanel, "Spawn sentrygun");
	DrawPanelItem(hPanel, "Remove guns");
	DrawPanelText(hPanel, "=======================");
	DrawPanelItem(hPanel, "Next");
	
	SendPanelToClient(hPanel, client, Menu_Special_1_Send, 99999); //메뉴 이벤트 연결
	CloseHandle(hPanel);
}

public Menu_Special_1_Send(Handle:menu, MenuAction:action, client, param)
{
	if(action == MenuAction_Select) {
		if(param ==1){
			if(!InfiniteAmmo[client])InfiniteAmmo[client] = true;
			else InfiniteAmmo[client] = false
		}
		if(param ==2){
    		SetEntityHealth(client, 100);
			set_temp_health(client, 0)
		}
		if(param ==3){
			Teleport(client, -1);
		}
		if(param ==4){
			if(CountTank() < 1) NoClientCommand("z_spawn", "tank");
		}
		if(param ==5){

		}
		if(param ==6){
			
		}
		if(param ==7){

		}
		if(param ==8){
			Menu_Special_2(client, -1);
		}

	}
}


public Action:Menu_Special_2(int client, int args) //이런 메뉴를 보여준다
{
	new Handle:hPanel = CreatePanel();
	

	SetPanelTitle(hPanel, "=====Basic Command=====");
	DrawPanelItem(hPanel, "Suicide");
	DrawPanelItem(hPanel, "Spectate");
	DrawPanelText(hPanel, "==========");
	DrawPanelItem(hPanel, "Prev");
	
	SendPanelToClient(hPanel, client, Menu_Special_2_Send, 99999); //메뉴 이벤트 연결
	CloseHandle(hPanel);
}

public Menu_Special_2_Send(Handle:menu, MenuAction:action, client, param)
{
	if(action == MenuAction_Select) {
		if(param ==1){
    		ForcePlayerSuicide(client);
		}
		if(param ==2){
			AFK(client, -1);
		}
		if(param ==3){
			Menu_Special_1(client, -1)
		}

	}
}


public Action:RestoreGravity(Handle:timer, any:client)
{
	//g_hCvarGravity.SetInt(800, true, false);
    return Plugin_Stop;
}

void set_temp_health(int client, float buffer)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", buffer);
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

public Action BanClientRequest(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(client > 0 && !IsFakeClient(client))
    {
        int banTime = 0;
        BanClient(client, banTime, true, "");
    }

    return Plugin_Handled;
}

//타이머 등록
public Action:CheckHeal(Handle:timer)
{
	for(int i = 1 ; i <= MaxClients ; i ++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2){
			if(IsHeal[i]){
				int nowreal = GetClientHealth(i);

				if(nowreal >= 100) continue;
				SetEntityHealth(i, nowreal + 2);

			}

		}
	}
    return Plugin_Continue;

}
//타이머 등록
public Action:ErrorDeadmanCheck(Handle:timer) //오류때문에 살아나지 못한 죽어있는 사람들을 살린다
{
    for(int i = 1 ; i <= MaxClients ; i ++) {
        if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i) != 2) continue;
		if(IsPlayerAlive(i)) continue;
		if(IsFakeClient(i)) continue;
			SDKCall(hRoundRespawn, i);
			Teleport(i, -1);
    }
    return Plugin_Continue;

}
//타이머 등록
public Action:SpawnMob(Handle:timer)
{
	if(!isGameLoading){
		NoClientCommand("z_spawn", "mob");
	}
    return Plugin_Continue;
}

//타이머 등록
public Action:SpawnTank(Handle:timer)
{
	if(!isGameLoading){
		int playercount = 0;
		for(int i = 1 ; i <= MaxClients ; i ++) {
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 2){
				playercount++;
			}
		}
		spawntankcountdown += playercount*10;

		if (spawntankcountdown >= SPAWNTANKCOUNT && CountTank() < 1) {
			NoClientCommand("z_spawn", "tank");
			// NoClientCommand("z_spawn", "boomer");
			// NoClientCommand("z_spawn", "boomer");
			// NoClientCommand("z_spawn", "boomer");
			spawntankcountdown = 0;
		}
	}
    return Plugin_Continue;
}

//타이머 등록
public Action:SendMessagesToPlayers(Handle:timer)
{
    PrintToChatAll("press H and join this server group.\nyou can check a command for the group members."); //모두에게 보낸다


    return Plugin_Continue;
}

//타이머 등록

public Action:checkSpectators(Handle:timer){
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 1) {
        	ShowJoinPanel(i);
        }
    }
}


public Action:SendMessagesToSpectators(Handle:timer)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 1) {
            PrintToChat(i, "Type /join");
            PrintHintText(i, "Type /join");
        }
    }

    return Plugin_Continue;
}


//명령어 등록
AFK(int client, int args)
{
        ChangeClientTeam(client, 1); // Assuming 1 is the index for spectators

    return Plugin_Handled;
}

//바로 사망시키는 함수
public Action:Event_CaughtBySpecial(Handle:event, const char[] name, bool:dontBroadcast)
{
    int attacker = GetClientOfUserId(GetEventInt(event, "userid", 0));
    int victim = GetClientOfUserId(GetEventInt(event, "victim", 0));
    if(victim > 0 && IsClientInGame(victim))
    {
        int predestination = -1;
        if(attacker != -1) predestination = Teleport(attacker, -1);
        if(victim != -1) Teleport(victim, predestination);

    }
    return Plugin_Continue;
}

void suicide(int client) {
    if (IsClientInGame(client)) {
        ForcePlayerSuicide(client);
    }
}

void revive(int client) {
    if (IsClientInGame(client)) {
        SDKCall(hRoundRespawn, client);
        SetEntityHealth(client, 50);
        Teleport(client, -1);
        CheatCommand(client, "give", "rifle");
        CheatCommand(client, "give", "baseball_bat");
    }
}

Action Timer_Revive(Handle timer, any data) {
    int client = data;
    if (IsClientInGame(client) && !IsPlayerAlive(client)) {
        revive(client);
        
    }

    return Plugin_Handled;
}

Action Timer_Suicide(Handle timer, any data) {
    int client = data;
    if (IsClientInGame(client)) {
		suicide(client);
    }

    return Plugin_Handled;
}

Action Timer_LowHP(Handle timer, any data) {
    int client = data;
    if (IsClientInGame(client)) {
			SetEntityHealth(client, GetClientHealth(client)/2);
    }

    return Plugin_Handled;
}


public Action:Event_LowHP(Handle event, const char[] name, bool dontBroadcast){
    int victimORnone = GetClientOfUserId(GetEventInt(event, "victim", 0));
	// if(victimORnone < 1) victimORnone = GetClientOfUserId(GetEventInt(event, "userid", 0));

    if (victimORnone > 0 &&
        IsClientInGame(victimORnone) &&
        IsPlayerAlive(victimORnone) &&
        GetClientTeam(victimORnone) == 2) {
			CreateTimer(0.1, Timer_LowHP, victimORnone);
    }
    return Plugin_Continue;
}

public Action:Event_Suicide(Handle event, const char[] name, bool dontBroadcast) {
    int user = GetClientOfUserId(GetEventInt(event, "userid", 0));

    if (user > 0 &&
        IsClientInGame(user) &&
        IsPlayerAlive(user) &&
        GetClientTeam(user) == 2) {
			CreateTimer(0.1, Timer_Suicide, user);

    }
    return Plugin_Continue;
}

public Action:Event_Revive(Handle event, const char[] name, bool dontBroadcast) {
    int user = GetClientOfUserId(GetEventInt(event, "userid", 0));
    if (user > 0 && 
        IsClientInGame(user) &&
        !IsPlayerAlive(user) &&
        GetClientTeam(user) == 2) {
        	CreateTimer(0.5, Timer_Revive, user);
			}
    return Plugin_Continue;
}

int Teleport(int client, int target) {
    new Int:validPlayers[MaxClients + 1];
    new numValidPlayers = 0;

    if(target == -1) {

        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && i != client)
            {
                validPlayers[numValidPlayers++] = i;
            }
        }

        if (numValidPlayers > 0)
        {
            new randomIndex = GetRandomInt(0, numValidPlayers - 1);
            new targetClient = validPlayers[randomIndex];

            new Float:coordinates[3];
            GetClientAbsOrigin(targetClient, coordinates);

            TeleportEntity(client, coordinates, NULL_VECTOR, NULL_VECTOR);
            return targetClient;
        }
    }

    else {
            new Float:coordinates[3];
            GetClientAbsOrigin(target, coordinates);
            TeleportEntity(client, coordinates, NULL_VECTOR, NULL_VECTOR);
            return target;
    }
}


public void OnPlayerTeamChange(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team = event.GetInt("team");
    
    if (client > 0 && IsClientInGame(client) && team == 1) { // 관전자 팀 (1)
        ShowJoinPanel(client);
    } else if (client > 0 && IsClientInGame(client) && team == 2) { // 생존자
            CloseJoinPanel(client);
	}

	setdifficulty();

}

void ShowJoinPanel(int client) {
    Panel panel = CreatePanel();
    SetPanelTitle(panel, "게임에 참여하려면 마우스 좌클릭 또는 1을 눌러주세요");
    DrawPanelItem(panel, "게임에 참여한다.");
    
    SendPanelToClient(panel, client, JoinPanelHandler, 20);
    CloseHandle(panel);
}

void CloseJoinPanel(int client) {
    Panel panel = new Panel();
    panel.SetTitle(" ");
    panel.Send(client, DummyHandler, 1); // 1초만 표시, 자동 닫힘
    delete panel;
}

int DummyHandler(Menu menu, MenuAction action, int param1, int param2) {
    return 0;
}

public int JoinPanelHandler(Menu menu, MenuAction action, int client, int param) {
    if (action == MenuAction_Select) {
        if (param == 1) {
			FakeClientCommand(client, "say /join");
			PrintHintText(client, "게임에 참여하려면 마우스 좌클릭을 누르세요");
        } else {
            ShowJoinPanel(client); // 다시 패널 표시
        }
    }
    return 0;
}

void NoClientCommand(const char[] command, const char[] arguments="") //client를 가짜로 만들어 입력해야 할 때
{
	int client=CreateFakeClient("Fake"); //가짜 클라이언트 만들고
	if(client){
		ChangeClientTeam(client, 3); //적으로 바꾸고
		Teleport(client, -1); //랜덤 플레이어에게 순간이동시킨다
		int flags=GetCommandFlags(command);
		SetCommandFlags(command, flags&~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, arguments);
		SetCommandFlags(command, flags|FCVAR_CHEAT);
		CreateTimer(0.1, Kickbot, client);
	}
}

public Action Kickbot(Handle timer, any client){
	if(IsFakeClient(client)) KickClientEx(client);
}

void CheatCommand(int client, const char[] command, const char[] arguments = "") //클라이언트 치트 사용 함수 1
{
	int iCmdFlags = GetCommandFlags(command), iFlagBits = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(command, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetUserFlagBits(client, iFlagBits);
	SetCommandFlags(command, iCmdFlags|FCVAR_CHEAT);
}

void ExecuteCheatCommand(int client, char[] command, char[] param1, char[] param2) //클라이언트 치트 사용 함수 2
{
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, param1, param2);
	SetCommandFlags(command, flags | GetCommandFlags(command));
}

int CountTank(){
	char classname[32];
	int TankCount =0;
	for(int i=1; i<=MaxClients; i++){
		if(IsClientInGame(i)&&IsFakeClient(i)&&GetClientTeam(i)==3){
			GetClientModel(i, classname, sizeof(classname));
			if(StrContains(classname, "hulk"))TankCount++;
		}
	}
	return TankCount;
}

#define USING_PILLS_ACT 187

#define DESERT_BURST_INTERVAL 0.35
#define DESERT_BURST_OFFSET_2 0
#define DESERT_BURST_OFFSET_3 4
#define DESERT_BURST_OFFSET_END 8
static int g_DesertBurstOffset = -1;
static float g_fBurstEndTime[MAXPLAYERS+1];
static float g_fBurstModifier;


static L4D2WeaponType g_iWeaponType[2048+1];
static Handle hReloadModifier;
static Handle hRateOfFire;
static Handle hItemUseDuration;
static Handle hOnPillsUse_L4D1;
static Handle hDeployModifier;
static Handle hDeployGun;
static Handle hGrenadePrimaryAttack;
static Handle hStartThrow;
static Handle hDesertBurstFire;

static Address CTerrorGun__GetRateOfFire_byte_address;
static Address CPistol__GetRateOfFire_byte_address;

static int g_iTempRef;
static float g_fTempSpeed;

Handle g_hOnMeleeSwing;
Handle g_hOnStartThrow;
Handle g_hOnReadyingThrow;
Handle g_hOnReloadModifier;
Handle g_hOnGetRateOfFire;
Handle g_hOnDeployModifier;

static ConVar hCvar_DoublePistolCycle;
static ConVar hCvar_UseIncapCycle;
static ConVar hCvar_DeploySetting;

static bool g_bDoublePistolCycle;
static bool g_bUseIncapCycle;
static int g_iDeploySetting;

static ConVar hCvar_IncapCycle;
static float g_fIncapCycle = 0.3;

static bool g_bL4D1IsUsingPills;
static int g_iPillsUseTimerOffset;

enum MeleeSwingInfo
{
	MeleeSwingInfo_Entity = 0,
	MeleeSwingInfo_Client,
	MeleeSwingInfo_SwingType
} 

static int g_iMeleeTempVals[3];

bool g_bIsL4D2;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion iEngineVersion = GetEngineVersion();
	if(iEngineVersion == Engine_Left4Dead2)
	{
		g_bIsL4D2 = true;
	}
	else if(iEngineVersion == Engine_Left4Dead)
	{
		g_bIsL4D2 = false;
	}
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1/2");
		return APLRes_SilentFailure;
	}
	
	RegPluginLibrary("JYW");
	g_hOnMeleeSwing = CreateGlobalForward("WH_OnMeleeSwing", ET_Event, Param_Cell, Param_Cell, Param_FloatByRef);
	g_hOnStartThrow = CreateGlobalForward("WH_OnStartThrow", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	g_hOnReadyingThrow = CreateGlobalForward("WH_OnReadyingThrow", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	g_hOnReloadModifier = CreateGlobalForward("WH_OnReloadModifier", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	g_hOnGetRateOfFire = CreateGlobalForward("WH_OnGetRateOfFire", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	g_hOnDeployModifier = CreateGlobalForward("WH_OnDeployModifier", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_FloatByRef);
	
	return APLRes_Success;
}


public void initializeweapon()
{
	LoadHooksAndPatches();
	
	CreateConVar("weaponhandling_version", PLUGIN_VERSION, "", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	hCvar_DoublePistolCycle = CreateConVar("wh_double_pistol_cycle_rate", "0", "1 = (double pistol shoot at double speed of a single pistol 2~ shots persec slower than vanilla) 0 = (keeps vanilla cycle rate of 0.075) before being modified", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	hCvar_UseIncapCycle = CreateConVar("wh_use_incap_cycle_cvar", "1", "1 = (use \"survivor_incapacitated_cycle_time\" for incap shooting cycle rate) 0 = (ignores the cvar and uses weapon_*.txt cycle rates) before being modified", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	hCvar_DeploySetting = CreateConVar("wh_deploy_animation_speed", "1", "1 = (match deploy animation speed to the \"DeployDuration\" keyvalue in weapon_*.txt) 0 = (ignore \"DeployDuration\" keyvalue in weapon_*.txt and matches deploy speed to animation speed) before being modified -1(do nothing)", FCVAR_NOTIFY, true, -1.0, true, 1.0);
	
	hCvar_IncapCycle = FindConVar("survivor_incapacitated_cycle_time");
	if(hCvar_IncapCycle == null)
	{
		LogError("Unable to find \"survivor_incapacitated_cycle_time\" cvar, assuming \"wh_use_incap_cycle_cvar\" is false");
	}
	else
	{
		hCvar_IncapCycle.AddChangeHook(eConvarChanged);
	}
	
	hCvar_DoublePistolCycle.AddChangeHook(eConvarChanged);
	hCvar_UseIncapCycle.AddChangeHook(eConvarChanged);
	hCvar_DeploySetting.AddChangeHook(eConvarChanged);
	
	CvarsChanged();
	AutoExecConfig(true, "JYW");
}

public void eConvarChanged(Handle hCvar, const char[] sOldVal, const char[] sNewVal)
{
	CvarsChanged();
}

void CvarsChanged()
{
	g_bDoublePistolCycle = hCvar_DoublePistolCycle.IntValue > 0;
	g_bUseIncapCycle = hCvar_UseIncapCycle.IntValue > 0;
	g_iDeploySetting = hCvar_DeploySetting.IntValue;
	
	if(hCvar_IncapCycle != null)
	{
		g_fIncapCycle = hCvar_IncapCycle.FloatValue;
	}
	else
	{
		g_bUseIncapCycle = false;
	}
}

public MRESReturn OnMeleeSwingPre(int pThis, Handle hReturn, Handle hParams)
{
	g_iMeleeTempVals[MeleeSwingInfo_Entity] = pThis;
	g_iMeleeTempVals[MeleeSwingInfo_Client] = DHookGetParam(hParams, 1);
	g_iMeleeTempVals[MeleeSwingInfo_SwingType] = DHookGetParam(hParams, 2);
	
	return MRES_Ignored;
}

public MRESReturn OnMeleeSwingpPost()
{
	if(!g_iMeleeTempVals[MeleeSwingInfo_SwingType]) 
		return MRES_Ignored;
	
	int iWeapon = g_iMeleeTempVals[MeleeSwingInfo_Entity];
	float fSpeed = 1.0;
	
	Call_StartForward(g_hOnMeleeSwing);
	Call_PushCell(g_iMeleeTempVals[MeleeSwingInfo_Client]);
	Call_PushCell(iWeapon);
	Call_PushFloatRef(fSpeed);
	Call_Finish();
	
	fSpeed = ClampFloatAboveZero(fSpeed);
	
	float flGameTime;
	float flNextTimeCalc;
	flGameTime = GetGameTime();
	flNextTimeCalc = (((GetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack") - flGameTime) / fSpeed) + flGameTime);
	
	SetEntPropFloat(iWeapon, Prop_Send, "m_flPlaybackRate", fSpeed);
	SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", flNextTimeCalc);
	
	return MRES_Ignored;
}

public void PostThinkOnce(int iClient)
{
	SDKUnhook(iClient, SDKHook_PostThink, PostThinkOnce);
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Data, "m_hActiveWeapon");
	if(!IsValidEntRef2(g_iTempRef) || iWeapon != EntRefToEntIndex(g_iTempRef))
		return;
	
	SetEntPropFloat(iWeapon, Prop_Send, "m_flPlaybackRate", g_fTempSpeed);
}

public MRESReturn OnStartThrow(int pThis, Handle hReturn)
{
	int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	float fSpeed = 1.0;
	
	Call_StartForward(g_hOnStartThrow);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fSpeed);
	Call_Finish();
	
	fSpeed = ClampFloatAboveZero(fSpeed);
	
	float flGameTime;
	float flNextTimeCalc;
	flGameTime = GetGameTime();
	flNextTimeCalc = (((GetEntPropFloat(pThis, Prop_Send, "m_fThrowTime") - flGameTime) / fSpeed) + flGameTime);
	SetEntPropFloat(pThis, Prop_Send, "m_fThrowTime", flNextTimeCalc);
	
	
	g_iTempRef = EntIndexToEntRef(pThis);
	g_fTempSpeed = fSpeed;
	
	SDKHook(iClient, SDKHook_PostThink, PostThinkOnce);
	return MRES_Ignored;
}

public MRESReturn OnReadyingThrow(int pThis)
{
	static int iClient;
	iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	static float fSpeed;
	fSpeed = 1.0;
	
	Call_StartForward(g_hOnReadyingThrow);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fSpeed);
	Call_Finish();
	
	fSpeed = ClampFloatAboveZero(fSpeed);
	
	static float flGameTime;
	static float flNextTimeCalc;
	flGameTime = GetGameTime();
	flNextTimeCalc = (((GetEntPropFloat(pThis, Prop_Send, "m_flNextPrimaryAttack") - flGameTime) / fSpeed) + flGameTime);
	
	SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", fSpeed);
	SetEntPropFloat(pThis, Prop_Send, "m_flNextPrimaryAttack", flNextTimeCalc);
	SetEntPropFloat(iClient, Prop_Send, "m_flNextAttack", flNextTimeCalc);
	
	return MRES_Ignored;
}

public MRESReturn OnReloadModifier(int pThis, Handle hReturn)
{
	int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	float fSpeed = 1.0;
	
	Call_StartForward(g_hOnReloadModifier);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fSpeed);
	Call_Finish();
	
	float fReloadSpeed = DHookGetReturn(hReturn);
	fReloadSpeed = ClampFloatAboveZero(fReloadSpeed / fSpeed);
	
	DHookSetReturn(hReturn, fReloadSpeed);
	return MRES_Override;
}

public MRESReturn OnGetRateOfFire(int pThis, Handle hReturn)
{
	static float fRateOfFire;
	static float fRateOfFireModifier;
	
	static int iClient;
	iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
		
	fRateOfFireModifier = 1.0;
	fRateOfFire = DHookGetReturn(hReturn);
	
	Call_StartForward(g_hOnGetRateOfFire);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fRateOfFireModifier);
	Call_Finish();
	
	if(g_iWeaponType[pThis] == L4D2WeaponType_Pistol && GetEntProp(pThis, Prop_Send, "m_isDualWielding", 1))
	{
		if(g_bDoublePistolCycle)
		{
			fRateOfFire = fRateOfFire * 0.5;
		}
		else
		{
			fRateOfFire = 0.075000003;
		}
	}
	
	if(g_bUseIncapCycle && GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1))
	{
		fRateOfFire = g_fIncapCycle;
	}
	
	fRateOfFire = ClampFloatAboveZero(fRateOfFire / fRateOfFireModifier);
	
	if(g_iWeaponType[pThis] == L4D2WeaponType_RifleDesert)
	{
		g_fBurstModifier = fRateOfFireModifier;
	}
	
	DHookSetReturn(hReturn, fRateOfFire);
	SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", fRateOfFireModifier);
	
	return MRES_Override;
}

public MRESReturn OnGetRateOfFireBurst(int pThis, Handle hReturn)
{
	static int iClient;
	iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	float flValveBurstData = GetEntDataFloat(pThis, g_DesertBurstOffset + DESERT_BURST_OFFSET_END);
	if(flValveBurstData == g_fBurstEndTime[iClient])
	{
		return MRES_Ignored;
	}
	
	float fTime = GetGameTime();
	flValveBurstData = flValveBurstData - fTime;
	flValveBurstData = ClampFloatAboveZero(flValveBurstData / g_fBurstModifier);
	g_fBurstEndTime[iClient] = flValveBurstData + fTime;
	
	SetEntDataFloat(pThis, g_DesertBurstOffset + DESERT_BURST_OFFSET_END, g_fBurstEndTime[iClient]);
	return MRES_Ignored;
}

public MRESReturn OnGetRateOfFireL4D1Pills(int pThis)
{
	int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1 || !g_bL4D1IsUsingPills)
	{
		g_bL4D1IsUsingPills = false;
		return MRES_Ignored;
	}
	g_bL4D1IsUsingPills = false;
	
	float fRateOfFireModifier = 1.0;
	
	Call_StartForward(g_hOnGetRateOfFire);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fRateOfFireModifier);
	Call_Finish();
	
	Address PillsUseTimerDuration = GetEntityAddress(pThis) + view_as<Address>(g_iPillsUseTimerOffset + 4);
	Address PillsUseTimerTimeStamp = PillsUseTimerDuration + view_as<Address>(4);
	
	float fRateOfFire = view_as<float>(LoadFromAddress(PillsUseTimerDuration, NumberType_Int32));
	fRateOfFire = ClampFloatAboveZero(fRateOfFire / fRateOfFireModifier);
	
	StoreToAddress(PillsUseTimerTimeStamp, view_as<int>(fRateOfFire + GetGameTime()), NumberType_Int32);
	StoreToAddress(PillsUseTimerDuration, view_as<int>(fRateOfFire), NumberType_Int32);
	
	SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", fRateOfFireModifier);
	return MRES_Ignored;
}

public MRESReturn OnIsUsingPills(int pThis, Handle hReturn, Handle hParams)
{
	int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	int iCurrentAct = DHookGetParam(hParams, 1);
	if(iCurrentAct != USING_PILLS_ACT || !DHookGetReturn(hReturn))
		return MRES_Ignored;
	
	g_bL4D1IsUsingPills = true;
	
	return MRES_Ignored;
}

public MRESReturn OnDeployModifier(int pThis, Handle hReturn)
{
	g_fTempSpeed = 1.0;
	
	int iClient = GetEntPropEnt(pThis, Prop_Send, "m_hOwnerEntity");
	if(iClient < 1)
		return MRES_Ignored;
	
	float fCurrentSpeed = DHookGetReturn(hReturn);
	float fSpeed = 1.0;
	
	switch(g_iDeploySetting)
	{
		case 0:
		{
			fCurrentSpeed = 1.0;
		}
		case 1:
		{
			g_fTempSpeed = 1.0 / fCurrentSpeed;
		}
	}
	
	Call_StartForward(g_hOnDeployModifier);
	Call_PushCell(iClient);
	Call_PushCell(pThis);
	Call_PushCell(g_iWeaponType[pThis]);
	Call_PushFloatRef(fSpeed);
	Call_Finish();
	
	fSpeed = ClampFloatAboveZero(fSpeed);
	g_fTempSpeed = g_fTempSpeed * fSpeed;
	DHookSetReturn(hReturn, ClampFloatAboveZero(fCurrentSpeed / fSpeed));
	return MRES_Override;
}

public MRESReturn OnDeployGun(int pThis)
{
	SetEntPropFloat(pThis, Prop_Send, "m_flPlaybackRate", g_fTempSpeed);
	return MRES_Ignored;
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(iEntity < 1 || sClassname[0] != 'w')
		return;

	g_iWeaponType[iEntity] = GetWeaponTypeFromClassname(sClassname);
	
	switch(g_iWeaponType[iEntity])
	{
		case L4D2WeaponType_AutoshotgunSpas, L4D2WeaponType_PumpshotgunChrome, 
			L4D2WeaponType_Autoshotgun, L4D2WeaponType_Pumpshotgun, L4D2WeaponType_GrenadeLauncher, 
			L4D2WeaponType_HuntingRifle, L4D2WeaponType_Magnum, L4D2WeaponType_Rifle, 
			L4D2WeaponType_SMG, L4D2WeaponType_RifleSg552,
			L4D2WeaponType_Pistol, L4D2WeaponType_RifleAk47, L4D2WeaponType_SMGMp5, 
			L4D2WeaponType_SMGSilenced, L4D2WeaponType_SniperAwp, L4D2WeaponType_SniperMilitary, 
			L4D2WeaponType_SniperScout, L4D2WeaponType_RifleM60:
		{
			DHookEntity(hReloadModifier, true, iEntity);
			DHookEntity(hRateOfFire, true, iEntity);
			DHookEntity(hDeployModifier, true, iEntity);
			DHookEntity(hDeployGun, true, iEntity);
		}
		case L4D2WeaponType_RifleDesert:
		{
			DHookEntity(hReloadModifier, true, iEntity);
			DHookEntity(hRateOfFire, true, iEntity);
			DHookEntity(hDeployModifier, true, iEntity);
			DHookEntity(hDeployGun, true, iEntity);
			DHookEntity(hDesertBurstFire, true, iEntity);
		}
		case L4D2WeaponType_Pills, L4D2WeaponType_Adrenaline:
		{
			if(!g_bIsL4D2)
			{
				DHookEntity(hOnPillsUse_L4D1, true, iEntity);
			}
			DHookEntity(hItemUseDuration, true, iEntity);
			DHookEntity(hDeployModifier, true, iEntity);
			DHookEntity(hDeployGun, true, iEntity);
		}
		case L4D2WeaponType_Melee, L4D2WeaponType_Defibrilator, L4D2WeaponType_FirstAid, L4D2WeaponType_UpgradeFire, L4D2WeaponType_UpgradeExplosive:
		{
			DHookEntity(hDeployModifier, true, iEntity);
			DHookEntity(hDeployGun, true, iEntity);
		}
		case L4D2WeaponType_Molotov, L4D2WeaponType_Pipebomb, L4D2WeaponType_Vomitjar:
		{
			DHookEntity(hGrenadePrimaryAttack, true, iEntity);
			DHookEntity(hStartThrow, true, iEntity);
			DHookEntity(hDeployModifier, true, iEntity);
			DHookEntity(hDeployGun, true, iEntity);
		}
	}
}


void LoadHooksAndPatches()
{
	Handle hGamedata = LoadGameConfigFile("JYW");
	if(hGamedata == null) 
		SetFailState("Failed to load \"%s.txt\" gamedata.", "JYW");
	
	
	int iOffset;
	iOffset = GameConfGetOffset(hGamedata, "CTerrorWeapon::GetReloadDurationModifier");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CTerrorPlayer::GetReloadDurationModifier'");
	
	hReloadModifier = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, OnReloadModifier);
	
	iOffset = GameConfGetOffset(hGamedata, "CTerrorGun::GetRateOfFire");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CTerrorGun::GetRateOfFire'");
	
	hRateOfFire = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, OnGetRateOfFire);
	
	
	if(g_bIsL4D2)
	{
		iOffset = GameConfGetOffset(hGamedata, "CBaseBeltItem::GetUseTimerDuration");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CBaseBeltItem::GetUseTimerDuration'");
		
		hItemUseDuration = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, OnGetRateOfFire);
		
		iOffset = GameConfGetOffset(hGamedata, "CRifle_Desert::PrimaryAttack");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CRifle_Desert::PrimaryAttack'");
		
		hDesertBurstFire = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnGetRateOfFireBurst);
		
		g_DesertBurstOffset = GameConfGetOffset(hGamedata, "CRifle_Desert::BurstTimes_StartOffset");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CRifle_Desert::BurstTimes_StartOffset'");
	}
	else
	{
		iOffset = GameConfGetOffset(hGamedata, "CPainPills::SendWeaponAnim");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CPainPills::SendWeaponAnim'");
		
		hOnPillsUse_L4D1 = DHookCreate(iOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnIsUsingPills);
		DHookAddParam(hOnPillsUse_L4D1, HookParamType_Int);
		
		iOffset = GameConfGetOffset(hGamedata, "CPainPills::PrimaryAttack");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CPainPills::PrimaryAttack'");
		
		hItemUseDuration = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnGetRateOfFireL4D1Pills);
		
		g_iPillsUseTimerOffset = GameConfGetOffset(hGamedata, "CPainPills::GetUseTimer");
		if(iOffset == -1)
			SetFailState("Unable to get offset for 'CPainPills::GetUseTime'");
	}
	
	iOffset = GameConfGetOffset(hGamedata, "CTerrorWeapon::GetDeployDurationModifier");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CTerrorWeapon::GetDeployDurationModifier'");
	
	hDeployModifier = DHookCreate(iOffset, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity, OnDeployModifier);
	
	iOffset = GameConfGetOffset(hGamedata, "CTerrorWeapon::Deploy");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CTerrorWeapon::Deploy'");
	
	hDeployGun = DHookCreate(iOffset, HookType_Entity, ReturnType_Unknown, ThisPointer_CBaseEntity, OnDeployGun);
	
	iOffset = GameConfGetOffset(hGamedata, "CBaseCSGrenade::PrimaryAttack");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CBaseCSGrenade::PrimaryAttack'");
	
	hGrenadePrimaryAttack = DHookCreate(iOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, OnReadyingThrow);
	
	iOffset = GameConfGetOffset(hGamedata, "CBaseCSGrenade::StartGrenadeThrow");
	if(iOffset == -1)
		SetFailState("Unable to get offset for 'CBaseCSGrenade::StartGrenadeThrow'");
	
	hStartThrow = DHookCreate(iOffset, HookType_Entity, ReturnType_Edict, ThisPointer_CBaseEntity, OnStartThrow);
	
	if(g_bIsL4D2)
	{
		Handle hDetour;
		hDetour = DHookCreateFromConf(hGamedata, "CTerrorMeleeWeapon::StartMeleeSwing");
		if(!hDetour)
			SetFailState("Failed to find 'CTerrorMeleeWeapon::StartMeleeSwing' signature");
		
		if(!DHookEnableDetour(hDetour, false, OnMeleeSwingPre))
			SetFailState("Failed to detour 'CTerrorMeleeWeapon::StartMeleeSwing'");
		
		if(!DHookEnableDetour(hDetour, true, OnMeleeSwingpPost))
			SetFailState("Failed to detour 'CTerrorMeleeWeapon::StartMeleeSwing'");
	}
	
	
	Address patch = GameConfGetAddress(hGamedata, "CTerrorGun::GetRateOfFire");
	if(patch)
	{
		int offset = GameConfGetOffset(hGamedata, "CTerrorGun::GetRateOfFire_patch");
		if(offset != -1) 
		{
			if(LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8) == 0x74)
			{
				CTerrorGun__GetRateOfFire_byte_address = patch + view_as<Address>(offset);
				StoreToAddress(CTerrorGun__GetRateOfFire_byte_address, 0xEB, NumberType_Int8);
				PrintToServer("WeaponHandling CTerrorGun::GetRateOfFire Incap cycle rate patched");
			}
			else
			{
				LogError("Incorrect offset for 'CTerrorGun::GetRateOfFire_patch'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'CTerrorGun::GetRateOfFire_patch'.");
		}
	}
	else
	{
		LogError("Error finding the 'CTerrorGun::GetRateOfFire' signature.'");
	}
	
	patch = GameConfGetAddress(hGamedata, "CPistol::GetRateOfFire");
	if(patch)
	{
		int offset = GameConfGetOffset(hGamedata, "CPistol::GetRateOfFire_patch");
		if(offset != -1) 
		{
			if(LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8) == 0x74)
			{
				CPistol__GetRateOfFire_byte_address = patch + view_as<Address>(offset);
				StoreToAddress(CPistol__GetRateOfFire_byte_address, 0xEB, NumberType_Int8);
				PrintToServer("WeaponHandling CPistol::GetRateOfFire Incap cycle rate patched");
			}
			else
			{
				LogError("Incorrect offset for 'CPistol::GetRateOfFire_patch'.");
			}
		}
		else
		{
			LogError("Invalid offset for 'CPistol::GetRateOfFire_patch'.");
		}
	}
	else
	{
		LogError("Error finding the 'CPistol::GetRateOfFire' signature.'");
	}
	
	delete hGamedata;
}

public void OnPluginEnd()
{
	int byte;
	
	if(CPistol__GetRateOfFire_byte_address != Address_Null)
	{
		byte = LoadFromAddress(CPistol__GetRateOfFire_byte_address, NumberType_Int8);
		if(byte == 0xEB)
		{
			StoreToAddress(CPistol__GetRateOfFire_byte_address, 0x74, NumberType_Int8);
			PrintToServer("WeaponHandling restored 'CPistol::GetRateOfFire'");
		}
	}	
	
	if(CTerrorGun__GetRateOfFire_byte_address != Address_Null)
	{
		byte = LoadFromAddress(CTerrorGun__GetRateOfFire_byte_address, NumberType_Int8);
		if(byte == 0xEB)
		{
			StoreToAddress(CTerrorGun__GetRateOfFire_byte_address, 0x74, NumberType_Int8);
			PrintToServer("WeaponHandling restored 'CTerrorGun::GetRateOfFire'");
		}
	}
}


static float ClampFloatAboveZero(float fSpeed)
{
	if(fSpeed <= 0.0)
		return 0.00001;
	return fSpeed;
}

static bool IsValidEntRef2(int iEntRef)
{
	return (iEntRef != 0 && EntRefToEntIndex(iEntRef) != INVALID_ENT_REFERENCE);
}

public void setReserveAmmo(int client, int slot, int size){
	new weaponent = GetPlayerWeaponSlot(client, slot);
	if (weaponent > 0 && IsValidEntity(weaponent))
	{
		int AmmoType = GetEntProp(weaponent, Prop_Data, "m_iPrimaryAmmoType")
		SetEntProp(client, Prop_Send, "m_iAmmo", size, _, AmmoType);

	}
}

public void setAmmo(int client, int slot, int size){
	new weaponent = GetPlayerWeaponSlot(client, slot);
	if (weaponent > 0 && IsValidEntity(weaponent))
	{
		SetEntProp(weaponent, Prop_Send, "m_iClip1", size);
	}
}

