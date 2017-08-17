VersionFinder
=============

VersionFinder is a script that has the ability to scan multiple websites, normally in a shared hosting environment, and report outdated version of common CMS installs.

Current Signatures
=============

This list is not automatically updated and may show outdated versions, for the latest signatures run versionfinder --signatures:
```
Signature Name            Minor Release   Current Release
PHPMailer                 5.2             5.2.23
CRE Loaded                7.003           7.003.4.2
Drupal                    7               7.56
Drupal                    8               8.3.5
e107                      1.0             1.0.4
e107                      2.1             2.1.5
 - e107 is currently stuck between old legacy software and a beta release.
Grav                      1               1.3.0
Joomla!                   3.7             3.7.5
Magento                   1.9             1.9.3.4
Magento                   2.1             2.1.7
Magento                   2.2             2.2.0
Mambo                     4.6             4.6.5
 - The Mambo project has been completely abandoned, there will be no future updates.
MediaWiki                 1.27            1.27.3
MediaWiki                 1.28            1.28.2
MediaWiki                 1.29            1.29.0
MODx                      1.2             1.2.1
MODx                      2.5             2.5.7
osCommerce                2.3             2.3.4
osCommerce                3.0             3.0.2
phpBB3                    3.2             3.2.1
Piwigo                    2.9             2.9.1
Redmine                   3.2             3.2.7
Redmine                   3.3             3.3.4
Redmine                   3.4             3.4.2
OpenX / Revive            4.0             4.0.2
vBulletin                 5.3             5.3.1
WHMCS                     7.0             7.0.3
 - End of Life Date: 31st October 2017
WHMCS                     7.1             7.1.2
 - End of Life Date: 31st December 2017
WHMCS                     7.2             7.2.3
 - End of Life Date: 31st May 2018
 - Due to potential security concerns, it is recommended to only run this on a server dedicated to WHMCS.
WordPress                 3.9             3.9.19
WordPress                 4.8.1           4.8.1
X-Cart                    4.7             4.7.8
X-Cart                    5.3             5.3.3.1
XOOPS                     2.5             2.5.8
ZenCart                   1.5             1.5.5
```

Usage
=============


```
Usage: ./versionfinder.pl [OPTIONS] [--user usernames] [--directory directories]

Scans server for known CMS versions and reports what is found.

    OPTIONS:
    
        --outdated
            Only prints outdated CMS installs.
            
        --signatures
            Prints the current signature versions and exits.
            
        --suspended
            Also scans cPanel's suspended accounts.
        
        --report <email>
            Sends a report to a specific email or list of email addresses.
            
        --noemptyreport
            Does not send a report if no results are returned.
        
        --update
            Forces an update of the script and signatures file.
            
        --grip [<email>]
            Sends a list and count of all version numbers.
            This will help show the distribution of installed CMS' on a system.
            By default this sends the grip list to james@jamesdooley.us, but can be changed by providing an email address.
            The only identifiable information in the report is the hostname.
            
    Adding Directories Manually:
    
        --user <usernames>
            Given a space separated list, will scan the homedir for each linux user.
            
        --directory <directories>
            Given a space separated list, will scan each directory.
        
If --user or --directory options are not set, will attempt to find users for cPanel and Plesk.
On systems without cPanel or Plesk, will attempt to scan /home and /var/www/html.
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
