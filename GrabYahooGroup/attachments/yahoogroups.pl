#!/usr/bin/perl -wT

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
my $password = ''; # Better here than the commandline.
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst
my ($user_group, $begin_msgid, $end_msgid) = @ARGV;

die "Please specify a group to process\n" unless $user_group;

if ($begin_msgid) { die "Begin message id should be integer\n" unless ($begin_msgid =~ /^\d*$/); }
if ($end_msgid) { die "End message id should be integer\n" unless ($end_msgid =~ /^\d*$/); }
die "End message id : $end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid and $end_msgid < $begin_msgid);

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
	
	print "Already logged in continuing.\n" if $VERBOSE; 
} else {
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
		 '.done'  => "http://groups.yahoo.com/group/$group/messages/1",
		 '.src'   => 'ym',
		 '.intl'  => 'us',
		 'login'  => $username,
		 'passwd' => $password
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
	}
	$cookie_jar->extract_cookies($response);
	
	die "Couldn't log in $username\n" if ( !$response->is_success );
	
	die "Wrong password entered for $username\n" if ( $content =~ /Invalid Password/ );
	
	die "Yahoo user $username does not exist\n" if ( $content =~ /ID does not exist/ );
	
	print "Successfully logged in as $username.\n" if $VERBOSE; 
}

$content = $response->content;

if ($content =~ /You've reached an Age-Restricted Area of Yahoo! Groups/) {
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
		}
		$cookie_jar->extract_cookies($response);
	
		print "Confirmed as a adult\n" if $VERBOSE;
	} else {
		print STDERR "This is a adult group exiting\n" if $VERBOSE;
		exit;
	}
}

eval {
	my $b;
	my $e;
	unless ($end_msgid) {
		($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
		die "Couldn't get message count" unless $e;
	}
	$begin_msgid = $b unless $begin_msgid;
	$end_msgid = $e unless $end_msgid;
	die "End message id :$end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid < $begin_msgid);

	foreach my $messageid ($begin_msgid..$end_msgid) {
		if (-d "$group/$messageid") {
			next if ($REFRESH and not -f "$group/$messageid/.working");
		} else {
			mkdir "$group/$messageid" or die "$group/$messageid: $!\n";
			open WFD, "> $group/$messageid/.working";
			close WFD;
		}
		print "Processing message $messageid\n" if $VERBOSE;

		$url = "http://groups.yahoo.com/group/$group/message/$messageid";
		$request = GET $url;
		$response = $ua->simple_request($request);
		if ($response->is_error) {
			print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
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
		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Continue to message/s) {
			$url = "http://groups.yahoo.com/group/$group/message/$messageid";
			$request = GET $url;
			$response = $ua->simple_request($request);
			if ($response->is_error) {
				print STDERR "[$url] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			$content = $response->content;
		}
		$cookie_jar->extract_cookies($response);
	
		my @attachments = $content =~ /<center><B>Attachment<\/center>.*?<B>(.*?href=".*?)"/sg;
		foreach my $attach (@attachments) {
			my ($filename, $imageurl) = $attach =~ /(.*?)<\/B>.*?href="(.*)/s;
			print "\t$filename " if $VERBOSE;
			$filename =~ s/[^\w_\-.]+//g;
			if (-f "$group/$messageid/$filename" and not $SAVEALL) {
				# Skip if file was downloaded previously
				print " .. skipping ..\n" if $VERBOSE;
				next;
			}
			print ".. downloading .." if $VERBOSE;
			$request = GET $imageurl;
			$response = $ua->simple_request($request);
			$cookie_jar->extract_cookies($response);
			my $content = $response->content;
			die "Download limit exceeded\n" if ($content =~ /Document Unavailable/);
			if ($response->is_error) {
				print STDERR "[$imageurl] " . $response->as_string . "\n" if $VERBOSE;
				exit;
			}
			die "$! : $filename\n" unless open(IFD, "> $group/$messageid/$filename");
			print IFD $content;
			close IFD;
			print ".. done\n" if $VERBOSE;
		}
		unlink "$group/$messageid/.working";
	}
	
	$cookie_jar->save if $COOKIE_SAVE;
};

if ($@) {
	$cookie_jar->save if $COOKIE_SAVE;
	die $@;
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
