#!/usr/bin/perl
use strict;
use warnings;

our $DEBUG=0;

if ($DEBUG) {
	use Data::Dumper;
}

our $HITS;
our $OUTDATED;

our $COLORS = {
	'reset'			=> "\e[0m",
	'default'		=> "",
	'bold'			=> "\e[1m",
	'black'			=> "\e[30m",
	'red'			=> "\e[31m",
	'green'			=> "\e[32m",
	'yellow'		=> "\e[33m",
	'blue'			=> "\e[34m",
	'magenta'		=> "\e[35m",
	'cyan'			=> "\e[36m",
	'white'			=> "\e[37m",
	'bold black'	=> "\e[1;30m",
	'bold red'		=> "\e[1;31m",
	'bold green'	=> "\e[1;32m",
	'bold yellow'	=> "\e[1;33m",
	'bold blue'		=> "\e[1;34m",
	'bold magenta'	=> "\e[1;35m",
	'bold cyan'		=> "\e[1;36m",
	'bold white'	=> "\e[1;37m",
};

our $resultformat = "%-25s %-15s %-s\n";
our $statusformat = "\r$COLORS->{blue}Starting scan in [%4s | %4s]: %-40s$COLORS->{reset}";

our $INTERACTIVE = -t STDOUT ? 1 : 0;
our $TERMINAL = -t STDERR ? 1 : 0;
$| = 1;



