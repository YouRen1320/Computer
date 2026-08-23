create table work_order(
  tenant_id varchar(64) not null,
  id varchar(64) not null,
  status varchar(32) not null,
  version bigint not null,
  primary key(tenant_id,id),
  check (version >= 0)
);
