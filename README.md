VersionFinder
=============

VersionFinder is a script that has the ability to scan multiple websites, normally in a shared hosting environment, and report outdated version of common CMS installs.

Current Signatures
=============

```
Program Name      Warn Ver    Cur Ver
Drupal7           7           7.26
Drupal6           6           6.30
e107              1           1.0.4
Joomla_1.5        1.5         1.5.999 #EOL
Joomla_1.7        1.7.999     1.7.999 #EOL
Joomla_2.5        2.5         2.5.18
Joomla_3.2        3.2         3.2.2
Mambo_CMS         4.6         4.6.5
MediaWiki         1.22        1.22.2
OpenX/Revive      3.0         3.0.2
osCommerce2       2.3         2.3.3.4
osCommerce3(dev)  3.0         3.0.2
CRE_Loaded6       6.999       6.999 #EOL
CRE_Loaded7       7.002       7.002.1.1
phpBB3            3.0         3.0.12
Piwigo            2.6         2.6.1
Redmine_2.3       2.3         2.3.4
Redmine_2.4       2.4         2.4.2
vBulletin_4       4.2         4.2.2
WordPress         3.8         3.8.1
X-Cart            5.0         5.0.11
XOOPS             2.5         2.5.6
ZenCart           1.5         1.5.1
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
wget https://raw.github.com/JamesDooley/VersionFinder/master/versionfinder.pl -O /root/bin/versionfinder
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


Note about Plesk support
=============

Plesk support was added recently, but has not been as throughly tested as cPanel.  All domains listed in /var/www/vhosts should be automatically scanned by the script.  The user option can be used to scan specific users in /var/www/vhosts, likewise the directory option can be used to scan a specific directory.


Note about other systems / vanilla LAMP
=============

There is the beginnings of code to pull information directly from apache / nginx to get a list of all sites to scan, this code is not finished and will take some work to complete on my end. In the mean time you can still use this script by specifying the specific directory you want to scan. If all of the sites exist in a specific parent directory you can scan that directory like so:

 versionfinder --directory /home
