#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/messages/yahoo2maildir.pl,v 1.21 2009-10-04 03:54:04 mithun Exp $

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;
use utf8;

use Crypt::SSLeay;
use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use Getopt::Long;
use HTML::Entities;
use Encode;

binmode(STDOUT,':utf8');

my $attachment_nobody = q{<br>
<i>[Attachment content not displayed.]</i><br><br>
</td></tr>
</table>};

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;

# There is always something breaking - might as well have a file to email out
my $DEBUG = 1;

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $SAVEALL = 0; # Force download every file even if the file exists locally.
my $REFRESH = 1; # Download only those messages which dont already exist.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

my $HUMAN_WAIT = 1; # Amount of time it would take a human being to read a page
my $HUMAN_REFLEX = 5; # Amount of time it would take a human being to react to a page

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my $username = '';
my $password = '';
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst

my $cycle = 1; # Every block cycle

my $group_domain;

my $sleep_duration = 0;

my $result = GetOptions ('verbose=i' => \$VERBOSE,
			 'getadult=i' => \$GETADULT,
			 'cookie_save=i' => \$COOKIE_SAVE,
			 'cookie_load=i' => \$COOKIE_LOAD,
			 'username=s' => \$username,
			 'password=s' => \$password,
			 'http_proxy=s' => \$HTTP_PROXY_URL,
			 'timeout=i' => \$TIMEOUT,
			 'user_agent=s' => \$USER_AGENT);

$| = 1 if ($VERBOSE); # Want to see the messages immediately if I am in verbose mode

my ($user_group, $bmsg, $emsg) = @ARGV;

terminate("Please specify a group to process") unless $user_group;

my $begin_msgid = 1;
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
$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;
$ua->agent($USER_AGENT);
$ua->timeout($TIMEOUT*60);
print STDERR "[INFO] Setting timeout to : " . $ua->timeout() . "\n" if $VERBOSE;
my $cookie_jar = HTTP::Cookies->new( 'file' => $Cookie_file );
$ua->cookie_jar($cookie_jar);
my $request;
my $response;
my $url = "http://login.yahoo.com/config/login?.done=http://groups.yahoo.com/group/$group/messages/$begin_msgid";
my $content;
if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

$request = GET $url;
$response = $ua->simple_request($request);
if ($response->is_error) {
	print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
	exit;
}

while ( $response->is_redirect ) {
	$cookie_jar->extract_cookies($response);
	$cookie_jar->save if $COOKIE_SAVE;
	$url = GetRedirectUrl($response);
	$request = GET $url;
	$response = $ua->simple_request($request);
	if ($response->is_error) {
		print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
		exit;
	}
}
$cookie_jar->extract_cookies($response);
$cookie_jar->save if $COOKIE_SAVE;

$content = $response->content;

if ($content =~ /Login Form/) {
	my ($login_url) = $content =~ m!<form method="post" action="(.+?login\.yahoo.+?)"!s;
	unless ($login_url) {
		if ($DEBUG) {
			open(DEBUG, '> content.html') or die "content.html:$!\n";
			print FD $content;
			close FD;
		}
		terminate("Can't isolate login URL - please email the content.html file to author if one is available");
	}

	my ($form) = $content =~ m!<form method="post" action=".+?login\.yahoo.+?".+?>(.+?)</form>!s;
	unless ($form) {
		if ($DEBUG) {
			open(DEBUG, '> content.html') or die "content.html:$!\n";
			print FD $content;
			close FD;
		}
		terminate("Can't isolate login form - please email the content.html file to author if one is available");
	}

	my %form_fields;

	while ($form =~ m!<input type=(.+?)>!sg) {
		my $input = $1;
		my ($name) = $input =~ m!name="*(.+?)[" ]!;
		my ($value) = $input =~ m!value="*(.*?)[" ]!;
		$form_fields{$name} = $value;
	}

	my $slogin = $form_fields{'.slogin'};
	$username = $slogin if $slogin;

	unless ($username) {
		print "Enter username : ";
		$username = <STDIN>;
		chomp $username;
	}
	$form_fields{'login'} = $username if $form_fields{'login'};
	$form_fields{'.slogin'} = $username if $form_fields{'.slogin'};
	$form_fields{'login'} = $username unless ($form_fields{'login'} or $form_fields{'.slogin'});

	unless ($password) {
		use Term::ReadKey;
		ReadMode('noecho');
		print "Enter password : ";
		$password = ReadLine(0);
		ReadMode('restore');
		chomp $password;
		print "\n";
	}
	$form_fields{'passwd'} = $password;

	$request = POST $login_url, [ %form_fields ];
	
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	terminate("[http://login.yahoo.com/config/login] " . $response->as_string) if ($response->is_error);
	#Generic login loop
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		terminate("[$url] " . $response->as_string) if ($response->is_error);
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
	}

	# JS Redirect if login successful
	while ( isJSRedirect($response) ) {
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		$url = GetJSRedirect($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		terminate("[$url] " . $response->as_string) if ($response->is_error);
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
	}

	# Adult confirmation redirect
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		terminate("[$url] " . $response->as_string) if ($response->is_error);
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
	}

	$content = $response->content;

	terminate("Couldn't log in $username") if ( !$response->is_success );
	terminate("Wrong password entered for $username") if ( $content =~ /Invalid Password/ );
	terminate("Yahoo user $username does not exist") if ( $content =~ /ID does not exist/ );
	terminate("Yahoo error : not a member of this group") if $content =~ /You are not a member of the group /;
	terminate("Yahoo error : nonexistant group") if $content =~ /There is no group called /;
	terminate("Yahoo error : database unavailable") if $content =~ /The database is unavailable at the moment/;

	print "Successfully logged in as $username.\n" if $VERBOSE; 
	
	$cookie_jar->save if $COOKIE_SAVE;
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
		terminate("[http://groups.yahoo.com/adultconf] " . $response->as_string) if ($response->is_error);
	
		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			terminate("[$url] " . $response->as_string) if ($response->is_error);
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
		}

		$content = $response->content;
	
		print "Confirmed as a adult\n" if $VERBOSE;
	
		$cookie_jar->save if $COOKIE_SAVE;
	} else {
		terminate("This is a adult group exiting");
	}
}

