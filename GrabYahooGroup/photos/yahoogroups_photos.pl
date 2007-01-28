#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/photos/yahoogroups_photos.pl,v 1.7 2007-01-28 00:38:16 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use Crypt::SSLeay;
use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
sub GetRedirectUrl($);

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;
$VERBOSE = $ENV{'VERBOSE'} if defined $ENV{'VERBOSE'};

my $SAVEALL = 0; # Force download every file even if the file exists locally.
my $REFRESH = 1; # Download only those messages which dont already exist.

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my $username = ''; # Better here than the commandline.
my $password = $ENV{'GY_PASSWD'};
$password = '' unless $password; # Better here than the commandline.
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst
my ($user_group) = @ARGV;

die "Please specify a group to process\n" unless $user_group;

my ($group) = $user_group =~ /^([\w_\-]+)$/;

unless (-d $group or mkdir $group) {
	print STDERR "$! : $group\n" if $VERBOSE;
}

my $Cookie_file = "$group/yahoogroups.cookies";

# Logon to Yahoo

my $ua = LWP::UserAgent->new;
$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;
$ua->agent($USER_AGENT);
$ua->timeout($TIMEOUT*60);
print "Setting timeout to : " . $ua->timeout() . "\n" if $VERBOSE;
my $cookie_jar = HTTP::Cookies->new( 'file' => $Cookie_file );
$ua->cookie_jar($cookie_jar);
my $request;
my $response;
my $url;
my $init_content;
if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

$request = GET "http://groups.yahoo.com/group/$group/files";
$response = $ua->simple_request($request);
if ($response->is_error) {
	print STDERR "[http://groups.yahoo.com/group/$group/files] " . $response->as_string . "\n" if $VERBOSE;
	exit;
}

while ( $response->is_redirect ) {
	$cookie_jar->extract_cookies($response);
	$url = GetRedirectUrl($response);
	$request = GET $url;
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
}
$cookie_jar->extract_cookies($response);

$init_content = $response->content;

my $login_rand;
my $u;
my $challenge;

if ($cookie_jar->as_string eq '' or ($init_content =~ /Sign in with your ID and password to continue/ or $init_content =~ /Verify your Yahoo! password to continue/)) {
	($login_rand) = $init_content =~ /<form method=post action="https:\/\/login.yahoo.com\/config\/login\?(.+?)"/s;
	($u) = $init_content =~ /<input type=hidden name=".u" value="(.+?)" >/s;
	($challenge) = $init_content =~ /<input type=hidden name=".challenge" value="(.+?)" >/s;

	unless ($username) {
		my ($slogin) = $init_content =~ /<input type=hidden name=".slogin" value="(.+?)" >/;
		$username = $slogin if $slogin;
	}

	unless ($username) {
		print "Enter username : ";
		$username = <STDIN>;
		chomp $username;
	}

	unless ($password) {
		use Term::ReadKey;
		ReadMode('noecho');
		print "Enter password : ";
		$password = ReadLine(0);
		ReadMode('restore');
		chomp $password;
		print "\n";
	}

	$request = POST 'http://login.yahoo.com/config/login',
		[
		 '.tries' => '1',
		 '.src'   => 'ygrp',
		 '.md5'   => '',
		 '.hash'  => '',
		 '.js'    => '',
		 '.last'  => '',
		 'promo'  => '',
		 '.intl'  => 'us',
		 '.bypass' => '',
		 '.partner' => '',
		 '.u'     => $u,
		 '.v'     => 0,
		 '.challenge' => $challenge,
		 '.yplus' => '',
		 '.emailCode' => '',
		 'pkg'    => '',
		 'stepid' => '',
		 '.ev'    => '',
		 'hasMsgr' => 0,
		 '.chkP'  => 'Y',
		 '.done'  => "http://groups.yahoo.com/group/$group/files",
		 'login'  => $username,
		 'passwd' => $password,
		 '.persistent' => 'y',
		 '.save'  => 'Sign In'
		];
	
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[http://login.yahoo.com/config/login] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	}

	$init_content = $response->content;

	die "Couldn't log in $username\n" if ( !$response->is_success );

	die "Wrong password entered for $username\n" if ( $init_content =~ /Invalid Password/ );

	die "Yahoo user $username does not exist\n" if ( $init_content =~ /ID does not exist/ );

	print "Successfully logged in as $username.\n" if $VERBOSE; 

	$cookie_jar->save if $COOKIE_SAVE;
}

if (($init_content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) or ($init_content =~ /you have reached an age-restricted area of Yahoo! Groups/)) {
	if ($GETADULT) {
		my ($ycb) = $init_content =~ /<input type="hidden" name="ycb" value="(.+?)">/;
		my ($dest) = $init_content =~ /<input type="hidden" name="dest" value="(.+?)">/;
		$request = POST 'http://groups.yahoo.com/adultconf',
			[
			 'ref' => '',
			 'dest' => $dest,
			 'ycb' => $ycb,
			 'accept' => 'I Accept'
			];
	
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD PUT');
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://groups.yahoo.com/adultconf] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
	
		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}

		$init_content = $response->content;
	
		print "Confirmed as a adult\n" if $VERBOSE;

		$cookie_jar->save if $COOKIE_SAVE;
	} else {
		print STDERR "This is a adult group exiting\n" if $VERBOSE;
		exit;
	}
}

