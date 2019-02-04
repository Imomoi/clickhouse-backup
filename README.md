# Clickhouse Backup Tool

## Description

This application backup databases and tables from local clickhouse instance

## Usage

To run application:

1. Follow installation instructions to install application itself and all required dependencies
2. Configure permissions to access Clickhouse shadow directory (need read and write access) and metadata directory (need read access)
3. Go to application directory
4. Make `config.yml` file in application directory
5. Run

        ~/infrastructure.clickhouse_backup/$ ./bin/clickhouse_backup config.yml

## Installation

To run this application you need to install MRI Ruby and other prerequisites.

I'll recomend to use RVM (rvm.io) and follow installation instructions for your OS environment.

Cause of specific Clickhouse behaviour Multi-User installed RVM is required (not per user)

> Following instruction on RVM installation may be outdated!

    ~/$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
    ~/$ \curl -sSL https://get.rvm.io | sudo bash -s stable

Now download application from bitbucket and install dependencies

    ~/$ git clone git@bitbucket.org:mediaparts/infrastructure.clickhouse_backup.git

Install and use latest stable Ruby 2.5 for clickhouse user. Run this commands

    ~/$ source /usr/local/rvm/scripts/rvm
    ~/$ rvm install 2.5
    ~/$ rvm use 2.5 --default
    ~/$ cd infrastructure.clickhouse_backup
    ~/infrastructure.clickhouse_backup/$ bundle install

Let's configure our application.

## Configuration

### Basic configuration

After you finish installation step you can use basic configuration file from `examples` directory.

    ~/infrastructure.clickhouse_backup/$ cp examples/config.yml.example config.yml

With this configuration application would use default options for Clickhouse connection and file locations, set backup location to current user HOME directory and will not upload backups to anywhere.

To fine configure application read next sections.

### Configuration file overview

Configuration file sections:

1. `clickhouse` - this section describes local clickhouse instance configuration
2. `backup` - this section describes `.tar` file making rules
3. `destinations` - this section describes backup remote storage options
4. `log_level` - this parameter describes logging level. Can be one of:
   - `DEBUG`
   - `INFO`
   - `WARN`
   - `ERROR`
5. `ignored_databases` - this parameter describes which databases should be ignored during buckup. Simple YAML array of strings

### Section `clickhouse`

> Required section

1. `connection` - connection parameters

   1. `scheme` - connection protocol `http` or `https`
   2. `host` - `localhost`, cause it cann't backup remote databases (may be nfs? ;)
   3. `port` - Clickhouse JSON API port
2. `shadow` - full path to shadow directory
3. `metadata` - metadata files location. This option can be in following formats:
   1. `REAL_PATH:CLICKHOUSE_INTERNAL_PATH` - this format will remap internal clickhouse path to real location on file system (for example in case you used symlinks)
   2. `PATH` - must be equal to internal clickhouse path

### Section `backup`

> Required section

1. `archive-prefix` - prefix for archive name
2. `temp-file-location` - path to location, where archive file would be stored. Can be relative path

### Section `destinations`

> Optional section

For now applications only support AWS S3 storage.

1. `s3` - configuration for AWS S3
    1. `bucket` - where to store backups
    2. `key` - AMI user API Access key ID
    3. `secret` - AMI user API Secret access key
    4. `region` - storage region

### Example

Following example describes config for Clickhouse running under docker on Windows with uploading to ASW S3

    ---
    clickhouse:
      connection:
        scheme: http
        host: localhost
        port: 32770
      shadow: "/mnt/c/Users/Backup/Documents/Kitematic/clickhouse-server/var/lib/clickhouse/shadow"
      metadata: "/var/lib/clickhouse/metadata:/mnt/c/Users/Viacheslav/Documents/Kitematic/clickhouse-server/var/lib/clickhouse/metadata"

    backup:
      archive-prefix: 'backup-local-'
      temp-file-location: "~/"

    destinations:
        s3: # AMI user: clickhouse-backup
          bucket: 'clickhouse-backup'
          key: 'AKIAJ...'
          secret: '6gVkcm...'
          region: 'us-east-1'

    log_level: DEBUG

    ignored_databases:
      - default
      - system
      - healthmon

## CRON

Example `crontab` configuration:

    0 0 * * * /usr/local/infrastructure.clickhouse_backup/examples/crontask.sh

## Errors and troubleshooting

### Permission denied on cleanup stage

If during cleanup stage you see lots of messages like in example, possibly you run 
backup not under Clickhouse DB user (by default - `clickhouse`)

    rm: cannot remove '1/data/..': Permission denied

### Unsecure world writable dir

If during cleanup stage you get error please follow instructions below.

    parent directory is world writable, FileUtils#remove_entry_secure does not work; abort: (...) (parent directory mode ...)

Clickhouse shadow directory must not be world writable. To check it follow next instructions

    clickhose-data-root$ ls --full

If you see something like this - it's OK (owner user: `clickhouse`, group: `clickhouse`, other - nonwritable)

    drwxrwxrwx  11 clickhouse clickhouse       4096 2018-11-14 09:18:16.066608906 +0000 data
    drwxrwxr-x 247 clickhouse clickhouse      12288 2018-12-07 08:40:46.097357747 +0000 shadow

If you see in output something like in next example:

    drwxrwxrwx  11 clickhouse clickhouse       4096 2018-11-14 09:18:16.066608906 +0000 data
    drwxrwxrwx 247 root       root            12288 2018-12-07 08:40:46.097357747 +0000 shadow

Fix permissions for clickhouse directory (here e assume that your Clickhouse running under `clickhouse` user)

    clickhose-data-root$ sudo chown clickhouse:clickhouse shadow
    clickhose-data-root$ sudo chmod o-w shadow/

## Data restoration

After unpacking backup archive you will find `restore.sh` scripts in root directory, each database directories and each table directories.

To make full restoration just run `restore.sh` in root directory.