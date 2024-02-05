-- Make partioned table
CREATE TABLE IF NOT EXISTS v3.trips_master
(   
    id UUId,
    device_id character varying(60) COLLATE pg_catalog."default",
    started_at timestamp with time zone,
    ended_at timestamp with time zone,
    move_started_at timestamp with time zone,
    move_ended_at timestamp with time zone,
    fleet_id integer,
    recv_time_started_at timestamp with time zone,
    recv_time_ended_at timestamp with time zone,
    duration double precision,
    distance double precision,
    hide boolean,
    max_speed double precision,
    is_day_time boolean,
    geo_state_id integer,
    distance_can double precision,
    CONSTRAINT trip_master_pkey PRIMARY KEY (id, started_at)
)   partition by range (started_at);

-- function for auto creating partitions
create or replace function v3.create_trip_if_not_exists(started_at timestamp with time zone) returns void
    as $body$
        declare monthStart date := date_trunc('month', started_at);
        declare monthEndExclusive date := monthStart + interval '1 month';
        declare tableName text := 'trip_' || to_char(started_at, 'YYYYmm');
    begin
        SET search_path TO v3;
        if to_regclass(tableName) is null then
            execute format('create table %I partition of trips_master for values from (%L) to (%L)', tableName, monthStart, monthEndExclusive);
            execute format('create index on %I (started_at)', tableName);
            execute format('create index on %I (started_at, device_id)', tableName);
        end if;
        SET search_path TO public;
    end;
$body$ language plpgsql;

-- View to represent the whole partiontions
create or replace view v3.trips as select * from v3.trips_master;

-- Rule for inserting into the view
CREATE OR REPLACE RULE auto_call_create_partition_trip_if_not_exists AS
ON INSERT TO v3.trips
DO INSTEAD
  ( SELECT v3.create_trip_if_not_exists(new.started_at) AS create_trip_if_not_exists;
	INSERT INTO v3.trips_master(id, device_id, started_at, ended_at, move_started_at, move_ended_at, fleet_id, recv_time_started_at, recv_time_ended_at, duration, distance, hide, max_speed, is_day_time, geo_state_id, distance_can)
	VALUES (new.id, new.device_id, new.started_at, new.ended_at, new.move_started_at, new.move_ended_at, new.fleet_id, new.recv_time_started_at, new.recv_time_ended_at, new.duration, new.distance, new.hide, new.max_speed, new.is_day_time, new.geo_state_id, new.distance_can)
   RETURNING v3.trips_master.*;
  );