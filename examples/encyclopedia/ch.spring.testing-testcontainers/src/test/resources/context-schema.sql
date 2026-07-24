create table if not exists work_order(tenant_id varchar(32),id varchar(32),status varchar(16),primary key(tenant_id,id));
merge into work_order key(tenant_id,id) values('tenant-a','wo-1','CREATED');
