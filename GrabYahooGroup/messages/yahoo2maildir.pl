#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/messages/yahoo2maildir.pl,v 1.20 2007-02-27 03:07:36 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use Crypt::SSLeay;
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

my $HUMAN_WAIT = 1; # Amount of time it would take a human being to read a page
my $HUMAN_REFLEX = 5; # Amount of time it would take a human being to react to a page

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my $username = ''; # Better here than the commandline.
my $password = $ENV{'GY_PASSWD'};
$password = '' unless $password; # Better here than the commandline.
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst
my $cycle = 1; # Every block cycle
my $group_domain;

my $sleep_duration = 0;

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

if (! -d $group and ($HUMAN_WAIT < 1 or $HUMAN_REFLEX < 1) ) {
	print "[WARN] You have disabled the reflex mode on the first run - are you sure this is intentional\n";
	print "       Hit enter to continue: ";
	my $cont = <STDIN>;
}
unless (-d $group or mkdir $group) {
	print STDERR "[INFO] $! : $group\n" if $VERBOSE;
}

my $Cookie_file = "$group/yahoogroups.cookies";

my $ua = LWP::UserAgent->new(keep_alive => 10);
$ua->env_proxy();
$ua->agent($USER_AGENT);
$ua->timeout($TIMEOUT*60);
print STDERR "[INFO] Setting timeout to : " . $ua->timeout() . "\n" if $VERBOSE;
my $cookie_jar = HTTP::Cookies->new( 'file' => $Cookie_file );
$ua->cookie_jar($cookie_jar);
my $request;
my $response;
my $url = "http://groups.yahoo.com/group/$group/messages/1";
my $content;
if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

$request = GET $url;
$response = $ua->simple_request($request);
if ($response->is_error) {
	print STDERR "[ERR] [http://groups.yahoo.com/group/$group/messages/1] " . $response->as_string . "\n" if $VERBOSE;
	exit;
}

while ( $response->is_redirect ) {
	$cookie_jar->extract_cookies($response);
	$url = GetRedirectUrl($response);
	$request = GET $url;
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
}
$cookie_jar->extract_cookies($response);

$content = $response->content;

my $login_rand;
my $u;
my $challenge;
my $done;

