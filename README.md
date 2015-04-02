VersionFinder
=============

VersionFinder is a script that has the ability to scan multiple websites, normally in a shared hosting environment, and report outdated version of common CMS installs.

Current Signatures
=============

```
Signature Name            Current Ver     Major Ver
PHPMailer                 5.2.9           5.2
CRE Loaded6               6.999           6
CRE Loaded7               7.2.4.2         7.2
Drupal 6.x                6.34            6
Drupal 7.x                7.34            7
e107                      1.0.4           1
Joomla 1.5.x              1.5.999         1.5
Joomla 1.7.x              1.7.999         1.7
Joomla 2.5.x              2.5.28          2.5
Joomla 3.4.x              3.4.0           3.4
Mambo                     4.6.999         4.6
MediaWiki                 1.24.1          1.24
OpenX / Revive            3.0.6           3.0
osCommerce 2.x            2.3.4           2.4
osCommerce 3.x (Devel)    3.0.2           3.0
phpBB3                    3.1.3           3.1
Piwigo                    2.7.4           2.7
Redmine                   2.6.3           2.6
vBulletin 4.x             4.2.2           4.2
WHMCS                     5.3.12          5.3
WordPress                 4.1.1           4.1
X-Cart 4.x                4.6.6           4.6
X-Cart 5.x                5.1.11          5.1
XOOPS                     2.5.7.1         2.5
ZenCart                   1.5.4           1.5
```

Usage
=============


```
Usage: /root/bin/versionfinder [OPTIONS] [--user usernames] [--directory directories]

Scans server for known CMS versions and reports what is found

	OPTIONS:
	
		--outdated
			Only prints outdated CMS installs.
			
		--signatures
			Prints the current signature versions and exits.
			
		--suspended
			Also scans cPanel's suspended accounts.
			
		--update
			Forces an update of the script and signatures file.
			
	Adding Directories Manually:
	
		--user <usernames>
			Given a space seperated list, will scan the homedir for each linux user.
			
		--directory <directories>
			Given a space seperated list, will scan each directory.
		
If --user or --directory options are not set, will attempt to find users for cPanel and Plesk.
On systems without cPanel or Plesk, will attempt to scan /home and /var/www/html
```

Quick installation
=============

You can quickly install the latest version of version finder using wget:

```
mkdir -p /root/bin/
wget --no-check-certificate https://raw.github.com/JamesDooley/VersionFinder/master/versionfinder.pl -O /root/bin/versionfinder
chmod 700 /root/bin/versionfinder
```

Automated Updates
=============

The latest version of the script will now automatically check for updates to the script and signatures file every time the script is run.
It does not require any special tags to do this update, it is built in before it does any scans.
This is limited to doing a check every 24 hours, but can be overridden using --update.

On systems that do not have curl, the update check will not be done. If the system does not have curl or wget the signatures file will not be downloaded.
In this case you will need to manually download the signatures file from the repo and keep that updated.


Note about EOL packages
=============

For the most part any major version of a CMS package, that is no longer available for easy download from a website, will be considered End Of Life.  This includes packages that may still be updated, the logic is that if it is not easy to find an update most users will not bother to update the software.  Exceptions to this may be allowed if updates can be done through the admin interface for a package.


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
