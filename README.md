VersionFinder
=============

VersionFinder is a script that has the ability to scan multiple websites, normally in a shared hosting environment, and report outdated version of common CMS installs.

Current Signatures
=============

```
Signature Name            Current Ver     Major Ver
CRE Loaded6               6.999           6
CRE Loaded7               7.2.1.4         7.2
Drupal 6.x                6.30            6
Drupal 7.x                7.26            7
e107                      1.0.4           1
Joomla 1.5.x              1.5.999         1.5
Joomla 1.7.x              1.7.999         1.7
Joomla 2.5.x              2.5.19          2.5
Joomla 3.2.x              3.2.3           3.2
Mambo                     4.6.5           4.6
MediaWiki                 1.22.4          1.22
OpenX / Revive            3.0.3           3.0
osCommerce 2.x            2.3.3.4         2.3
osCommerce 3.x (Devel)    3.0.2           3.0
phpBB3                    3.0.12          3.0
Piwigo                    2.6.1           2.6
Redmine                   2.4.4           2.4
vBulletin 4.x             4.2.2           4.2
WordPress                 3.8.1           3.8
X-Cart 4.x                4.6.3           4.6
X-Cart 5.x                5.0.12          5.0
XOOPS                     2.5.6           2.5
ZenCart                   1.5.1           1.5
```

Usage
=============


```
Usage: ./versionfinder [OPTION] [--user usernames] [--directory directories]

Scan server for known CMS versions and report what is found

	--outdated
		Returns only outdated packages, does not print headings
	--user <username>
		Given a space seperated list, will scan the homedir for each linux user.
	--directory <directory>
		Given a space seperated list, will scan each directory.
```

Quick installation
=============

You can quickly install the latest version of version finder using wget:

```
mkdir -p /root/bin/
wget --no-check-certificate https://raw.github.com/JamesDooley/VersionFinder/master/versionfinder.pl -O /root/bin/versionfinder
chmod 700 /root/bin/versionfinder
```

Note about EOL packages
=============

For the most part any major version of a CMS package, that is no longer available for easy download from a webside, will be considered End Of Life.  This includes packages that may still be updated, the logic is that if it is not easy to find an update most users will not bother to update the software.  Exceptions to this may be allowed if updates can be done through the admin interface for a package.


Note about packages with multiple signatures
=============

Several packages, such as Joomla, have multiple signatures to handle either architecture changes or to simplify support for multiple still supported major / minor releases.


Note about cPanel support
=============

Version finder was mainly designed with cPanel support in mind.  It should automatically detect all accounts on the server and scan all of the proper directories related to the account.  The user option can be used to scan specific users, likewise the directory option can be used to scan a specific directory.

Will also scan /var/www/html and /usr/local/apache/htdocs if they exist.


Note about Plesk support
=============

Plesk support was added recently, but has not been as throughly tested as cPanel.  All domains listed in /var/www/vhosts should be automatically scanned by the script.  The user option can be used to scan specific users in /var/www/vhosts, likewise the directory option can be used to scan a specific directory.

Will also scan /var/www/vhosts and /var/www/html if they exist.

Note about other systems / vanilla LAMP
=============

By default if Plesk and cPanel are not found the script will let you know that it can automatically scan /home and /var/www/html.
For now you will need to hit enter to accept this.

If you want to bypass the message or want to scan a different directory you can use:

 versionfinder --directory /home