our $SIGNATURES= {
	drupal7=>{
		name=>"Drupal 7.x",
		majorver=>"7",
		curver=>"7.26",
		fingerprint=> {
			file=>"authorize.php",
			signature=>"Drupal",
			version=>{
				file=>"includes/bootstrap.inc",
				regex=>"define.*VERSION', '(.*)'"
			}
		},
	},
	drupal6=>{
		name=>"Drupal 6.x",
		majorver=>"6",
		curver=>"6.30",
		fingerprint=>{
			file=>"includes/database.mysql.inc",
			signature=>"Drupal",
			version=>{
				file=>"CHANGELOG.txt",
				regex=>"Drupal (.*),"
			}
		},
	},
	e107=>{
		name=>"e107",
		majorver=>"1",
		curver=>"1.0.4",
		fingerprint=>{
			file=>"e107_config.php",
			version=>{
				files=>["admin/ver.php","e107_admin/ver.php"],
				regex=>'e107_version.*"(.*)";'
			}
		},
	},
	joomla15=> {
		name=>"Joomla 1.5.x",
		majorver=>"1.5",
		curver=>"1.5.999",
		eol=>1,
		fingerprint=>{
			file=>"includes/joomla.php",
			signature=>"Joomla.Legacy",
			version=>{
				file=>"CHANGELOG.php",
				regex=>"-* (.*) Stable Release"
			}
		}
	},
	joomla17=> {
		name=>"Joomla 1.7.x",
		majorver=>"1.7",
		curver=>"1.7.999",
		eol=>1,
		fingerprint=>{
			file=>"joomla.xml",
			signature=>"Joomla",
			version=>{
				file=>"includes/version.php",
				regex=>'(?:\$RELEASE|\$DEV_LEVEL) = \'(.*)\'',
				multiline=>1
			}
		},
	},
	joomla25=>{
		name=>"Joomla 2.5.x",
		majorver=>"2.5",
		curver=>"2.5.19",
		fingerprint=>{
			file=>"joomla.xml",
			signature=>"Joomla",
			version=>{
				file=>"libraries/cms/version/version.php",
				regex=>'(?:\$RELEASE|\$DEV_LEVEL) = \'(.*)\'',
				multiline=>1
			}
		}
	},
	joomla32=>{
		name=>"Joomla 3.2.x",
		majorver=>"3.2",
		curver=>"3.2.3",
		fingerprint=>{
			file=>"web.config.txt",
			version=>{
				file=>"libraries/cms/version/version.php",
				regex=>'(?:\$RELEASE|\$DEV_LEVEL) = \'(.*)\'',
				multiline=>1
			}
		}
	},
	mambo=>{
		name=>"Mambo",
		majorver=>"4.6",
		curver=>"4.6.5",
		fingerprint=>{
			file=>"includes/mambofunc.php",
			version=>{
				file=>"includes/version.php",
				regex=>'(?:\$RELEASE|\$DEV_LEVEL) = \'(.*)\'',
				multiline=>1	
			}
			
		}
	},
	mediawiki=>{
		name=>"MediaWiki",
		majorver=>"1.22",
		curver=>"1.22.4",
		fingerprint=>{
			file=>"includes/DefaultSettings.php",
			signature=>"mediawiki",
			version=>{
				file=>"includes/DefaultSettings.php",
				regex=>'\$wgVersion = \'(.*)\''
			}
		}
	},
	openx=>{
		name=>"OpenX / Revive",
		majorver=>"3.0",
		curver=>"3.0.3",
		fingerprint=>{
			file=>"lib/OX.php",
			signature=>"OpenX",
			version=>{
				file=>"constants.php",
				regex=>"VERSION', '(.*)'",
			}
		}
	},
	oscommerce2=>{
		name=>"osCommerce 2.x",
		majorver=>"2.3",
		curver=>"2.3.3.4",
		exclude=>"zen-cart",
		fingerprint=>{
			file=>"includes/filenames.php",
			signature=>"osCommerce",
			version=>{
				file=>"includes/version.php",
				flatfile=>1
			}
		}
	},
	oscommerce3=>{
		name=>"osCommerce 3.x (Devel)",
		majorver=>"3.0",
		curver=>"3.0.2",
		fingerprint=>{
			file=>"OM/Core/OSCOM.php",
			signature=>"osCommerce",
			version=>{
				file=>"OM/version.txt",
				flatfile=>1
			}
		}
	},
	creloaded6=>{
		name=>"CRE Loaded6",
		majorver=>"6",
		curver=>"6.999",
		eol=>1,
		fingerprint=>{
			file=>'/admin/includes/version.php',
			signature=>"CRE Loaded6",
			version=>{
				file=>'/admin/includes/version.php',
				regex=>'INSTALLED_(?:VERSION_MAJOR|VERSION_MINOR|PATCH)\', \'(.*)\'',
				multiline=>1
			}
		}
	},
	creloaded7=>{
		name=>"CRE Loaded7",
		majorver=>"7.2",
		curver=>"7.2.1.4",
		fingerprint=>{
			file=>'checkout.php',
			signature=>'loaded7',
			version=>{
				file=>'/includes/version.txt',
				regex=>'^(.*)\|',
			}
		}
	},
	phpbb3=>{
		name=>"phpBB3",
		majorver=>"3.0",
		curver=>"3.0.12",
		fingerprint=>{
			file=>"includes/bbcode.php",
			signature=>"phpBB3",
			version=>{
				file=>"includes/constants.php",
				regex=>"PHPBB_VERSION', '(.*)'"
			}
		}
	},
	piwigo=>{
		name=>"Piwigo",
		majorver=>"2.6",
		curver=>"2.6.1",
		fingerprint=>{
			file=>"identification.php",
			signature=>"Piwigo",
			version=>{
				file=>"include/constants.php",
				regex=>"PHPWG_VERSION', '(.*)'"
			}
		}
	},
	redmine=>{
		name=>"Redmine",
		majorver=>"2.4",
		curver=>"2.4.4",
		fingerprint=>{
			file=>"lib/redmine.rb",
			signature=>"redmine",
			version=>{
				file=>"doc/CHANGELOG",
				regex=>"==.* v(.*)"
			}
		}
	},
	vbulletin4=>{
		name=>"vBulletin 4.x",
		majorver=>"4.2",
		curver=>"4.2.2",
		fingerprint=>{
			file=>"admincp/diagnostic.php",
			signature=>"vbulletin",
			version=>{
				file=>"admincp/diagnostic.php",
				regex=>"sum_versions.*vbulletin.*=> '(.*)'"
			}
		}
	},
	wordpress=>{
		name=>"WordPress",
		majorver=>"3.8",
		curver=>"3.8.1",
		fingerprint=>{
			file=>"wp-config.php",
			version=>{
				file=>"wp-includes/version.php",
				regex=>'\$wp_version = \'(.*)\''
			}
		}
	},
	xcart4=>{
		name=>"X-Cart 4.x",
		majorver=>"4.6",
		curver=>"4.6.3",
		fingerprint=>{
			file=>"cart.php",
			signature=>'version.*xcart_4',
			version=>{
				file=>"VERSION",
				regex=>"Version (.*)"
			}
		}
	},
	xcart5=>{
		name=>"X-Cart 5.x",
		majorver=>"5.0",
		curver=>"5.0.12",
		fingerprint=>{
			file=>"cart.php",
			signature=>"category.*X-Cart 5",
			version=>{
				file=>"Includes/install/install_settings.php",
				regex=>"LC_VERSION', '(.*)'"
			}
		}
	},
	xoops=>{
		name=>"XOOPS",
		majorver=>"2.5",
		curver=>"2.5.6",
		fingerprint=>{
			file=>"xoops.css",
			version=>{
				file=>"include/version.php",
				regex=>"XOOPS_VERSION.*XOOPS (.*)'"
			}
		}
	},
	zencart=>{
		name=>"ZenCart",
		majorver=>"1.5",
		curver=>"1.5.1",
		fingerprint=>{
			file=>"includes/filenames.php",
			signature=>"Zen Cart",
			version=>{
				file=>"includes/version.php",
				regex=>'PROJECT_VERSION_(?:MAJOR|MINOR)\', \'(.*)\'',
				multiline=>1
			}
		}
	}
};

