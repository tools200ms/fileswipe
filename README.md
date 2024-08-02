# FilesWipe

**FilesWipe** is a set of Bash scripts developed to do a simple job:

* removal of an old (backup and other) files

In the case of a small databases it's OK to set up periodic database dumps. So after all there is a list of files such as `backup-<dump date>_dbdump.sql.xz`.

To ensure that a data set is not growing 'limitlessly', there is the need for
an old file removal. Thus, **FilesWipe** has been developed, additionally it
provides:

* File removal policy
* Configuration file
* Countermeasures to prevent from purging all data

It's a `bash` shell script, thus it is practically 'dependency free' making it a good solution for embedded systems. It can be used to purge mentioned database dump files, but also other periodic backup files or cache files.

## Usage
This packege comes with two scripts: 
* fileswipe - cleanup directory indicated by command's argument
* fileswipe-all - cleanup directories indicated in `/etc/fwtab` file

## Setup
Install by simply coping `fileswipe` and `fileswipe-all` to `/usr/local/bin`:
```bash
git clone https://github.com/tools200ms/fileswipe.git
cd fileswipe/
sudo cp fileswipe fileswipe-run /usr/local/bin/
sudo chmod +x /usr/local/bin/fileswipe*
```

## Direct call 'fileswipe'
**FilesWipe** can be run directly by command:
````bash
fileswipe /path/to/directory 1week 2
````
where:

* `/path/to/directory` is a path to directory with files designed for a potential removal.

* `1week` is removal `defer time`, files that are younger will be keeped, only older files will be considered for removal in accordance with `removal frequency` that is given as a next argument.

* `2` is a `removal frequency`, `2` means to remove every second file, `1` means to remove all files that passed `defer time`, `3` or `4` tells to remove every third or forth file.


`defer time` is a number directly followed by `day`, `days`, `week` or `weeks` keyword.

**NOTE 1:**
**FilesWipe** will not remove files even if its `defer time` has passed if there is too little files in a directory. This is to prevent data loss in the case if directory has not been feed with a fresh data.


**NOTE 2:**
**FilesWipe** determinates file age by reading *last modification* time.

## '/etc/fwtab' file
The list of directories and removal policy can be added into `/etc/fwtab` file:
```fstab
# This is a content of '/etc/fwtab'

/srv/dbdump2   1week     2
/srv/dbdump2   2weeks    2
```
This directory is read by `fileswipe-all` which, when run does an appropriate cleanings.

### Usage - periodic wipe

To have **FilesWipe** to do jobs periodically link `fileswipe-all` to `/etc/cron.daily/`:
```bash
ln -s /usr/local/bin/fileswipe-all /etc/cron.daily/
```
... or, other 'cron' diectory if your system applies other convention.


# Summary
For any suggestions, feature requests etc. please feel free to fill [Issues](https://github.com/tools200ms/fileswipe/issues)