eval {
	die "Yahoo error : database unavailable" if $init_content =~ /The database is unavailable at the moment/;
	download_folder('', '');
	$cookie_jar->save if $COOKIE_SAVE;
};

if ($@) {
	$cookie_jar->save if $COOKIE_SAVE;
	die $@;
}


sub download_folder {
	my ($folder_id, $folder_name) = @_;

	print "[$group]$folder_name\n" if $VERBOSE;

	unless (-d "$group/$folder_name" or mkdir "$group/$folder_name") {
		print STDERR "$! : $group/$folder_name\n" if $VERBOSE;
	}

	$request = GET "http://ph.groups.yahoo.com/group/$group/photos/browse/$folder_id";
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[http://ph.groups.yahoo.com/group/$group/photos/browse/$folder_id?b=1&m=t] " . $response->as_string . "\n" if $VERBOSE;
		return;
	}

	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
			return;
		}
	}
	$cookie_jar->extract_cookies($response);

	my ($content) = $response->content =~ /<!-- start content include -->\n(.+)\n<!-- end content include -->/s;

	my @locators;

	while ($content =~ m!(<a href="/group/$group/photos/browse/\w+">[\w_ -]+</a>)!sg) {
		push @locators, $1;
	}

	while ($content =~ m!(<a href="/group/$group/photos/view/\w+\?b=\d+"><img src="http://.+?/__tn_/.+?"></a>)!sg) {
		push @locators, $1;
	}

	while ($response->content =~ /<a href="\/group\/$group\/photos\/browse\/$folder_id\?b=(\d+).+?">Next/) {
		my $next = $1;
		$request = GET "http://ph.groups.yahoo.com/group/$group/photos/browse/$folder_id?b=$next&m=t";
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://ph.groups.yahoo.com/group/$group/photos/browse/$folder_id?b=$next&m=t] " . $response->as_string . "\n" if $VERBOSE;
			return;
		}

		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				return;
			}
		}
		$cookie_jar->extract_cookies($response);

		($content) = $response->content =~ /<!-- start content include -->\n(.+)\n<!-- end content include -->/s;

		while ($content =~ m!(<a href="/group/$group/photos/browse/\w+">[\w_ -]+<\/a>)!sg) {
			push @locators, $1;
		}
		while ($content =~ m!(<a href="/group/$group/photos/view/\w+\?b=\d+"><img src="http://.+?/__tn_/.+?"></a>)!sg) {
			push @locators, $1;
		}
	}

	foreach my $file_loc (@locators) {
		if (my ($folder_id, $folder_name) = $file_loc =~ m!<a href="/group/$group/photos/browse/(.+?)">(.+?)</a>!) {
			download_folder($folder_id, $folder_name);
			next;
		}

		my ($file_seq, $file_name) = $file_loc =~ m!"/group/$group/photos/view/$folder_id\?b=(\d+)"><img src="http://.+?/__tn_/([^.]+\.\w+)\?.+?"></a>!;
		next if -f "$group/$folder_name/$file_name";
		print "\t$folder_name/$file_name .." if $VERBOSE;

		$request = GET "http://ph.groups.yahoo.com/group/$group/photos/view/$folder_id?b=$file_seq";
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "\n\t[http://ph.groups.yahoo.com/group/$group/photos/view/$folder_id?b=$file_seq] " . $response->as_string . "\n" if $VERBOSE;
			next;
		}
		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "\n\t[$url] " . $response->as_string . "\n" if $VERBOSE;
				next;
			}
		}
		$cookie_jar->extract_cookies($response);
		$content = $response->content;
		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Continue to message/s) {
			$request = GET "http://ph.groups.yahoo.com/group/$group/photos/view/$folder_id?b=$file_seq";
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "\n\t[http://ph.groups.yahoo.com/group/$group/photos/view/$folder_id?b=$file_seq] " . $response->as_string . "\n" if $VERBOSE;
				next;
			}
			$content = $response->content;
		}
		$cookie_jar->extract_cookies($response);

		my ($image_url) = $content =~ /<!-- start content include -->.+<img src="(.+?)".+<!-- end content include -->/s;
		die "Image URL not found .. dumping content\n$content\n" if (! $image_url and $VERBOSE);
		$request = GET $image_url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[$image_url] " . $response->as_string . "\n" if $VERBOSE;
			next;
		}
		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				next;
			}
		}
		$cookie_jar->extract_cookies($response);
		$content = $response->content;

		die "$! : $group/$folder_name/$file_name\n" unless open(IFD, "> $group/$folder_name/$file_name");
		binmode(IFD);
		print IFD $content;
		close IFD;
		print ".. done\n" if $VERBOSE;

		$cookie_jar->save if $COOKIE_SAVE;
	}
}

sub GetRedirectUrl($) {
	my ($response) = @_;
	my $url = $response->header('Location') || return undef;

	# the Location URL is sometimes non-absolute which is not allowed, fix it
	local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	my $base = $response->base;
	$url = $HTTP::URI_CLASS->new($url, $base)->abs($base);

	return $url;
}
