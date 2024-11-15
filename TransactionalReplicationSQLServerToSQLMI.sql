DECLARE @SourceServerName NVARCHAR(255) = @@SERVERNAME,
    @SourceServerPassword NVARCHAR(255) = '',
	@TargetServerName NVARCHAR(255) = '',
	@TargetServerAdminUsername NVARCHAR(255) = '', 
	@TargetServerPassword NVARCHAR(255) = '',
	@NewDistributionDatabaseName NVARCHAR(255) = 'distribution', 
	@DistributionPublisherWorkingDirectory NVARCHAR(512) = 'C:\replication\snapshot', --Path for the snapshot folder on the source machine
	@ReplicationSourceDatabaseName NVARCHAR(255) = 'migration-source',
	@ReplicationTargetDatabaseName NVARCHAR(255) = 'migration-target',
	@PublicationName NVARCHAR(255) = 'publication',
	@ArticleName NVARCHAR(255) = 'Profiles',
	@ArticleTableName NVARCHAR(255) = 'Profiles';

PRINT @@SERVERNAME

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Agent XPs', 1;
RECONFIGURE;

USE master;
EXEC sp_adddistributor 
    @distributor = @TargetServerName, 
    @password = @SourceServerPassword;

EXEC sp_adddistributiondb 
    @database = @NewDistributionDatabaseName,
    @security_mode = 1;
RECONFIGURE;

EXEC sp_adddistpublisher 
    @publisher = @TargetServerName,
    @distribution_db = @NewDistributionDatabaseName,
    @working_directory = @DistributionPublisherWorkingDirectory, -- Path for snapshot folder
    @security_mode = 1;

EXEC sp_helpdistributor;

USE [master];
EXEC sp_replicationdboption 
    @dbname = @ReplicationSourceDatabaseName, 
    @optname = N'publish', 
    @value = N'true';

SELECT is_distributor, name  
FROM sys.servers 
WHERE name = @SourceServerName;

USE [migration-source];
EXEC sp_addpublication 
    @publication = @PublicationName,
    @description = N'Transactional publication of database changes',
    @sync_method = N'native', 
    @retention = 0, 
    @allow_push = N'true', 
    @allow_pull = N'false', 
    @allow_anonymous = N'false', 
    @enabled_for_internet = N'false', 
    @snapshot_in_defaultfolder = N'true', 
    @compress_snapshot = N'false', 
    @ftp_port = 21, 
    @allow_subscription_copy = N'false', 
    @add_to_active_directory = N'false', 
    @repl_freq = N'continuous', 
    @status = N'active',
    @independent_agent = N'true',
    @immediate_sync = N'false';

EXEC sp_helppublication @publication = @PublicationName;

EXEC sp_addarticle 
	@publication = @PublicationName, 
	@article = @ArticleName,
	@source_object = @ArticleTableName, 
	@type = N'logbased', 
	@description = N'YourTableName replication article', 
	@ins_cmd = N'SQL', 
	@del_cmd = N'SQL', 
	@upd_cmd = N'SQL';

-- Create snapshot for publication
EXEC sp_addpublication_snapshot 
    @publication = @PublicationName, 
    @frequency_type = 1, 
    @frequency_interval = 1, 
    @frequency_relative_interval = 0, 
    @frequency_recurrence_factor = 1, 
    @frequency_subday = 8, 
    @frequency_subday_interval = 1, 
    @active_start_time_of_day = 0, 
    @active_end_time_of_day = 235959, 
    @active_start_date = 20241023;

USE [migration-source];
EXEC sp_addsubscription 
    @publication = @PublicationName, 
    @subscriber = @TargetServerName, 
    @destination_db = @ReplicationTargetDatabaseName, 
    @subscription_type = N'push', 
    @sync_type = N'automatic', 
    @article = N'all', 
    @update_mode = N'read only', 
    @subscriber_type = 0;

-- Add the subscription agent job
EXEC sp_addpushsubscription_agent 
    @publication = @PublicationName, 
    @subscriber = @TargetServerName, 
    @subscriber_db = @ReplicationTargetDatabaseName, 
    @subscriber_login = @TargetServerAdminUsername, 
    @subscriber_password = @TargetServerPassword, 
    @subscriber_security_mode = 0;