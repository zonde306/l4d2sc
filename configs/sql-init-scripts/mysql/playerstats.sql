DELIMITER //
CREATE FUNCTION IF NOT EXISTS `APPLY_MODIFIER`(
	`name` VARCHAR(50),
	`value` INT
) RETURNS double
BEGIN
	DECLARE modifier FLOAT;
	
	SELECT s.modifier INTO modifier FROM STATS_SKILLS s WHERE s.name = name;
	
	IF modifier IS NULL 
	THEN
		SELECT 1.0 INTO modifier;
	END IF;
		
	RETURN value * modifier;
END//
DELIMITER ;

CREATE TABLE IF NOT EXISTS `STATS_PLAYERS` (
  `steam_id` varchar(64) NOT NULL,
  `last_known_alias` varchar(255) DEFAULT NULL,
  `last_join_date` timestamp NULL DEFAULT current_timestamp(),
  `hide_extra_stats` tinyint(4) DEFAULT 0,
  `survivor_killed` int(10) unsigned NOT NULL DEFAULT 0,
  `survivor_incapped` int(10) unsigned DEFAULT 0,
  `infected_killed` int(10) unsigned NOT NULL DEFAULT 0,
  `infected_headshot` int(10) unsigned NOT NULL DEFAULT 0,
  `skeet_hunter_sniper` int(11) NOT NULL DEFAULT 0,
  `skeet_hunter_shotgun` int(11) NOT NULL DEFAULT 0,
  `skeet_hunter_melee` int(11) NOT NULL DEFAULT 0,
  `skeet_tank_rock` int(11) NOT NULL DEFAULT 0,
  `witch_crown_standard` int(11) NOT NULL DEFAULT 0,
  `witch_crown_draw` int(11) NOT NULL DEFAULT 0,
  `boomer_pop` int(11) NOT NULL DEFAULT 0,
  `charger_level` int(11) NOT NULL DEFAULT 0,
  `smoker_tongue_cut` int(11) NOT NULL DEFAULT 0,
  `hunter_dead_stop` int(11) NOT NULL DEFAULT 0,
  `boomer_quad` int(11) NOT NULL DEFAULT 0,
  `hunter_twenty_five` int(11) NOT NULL DEFAULT 0,
  `death_charge` int(11) NOT NULL DEFAULT 0,
  `tank_rock_hits` int(11) NOT NULL DEFAULT 0,
  `create_date` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`steam_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `STATS_SKILLS` (
  `name` varchar(50) NOT NULL,
  `modifier` float DEFAULT NULL,
  `update_date` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE VIEW IF NOT EXISTS `STATS_VW_PLAYER_RANKS` AS select `b`.`steam_id` AS `steam_id`,`b`.`last_known_alias` AS `last_known_alias`,date_format(`b`.`last_join_date`,'%Y-%m-%d %h:%i:%s %p') AS `last_join_date`,`b`.`survivor_killed` AS `survivor_killed`,`b`.`survivor_incapped` AS `survivor_incapped`,`b`.`infected_killed` AS `infected_killed`,`b`.`infected_headshot` AS `infected_headshot`,round(`b`.`total_points`,2) AS `total_points`,`b`.`rank_num` AS `rank_num`,date_format(`b`.`create_date`,'%Y-%m-%d %h:%i:%s %p') AS `create_date` from (select `s`.`steam_id` AS `steam_id`,`s`.`last_known_alias` AS `last_known_alias`,`s`.`last_join_date` AS `last_join_date`,`s`.`survivor_killed` AS `survivor_killed`,`s`.`survivor_incapped` AS `survivor_incapped`,`s`.`infected_killed` AS `infected_killed`,`s`.`infected_headshot` AS `infected_headshot`,`APPLY_MODIFIER`('survivor_incapped',`s`.`survivor_incapped`) + `APPLY_MODIFIER`('survivor_killed',`s`.`survivor_killed`) + `APPLY_MODIFIER`('infected_killed',`s`.`infected_killed`) + `APPLY_MODIFIER`('infected_headshot',`s`.`infected_headshot`) AS `total_points`,row_number() over ( order by `s`.`survivor_incapped` + `s`.`survivor_killed` + `s`.`infected_headshot` + `s`.`infected_killed` desc,`s`.`create_date`) AS `rank_num`,`s`.`create_date` AS `create_date` from `STATS_PLAYERS` `s`) `b`;

CREATE VIEW IF NOT EXISTS `STATS_VW_PLAYER_RANKS_EXTRAS` AS select `b`.`steam_id` AS `steam_id`,`b`.`last_known_alias` AS `last_known_alias`,date_format(`b`.`last_join_date`,'%Y-%m-%d %h:%i:%s %p') AS `last_join_date`,`b`.`survivor_killed` AS `survivor_killed`,`b`.`survivor_incapped` AS `survivor_incapped`,`b`.`infected_killed` AS `infected_killed`,`b`.`infected_headshot` AS `infected_headshot`,`b`.`skeet_hunter_sniper` AS `skeet_hunter_sniper`,`b`.`skeet_hunter_shotgun` AS `skeet_hunter_shotgun`,`b`.`skeet_hunter_melee` AS `skeet_hunter_melee`,`b`.`skeet_tank_rock` AS `skeet_tank_rock`,`b`.`witch_crown_standard` AS `witch_crown_standard`,`b`.`witch_crown_draw` AS `witch_crown_draw`,`b`.`boomer_pop` AS `boomer_pop`,`b`.`charger_level` AS `charger_level`,`b`.`smoker_tongue_cut` AS `smoker_tongue_cut`,`b`.`hunter_dead_stop` AS `hunter_dead_stop`,`b`.`boomer_quad` AS `boomer_quad`,`b`.`hunter_twenty_five` AS `hunter_twenty_five`,`b`.`death_charge` AS `death_charge`,`b`.`tank_rock_hits` AS `tank_rock_hits`,`b`.`total_points` AS `total_points`,`b`.`rank_num` AS `rank_num`,date_format(`b`.`create_date`,'%Y-%m-%d %h:%i:%s %p') AS `create_date` from (select `s`.`steam_id` AS `steam_id`,`s`.`last_known_alias` AS `last_known_alias`,`s`.`last_join_date` AS `last_join_date`,`s`.`survivor_killed` AS `survivor_killed`,`s`.`survivor_incapped` AS `survivor_incapped`,`s`.`infected_killed` AS `infected_killed`,`s`.`infected_headshot` AS `infected_headshot`,`s`.`skeet_hunter_sniper` AS `skeet_hunter_sniper`,`s`.`skeet_hunter_shotgun` AS `skeet_hunter_shotgun`,`s`.`skeet_hunter_melee` AS `skeet_hunter_melee`,`s`.`skeet_tank_rock` AS `skeet_tank_rock`,`s`.`witch_crown_standard` AS `witch_crown_standard`,`s`.`witch_crown_draw` AS `witch_crown_draw`,`s`.`boomer_pop` AS `boomer_pop`,`s`.`charger_level` AS `charger_level`,`s`.`smoker_tongue_cut` AS `smoker_tongue_cut`,`s`.`hunter_dead_stop` AS `hunter_dead_stop`,`s`.`boomer_quad` AS `boomer_quad`,`s`.`hunter_twenty_five` AS `hunter_twenty_five`,`s`.`death_charge` AS `death_charge`,`s`.`tank_rock_hits` AS `tank_rock_hits`,`APPLY_MODIFIER`('survivor_incapped',`s`.`survivor_incapped`) + `APPLY_MODIFIER`('survivor_killed',`s`.`survivor_killed`) + `APPLY_MODIFIER`('infected_killed',`s`.`infected_killed`) + `APPLY_MODIFIER`('infected_headshot',`s`.`infected_headshot`) + `APPLY_MODIFIER`('skeet_hunter_sniper',`s`.`skeet_hunter_sniper`) + `APPLY_MODIFIER`('skeet_hunter_shotgun',`s`.`skeet_hunter_shotgun`) + `APPLY_MODIFIER`('skeet_hunter_melee',`s`.`skeet_hunter_melee`) + `APPLY_MODIFIER`('skeet_tank_rock',`s`.`skeet_tank_rock`) + `APPLY_MODIFIER`('witch_crown_standard',`s`.`witch_crown_standard`) + `APPLY_MODIFIER`('witch_crown_draw',`s`.`witch_crown_draw`) + `APPLY_MODIFIER`('boomer_pop',`s`.`boomer_pop`) + `APPLY_MODIFIER`('charger_level',`s`.`charger_level`) + `APPLY_MODIFIER`('smoker_tongue_cut',`s`.`smoker_tongue_cut`) + `APPLY_MODIFIER`('hunter_dead_stop',`s`.`hunter_dead_stop`) + `APPLY_MODIFIER`('boomer_quad',`s`.`boomer_quad`) + `APPLY_MODIFIER`('hunter_twenty_five',`s`.`hunter_twenty_five`) + `APPLY_MODIFIER`('death_charge',`s`.`death_charge`) + `APPLY_MODIFIER`('tank_rock_hits',`s`.`tank_rock_hits`) AS `total_points`,row_number() over ( order by `s`.`survivor_incapped` + `s`.`survivor_killed` + `s`.`infected_headshot` + `s`.`infected_killed` + `s`.`skeet_hunter_sniper` + `s`.`skeet_hunter_shotgun` + `s`.`skeet_hunter_melee` + `s`.`skeet_tank_rock` + `s`.`witch_crown_standard` + `s`.`witch_crown_draw` + `s`.`boomer_pop` + `s`.`charger_level` + `s`.`smoker_tongue_cut` + `s`.`hunter_dead_stop` + `s`.`boomer_quad` + `s`.`hunter_twenty_five` + `s`.`death_charge` + `s`.`tank_rock_hits` desc,`s`.`create_date`) AS `rank_num`,`s`.`create_date` AS `create_date` from `STATS_PLAYERS` `s`) `b`;
