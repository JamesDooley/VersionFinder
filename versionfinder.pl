#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(newline);

use FindBin qw($RealBin $RealScript);
use File::Basename;

our $DEBUG=0;

our $HITS;
our $OUTDATED;
our $SUSPENDED;

our @SIGFILELIST;

our $GRIP;
our $SENDGRIP = 0;
our $GRIP_EMAIL = 'james@jamesdooley.us';

our $REPORTEMAIL;
our $NOEMPTYREPORT;

our $RESULTS;

#Automated Updates
our $REPO = "https://raw.githubusercontent.com/JamesDooley/VersionFinder/master";
our $UpdateCheckTime = 43200; # 12 hours

our @OARGV = @ARGV;

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
	$directory =~ s|/+$||;
	return if ($directory eq "");
	return if ($directory =~ /virtfs$/i);
	return if ($directory =~ m#/home/\w+/(?:mail)#);
	return if (-l "$directory");
	
	_DEBUG(2,"Scanning directory " . escdir($directory));
	my $checked;
	foreach my $sigfile (@SIGFILELIST) {
		my $file = (keys %$sigfile)[0];
		if (-e "$directory/$file") {
			my $signame = $sigfile->{$file};
			next if ($checked->{$signame});
			$checked->{$signame} = 1;
			_DEBUG("Signature file found in ". escdir($directory) ." for $signame");
			checkcms($directory,$signame);
		}
	}
	
	undef $!;
	opendir (my $dir, $directory);
	if ($!) {
		push (@{$HITS->{globerror}}, $directory);
		return;
	}
	my @DIRS = grep {!/^\.*$/ && -d "$directory/$_"} readdir($dir);
	closedir ($dir);
	
	ScanDir ("$directory/$_") foreach (@DIRS);
	
}

