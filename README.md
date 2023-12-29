# FilesWipe

**FilesWipe** is a set of Bash scripts developed to do a simple job:

* removal of an old (backup) files

In the case of small databases it's OK to setup periodic database dumps.
Also, it's good to keep versioning, thus usually such a backup is a set of
files named `backup-<date>_dbdump.sql.xz` that are added on e.g. daily basis
to a certain directory.

But, to ensure that a data set is not growing 'limitlessly', there is the need for
an old file removal. Thus, **FilesWipe** has been developed, additionally it
provides:

* File removal policy
* Configuration file
* Countermeasures to prevent from purging all data

It's a Bash shell program, I run it on VM's that collect various files. Files are
keep for a certain amount of time, after which data is removed to keep space usage in balance.
DB dump files is just one example, other is a purge of an old cache files.

## Usage - single swipe

**FilesWipe** can be run directly with command:
````bash
fileswipe.sh /path/to/directory 1week 2
````
where:

`/path/to/directory` is a path to directory holding file set for potential removal.

`1week` is removal `defer time`, files that are younger will be keep, only older files will
be considered for removal in accordance with `removal frequency` that is a next argument.

`2` is a `removal frequency`, `2` means to remove every second file, `1` means to removal of
all files that passed `defer time`, `3` or `4` tells to remove every third or forth file.


`defer time` is a number directly postfixed with `day`, `days`, `week` or `weeks`.

--------------------------------------------------------------------------------------------
**NOTE 1:**
**FilesWipe** will not remove files even if its `defer time` has passed if there is too little files in a directory.
This is to prevent from losing data in the case if directory has not been feed with a fresh versions.
--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
**NOTE 2:**
**FilesWipe** determinates file age by reading *last modification* time.
--------------------------------------------------------------------------------------------

## Usage - periodic swipe

To have **FilesWipe** to do jobs periodically add `fileswipe-run` to be launched by Cron as `root` user on preferably daily basis.

Usually it's a matter of placing that file in `/etc/cron.daily/` or a like directory.

`fileswipe-run` reads `/etc/fwtab` that is holding desired configuration:

```
# This is a content of '/etc/fwtab', keep here configuration for FilesWipe

/path/to/directory    1week    2
```

--------------------------------------------------------------------------------------------
**NOTE 3:**
`fileswipe.sh` is launched (by `fileswipe-run`) with a privileges of a directory owner
(directory holding files for wipe). Make sure proper 'read-write-search' permissions are set.
--------------------------------------------------------------------------------------------

# Summary
For any suggestions, feature requests etc. please feel free to fill [Issues](https://github.com/tools200ms/fileswipe/issues)
