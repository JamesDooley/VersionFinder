#!/usr/bin/perl
use strict;
use warnings;

use FindBin qw($RealBin $RealScript);
use File::Basename;
use Storable;

our $DEBUG=0;

our $HITS;
our $OUTDATED;
our $SUSPENDED;

#Automated Updates
our $REPO = "https://raw.githubusercontent.com/JamesDooley/VersionFinder/master";
our $UpdateCheckTime = 86400; # 24 hours

our $COLORS = {
	'reset' => "\e[0m",
	'bold' => "\e[1m",
	'black' => "\e[30m",
	'red' => "\e[31m",
	'green' => "\e[32m",
	'yellow' => "\e[33m",
	'blue' => "\e[34m",
	'magenta' => "\e[35m",
	'cyan' => "\e[36m",
	'white' => "\e[37m",
	'bold black' => "\e[1;30m",
	'bold red' => "\e[1;31m",
	'bold green' => "\e[1;32m",
	'bold yellow' => "\e[1;33m",
	'bold blue' => "\e[1;34m",
	'bold magenta' => "\e[1;35m",
	'bold cyan' => "\e[1;36m",
	'bold white' => "\e[1;37m",
};

our $DEBUGCOLOR = {
	0 => $COLORS->{reset},
	1 => $COLORS->{red},
	2 => $COLORS->{magenta},
	3 => $COLORS->{'bold white'}
};

our $resultformat = "%-25s %-15s %-s\n";
our $statusformat = "\r$COLORS->{blue}Starting scan in [%4s | %4s]: %-40s$COLORS->{reset}";

our $INTERACTIVE = -t STDOUT ? 1 : 0;
our $TERMINAL = -t STDERR ? 1 : 0;
$| = 1;

our $SIGNATURES;

