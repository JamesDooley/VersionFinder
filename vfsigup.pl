#!/usr/bin/env perl

use strict;
use warnings;

use 5.10.0;
use lib './';
use Mojo::UserAgent;
use Data::Dumper;
use Hash::Merge qw(merge);

use FindBin qw($RealBin $RealScript);
use File::Basename;

chomp(our $DIFF = qx(which diff));
chomp(our $MELD = qx(which meld));

unless ($DIFF) {
	say "Requires diff to be able to compare signature files";
	exit 1;
}

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

our $ua = Mojo::UserAgent->new();

$ua->transactor->name("VersionFinder https://github.com/JamesDooley/VersionFinder");
$ua->max_redirects(5);

our ($SIGNATURES, @SIGLIST, $SIGFILE, $UPDATE, $CHECK, $ERROR, $NOERROR);

while (@ARGV) {
	my $opt = shift @ARGV;
	if ($opt =~ /^--sigfile$/i) {
		if ($ARGV[0] !~ /^-/) {
			$SIGFILE = shift @ARGV;
		} else {
			say "--sigfile requires a filename to process";
			exit 1;
		}
	} elsif ($opt =~ /^--update$/i) {
		$UPDATE = 1;
	} elsif ($opt =~ /^--check$/i) {
		$CHECK = 1;
	} elsif ($opt =~ /^--noerrors$/i) {
		$NOERROR = 1;
	} elsif ($opt =~ /^--sigs$/i) {
		while (@ARGV && $ARGV[0] !~ /^-/) {
			push (@SIGLIST, shift @ARGV);
		}
	} elsif ($opt =~ /^(?:--help|-h)$/i)  {
		printHelp();
	} else {
		say "Unknown option $opt";
		printHelp();
	}
}

unless ($SIGFILE) {
	if (-e '.vf_signatures') {
		$SIGFILE = '.vf_signatures';
	} elsif (-e $RealBin.'/.vf_signatures') {
		$SIGFILE = $RealBin.'/.vf_signatures';
	} elsif (-e '/root/bin/.vf_signatures') {
                $SIGFILE = '/root/bin/.vf_signatures';
        }
}

unless (-e $SIGFILE) {
	say "Unable to locate signature file, please specify with --sigfile option";
	exit 1;
}

if ($UPDATE && $CHECK) {
	say "--update and --check can not be used together.";
	exit 1;
}

require $SIGFILE;

unless (@SIGLIST) {
	@SIGLIST = sort keys %$SIGNATURES
}

pullVersions();

if ($ERROR &&  ! $NOERROR) {
	say "Error encountered pulling updates, not continuing without --noerrors";
	exit 2;
}
my $dd = Data::Dumper->new([$SIGNATURES], [qw($SIGNATURES)]);
$dd->Indent(1);
$dd->Sortkeys(1);

my $fh;
if ($UPDATE) {
	open ($fh, '>', $SIGFILE);
} else {
	open ($fh, '>', "$SIGFILE.new");
}

print $fh $dd->Dump;
close ($fh);

unless ($UPDATE) {
	qx($DIFF -q $SIGFILE $SIGFILE.new);
	if ($? == 0) {
		say "Signature versions match, nothing to update";
		exit 0;
	}
	if ($MELD) {
		qx($MELD $SIGFILE $SIGFILE.new);
	} else {
		qx($DIFF -u $SIGFILE $SIGFILE.new);
	}
	unless ($CHECK) {
		say " Push Changes? [y/N]: ";
		if (<> =~ /y/i) {
			my $dd = Data::Dumper->new([$SIGNATURES], [qw($SIGNATURES)]);
			$dd->Indent(1);
			$dd->Sortkeys(1);
			open (my $fh, '>', "$SIGFILE");
			print $fh $dd->Dump;
			close ($fh);
			say "Signature file updated";
		}
	}
	unlink "$SIGFILE.new";
}

sub printHelp {
	print << "EOF";
	Usage: $0 [options]
	This script is intended to update the signatures file directly from each CMS' website.
	Generally this should only be used to update signatures in the github repo itself.
	
	Options:
	   --sigfile      Location of the VersionFinder signature file (default: ./.vf_signatures)
	   --update	  Do not prompt to verify changes, automatically update signature file.
	   --check	  Do not update signature file, display differences.
	   --sigs [list]  Specify specific signatures to update or check, space separated list.
	   
	Unless --update is supplied, it will display the differences using meld or diff.
EOF
	exit 1;
}

sub cPrint {
	my ($text, $color) = @_;
	return unless $text;
	unless ($color && $COLORS->{$color}) {
		print $text;
		return;
	}
	print $COLORS->{$color}. $text . $COLORS->{reset}."\n";
	return;
}

sub processVersion {
	my ($version, $majcnt, $mincnt) = @_;
	my ($major, $minor);

	# Try to pull major version
	if ($majcnt && $majcnt == 2) {
		if ($version =~ m/^([0-9]*\.[0-9]*)/) {
			$major = $1;
		}
	} else {
		if ($version =~ /^([0-9]*)\.[0-9.]+/) {
			$major = $1;
		}
	}

	# Try to pull minor version
    if ($mincnt && $mincnt == 2) {
        if ($version =~ m/^([0-9]*\.[0-9]*)/) {
            $minor = $1;
        }
    } else {
        if ($version =~ /^([0-9]*)\.[0-9.]+/) {
            $minor = $1;
        }
    }
	return 0 unless ($major && $minor);
	return {major => $major, minor => $minor, release => $version};
}

