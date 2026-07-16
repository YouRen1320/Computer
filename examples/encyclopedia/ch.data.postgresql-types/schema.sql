BEGIN;

CREATE SCHEMA IF NOT EXISTS factorycare;
DROP TABLE IF EXISTS factorycare.device_tag;
DROP TABLE IF EXISTS factorycare.tag;
DROP TABLE IF EXISTS factorycare.device;
DROP DOMAIN IF EXISTS factorycare.asset_code;

CREATE DOMAIN factorycare.asset_code AS text
  CHECK (VALUE ~ '^SN-[0-9]{3}$');

CREATE TABLE factorycare.device (
  device_id uuid DEFAULT uuidv7(),
  serial_number factorycare.asset_code NOT NULL,
  status text NOT NULL,
  vendor_metadata jsonb,
  search_aliases text[],
  CONSTRAINT device_pkey PRIMARY KEY (device_id),
  CONSTRAINT device_serial_number_key UNIQUE (serial_number),
  CONSTRAINT device_status_check
    CHECK (status IN ('ACTIVE', 'MAINTENANCE', 'RETIRED')),
  CONSTRAINT device_vendor_metadata_object_check
    CHECK (vendor_metadata IS NULL OR jsonb_typeof(vendor_metadata) = 'object'),
  CONSTRAINT device_search_aliases_check
    CHECK (
      search_aliases IS NULL
      OR (cardinality(search_aliases) <= 5 AND array_position(search_aliases, NULL) IS NULL)
    )
);

CREATE TABLE factorycare.tag (
  tag_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tag_name text NOT NULL UNIQUE
);

CREATE TABLE factorycare.device_tag (
  device_id uuid NOT NULL REFERENCES factorycare.device (device_id),
  tag_id bigint NOT NULL REFERENCES factorycare.tag (tag_id),
  PRIMARY KEY (device_id, tag_id)
);

ROLLBACK;