if (!(-f $Cookie_file) or $content =~ /sign\s+in\s+now/i or $content =~ /Sign in to Yahoo/ or $content =~ /Sign in with your ID and password to continue/ or $content =~ /To access\s+Yahoo! Groups...<\/span><br>\s+<strong>Sign in to Yahoo/ or $content =~ /Verify your Yahoo! password to continue/ or $content =~ /sign in<\/a> now/) {
	($login_rand) = $content =~ /<form method=post action="https:\/\/login.yahoo.com\/config\/login_verify2\?(.*?)"/s;
	($u) = $content =~ /<input type=hidden name=".u" value="(.+?)" >/s;
	($challenge) = $content =~ /<input type=hidden name=".challenge" value="(.+?)" >/s;
	($pd) = $content =~ /<input type=hidden name=".pd" value="(.+?)" >/s;

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

	$request = POST 'http://login.yahoo.com/config/login_verify2',
		[
		 '.src'   => 'ygrp',
		 '.tries' => '1',
		 '.done'  => "http://groups.yahoo.com/group/$group/",
		 '.md5'   => '',
		 '.hash'  => '',
		 '.js'    => '',
		 '.partner' => '',
		 '.slogin'  => $username,
		 '.intl'  => 'us',
		 '.fUpdate' => '',
		 '.prelog' => '',
		 '.bid' => '',
		 '.aucid' => '',
		 '.challenge' => $challenge,
		 '.yplus' => '',
		 '.childID' => '',
		 'pkg'    => '',
		 'hasMsgr' => 0,
		 '.pd'     => $pd,
		 '.u'     => $u,
		 '.persistent' => 'y',
		 'passwd' => $password,
		 '.save'  => 'Sign In'
		];


	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
	print STDERR "[INFO] [Sleeping for $sleep_duration seconds]\n" if ($VERBOSE and $sleep_duration);
	sleep($sleep_duration);
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[ERR] [http://login.yahoo.com/config/login] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	}

	$content = $response->content;

	terminate("Couldn't log in $username") if ( !$response->is_success );

	terminate("Wrong password entered for $username") if ( $content =~ /Invalid Password/ );

	terminate("Yahoo user $username does not exist") if ( $content =~ /ID does not exist/ );

	print STDERR "[INFO] Successfully logged in as $username.\n" if $VERBOSE; 

	$cookie_jar->save if $COOKIE_SAVE;
}


if (($content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) or ($content =~ /you have reached an age-restricted area of Yahoo! Groups/)) {
	if ($GETADULT) {
                my ($ycb) = $content =~ /<input type="hidden" name="ycb" value="(.+?)">/;
                my ($dest) = $content =~ /<input type="hidden" name="dest" value="(.+?)">/;
		$request = POST 'http://groups.yahoo.com/adultconf',
			[
			 'ref' => '',
			 'dest'  => $dest,
                         'ycb' => $ycb,
			 'accept' => 'I Accept'
			];
	
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD PUT');
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR "[INFO] [Sleeping for $sleep_duration seconds]\n" if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [http://groups.yahoo.com/adultconf] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
	
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}

		$content = $response->content;
	
		print STDERR "[INFO] Confirmed as a adult\n" if $VERBOSE;

		$cookie_jar->save if $COOKIE_SAVE;
	} else {
		print STDERR "[ERR] This is a adult group exiting\n" if $VERBOSE;
		exit;
	}
}

if ($content =~ /You are not a member of the group <b>$group/) {
	print STDERR "[ERR] Not a member of the group $group\n";
	exit;
}

($group_domain) = $url =~ /\/\/(.*?groups.yahoo.com)\//;

eval {
	$content = $response->content;
	while ($content =~ /Unfortunately, we are unable to process your request at this time/i) {
		print STDERR "[WARN] [" . $request->uri . "] Yahoo has blocked us ?\n" if $VERBOSE;
		$sleep_duration = 3600*$cycle;
		print STDERR "[INFO] [Sleeping for $sleep_duration seconds]\n" if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR "[INFO] [Sleeping for $sleep_duration seconds]\n" if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [" . $request->uri . "]\n" . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}
		$content = $response->content;
		$cycle++;
	}
	my ($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
	terminate("Couldn't get message count") unless $e;
	$begin_msgid = $b unless $begin_msgid;
	$end_msgid = $e unless $end_msgid;
	terminate("End message id :$end_msgid should be greater than begin message id : $begin_msgid") if ($end_msgid < $begin_msgid);

	if ($end_msgid > $e) {
		print STDERR "[WARN] End message id is greater than what is reported by Yahoo - adjusting value to $e\n";
		$end_msgid = $e;
	}

	print STDERR "[INFO] Processing messages between $begin_msgid and $end_msgid\n" if $VERBOSE;

	foreach my $messageid ($begin_msgid..$end_msgid) {
		next if $REFRESH and -f "$group/$messageid";
		print STDERR "[INFO] $messageid: " if $VERBOSE;

		$url = "http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1";
		$request = GET $url;
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR "\n[INFO] [Sleeping for $sleep_duration seconds]\t" if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
		}
		$content = $response->content;

		# Is this the holding page when Yahoo is blocking your requests ?
		# Assuming we are being blocked - lets pause rather than get sacrificed
		while ($content =~ /Unfortunately, we are unable to process your request at this time/i) {
			print STDERR "[WARN] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] Yahoo has blocked us ?\n" if $VERBOSE;
			$sleep_duration = 3600*$cycle;
			print STDERR "\n[INFO] [Sleeping for $sleep_duration seconds]\t" if ($VERBOSE and $sleep_duration);
			sleep($sleep_duration);
			$url = "http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
			print STDERR "\n[INFO] [Sleeping for $sleep_duration seconds]\t" if ($VERBOSE and $sleep_duration);
			sleep($sleep_duration);
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			while ( $response->is_redirect ) {
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
					exit;
				}
				$cookie_jar->extract_cookies($response);
			}
			$content = $response->content;
			$cycle++;
		}

		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Yahoo! Groups is an advertising supported service/ or $content =~ /Continue to message/s) {
			$url = "http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			while ( $response->is_redirect ) {
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
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

		my ($email_header, $email_body) = $email_content =~ /<td class="source user">\s+(From .+?)\s+<br>\s+<br>\s+(.+)<\/td>/s;
		if ($email_body eq $attachment_nobody) {
			print "... body contains attachment with no body\n";
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}

		$email_header =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_header =~ s/<.+?>//g;
		$email_header = HTML::Entities::decode($email_header);
		$email_body =~ s/<a href=".+?>(.+?)<\/a>/$1/g; # Yahoo hyperlinks every URL which is not already a hyperlink.
		$email_body =~ s/<.+?>//g;
		$email_body = HTML::Entities::decode($email_body);
		open (MFD, "> $group/$messageid");
		print MFD $email_header;
		print MFD "\n\n";
		print MFD $email_body;
		close MFD;
		print "\n" if $VERBOSE;

		$cookie_jar->save if $COOKIE_SAVE;
	}
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