sub pullSingleVersion {
	my ($url, $base, $verreg, $majcnt, $mincnt) = @_;
	my $tx = $ua->get($url);
	if ($tx->error) {
		cPrint("Unable to connect to $url","magenta");
		$ERROR = 1;
		return 0;
	}

    my $section;
    if ($base) {
	   $section = $tx->res->dom->at($base);
	   if (!$section or $section eq 0) {
		  cPrint("CSS base did not provide a result ($base)","red");
		  $ERROR = 1;
		  return 0;
	   }
    } else {
       $section = $tx->res->dom;
    }

	my $line = $section->text;
	unless ($line) {
		cPrint("CSS base did not return text ($base)","bold yellow");
		$ERROR = 1;
		return 0;
	}
	if ($line =~ /$verreg/) {
		my $ver = $1;
		$ver =~ s/ Patch (Level )?/\./;
		unless ($ver) {
			cPrint("Version regex did not return a result ($verreg)",'yellow');
			$ERROR = 1;
			return 0;
		}
		if (my $vers = processVersion($ver,$majcnt, $mincnt)) {
			cPrint("Maj: $vers->{major} Min: $vers->{minor} ($ver)",'green');
			return $vers;
		} else {
			cPrint("Unable to pull major version from ($ver)",'red');
			$ERROR = 1;
			return 0;
		}
	} else {
		cPrint("Unable to pull version from string ($line)",'red');
		$ERROR = 1;
		return 0;
	}
}

sub pullMultipleVersions {
	my ($url, $base, $verreg, $majcnt, $mincnt) = @_;
	my $tx = $ua->get($url);
	if ($tx->error) {
		cPrint("Unable to connect to $url","magenta");
		$ERROR = 1;
		return 0;
	}

	my $section = $tx->res->dom->find($base);
	if ($section eq 0) {
		cPrint("CSS base did not provide a result ($base)","red");
		$ERROR = 1;
		return 0;
	}
	my $verlist;
	our $found=0;
	$section->each( sub {
		my $line = shift->text;
		return 0 unless ($line =~ /$verreg/);
		my $ver = $1;
		$ver =~ s/ Patch (Level )?/\./;
		return 0 unless ($ver);
		if (my $vers = processVersion($ver,$majcnt, $mincnt)) {
			cPrint("Maj: $vers->{major} Min: $vers->{minor} ($ver)",'green');
			$found=1;
			$verlist->{$vers->{major}} = { minor => $vers->{minor}, release => $vers->{release} };
		}
	});
	unless ($found) {
		cPrint("Version regex did not return a result ($verreg)",'yellow');
		$ERROR = 1;
		return 0;
	}
	return $verlist;
}

sub pullVersions {
	no strict qw(refs);
	foreach my $signame (@SIGLIST) {
		my $signature = $SIGNATURES->{$signame};
		my $release = {};
		my $error;
		say " -- $signame --";
		unless ($signature->{update}) {
			say "No update rules";
			next
		}
		foreach my $uname (keys %{$signature->{update}}) {
			my $u = $signature->{update}->{$uname};
			if ($uname eq 'sub') {
				eval(&$u);
				$error=1;
			} elsif ($u->{single}) {
				if (my $ver = pullSingleVersion($u->{url}, $u->{base}, $u->{regex}, $u->{major}, $u->{minor})) {
					$release->{$ver->{major}} = { minor => $ver->{minor}, release => $ver->{release}};
				} else {
					say "Unable to pull releases for $uname";
					$error=1;
				}
			} else {
				if (my $ver = pullMultipleVersions($u->{url}, $u->{base}, $u->{regex}, $u->{major}, $u->{minor})) {
					$release = merge($release, $ver);
				} else {
					say "Unable to pull releases for $uname";
					$error=1;
				}
			}
		}
		$SIGNATURES->{$signame}->{releases} = $release unless $error;
	}
}

sub whmcs_json {
	my $tx = $ua->get('https://download.whmcs.com/assets/scripts/get-downloads.php');
	if ($tx->error) {
                cPrint("Unable to connect to https://download.whmcs.com/assets/scripts/get-downloads.php","magenta");
                $ERROR = 1;
                return 0;
        }
	my $release = {};
	my $versioninfo = $tx->res->json;
	my $ver = processVersion($versioninfo->{latestVersion}->{version},2,2);
	if ($ver) {
		cPrint("Maj: $ver->{major} Min: $ver->{minor} ($versioninfo->{latestVersion}->{version})",'green');
		$release->{$ver->{major}} = {minor => $ver->{minor}, release => $ver->{release}};
	} else {
		say "Unable to pull releases for whmcs";
		$ERROR = 1;
		return 0;
	}
	if ($versioninfo->{ltsReleases} && ref $versioninfo->{ltsReleases} eq 'ARRAY' ) {
		foreach my $lts (@{$versioninfo->{ltsReleases}}) {
			my $ver = processVersion($lts->{version},2,2);
			if ($ver) {
				cPrint("Maj: $ver->{major} Min: $ver->{minor} ($versioninfo->{latestVersion}->{version})",'green');
				$release->{$ver->{major}} = {minor => $ver->{minor}, release => $ver->{release}};
		        } else {
        		        say "Unable to pull releases for whmcs";
                		$ERROR = 1;
		                return 0;
        		}
		};
	};
	$SIGNATURES->{whmcs}->{releases} = $release;

	my $eols = {
		'all' => 'Due to potential security concerns, it is recommended to only run this on a server dedicated to WHMCS.'
	};
	foreach my $ver (keys %{$versioninfo->{patchSets}}) {
		$eols->{$ver} = "End of Life Date: ". $versioninfo->{patchSets}->{$ver}->{eolDate};
	}
	$SIGNATURES->{whmcs}->{notices} = $eols;
}