sub checkcms {
	my ($directory, $signame) = @_;
	
	my $signature = $SIGNATURES->{$signame};
	my $matched;
	foreach my $fingerprint (@{$signature->{fingerprints}}) {
		my $signaturefile = "$directory/" . $fingerprint->{file};
		next unless (-e $signaturefile);
		_DEBUG("Signature file (".$fingerprint->{file}.") found in " . escdir($directory) . " for $signame");
		if ($fingerprint->{signature}) {
			if (FileContains("$signaturefile", $fingerprint->{signature})) {
				_DEBUG("Fingerprint match for $signame found in " . escdir($directory));
			} else {
				next;
			}
		}
		if ($fingerprint->{exclude}) {
			if (FileContains("$signaturefile", $fingerprint->{exclude})) {
				_DEBUG("Fingerprint matches exclude, skipping match");
				next;
			}
		}
		$matched=1;
	}
	unless ($matched) {
		_DEBUG("No fingerprint matches for $signame in " . escdir($directory));
		return;
	}

	_DEBUG("Signature match found in " . escdir($directory) . " for $signame");
	my $ver;
	foreach my $version (@{$signature->{versions}}) {
		my $verfile = "$directory/" . $version->{file};
		_DEBUG("Checking for " . escdir($directory) . "/" . $version->{file});
		next unless (-e "$verfile");
		if ($version->{regex}) {
			my $regex = $version->{regex};
			_DEBUG("Attempting to pull version using regex method");
			my $versionfile = do{local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
			if ($version->{exclude}) {
				my $exclude = $version->{exclude};
				if ($versionfile =~ m/$exclude/) {
					_DEBUG("Version file found but matched exclude");
					next;
				}
			}
			if ($version->{multiline}) {
				_DEBUG("Attempting multiline regex check");
				my @matches = ($versionfile =~ m/$regex/g);
				next unless $matches[0];
				_DEBUG(Dumper(@matches));
				$ver = shift @matches;
				foreach my $match (@matches) {
					$ver .= ".$match";
				}
			} else {
				$versionfile =~ m/$regex/;
				next unless $1;
				$ver = $1;
			}
		} elsif ($version->{sub}) {
			_DEBUG("Attempting to pull version using subroutine");
			$ver = &$version->{sub}($verfile);
		} elsif ($version->{flatfile}) {
			_DEBUG("Attempting to pull version using flat file");
			my $versionfile = do{local $/ = undef; open my $fh, "<", $verfile; <$fh>;};
			my @matches = ($versionfile =~ m/^(.*)$/g);
			if (scalar @matches > 2) {
				_DEBUG("\@matches > 2", Dumper(@matches));
				next;
			}
			unless ($matches[0]) {
				_DEBUG("\@matches[0] is not set");
				next;
			}
			$ver = $matches[0];
		}
		if ($ver && $version->{filter}) {
			$ver =~ s/$version->{filter}/\./; 
		}
	}
	$ver =~ s/\r// if ($ver);
	unless ($ver) {
		_DEBUG("CMS signature match but unable to get version information");
		$GRIP->{$signame}->{"Unknown"}++;
		my $result = {
			signature => $signame,
			name => $signature->{name},
			directory => escdir($directory)
		};
		push (@{$HITS->{nover}}, $result);
		return;
	}
	my $vermsg = escdir($directory) ."contains $signame $ver";
	$GRIP->{$signame}->{$ver}++;
	_DEBUG($vermsg);
	my $result = {
		signature => $signame,
		name => $signature->{name},
		directory => escdir($directory),
		version => $ver
	};
	push(@{$result->{notice}}, $signature->{notices}->{all}) if ($signature->{notices}->{all});
	$matched = "";
    if ($signature->{CVE}) {
        foreach my $id (keys %{$signature->{CVE}}) {
            my $cve = $signature->{CVE}->{$id};
            foreach my $version (@{$cve->{versions}}) {
                _DEBUG("Checking CVE $id with $version ($ver)");
                if ($version =~ /^(.*) - (.*)$/) {
                    my $min = $1;
                    my $max = $2;
                    _DEBUG("Min: $min (".vercomp($ver, $min).") -  Max: $max (".vercomp($ver,$max).")");
                    
                    next if (vercomp($ver, $min) == 2); # Installed version is less that minimum 
                    next if (vercomp($ver, $max) == 1); # Installed version is greater than maximum
                    _DEBUG("Appears to be vulnerable");
                    if (! $HITS->{CVE}->{$id}) {
                        $HITS->{CVE}->{$id} = $cve;
                    }
                    push(@{$HITS->{CVE}->{$id}->{found}}, $result);
                    next;
                }
            }
        }
    }
	foreach my $major (keys %{$signature->{releases}}) {
		_DEBUG("Checking $ver against $major");
		if ($ver =~ /^$major/) {
			_DEBUG("Matched Major $major");
			$matched = 1;
			my $release = $signature->{releases}->{$major};
			
			# Check all parts of the version for a matching notice
			if ($signature->{notices}) {
				my @verpart = split('\.',$ver);
				while (@verpart) {
					my $nver = join('.',@verpart);
					my $notice = $signature->{notices}->{$nver} || '';
					_DEBUG("Version Notice - $nver: ".($notice || 'None'));
					push(@{$result->{notice}}, $notice) if ($notice);
					pop @verpart;
				}
			}
			
            if ($release->{eol}) {
                _DEBUG("$signame found matching EOL product in " . escdir($directory));
                push(@{$HITS->{eol}}, $result);
                return
            }
			_DEBUG("Comp: $ver <=> $release->{release}");
			my $vercomp = vercomp($ver, $release->{release});
			_DEBUG(" - : $vercomp");
			if ($vercomp == 0) {
				_DEBUG("$signame found, matches supported release in " . escdir($directory));
				push(@{$HITS->{current}}, $result);
			} elsif ($vercomp == 1) {
				_DEBUG("$signame found, installed version is greater than signature in " . escdir($directory));
				push(@{$result->{notice}}, "Version installed is greater than signature, either this is a beta release or the signature file is outdated.");
				push(@{$HITS->{current}}, $result)
			} elsif ($vercomp == 2) {
				$vercomp = vercomp($ver, $release->{minor});
				if ($vercomp == 2) {
					_DEBUG("$signame found, installed version is really outdated in " . escdir($directory));
					push(@{$HITS->{reallyold}}, $result);
				} else {
					_DEBUG("$signame found, installed version is outdated in " . escdir($directory));
					push(@{$HITS->{outdated}}, $result);
				}
			}
		}
	}
	unless ($matched) {
		my $max = (sort { $b <=> $a } keys %{$signature->{releases}})[0];
		my $vercomp = vercomp($ver, $max);
		#my $vmax = (sort { $b <=> $a } ($max, $ver))[0];
		if ($vercomp == 1) {
			_DEBUG("$signame found, installed major version is greater than supported releases in " . escdir($directory));
			push(@{$result->{notice}}, "Version installed is greater than supported major release, either this is a beta release or the signature file is outdated.");
			push(@{$HITS->{current}}, $result);
		} else {
			_DEBUG("$signame found, installed major version is less than supported releases in " . escdir($directory) . ". Marking as EOL.");
			_DEBUG(Dumper($result));
			push(@{$HITS->{eol}}, $result);
		}
	}
}

sub escdir {
	my $dir = shift;
	$dir =~ s/\\/\\\\/g;
	$dir =~ s/\t/\\t/g;
	$dir =~ s/\n/\\n/g;
	return $dir;
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
	print $DEBUGCOLOR->{$level} if ($TERMINAL);
	foreach my $msg (@_) {
		print "DEBUG $level: $msg\n";
	}
	print $COLORS->{reset} if ($TERMINAL);
}

sub printUsage {
	print <<EOF;
Usage: $0 [OPTIONS] [--user usernames] [--directory directories]

Scans server for known CMS versions and reports what is found.

	OPTIONS:
	
		--outdated
			Only prints outdated CMS installs.
			
		--signatures
			Prints the current signature versions and exits.
		
		--sigs <signatures>
		    Limits scanning to specified signatures.
		    Takes a space seperated list of signature names, use --signatures to see what names you can use.
		    Signature names are not case sensitive.
		
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
			By default this sends the grip list to james\@jamesdooley.us, but can be changed by providing an email address.
			The only identifiable information in the report is the hostname.
			
	Adding Directories Manually:
	
		--user <usernames>
			Given a space separated list, will scan the homedir for each linux user.
			
		--directory <directories>
			Given a space separated list, will scan each directory.
		
If --user or --directory options are not set, will attempt to find users for cPanel and Plesk.
On systems without cPanel or Plesk, will attempt to scan /home and /var/www/html.

EOF
exit
}
sub getUserDir {
	my ($user) = @_;
	if (ref $user) {
		print "getUserDir called with a reference:" . Dumper($user);
		return;
	};
	_DEBUG("getUserDir called with: " . Dumper($user));
	if (-d "/var/cpanel") {
		my $userpasswd;
		if (qx(which getent)) {
			_DEBUG("Running: getent passwd $user");
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

sub reportPrint {
	my ($line, $color, $format) = @_;
	
	if (ref $line eq "HASH") {
		# Result formatted line
		$format = $resultformat unless $format;
		$RESULTS .= sprintf $format, $line->{name} || '', $line->{version} || '', $line->{directory} || '' if $REPORTEMAIL;
		
		$format = $COLORS->{$color} . $format . $COLORS->{reset} if ($INTERACTIVE && $color);
		
		printf $format, $line->{name} || '', $line->{version} || '', $line->{directory} || '';
	} else {
		# String formatted line
		$format = "%s\n" unless $format;
		$RESULTS .= sprintf $format, $line;
		
		$format = $COLORS->{$color} . $format . $COLORS->{reset} if ($INTERACTIVE && $color);
		
		printf $format, $line;
	}
}

sub generateResults {
	my $display;
	
	reportPrint("Version Finder Results",'',"\n%s\n\n");
	
	if (! $OUTDATED && $HITS->{current}) {
		$display = 1;
		reportPrint("==== Up-To-Date CMS Packages ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{current}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'green');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
	}
	if ($HITS->{eol}) {
		$display = 1;
		reportPrint("==== End-Of-Life CMS Packages ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{eol}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'magenta');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
	}
	if ($HITS->{reallyold}) {
		$display = 1;
		reportPrint("==== Very Outdated CMS Packages ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{reallyold}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'red');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
	}
	if ($HITS->{outdated}) {
		$display = 1;
		reportPrint("==== Outdated CMS Packages ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{outdated}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'yellow');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
	}
	if ($HITS->{nover}) {
		$display = 1;
		reportPrint("==== Unable to Determine Version Number ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{nover}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'magenta');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
	}
	if ($HITS->{globerror}) {
		$display = 1;
		reportPrint("==== Glob error in the following folders ====",'',"\n%s\n\n");
		
		foreach my $hit (@{$HITS->{globerror}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'magenta');
			reportPrint(" - " . $_) for @{$hit->{notice}};
		}
		reportPrint("These folders were not scanned due to possible recursion errors.",'',"%s\n\n");
	}
	if ($HITS->{suspended}) {
		$display = 1;
		reportPrint("==== Suspended accounts not scanned ====",'',"\n%s\n\n");
		foreach my $hit (@{$HITS->{suspended}}) {
			_DEBUG(Dumper($hit));
			reportPrint($hit, 'yellow');
		}
		reportPrint("These accounts were not scanned, to scan them include the --suspended flag.",'',"%s\n\n");
	}
	if ($HITS->{CVE}) {
		$display = 1;
		foreach my $id (keys %{$HITS->{CVE}}) {
			my $cve = $HITS->{CVE}->{$id};
			
			my $header = "CVE: $id";
			if ($cve->{level}) {
				$header .= " ($cve->{level})";
			};
			reportPrint("==== $header ====",'',"\n%s\n");
			if ($cve->{url}) {
				reportPrint("Url: $cve->{url}")
			}
			if ($cve->{description}) {
				reportPrint($cve->{description}."");
			}
			foreach my $hit (@{$cve->{found}}) {
				_DEBUG(Dumper($hit));
				reportPrint($hit, 'red');
			}
			reportPrint("EOL software may never receive an official patch to fix this CVE.",'',"%s\n\n");
		}
	}
	unless ($display) {
		if ($OUTDATED && $HITS->{current}) {
			reportPrint("==== No Outdated CMS Packages Found ====");
		} else {
			reportPrint("==== No CMS Packages Found ====");
		}
		$RESULTS = "" if ($NOEMPTYREPORT);
	}
	
}

sub sendResults {
	my $mailcmd;
	if (qx(which sendmail 2>/dev/null)) {
		$mailcmd = 'sendmail -t';
	} else {
		warn 'Sendmail command is not found on this machine, unable to send results';
		return 0;
	}
	my $subject=qx(hostname) . " :: VersionFinder Results";
	open (my $MAIL,"|$mailcmd");
	print $MAIL "Subject: $subject\n";
	print $MAIL "To: $REPORTEMAIL\n";
	print $MAIL $RESULTS;
	close ($MAIL);
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
	my $ScriptUpdated;
	if (-e "$RealBin/.vf_updates") {
		open (my $FH, "<","$RealBin/.vf_updates");
		while (<$FH>) {
			$_ =~ /^([a-zA-Z_.]*):(.*)$/;
			next unless ($1 && $2);
			$VFUpdates->{$1} = $2;
		}
	}
	return if ($VFUpdates->{manual});
	if ($VFUpdates->{lastcheck} && $VFUpdates->{lastcheck} + $UpdateCheckTime > time) {
		if ($INTERACTIVE) {
			print $COLORS->{blue} . "[Deferred]" . $COLORS->{reset} . "\n";
		} else {
			print "[Deferred]\n";
		}
		return;
	}
	print "\n";
	foreach my $file ('versionfinder.pl','.vf_signatures') {
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
				$ScriptUpdated = 1 if ($file eq "versionfinder.pl");
		};
		
	}
	if (-e "$RealBin/versionfinder.sigs") {
		delete $VFUpdates->{'versionfinder.sigs'};
		unlink "$RealBin/versionfinder.sigs";
	}
	$VFUpdates->{lastcheck} = time;
	open (my $FH, ">", "$RealBin/.vf_updates");
	foreach my $var (keys %$VFUpdates) {
		print $FH "$var:".$VFUpdates->{$var}."\n";
	}
	close $FH;
	if ($ScriptUpdated) {
		print "Main script updated, restarting\n\n";
		exec($^X, $0, @OARGV);
		exit 0;
	}
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
			print $COLORS->{red} . "[Failed]" . $COLORS->{reset} . "\n - File did not download properly.\n";
		} else {
			print "[Failed]\n - File did not download properly.\n";
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

sub GenSigFileList {
	foreach my $signame (keys %$SIGNATURES) {
		foreach my $fingerprint (@{$SIGNATURES->{$signame}->{'fingerprints'}}) {
			push (@SIGFILELIST, {$fingerprint->{file} => $signame});
		}
	}
}

sub printSignatures {
	require "$RealBin/.vf_signatures" unless ($SIGNATURES);
	printf $resultformat, "Signature Name", "Minor Release", "Current Release";
	foreach my $signame (sort {$a cmp $b} keys %$SIGNATURES) {
		my $signature = $SIGNATURES->{$signame};
		foreach my $relver (sort {$a <=> $b} keys %{$signature->{releases}}) {
			my $release = $signature->{releases}->{$relver};
			printf $resultformat, $signature->{name}, $release->{minor}, $release->{release};
			printf "%s\n", " - " . $signature->{notices}->{$relver} if ($signature->{notices}->{$relver});
		}
		printf "%s\n", " - " . $signature->{notices}->{all} if ($signature->{notices}->{all});
	}
	exit 1;
}

unless (-e "$RealBin/.vf_signatures") {
	updateFile(".vf_signatures");
	die "Signatures file is not found and could not be downloaded, please manually install from the github repo." unless (-e "$RealBin/.vf_signatures");
}

our @scandirs;
our %SIGLIST;

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
			printSignatures;
		} elsif ($argument =~ /^--sigs$/i) {
		    while (@ARGV && $ARGV[0] !~ /^-/) {
		        my $signame = lc(shift @ARGV);
		        $SIGLIST{$signame} = 1;
		    }
		} elsif ($argument =~ /^--suspended/i) {
			$SUSPENDED=1;
		} elsif ($argument =~ /^--report/i) {
			my @EMAILS;
			while (@ARGV && $ARGV[0] =~ /\@/) {
				push(@EMAILS,shift @ARGV)
			}
			$REPORTEMAIL = join(',', @EMAILS);
		} elsif ($argument =~ /^--noemptyreport/i) {
			$NOEMPTYREPORT = 1;
		} elsif ($argument =~ /^--grip/i) {
			$SENDGRIP = 1;
			if (@ARGV && $ARGV[0] =~ /\@/) {
				$GRIP_EMAIL = shift @ARGV;
			}
		} elsif ($argument =~ /^--debug/i) {
			if (@ARGV && $ARGV[0] =~ /[0-9]/) {
				$DEBUG = shift @ARGV;
			} else {
				$DEBUG=1;
			}
		} elsif ($argument =~ /^--update/i) {
			updateFile("versionfinder.pl");
			updateFile(".vf_signatures");
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

require "$RealBin/.vf_signatures";

if (%SIGLIST) {
    foreach my $signame (keys %$SIGNATURES) {
        delete $SIGNATURES->{$signame} unless ($SIGLIST{$signame});
    }
}

GenSigFileList;

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

generateResults();

if ($REPORTEMAIL) {
	sendResults() if $RESULTS;
}

if ($SENDGRIP) {
	print $COLORS->{green} . " Sending Grip List" . $COLORS->{reset} . "\n";
	my $mailcmd;
	if (qx(which sendmail 2>/dev/null)) {
		$mailcmd = 'sendmail -t';
	} else {
		warn 'Sendmail command is not found on this machine, unable to send grip list';
		exit 1;
	}
	my $subject=qx(hostname) . " :: GRIP LIST";
	open (my $MAIL,"|$mailcmd");
	print $MAIL "Subject: $subject\n";
	print $MAIL "To: $GRIP_EMAIL\n";
	print $MAIL Dumper($GRIP);
	close ($MAIL);
}
