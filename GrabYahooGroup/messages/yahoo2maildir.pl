#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/messages/yahoo2maildir.pl,v 1.12 2005-07-03 22:29:59 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities;

my $attachment_nobody = q{<br>
<i>[Attachment content not displayed.]</i><br><br>
</td></tr>
</table>};

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;
$VERBOSE = $ENV{'VERBOSE'} if $ENV{'VERBOSE'};

my $SAVEALL = 0; # Force download every file even if the file exists locally.
my $REFRESH = 1; # Download only those messages which dont already exist.

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

my $HUMAN_WAIT = 40; # Amount of time it would take a human being to read a page
my $HUMAN_REFLEX = 20; # Amount of time it would take a human being to react to a page

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my $username = ''; # Better here than the commandline.
my $password = $ENV{'GY_PASSWD'};
$password = '' unless $password; # Better here than the commandline.
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst
my $cycle = 1; # Every block cycle

my $sleep_duration = 0;

unless ($HTTP_PROXY_URL) {
	if ($ENV{'http_proxy'}) {
		$HTTP_PROXY_URL = $ENV{'http_proxy'};
	}
}

srand(time() . $$);

my ($user_group, $bmsg, $emsg) = @ARGV;

terminate("Please specify a group to process") unless $user_group;

my $begin_msgid;
my $end_msgid;

if (defined $bmsg) {
	if ($bmsg =~ /^(\d+)$/) {
		$begin_msgid = $1;
	} else {
		terminate("Begin message id should be integer");
	}
}

if (defined $emsg) {
	if ($emsg =~ /^(\d+)$/) {
		$end_msgid = $1;
	} else {
		terminate("End message id should be integer");
	}
}

terminate("End message id : $end_msgid should be greater than begin message id : $begin_msgid") if ($end_msgid and $end_msgid < $begin_msgid);

my ($group) = $user_group =~ /^([\w_\-]+)$/;

unless (-d $group or mkdir $group) {
	print STDERR "$! : $group\n" if $VERBOSE;
}

my $Cookie_file = "$group/yahoogroups.cookies";

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

$request = GET "http://groups.yahoo.com/group/$group/messages/1";
$response = $ua->simple_request($request);
if ($response->is_error) {
	print STDERR "[http://groups.yahoo.com/group/$group/messages/1] " . $response->as_string . "\n" if $VERBOSE;
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

if (!(-f $Cookie_file) or $content =~ /Sign in to Yahoo/ or $content =~ /Sign in with your ID and password to continue/ or $content =~ /To access\s+Yahoo! Groups...<\/span><br>\s+<strong>Sign in to Yahoo/ or $content =~ /Verify your Yahoo! password to continue/ or $content =~ /sign in<\/a> now/) {
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
		 '.done'  => "http://groups.yahoo.com/group/$group/messages/1",
		 'login'  => $username,
		 'passwd' => $password,
		 '.persistent' => 'y',
		 '.save'  => 'Sign In'
		];
	
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
	print STDERR "[Sleeping for $sleep_duration seconds] " if $VERBOSE;
	sleep($sleep_duration);
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
			 'dest'  => "/group/$group/messages/1",
			 'accept' => 'I Accept'
			];
	
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD PUT');
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR "[Sleeping for $sleep_duration seconds] " if $VERBOSE;
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://groups.yahoo.com/adultconf] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	
		while ( $response->is_redirect ) {
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

if ($content =~ /You are not a member of the group <b>$group/) {
	print STDERR "Not a member of the group $group\n";
	exit;
}

eval {
	$content = $response->content;
	my ($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
	terminate("Couldn't get message count") unless $e;
	$begin_msgid = $b unless $begin_msgid;
	$end_msgid = $e unless $end_msgid;
	terminate("End message id :$end_msgid should be greater than begin message id : $begin_msgid") if ($end_msgid < $begin_msgid);

	if ($end_msgid > $e) {
		print STDERR "End message id is greater than what is reported by Yahoo - adjusting value to $e\n";
		$end_msgid = $e;
	}

	print "Processing messages between $begin_msgid and $end_msgid\n" if $VERBOSE;

	foreach my $messageid ($begin_msgid..$end_msgid) {
		next if $REFRESH and -f "$group/$messageid";
		print "$messageid: " if $VERBOSE;

		$url = "http://groups.yahoo.com/group/$group/message/$messageid?source=1\&unwrap=1";
		$request = GET $url;
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR "[Sleeping for $sleep_duration seconds] " if $VERBOSE;
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		while ( $response->is_redirect ) {
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

		# Is this the holding page when Yahoo is blocking your requests ?
		# Assuming we are being blocked - lets pause rather than get sacrificed
		while ($content =~ /Unfortunately, we are unable to process your request at this time/i) {
			print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] Yahoo has blocked us ?\n" if $VERBOSE;
			$sleep_duration = 3600*$cycle;
			print STDERR "[Sleeping for $sleep_duration seconds] " if $VERBOSE;
			sleep($sleep_duration);
			$url = "http://groups.yahoo.com/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
			print STDERR "[Sleeping for $sleep_duration seconds] " if $VERBOSE;
			sleep($sleep_duration);
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			while ( $response->is_redirect ) {
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
			$cycle++;
		}

		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Yahoo! Groups is an advertising supported service/ or $content =~ /Continue to message/s) {
			$url = "http://groups.yahoo.com/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[http://groups.yahoo.com/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			while ( $response->is_redirect ) {
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
		}

		# If the page has been purged from the system
		if ($content =~ /Message $messageid does not exist in $group/s) {
			print "\tmessage purged from the system\n" if $VERBOSE;
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}

		my ($email_content) = $content =~ /<!-- start content include -->\s(.+?)\s<!-- end content include -->/s;

		my ($email_header, $rest) = $email_content =~ /<table.+?<tt>(.+?)<\/tt>(.+)/s;
		if ($rest eq $attachment_nobody) {
			print "... body contains attachment with no body\n";
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}
		my ($email_body) = $rest =~ /<tt>(.+?)<\/td>/s;

		$email_header =~ s/<br>//gi;
		$email_header =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_header =~ s/<.+?>//g;
		$email_header = HTML::Entities::decode($email_header);
		$email_body =~ s/<br>//gi;
		$email_body =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_body =~ s/<.+?>//g;
		$email_body = HTML::Entities::decode($email_body);
		open (MFD, "> $group/$messageid");
		print MFD $email_header;
		print MFD "\n";
		print MFD $email_body;
		close MFD;
		print "\n" if $VERBOSE;
	}

	$cookie_jar->save if $COOKIE_SAVE;
};

if ($@) {
	$cookie_jar->save if $COOKIE_SAVE;
	die $@;
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

