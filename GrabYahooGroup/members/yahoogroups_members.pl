#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/members/yahoogroups_members.pl,v 1.4 2006-04-09 08:41:39 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use Getopt::Long;


# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 0;

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $username = ''; # Better here than the commandline.
my $password = '';
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst

my $result = GetOptions ('verbose=i' => \$VERBOSE,
			 'getadult=i' => \$GETADULT,
			 'username=s' => \$username,
			 'password=s' => \$password,
			 'http_proxy=s' => \$HTTP_PROXY_URL,
			 'timeout=i' => \$TIMEOUT,
			 'user_agent=s' => \$USER_AGENT);

die "Can't parse command line parameters\n" unless $result;

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my ($user_group) = @ARGV;

terminate("Please specify a group to process") unless $user_group;

my ($group) = $user_group =~ /^([\w_\-]+)$/;

# Logon to Yahoo

my $ua = LWP::UserAgent->new;
$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;
$ua->agent($USER_AGENT);
$ua->timeout($TIMEOUT*60);
print "Setting timeout to : " . $ua->timeout() . "\n" if $VERBOSE;
my $cookie_jar = HTTP::Cookies->new();
$ua->cookie_jar($cookie_jar);
my $request;
my $response;
my $url;
my $content;

download_members();

sub download_members {

	$request = GET "http://groups.yahoo.com/group/$group/members?start=0&xm=1&m=s&group=sub";
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[http://groups.yahoo.com/group/$group/members?start=0&xm=1&m=s&group=sub] " . $response->as_string . "\n" if $VERBOSE;
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
	
	if ($content =~ /Sign in to Yahoo/ or $content =~ /Sign in with your ID and password to continue/ or $content =~ /Verify your Yahoo! password to continue/) {
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
			 '.done'  => "http://groups.yahoo.com/group/$group/members?start=0&xm=1&m=s&group=sub",
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
	
		terminate("Wrong password entered for $username") if ( $content =~ /Invalid ID or password/ );
	
		terminate("Yahoo user $username does not exist") if ( $content =~ /ID does not exist/ );
	
		print "Successfully logged in as $username.\n" if $VERBOSE; 
	}
	
	if (($content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) or ($content =~ /you have reached an age-restricted area of Yahoo! Groups/)) {
		if ($GETADULT) {
			my ($ycb) = $content =~ /<input type="hidden" name="ycb" value="(.+?)">/;
			my ($dest) = $content =~ /<input type="hidden" name="dest" value="(.+?)">/;
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
	
			$content = $response->content;
		
			print "Confirmed as a adult\n" if $VERBOSE;
		} else {
			print STDERR "This is a adult group exiting\n" if $VERBOSE;
			exit;
		}
	}
	
	eval {
		terminate("Yahoo error : not a member of this group") if $content =~ /You are not a member of the group /;
		terminate("Yahoo error : member list available only to moderator") if $content =~ /You are not a moderator of the group /;
		terminate("Yahoo error : nonexistant group") if $content =~ /There is no group called /;
		terminate("Yahoo error : database unavailable") if $content =~ /The database is unavailable at the moment/;
		while (1) {
			my ($cells) = $content =~ /<!-- start content include -->\s+(.+?)\s+<!-- end content include -->/s;
			while ($cells =~ /<td class="info">(.+?)<\/td>\s<td class="yid selected ygrp-nowrap">\s(.+?)\s<\/td>\s<td class="email ygrp-nowrap">\s(.+?)\s<\/td>\s<td class="date ygrp-nowrap">\s(.+?)\s<\/td>/sg) {
				my $member_block = $1;
				my $yahoo_id = $2;
				my $email_id = $3;
				my $join_date = $4;

				my $member = '';
				if ($member_block =~ /<span class="name">\s(.+?)\s<\/span>/) {
					$member = $1;
					$member =~ s/<.+?>//g;
					$member =~ s/^ //;
				}

				my $online = '';
				if ($member_block =~ /<span class="ygrp-nowrap">.+?<img src=.+?alt="(.+?)"/s) {
					$online = $1;
					$online = 'Online' if $online =~ /Online/;
					$online = 'Unknown' if $online =~ /Send/;
				}

				$yahoo_id =~ s/<.+?>//g;
				$yahoo_id =~ s/\s+//g;

				$email_id =~ s/<.+?>//g;
				$email_id =~ s/\s+//g;

				$join_date =~ s/&nbsp;/ /g;

				print "$member\t$online\t$yahoo_id\t$email_id\t$join_date\n";
			}
			last if $content =~ /<span class="inactive">Next&nbsp;&gt;<\/span>/;

			my ($next_start) = $content =~ /<a href="\/group\/$group\/members\?start=(\d+)&.+?">Next&nbsp;&gt;<\/a>/;
			$request = GET "http://groups.yahoo.com/group/$group/members?start=$next_start";
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[http://groups.yahoo.com/group/$group/members?start=$next_start] " . $response->as_string . "\n" if $VERBOSE;
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
		}
	};

	if ($@) {
		die $@;
	}
}


sub terminate {
	my ($message) = @_;

	print STDERR "\t$message\n";
	exit;
}


sub GetRedirectUrl {
	my ($response) = @_;
	my $url = $response->header('Location') || return undef;

	# the Location URL is sometimes non-absolute which is not allowed, fix it
	local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	my $base = $response->base;
	$url = $HTTP::URI_CLASS->new($url, $base)->abs($base);

	return $url;
}
