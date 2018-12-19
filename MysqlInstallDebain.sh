#!/bin/sh

# User Variables
RootPwd='154860c306a3b969f484440e6858775b'
MysqlPort='3306'

#1
ServiceId=`ifconfig eth0|grep inet|grep netmask|awk '{print $2}'|awk -F '.' '{print $3,$4}'|sed "s/ //g"`
InnodbBufferSize=`cat /proc/meminfo|grep MemTotal|awk '{printf("%.f",$2/1024/1024*0.6-1)}'`

# Function
function SetSystemVariables(){
    echo 0 > /proc/sys/vm/swappiness
    echo "vm.swappiness = 0" >> /etc/sysctl.conf
    sysctl -p
}

function CreateUserAndDir(){
    groupadd mysql
    useradd -r -g mysql -s /bin/false mysql
    mkdir -p /data/mysql/data/${MysqlPort}/
    mkdir -p /data/mysql/log/${MysqlPort}/{binlog,errorlog,slowlog,relaylog}
    mkdir -p /data/mysql/scripts/${MysqlPort}/
    chown -R mysql:mysql /data/mysql/
    chown -R mysql:mysql /usr/local/mysql
    rm -rf /etc/mysql/
    rm -rf /etc/my.cnf
    mkdir -p /etc/mysql/
}

