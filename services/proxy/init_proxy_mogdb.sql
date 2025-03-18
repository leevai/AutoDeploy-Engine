DELETE FROM dbaas.os_host where host_id='8052f3c4-5f92-4637-869e-e2305b60933b';
INSERT INTO dbaas.os_host
(host_id, host_name, os_admin_user, os_type, tenant_id, host_ip, eth_name, subnet_mask, os_version, "version", state,
 "type", host_port, init_home, log_home, os_password, proxy_id, environment, agent_version, "describe", outside_ip,
 inside_ip, cluster_name, cluster_id, hardware_platform, os_manufacturer, os_kernel, cpu_type, cpu_core_num,
 memory_size, machine_type, os_start_time, jdk_version, build_date, proxy_version, run_user, is_root_install,
 is_default, proxy_start_time, create_time, row_change_time)
VALUES ('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', '#hostname#', NULL, 'Linux', 'a24c36da7f1d436d82fabfa61e2795b2',
        '#hostip#', NULL, NULL, '#osversion#', 0, '1', '1', '8200', '/zcloud/proxy', '/zcloud/proxy/log', NULL,
        NULL, NULL, '', '无描述', '#hostip#', '#hostip#', '#hostip#', '7c26c50a-7a7d-4c6a-8227-c98075ab5da1',
        '#hardwareplatform#', 'RedHat', '#oskernel#', '#cputype#', '#cpunum#', '#memorysize#',
        '#machinetype#', pg_systimestamp(), '', pg_systimestamp(), '#proxyversion#', 'zcloud', 1, 1, pg_systimestamp(), pg_systimestamp(),
        pg_systimestamp())
    ON DUPLICATE KEY UPDATE host_name='#hostname#',
                         host_ip='#hostip#',
                         outside_ip='#hostip#',
                         inside_ip='#hostip#',
                         cluster_name='#hostip#';

delete from dbaas.os_host_component where node_id = '8e621ae3-02bb-4bbc-9f08-863d9d6f9d62';
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_node_exporter', 8211, 'zcloud_node_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_oracle_exporter', 8203, 'zcloud_oracle_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1, pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_redis_exporter', 8204, 'zcloud_redis_exporter', '', pg_systimestamp(), '可用', pg_systimestamp(), '无描述', 1, pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_postgresql_exporter', 8205, 'zcloud_postgresql_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'rceEngine', 8212, 'rceEngine', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'chisel', 8222, 'chisel', '', pg_systimestamp(), '可用', pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_zoramon', 8214, 'zcloud_zoramon', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_db2_exporter', 8216, 'zcloud_db2_exporter', '', pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_slowmon_collector', 8217, 'zcloud_slowmon_collector', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_custom_sql_exporter', 8218, 'zcloud_custom_sql_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(), pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_mongodb_exporter', 8219, 'zcloud_mongodb_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_mssql_exporter', 8220, 'zcloud_mssql_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_commondb_exporter', 8221, 'zcloud_commondb_exporter', '',  pg_systimestamp(), '可用', pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_mysql_exporter', 8202, 'zcloud_mysql_exporter', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(), pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_zdbmon_collector', 9915, 'zcloud_zdbmon_collector', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;
INSERT IGNORE INTO dbaas.os_host_component
(node_id, component_name, port, component_type, component_version, build_date, "status", start_time, "describe", host_type, create_time, row_change_time)
VALUES('8e621ae3-02bb-4bbc-9f08-863d9d6f9d62', 'zcloud_proxy_nginx', 8215, 'zcloud_proxy_nginx', '',  pg_systimestamp(), '可用',  pg_systimestamp(), '无描述', 1,  pg_systimestamp(),  pg_systimestamp()) ;


