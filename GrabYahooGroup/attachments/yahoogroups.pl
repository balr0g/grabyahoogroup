#!/usr/bin/perl -wT

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities;
sub GetRedirectUrl($);

# By default works in quite mode other than die's.
my $DEBUG = 1 if $ENV{'DEBUG'};

my $SAVEALL = 0; # Force download every file even if the file exists locally.
my $REFRESH = 1; # Download only those messages which dont already exist.

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

$| = 1 if ($DEBUG); # Want to see the messages immediately if I am in debug mode

my $username = ''; # Better here than the commandline.
my $password = ''; # Better here than the commandline.
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/

my ($user_group, $begin_msgid, $end_msgid) = @ARGV;

die "Please specify a group to process\n" unless $user_group;

if ($begin_msgid) { die "Begin message id should be integer\n" unless ($begin_msgid =~ /^\d*$/); }
if ($end_msgid) { die "End message id should be integer\n" unless ($end_msgid =~ /^\d*$/); }
die "End message id : $end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid and $end_msgid < $begin_msgid);

my ($group) = $user_group =~ /^([\w_]+)$/;

unless (-d $group or mkdir $group) {
	print STDERR "$! : $group\n" if $DEBUG;
}

my $Cookie_file = "$group/yahoogroups.cookies";

# Logon to Yahoo

my $ua = LWP::UserAgent->new;
$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;
$ua->agent('GrabYahooGroup/0.04');
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
	
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
	}
	
	print "Already logged in continuing.\n" if $DEBUG; 

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
		 '.done'  => "http://groups.yahoo.com/group/$group/",
		 '.src'   => 'ym',
		 '.intl'  => 'us',
		 'login'  => $username,
		 'passwd' => $password
		];
	
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
	}
	
	die "Couldn't log in $username\n" if ( !$response->is_success );
	
	$content = $response->content;
	
	$content = HTML::Entities::decode($content);
	
	die "Wrong password entered for $username\n" if ( $content =~ /Invalid Password/ );
	
	die "Yahoo user $username does not exist\n" if ( $content =~ /ID does not exist/ );
	
	print "Successfully logged in as $username.\n" if $DEBUG; 
}

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

	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
	}

	print "Confirmed as a adult\n" if $DEBUG;
}

eval {
	my $b;
	my $e;
	unless ($end_msgid) {
		$content = $response->content;
		$content = HTML::Entities::decode($content);
		($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
		die "Couldn't get message count" unless $e;
	}
	$begin_msgid = $b unless $begin_msgid;
	$end_msgid = $e unless $end_msgid;
	die "End message id :$end_msgid should be greater than begin message id : $begin_msgid\n" if ($end_msgid < $begin_msgid);

	foreach my $messageid ($begin_msgid..$end_msgid) {
		unless (-d "$group/$messageid" or mkdir "$group/$messageid") {
			print STDERR "$! : $messageid\n" if $DEBUG;
		}
		my $nextmsg = $messageid + 1;
		next if $REFRESH and -d "$group/$nextmsg";
		print "$messageid: " if $DEBUG;

		$url = "http://groups.yahoo.com/group/$group/message/$messageid";
		$request = GET $url;
		$response = $ua->simple_request($request);
		while ( $response->is_redirect ) {
			$cookie_jar->extract_cookies($response);
			$url = GetRedirectUrl($response);
			$request = GET $url;
			$response = $ua->simple_request($request);
		}
		$content = $response->content;
		$content = HTML::Entities::decode($content);
		# If the page comes up with just a advertizement without the message.
		if ($content =~ /Continue to message/s) {
			$url = "http://groups.yahoo.com/group/$group/message/$messageid";
			$request = GET $url;
			$response = $ua->simple_request($request);
			$content = $response->content;
			$content = HTML::Entities::decode($content);
		}
	
		my @attachments = $content =~ /<center><B>Attachment<\/center>.*?<B>(.*?href=".*?)"/sg;
		foreach my $attach (@attachments) {
			my ($filename, $imageurl) = $attach =~ /(.*?)<\/B>.*?href="(.*)/s;
			$filename =~ s/([^\w_\-.]*)//g;
			if ($DEBUG and -f $filename) {
				print "-";
				next unless $SAVEALL; # Skip if file was downloaded previously
			}
			print "." if $DEBUG;
			$request = GET $imageurl;
			$response = $ua->simple_request($request);
			my $content = $response->content;
			die "Download limit exceeded\n" if ($content =~ /Document Unavailable/);
			die "$! : $filename\n" unless open(IFD, "> $group/$messageid/$filename");
			print IFD $content;
			close IFD;
		}
		print "\n" if $DEBUG;
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
