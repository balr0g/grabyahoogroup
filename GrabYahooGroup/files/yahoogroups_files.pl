#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/files/yahoogroups_files.pl,v 1.4 2004-08-31 12:39:57 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
sub GetRedirectUrl($);

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;
$VERBOSE = $ENV{'VERBOSE'} if $ENV{'VERBOSE'};

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

terminate("Please specify a group to process") unless $user_group;

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
my $content;
if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

download_folder('');

sub download_folder {
	my ($sub_folder) = @_;
	print "[$group]$sub_folder\n" if $VERBOSE;

	unless (-d "$group$sub_folder" or mkdir "$group$sub_folder") {
		print STDERR "$! : $group$sub_folder\n" if $VERBOSE;
	}

	$request = GET "http://groups.yahoo.com/group/$group/files$sub_folder";
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[http://groups.yahoo.com/group/$group/files$sub_folder] " . $response->as_string . "\n" if $VERBOSE;
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
	
	$content = $response->content;
	
	my $login_rand;
	my $u;
	my $challenge;
	
	if ($content =~ /Sign in with your ID and password to continue/ or $content =~ /Verify your Yahoo! password to continue/) {
		($login_rand) = $content =~ /<form method=post action="https:\/\/login.yahoo.com\/config\/login\?(.+?)"/s;
		($u) = $content =~ /<input type=hidden name=".u" value="(.+?)" >/s;
		($challenge) = $content =~ /<input type=hidden name=".challenge" value="(.+?)" >/s;

		unless ($username) {
			my ($slogin) = $content =~ /<input type=hidden name=".slogin" value="(.+?)" >/;
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
			 '.done'  => "http://groups.yahoo.com/group/$group/files$sub_folder",
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
	
		$content = $response->content;
	
		terminate("Couldn't log in $username") if ( !$response->is_success );
	
		terminate("Wrong password entered for $username") if ( $content =~ /Invalid Password/ );
	
		terminate("Yahoo user $username does not exist") if ( $content =~ /ID does not exist/ );
	
		print "Successfully logged in as $username.\n" if $VERBOSE; 
	}
	
	if (($content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) or ($content =~ /you have reached an age-restricted area of Yahoo! Groups/)) {
		if ($GETADULT) {
			$request = POST 'http://groups.yahoo.com/adultconf',
				[
				 'ref' => '',
				 'dest'  => "/group/$group/files$sub_folder",
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
	
			$content = $response->content;
		
			print "Confirmed as a adult\n" if $VERBOSE;
		} else {
			print STDERR "This is a adult group exiting\n" if $VERBOSE;
			exit;
		}
	}
	
	eval {
		terminate("Yahoo error : not a member of this group") if $content =~ /You are not a member of the group /;
		terminate("Yahoo error : nonexistant group") if $content =~ /There is no group called /;
		terminate("Yahoo error : database unavailable") if $content =~ /The database is unavailable at the moment/;
		my ($cells) = $content =~ /<!-- start content include -->\s+(.+?)\s+<!-- end content include -->/s;
		while ($cells =~ /<tr valign=top.+?<a href="(.+?)">(.+?)<\/a>\s+<br>.+?<\/tr>/sg) {
			my $file_url = $1;
			my $file_name = $2;
			next if -f "$group$sub_folder/$file_name";
			if ($file_url =~ /\/$/) {
				download_folder("$sub_folder/$file_name");
				next;
			}
			print "\t$sub_folder/$file_name .." if $VERBOSE;
	
			$request = GET $file_url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "\n\t[$file_url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			while ( $response->is_redirect ) {
				$cookie_jar->extract_cookies($response);
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "\n\t[$url] " . $response->as_string . "\n" if $VERBOSE;
					exit;
				}
			}
			$cookie_jar->extract_cookies($response);
			$content = $response->content;
			# If the page comes up with just a advertizement without the message.
			if ($content =~ /Continue to message/s) {
				$request = GET $file_url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "\n\t[$file_url] " . $response->as_string . "\n" if $VERBOSE;
					exit;
				}
				$content = $response->content;
			}
			$cookie_jar->extract_cookies($response);

			terminate("Yahoo error : group download limit exceeded") if (($content =~ /The document you requested is temporarily unavailable because this group\s+has exceeded its download limit/s) and $VERBOSE);
			if (($content =~ /The document you requested is temporarily unavailable because you\s+has exceeded its download limit/s) and $VERBOSE) {
				print STDERR "Yahoo error : user download limit exceeded";
				next;
			}
		
			terminate("$! : $file_name") unless open(IFD, "> $group$sub_folder/$file_name");
			binmode(IFD);
			print IFD $content;
			close IFD;
			print ".. done\n" if $VERBOSE;
		}
		
		$cookie_jar->save if $COOKIE_SAVE;
	};
	
	if ($@) {
		$cookie_jar->save if $COOKIE_SAVE;
		die $@;
	}
}


sub terminate {
	my ($message) = @_;

	print STDERR "\t$message\n";
	exit;
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
