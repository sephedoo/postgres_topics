CREATE EXTENSION btree_gist;

ALTER TABLE blocks
  add constraint unique_time_range
  -- multiple columns
 EXCLUDE USING gist(device_id WITH =, tstzrange(started_at, ended_at) WITH &&)

