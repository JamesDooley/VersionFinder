VersionFinder
=============

VersionFinder is a script that has the ability to scan multiple websites, normally in a shared hosting environment, and report outdated version of common CMS installs.


Usage
=============
Usage: ./versionfinder [OPTION] [--user username]
Scan server for known CMS versions and report what is found
 --outdated
	Returns only outdated packages, does not print headings
 --report
	Removes coloring format for easy export to file using > filename
 --csv
	Prints output in CSV format.
 --user <username>
	Scans only user's account, use quotes for a providing a list of users
 --sigs
	Print current list of program versions