function CreateMysqlUser(){
    MysqlTmpPwd=`cat /data/mysql/log/${MysqlPort}/errorlog/mysql-error.log |grep root@localhost:|awk -F ':' '{print $5}'|sed "s/ //g"`

    # Change root password
    /usr/local/mysql/bin/mysql -uroot -p${mysqlpwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"alter user root@'localhost' identified by '${RootPwd}';"

    # Create Replication User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"grant replication slave,replication client on *.* to repl@'10.%' identified by '3b5ebd5bee40acba9568d832d21cdf93';"

    # Create Secondary Root User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"grant all on *.* to ezroot@'localhost' identified by '7890uiop;lkj.,mn' with grant option;"

    # Create Remote User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"grant select,update,delete,insert,create on *.* to dba_rw@'10.%' identified by 'wZsgltgMW4NtoG4P';"

    # Create Read-Only User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"grant select on *.* to devro@'10.%' identified by 'rYfulPFLeQ1v9Zb';"

    # Create Bi User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"grant select on *.* to datadump_bi@'10.%' identified by 'UweY9PVrQlFpZCcS';"

    # Create PMM User
    /usr/local/mysql/bin/mysql -uroot -p${RootPwd} --socket=/data/mysql/data/${MysqlPort}/mysql.sock --connect-expired-password -e"GRANT SELECT, PROCESS, SUPER, REPLICATION CLIENT, RELOAD ON *.* TO 'pmm_user'@'localhost' IDENTIFIED BY 'X1c1SvXDcfHGrW7X';GRANT SELECT, UPDATE, DELETE, DROP ON performance_schema.* TO 'pmm_user'@' localhost';"
}

function RestartMysql(){
    /etc/init.d/mysqld_${MysqlPort} restart
}

function InstallMysql(){
    SetSystemVariables

    cd /tmp
#    wget https://www.percona.com/downloads/Percona-Server-LATEST/Percona-Server-5.7.24-26/binary/tarball/Percona-Server-5.7.24-26-Linux.x86_64.ssl100.tar.gz
    tar -xvzf Percona-Server-5.7.24-26-Linux.x86_64.ssl100.tar.gz
    mv Percona-Server-5.7.24-26-Linux.x86_64.ssl100 /usr/local/mysql

    cat > /etc/mysql/my_${MysqlPort}.cnf  << EOF
[mysql]
# CLIENT #
port = ${MysqlPort}
socket = /data/mysql/data/${MysqlPort}/mysql.sock
default-character-set = utf8mb4

[mysqld]
# GENERAL #
user = mysql
port = ${MysqlPort}
default-storage-engine = InnoDB
socket = /data/mysql/data/${MysqlPort}/mysql.sock
pid-file = /data/mysql/data/${MysqlPort}/mysql.pid
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
autocommit = 1
lower_case_table_names = 1
log_bin_trust_function_creators = 1
server_id = ${ServiceId}
transaction_isolation = READ-COMMITTED
sql_mode = "NO_ENGINE_SUBSTITUTION"
secure-file-priv = ""

# CONNECTION #
interactive_timeout = 1800
wait_timeout = 1800
lock_wait_timeout = 1800
skip_name_resolve = 1

# MyISAM #
key-buffer-size = 32M
#myisam-recover = FORCE,BACKUP

# SAFETY #
max-allowed-packet = 16M
max-connect-errors = 1000000

# DATA STORAGE #
datadir = /data/mysql/data/${MysqlPort}/

# BINARY LOGGING #
log-bin = /data/mysql/log/${MysqlPort}/binlog/mysql-bin
expire-logs-days = 7
sync-binlog = 1
binlog_format = ROW

# CACHES AND LIMITS #
tmp-table-size = 32M
max-heap-table-size = 32M
query-cache-type = 0
query-cache-size = 0
max-connections = 1024
thread-cache-size = 50
open-files-limit = 65535
table-definition-cache = 4096
table-open-cache = 4096

# INNODB #
innodb-flush-method = O_DIRECT
innodb-log-files-in-group = 2
innodb-log-file-size = 1G
innodb-flush-log-at-trx-commit = 1
innodb-file-per-table = 1
innodb-buffer-pool-size = ${InnodbBufferSize}G
innodb_buffer_pool_instances = 4
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_at_shutdown = 1
innodb_lru_scan_depth = 4096
innodb_lock_wait_timeout = 5
innodb_io_capacity = 1000
innodb_io_capacity_max = 2000
#innodb_undo_logs = 128
#innodb_undo_tablespaces = 3
innodb_flush_neighbors = 1
innodb_log_buffer_size = 64M
innodb_purge_threads = 4
innodb_large_prefix = 1
innodb_thread_concurrency = 64
innodb_print_all_deadlocks = 1
innodb_sort_buffer_size = 64M
innodb_write_io_threads = 16
innodb_read_io_threads = 16
innodb_stats_persistent_sample_pages = 64
innodb_autoinc_lock_mode = 2
innodb_open_files = 4096

# LOGGING #
log-error = /data/mysql/log/${MysqlPort}/errorlog/mysql-error.log
log-queries-not-using-indexes = 0
slow-query-log = 1
slow-query-log-file = /data/mysql/log/${MysqlPort}/slowlog/mysql-slow.log
long_query_time = 1
log-slave-updates = 1
long_query_time = 1
binlog-rows-query-log-events = 1
log-bin-trust-function-creators = 1

# REPLICATION #
master_info_repository = TABLE
relay_log_info_repository = TABLE
relay_log = /data/mysql/log/${MysqlPort}/relaylog/mysql-relay.log
relay_log_recovery = 1
slave_skip_errors = ddl_exist_errors
slave-rows-search-algorithms = 'INDEX_SCAN,HASH_SCAN'
report-host = 1

# SEMI REPLICATION #
plugin_load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
#rpl_semi_sync_master_enabled = 1
#rpl_semi_sync_master_timeout = 3000
#rpl_semi_sync_slave_enabled = 1

# GTID REPLICATION #
enforce_gtid_consistency = 1
gtid_mode = on
binlog_gtid_simple_recovery=1

# new innodb settings #
innodb_buffer_pool_dump_pct = 40
innodb_page_cleaners = 4
#innodb_undo_log_truncate = 1
#innodb_max_undo_log_size = 1G
innodb_purge_rseg_truncate_frequency = 128

# new replication settings #
slave-parallel-type = LOGICAL_CLOCK
slave-parallel-workers = 16
slave_preserve_commit_order = 1
slave_transaction_retries= 128

# other change settings #
log_timestamps = system
show_compatibility_56 = on
EOF

    echo "" >> /etc/profile
    echo "export PATH=\$PATH:/usr/local/mysql/bin" >> /etc/profile
    cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld_${MysqlPort}
    sed -i "s/Percona-Server-5.7.18-15-Linux.x86_64.ssl100/mysql/g" /etc/init.d/mysqld_${MysqlPort}
    
#    RestartMysql
#    CreateMysqlUser()
#    
#    sed -i "s/        //g" /etc/mysql/my_${MysqlPort}.cnf
#    sed -i "s/#rpl_semi_sync_master_enabled = 1/rpl_semi_sync_master_enabled = 1/g" /etc/mysql/my_${MysqlPort}.cnf
#    sed -i "s/#rpl_semi_sync_master_timeout = 3000/rpl_semi_sync_master_timeout = 3000/g" /etc/mysql/my_${MysqlPort}.cnf
#    sed -i "s/#rpl_semi_sync_slave_enabled = 1/rpl_semi_sync_slave_enabled = 1/g" /etc/mysql/my_${MysqlPort}.cnf
#    
#    RestartMysql

}

function InstallPtTool(){
    cd /tmp
    wget https://repo.percona.com/apt/percona-release_0.1-4.$(lsb_release -sc)_all.deb
    dpkg -i percona-release_0.1-4.$(lsb_release -sc)_all.deb
    apt-get update
    apt-get -y install percona-toolkit
    apt-get -y install percona-xtrabackup-24
}

function InstallPmm(){
    cd /tmp
    dpkg -i pmm-client_1.1.5-1.trusty_amd64.deb
    apt-get -y install pmm-client
    # pmm-admin config --server 10.20.90.73:80 --server-user ezbuy --server-password 86cd3c7c3e874844375aeb1c0ed3aa61
    # pmm-admin add linux:metrics
    # pmm-admin add mysql --user pmm_user --password X1c1SvXDcfHGrW7X
    # pmm-admin add mysql:queries --user pmm_user --password X1c1SvXDcfHGrW7X
}

# Main
InstallMysql