sub ScanDir {
	my $directory = shift;
	return if ($directory =~ /virtfs$/i);
	return if (-l "$directory");
	
	foreach my $signame (keys %$SIGNATURES) {
		my $signature = $SIGNATURES->{$signame};
		my $signaturefile = "$directory/" . $signature->{fingerprint}->{file};
		next unless (-e $signaturefile);
		print "DEBUG: Signature file found in $directory for $signame\n" if $DEBUG;
		if ($signature->{fingerprint}->{signature}) {
			if (FileContains("$signaturefile",$signature->{fingerprint}->{signature})) {
				print "DEBUG: Signature match for $signame found in $directory\n" if $DEBUG;
				if ($signature->{fingerprint}->{exclude}) {
					next if FileContains("$signaturefile",$signature->{fingerprint}->{exclude})
				}
			} else {
				print "DEBUG: Signature did not match for $signame in $directory\n" if $DEBUG;
				next;
			}
		}
		my @verfiles;
		if ($signature->{fingerprint}->{version}->{files}) {@verfiles = @{$signature->{fingerprint}->{version}->{files}}};
		if ($signature->{fingerprint}->{version}->{file}) {push(@verfiles,$signature->{fingerprint}->{version}->{file})};
		my $version;
		foreach my $verfile (@verfiles) {
			$verfile = "$directory/$verfile";
			print "DEBUG: Checking for $verfile\n" if $DEBUG;
			next unless (-e "$verfile");
			if ($signature->{fingerprint}->{version}->{regex}) {
				print "DEBUG: Using regex check\n" if $DEBUG;
				my $regex = $signature->{fingerprint}->{version}->{regex};
				my $versionfile = do {local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
				if ($signature->{fingerprint}->{version}->{exclude}) {
					next if $versionfile =~ m/$signature->{fingerprint}->{version}->{exclude}/;
				}
				if ($signature->{fingerprint}->{version}->{multiline}) {
					print "DEBUG: Multiline regex\n" if $DEBUG;
					my @matches = ($versionfile =~ m/$regex/g);
					next unless $matches[0];
					$version = $matches[0];
					print "DEBUG: ". Dumper(@matches) if $DEBUG;
					for (my $i=1; $i<scalar @matches; $i++) {
						$version .= ".$matches[$i]";
					}
				} else {
					$versionfile =~ m/$regex/;
					next unless $1;
					$version = $1;
				}
			} elsif ($signature->{fingerprint}->{version}->{sub}) {
				print "DEBUG: Using sub check\n" if $DEBUG;
				&$signature->{fingerprint}->{version}->{sub}($verfile);
			} elsif ($signature->{fingerprint}->{version}->{flatfile}) {
				print "DEBUG: Using flatfile check\n" if $DEBUG;
				my @matches;
				my $versionfile = do {local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
				@matches = ($versionfile =~ m/^(.*)$/g);
				if (scalar @matches > 2) {
					print "DEBUG: \@matches > 2\n" if $DEBUG;
					print "DEBUG: " . Dumper(@matches) if $DEBUG;
					next;
				}
				unless ($matches[0]) {
					print "DEBUG: \@matches[0] is not set\n" if $DEBUG;
					print "DEBUG: " . Dumper(@matches) if $DEBUG;
					next;
				}
				$version = $matches[0];
			}
			last if $version;
		}
		unless ($version) {
			print "DEBUG: CMS signature match but unable to get version information\n" if $DEBUG;
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
			print "DEBUG: - $signame found matching EOL product in $directory\n" if $DEBUG;
			next;
		}
		my $vercomp = vercomp($version, $signature->{curver});
		if ($vercomp == 0) {
			push (@{$HITS->{current}}, $result);
			print "DEBUG: - $signame found, matches current version in $directory\n" if $DEBUG;
		} elsif ($vercomp == 1) {
			push (@{$HITS->{current}}, $result);
			print "DEBUG: - $signame found, installed version is greater than signature in $directory\n" if $DEBUG;
		} elsif ($vercomp == 2) {
			$vercomp = vercomp($version, $signature->{majorver});
			if ($vercomp == 2) {
				$result->{reallyold} = 1;
			}
			push (@{$HITS->{outdated}}, $result);
			print "DEBUG: - $signame found, installed version is outdated in $directory\n" if $DEBUG;
		}
	}
	foreach my $object (glob "'$directory/.*' '$directory/*'") {
		next if $object =~ m|\.$|;
		$object =~ s|//*|/|g;
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

sub printUsage {
	print <<EOF;
Usage: $0 [OPTIONS] [--user usernames] [--directory directories]

Scans server for known CMS versions and reports what is found

	OPTIONS:
	
		--outdated
			Only prints outdated CMS installs
			
		--signatures
			Prints the current signature versions and exits
		
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
	print "==== No CMS Packages Found ====" unless ($HITS);
	
}


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
		} else {
			print "Unknown option: $argument\n";
			exit 1;
		}
	}
}

unless (@scandirs) {
	if (-d "/var/cpanel") {
		foreach my $user (glob("/var/cpanel/users/*")) {
			$user =~ s/.*\/(.*$)/$1/;
			push(@scandirs, getUserDir($user));
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