sub ScanDir {
	my $directory = shift;
	return if ($directory =~ /virtfs$/i);
	return if (-l "$directory");
	
	_DEBUG(2,"Scanning directory $directory");
	foreach my $signame (keys %$SIGNATURES) {
		my $signature = $SIGNATURES->{$signame};
		my $signaturefile = "$directory/" . $signature->{fingerprint}->{file};
		next unless (-e $signaturefile);
		_DEBUG("Signature file found in $directory for $signame");
		if ($signature->{fingerprint}->{signature}) {
			if (FileContains("$signaturefile",$signature->{fingerprint}->{signature})) {
				_DEBUG("Signature match for $signame found in $directory");
				if ($signature->{fingerprint}->{exclude}) {
					next if FileContains("$signaturefile",$signature->{fingerprint}->{exclude})
				}
			} else {
				_DEBUG("Signature did not match for $signame in $directory");
				next;
			}
		}
		my @verfiles;
		if ($signature->{fingerprint}->{version}->{files}) {@verfiles = @{$signature->{fingerprint}->{version}->{files}}};
		if ($signature->{fingerprint}->{version}->{file}) {push(@verfiles,$signature->{fingerprint}->{version}->{file})};
		my $version;
		foreach my $verfile (@verfiles) {
			$verfile = "$directory/$verfile";
			_DEBUG("Checking for $verfile");
			next unless (-e "$verfile");
			if ($signature->{fingerprint}->{version}->{regex}) {
				_DEBUG("Using regex check");
				my $regex = $signature->{fingerprint}->{version}->{regex};
				my $versionfile = do {local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
				if ($signature->{fingerprint}->{version}->{exclude}) {
					next if $versionfile =~ m/$signature->{fingerprint}->{version}->{exclude}/;
				}
				if ($signature->{fingerprint}->{version}->{multiline}) {
					_DEBUG("Multiline regex");
					my @matches = ($versionfile =~ m/$regex/g);
					next unless $matches[0];
					$version = $matches[0];
					_DEBUG(Dumper(@matches));
					for (my $i=1; $i<scalar @matches; $i++) {
						$version .= ".$matches[$i]";
					}
				} else {
					$versionfile =~ m/$regex/;
					next unless $1;
					$version = $1;
				}
			} elsif ($signature->{fingerprint}->{version}->{sub}) {
				_DEBUG("Using sub check");
				&$signature->{fingerprint}->{version}->{sub}($verfile);
			} elsif ($signature->{fingerprint}->{version}->{flatfile}) {
				_DEBUG("Using flatfile check");
				my @matches;
				my $versionfile = do {local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
				@matches = ($versionfile =~ m/^(.*)$/g);
				if (scalar @matches > 2) {
					_DEBUG("\@matches > 2",Dumper(@matches));
					next;
				}
				unless ($matches[0]) {
					_DEBUG("\@matches[0] is not set",Dumper(@matches));
					next;
				}
				$version = $matches[0];
			}
			last if $version;
		}
		unless ($version) {
			_DEBUG("CMS signature match but unable to get version information");
			my $result = {
				signature => $signame,
				directory => $directory
			};
			push (@{$HITS->{nover}}, $result);
		}
		next unless $version;
		if ($signature->{fingerprint}->{version}->{filter}) {
			$version =~ s/$signature->{fingerprint}->{version}->{filter}/\./;
		}
		next unless $version;
		my $vermsg = "$directory contains $signame $version";
		my $result = {
			signature => $signame,
			directory => $directory,
			version => $version
		};
		
		if ($signature->{eol}) {
			push (@{$HITS->{eol}}, $result);
			_DEBUG("$signame found matching EOL product in $directory");
			next;
		}
		my $vercomp = vercomp($version, $signature->{curver});
		if ($vercomp == 0) {
			push (@{$HITS->{current}}, $result);
			_DEBUG("$signame found, matches current version in $directory");
		} elsif ($vercomp == 1) {
			push (@{$HITS->{current}}, $result);
			_DEBUG("$signame found, installed version is greater than signature in $directory");
		} elsif ($vercomp == 2) {
			$vercomp = vercomp($version, $signature->{majorver});
			if ($vercomp == 2) {
				$result->{reallyold} = 1;
			}
			push (@{$HITS->{outdated}}, $result);
			_DEBUG("$signame found, installed version is outdated in $directory");
		}
	}
	my $globdir = $directory;
	$globdir =~ s|\\|\\\\|g;
	$globdir =~ s|\ |\\\ |g;
	$globdir =~ s|\t|\\t|g;
	_DEBUG(3,"Using: $globdir for glob");
	my @glob = <$globdir/{,.}*>;
	if (! @glob) {
		push(@{$HITS->{globerror}},$directory);
		return;
	}
	
	foreach my $object (@glob) {
		next if $object =~ m|\.$|;
		$object =~ s|//*|/|g;
		if ($object =~ m|\n|) {
			push (@{$HITS->{globerror}},$object);
			next;
		}
		next if $object =~ m#/home/\w+/(?:mail)#;
		if (-d $object) {
			ScanDir("$object");
		}
	}
}

sub vercomp {
	#Returns 0 if equal
	#Returns 1 if ver1 > ver2
	#Returns 2 if ver2 > ver2
	
	my ($ver1, $ver2) = @_;
	
	return 0 if ($ver1 eq $ver2);
	
	my @ver1 = split(/\./,$ver1);
	my @ver2 = split(/\./,$ver2);
	
	my $digitcount;

	$digitcount = (scalar @ver1 >= scalar @ver2) && scalar @ver1 || scalar @ver2;

	for (my $i=0; $i<$digitcount; $i++) {
		$ver1[$i] = 0 unless $ver1[$i];
		$ver2[$i] = 0 unless $ver2[$i];
		if ($ver1[$i] =~ /^([0-9]*)(?:[_-])alpha/i) {
			$ver1[$i] = $1-.002;
		} elsif ($ver1[$i] =~ /^([0-9]*)(?:[_-])beta/i) {
			$ver1[$i] = $1-.001;
		}
		if ($ver2[$i] =~ /^([0-9]*)(?:[_-])alpha/i) {
			$ver2[$i] = $1-.002;
		} elsif ($ver2[$i] =~ /^([0-9]*)(?:[_-])beta/i) {
			$ver2[$i] = $1-.001;
		}		
		
		$ver1[$i] =~ s/^([0-9]*)/$1/;
		$ver2[$i] =~ s/^([0-9]*)/$1/;
		
		$ver1[$i] = 0 unless $ver1[$i];
		$ver2[$i] = 0 unless $ver2[$i];
		
		if ($ver1[$i] > $ver2[$i]) {
			return 1
		} elsif ($ver1[$i] < $ver2[$i]) {
			return 2
		}
	}
	return 0;
}


sub FileContains {
	my ($filename,$string) = @_;
	return 2 unless (-e $filename);
	open (my $FH, "$filename");
	if (grep{/$string/} <$FH>) {
		close $FH;
		return 1;
	}
	close $FH;
	return 0;
}

sub _DEBUG {
	return unless $DEBUG;
	my $level = 1;
	$level = shift if ($_[0] =~ m|^[0-9]$|);
	return if ($level > $DEBUG);
	print $DEBUGCOLOR->{$level};
	foreach my $msg (@_) {
		print "DEBUG $level: $msg\n";
	}
	print $COLORS->{reset};
}

sub printUsage {
	print <<EOF;
Usage: $0 [OPTIONS] [--user usernames] [--directory directories]

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

EOF
exit
}
sub getUserDir {
	my ($user) = @_;
	if (-d "/var/cpanel") {
		my $userpasswd;
		if (qx(which getent)) {
			$userpasswd = qx(getent passwd $user);
			chomp $userpasswd;
		} else {
			$userpasswd = qx(grep '^$user:' /etc/passwd);
			chomp $userpasswd; 
		}
		return unless $userpasswd;
		my @userpasswd = split(/:/,$userpasswd);
		return $userpasswd[5];
	}
}

sub printResults {
	
	print "\nVersion Finder Results\n\n";
	unless ($OUTDATED) {
		print "\n==== Up-To-Date CMS Packages ====\n";
		foreach my $hit (@{$HITS->{current}}) {
			printf $COLORS->{green} . $resultformat . $COLORS->{reset}, $hit->{signature}, $hit->{version}, $hit->{directory} if $INTERACTIVE;
			printf $resultformat, $hit->{signature}, $hit->{version}, $hit->{directory} unless $INTERACTIVE;
		}
	}
	if ($HITS->{eol}) {
		print "\n==== End-Of-Life CMS Packages ====\n";
		foreach my $hit (@{$HITS->{eol}}) {
			printf $COLORS->{magenta} . $resultformat . $COLORS->{reset}, $hit->{signature}, $hit->{version}, $hit->{directory} if $INTERACTIVE;
			printf $resultformat, $hit->{signature}, $hit->{version}, $hit->{directory} unless $INTERACTIVE;
		}
	}
	if ($HITS->{outdated}) {
		print "\n==== Outdated CMS Packages ====\n";
		foreach my $hit (@{$HITS->{outdated}}) {
			printf $COLORS->{red} . $resultformat . $COLORS->{reset}, $hit->{signature}, $hit->{version}, $hit->{directory} if $INTERACTIVE && $hit->{reallyold};
			printf $COLORS->{yellow} . $resultformat . $COLORS->{reset}, $hit->{signature}, $hit->{version}, $hit->{directory} if $INTERACTIVE && ! $hit->{reallyold};
			printf $resultformat, $hit->{signature}, $hit->{version}, $hit->{directory} unless $INTERACTIVE;
		}
	}
	if ($HITS->{nover}) {
		print "\n==== Unable to Determine Version Number ====\n";
		foreach my $hit (@{$HITS->{nover}}) {
			printf $COLORS->{magenta} . $resultformat . $COLORS->{reset}, $hit->{signature}, "", $hit->{directory} if $INTERACTIVE;
			printf $resultformat, $hit->{signature}, "", $hit->{directory} unless $INTERACTIVE;
		}
	}
	if ($HITS->{globerror}) {
		print "\n==== Glob error in the following folders ====\n";
		foreach my $hit (@{$HITS->{globerror}}) {
			print $COLORS->{magenta} . $hit . $COLORS->{reset} . "\n";
		}
		print "These folders were not scanned due to possible recursion errors.\n";
	}
	if ($HITS->{suspended}) {
		print "\n==== Suspended accounts not scanned ====\n";
		foreach my $hit (@{$HITS->{suspended}}) {
			print $COLORS->{yellow} . $hit . $COLORS->{reset} . "\n";
		}
		print "These accounts were not scanned, to scan them include the --suspended flag.\n";
	}
	print "==== No CMS Packages Found ====" unless ($HITS);
	
}

sub checkUpdate {
	print "Checking for updates: ";
	unless (qx(which curl 2>/dev/null)) {
		if ($INTERACTIVE) {
			print $COLORS->{red} . "[Failed]" . $COLORS->{reset} . "\n - Curl is not found on this system\n - " . $COLORS->{yellow} . "Automated update checks are disabled." . $COLORS->{reset}."\n"
		} else {
			print " [Failed]\n - Curl is not found on this system\n - Automated update checks are disabled.\n"
		}
		return;
	};
	my $VFUpdates;
	my @ToUpdate;
	if (-e "$RealBin/.vf_updates") {
		open (my $FH, "<","$RealBin/.vf_updates");
		while (<$FH>) {
			$_ =~ /^([a-zA-Z.]*):(.*)$/;
			next unless ($1 && $2);
			$VFUpdates->{$1} = $2;
		}
	}
	if ($VFUpdates->{lastcheck} && $VFUpdates->{lastcheck} + $UpdateCheckTime > time) {
		if ($INTERACTIVE) {
			print $COLORS->{blue} . "[Deferred]" . $COLORS->{reset} . "\n";
		} else {
			print "[Deferred]\n";
		}
		return;
	}
	print "\n";
	foreach my $file ("versionfinder.pl","versionfinder.sigs") {
		print "- Checking $file ";
		my $header = qx(curl -I "$REPO/$file" 2>/dev/null);
		unless ($header =~ /ETag:.+"(.*)"/) {
			if ($INTERACTIVE) {
				print $COLORS->{red} . "[Failed]" . $COLORS->{reset} . "\n - Repo did not return an ETag\n - " . $COLORS->{yellow} . "Automated update checks are temporarily disabled." . $COLORS->{reset}."\n"
			} else {
				print "[Failed]\n - Repo did not return an ETag\n - Automated update checks are disabled.\n"
			}
			next;
		}
		if ($VFUpdates->{$file} && $VFUpdates->{$file} eq $1) {
			if ($INTERACTIVE) {
				print $COLORS->{green} . "[Ok]" . $COLORS->{reset} . "\n"
			} else {
				print "[Ok]\n"
			}
			next;
		}
		if ($INTERACTIVE) {
				print $COLORS->{blue} . "[Update Needed]" . $COLORS->{reset} . "\n"
		} else {
				print "[Update Needed]\n"
		}
		if (updateFile("$file")) {
				$VFUpdates->{$file} = $1;
		};
		
	}
	$VFUpdates->{lastcheck} = time;
	open (my $FH, ">", "$RealBin/.vf_updates");
	foreach my $var (keys %$VFUpdates) {
		print $FH "$var:".$VFUpdates->{$var}."\n";
	}
	close $FH;
	
}

sub updateFile {
	my $file = shift;
	print "Attempting to update $file ";
	if (qx(which wget)) {
		qx(wget --quiet --no-check-certificate -O "$RealBin/$file.new" "$REPO/$file");
	} elsif (qx(which curl)) {
		qx(curl --fail --output "$RealBin/$file.new" "$REPO/$file" 2>/dev/null);
	} else {
		if ($INTERACTIVE) {
			print $COLORS->{red} . "[Failed]" . $COLORS->{reset} . "\n - Need Curl or Wget for automatic downloads\n - " . $COLORS->{yellow} . "Automated updates are temporarily disabled, please manually update." . $COLORS->{reset}."\n";
		} else {
			print "[Failed]\n - Need Curl or Wget for automatic downloads\n - Automated update checks are disabled, please manually update.\n";
		}
		return 0;
	}
	if ( ! -e "$RealBin/$file.new" || -z "$RealBin/$file.new") {
		unlink "$RealBin/$file.new" if (-e "$RealBin/$file.new");
		if ($INTERACTIVE) {
			print $COLORS->{red} . "[Failed]" . $COLORS->{reset} . "\n - File did not download properly\n";
		} else {
			print "[Failed]\n - Need Curl or Wget for automatic downloads\n - Automated update checks are disabled, please manually update.\n";
		}
		return 0;
	}
	my $realfile;
	if ($file =~ /versionfinder.pl/) {
		$realfile = $RealScript;
	} else {
		$realfile = $file;
	}
	unlink "$RealBin/$realfile" if (-e "$RealBin/$realfile" && -e "$RealBin/$file.new");
	rename "$RealBin/$file.new","$RealBin/$realfile";
	if ($file =~ /versionfinder.pl/) {
		chmod 0755, "$RealBin/$realfile";
	}
	if ($INTERACTIVE) {
		print $COLORS->{green} . "[Updated]" . $COLORS->{reset} ."\n";
	} else {
		print "[Updated]\n";
	}
	return 1;
}

unless (-e "$RealBin/versionfinder.sigs") {
	updateFile("versionfinder.sigs");
	die "Signatures file is not found and could not be downloaded, please manually install from the github repo." unless (-e "$RealBin/versionfinder.sigs");
}
$SIGNATURES = ${retrieve("$RealBin/versionfinder.sigs")};

our @scandirs;
while (@ARGV) {
	my $argument = shift @ARGV;
	if ($argument =~ /^-/) {
		if ($argument =~ /^--user/i) {
			while (@ARGV && $ARGV[0] !~ /^-/ ) {
				my $user = shift @ARGV;
				push(@scandirs, getUserDir($user));
			}
		} elsif ($argument =~ /^--directory/i) {
			while (@ARGV && $ARGV[0] !~ /^-/) {
				my $directory = shift @ARGV;
				push(@scandirs,$directory) if (-d "$directory");
			}
		} elsif ($argument =~ /^--outdated/i) {
			$OUTDATED=1;
		} elsif ($argument =~ /^--help/i) {
			printUsage;
		} elsif ($argument =~ /^--signatures/i) {
			printf $resultformat, "Signature Name", "Current Ver", "Major Ver";
			foreach my $signame (sort {$a cmp $b} keys %{$SIGNATURES}) {
				printf $resultformat, $SIGNATURES->{$signame}->{name}, $SIGNATURES->{$signame}->{curver}, $SIGNATURES->{$signame}->{majorver};
			}
			exit 0;
		} elsif ($argument =~ /^--suspended/i) {
			$SUSPENDED=1;
		} elsif ($argument =~ /^--debug/i) {
			if (@ARGV && $ARGV[0] =~ /[0-9]/) {
				$DEBUG = shift @ARGV;
			} else {
				$DEBUG=1;
			}
		} elsif ($argument =~ /^--update/i) {
			updateFile "versionfinder.pl";
			updateFile "versionfinder.sigs";
			exit 0;
		} else {
			print "Unknown option: $argument\n";
			exit 1;
		}
	}
}

if ($DEBUG) {
	use Data::Dumper;
}

unless (@scandirs) {
	if (-d "/var/cpanel") {
		foreach my $user (glob("/var/cpanel/users/*")) {
			$user =~ s/.*\/(.*$)/$1/;
			if (-e "/var/cpanel/suspended/$user" && ! $SUSPENDED) {
				push(@{$HITS->{suspended}},$user);
			} else {
				push(@scandirs, getUserDir($user));
			}
		};
		if (-d "/var/www/html") {
			push(@scandirs, "/var/www/html");
		}
		if (-d "/usr/local/apache/htdocs") {
			push(@scandirs, "/usr/local/apache/htdocs");
		}
	} elsif (-d "/usr/local/psa") {
		foreach my $vhost (glob("/var/www/vhosts")) {
			push(@scandirs, $vhost);
		}
		if (-d "/var/www/html") {
			push(@scandirs, "/var/www/html");
		}
	}
}

unless (@scandirs) {
	if ($INTERACTIVE) {
		print "Unable to automatically find directories, press enter to scan /home and /var/www/html.\n";
		print "Otherwise Ctrl-C to manually provide directories to scan with --directory";
		<>;
	}
	if (-d "/home") {
		push(@scandirs,"/home");
	}
	if (-d "/var/www/html") {
		push(@scandirs,"/var/www/html");
	}
}

die "Unable to find any directories to scan" unless (@scandirs);
checkUpdate;

my $dircount = scalar @scandirs;
my $curcount = 0;
foreach my $directory (@scandirs) {
	$curcount++;
	my $title = $directory;
	substr($title,20,-17,"...") if (length $title > 40);
	printf STDERR $statusformat, $curcount, $dircount, $title if ($TERMINAL); 
	ScanDir($directory);
}
print STDERR "\n" if ($TERMINAL);

printResults();