($group_domain) = $url =~ /\/\/(.*?groups.yahoo.com)\//;

eval {
	$content = $response->content;
	while ($content =~ /Unfortunately, we are unable to process your request at this time/i) {
		print STDERR "[WARN] [" . $request->uri . "] Yahoo has blocked us ?\n" if $VERBOSE;
		$sleep_duration = 3600*$cycle;
		print STDERR " .... sleep $sleep_duration .... " if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
		print STDERR " .... sleep $sleep_duration .... " if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [" . $request->uri . "]\n" . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
		}
		$content = $response->content;
		$cycle++;
	}
	$content =~ s!<.+?>!!gs;
	my ($b, $e) = $content =~ /(\d+)-\d+ \w+ (\d+)/;
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
		print STDERR ".... sleep $sleep_duration .... " if ($VERBOSE and $sleep_duration);
		sleep($sleep_duration);
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
			exit;
		}
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		while ( $response->is_redirect ) {
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
		}
		$content = $response->content;

		# Is this the holding page when Yahoo is blocking your requests ?
		# Assuming we are being blocked - lets pause rather than get sacrificed
		while ($content =~ /Unfortunately, we are unable to process your request at this time/i) {
			print STDERR "[WARN] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] Yahoo has blocked us ?\n" if $VERBOSE;
			$sleep_duration = 3600*$cycle;
			print STDERR " .... sleep $sleep_duration .... " if ($VERBOSE and $sleep_duration);
			sleep($sleep_duration);
			$url = "http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$sleep_duration = $HUMAN_WAIT + int(rand($HUMAN_REFLEX));
			print STDERR " .... sleep $sleep_duration .... " if ($VERBOSE and $sleep_duration);
			sleep($sleep_duration);
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
			while ( $response->is_redirect ) {
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
					exit;
				}
				$cookie_jar->extract_cookies($response);
				$cookie_jar->save if $COOKIE_SAVE;
			}
			$content = $response->content;
			$cycle++;
		}

		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Yahoo! Groups is an advertising supported service/ or $content =~ /Continue to message/s or $content =~ m!href="/group/$group/message/$messageid!) {
			$url = "http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1";
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[ERR] [http://$group_domain/group/$group/message/$messageid?source=1\&unwrap=1] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
			while ( $response->is_redirect ) {
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				if ($response->is_error) {
					print STDERR "[ERR] [$url] " . $response->as_string . "\n" if $VERBOSE;
					exit;
				}
				$cookie_jar->extract_cookies($response);
				$cookie_jar->save if $COOKIE_SAVE;
			}
			$content = $response->content;
		}

		# If the page has been purged from the system
		if ($content =~ /Message ($messageid)? does not exist in $group/s) {
			print "[PURGED]\n" if $VERBOSE;
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}

		my ($email_content) = $content =~ /<!-- start content include -->\s(.+?)\s<!-- end content include -->/s;

		my ($email_header, $email_body) = $email_content =~ m!<td class="source user">\s+(From .+?)\s+<br>\s+<br>\s+(.+)</td>!s;
		unless ($email_body) {
			print "[potentially PURGED]\n" if $VERBOSE;
			open (MFD, "> $group/$messageid");
			close MFD;
			next;
		}
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

		my ($subject) = $email_header =~ /Subject: (.+?)\s+[\w-]+:/s;
		$subject = Encode::decode('MIME-Header', $subject);
		print "$subject\n" if $VERBOSE;

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

sub isJSRedirect {
	my ($response) = @_;
	return 1 if $response->content() =~ m!location.replace!s;
}

sub GetJSRedirect {
	my ($response) = @_;

	my ($redirect) = $response->content() =~ m!location.replace\(['"]*(.+?)['"]*\)!s;

	return unless $redirect;

	# the Location URL is sometimes non-absolute which is not allowed, fix it
	local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	my $base = $response->base;
	my $url = $HTTP::URI_CLASS->new($redirect, $base)->abs($base);

	return $url;
}

