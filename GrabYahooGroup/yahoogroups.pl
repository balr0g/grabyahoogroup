#!/usr/bin/perl -w

# Inspired by Ravi Ramkissoon's fetchyahoo utility. [http://web.mit.edu/ravir/fetchyahoo/index.html]
# The basic mechanism for logging on to Yahoo has been taken from his program.
# Needs atleast one parameter : the group to be downloaded.
# You can also provide the begin and end message id to download.
# The program will create a directory in the current directory for every group it downloads.
# Each message id will have a separate directory and the attachments will be named as provided
# by the poster. It sanitizes the filename by throwing out all the non word characters
# excluding "." from the filename.
# 
# By default the tool will run in quite mode assuming the user wants to run it in batchmode.
# set a environment variable DEBUG to a true value to run in verboose mode.
#
# Adapted by : Mithun Bhattacharya [mithun at users sourceforge net] 9/9/2002

use strict;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities;
sub GetRedirectUrl($);

# If you dont want to keep a file yet skip its download make it a zero byte file.

my $DEBUG = 1 if $ENV{'DEBUG'}; # By default works in quite mode other than die's.

my $SAVEALL = 0; # Force download every file even if the file exists locally.

my $GETADULT = 1; # Allow adult groups to be downloaded.

$| = 1 if ($DEBUG); # Want to see the messages immediately if I am in debug mode

my $username = 'username'; # Better here than the commandline.
my $password = 'password'; # Better here than the commandline.

# Mandatory : group to download
# Optional : begining message id and ending message id - give both or none.

my ($group, $begin_msgid, $end_msgid) = @ARGV;

die "Please specify a group to process\n" unless $group;

if ($begin_msgid) {
	die "Msg id's should be integers\n" unless ($begin_msgid =~ /^\d*$/);
	die "You must specify both/neither of begining and ending message id\n" unless $end_msgid;
	die "Msg id's should be integers\n" unless ($end_msgid =~ /^\d*$/);
}

unless (mkdir $group) {
	print STDERR "$! : $group\n" if $DEBUG;
}

die "$! : $group\n" unless chdir $group;

# Logon to Yahoo

my $ua = LWP::UserAgent->new;
$ua->agent('GrabYahooGroup/0.04');
my $cookie_jar = HTTP::Cookies->new();
$ua->cookie_jar($cookie_jar);
my $request = POST 'http://login.yahoo.com/config/login',
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
my $response = $ua->simple_request($request);
my $url;
while ( $response->is_redirect ) {
	$cookie_jar->extract_cookies($response);
	$url = GetRedirectUrl($response);
	$request = GET $url;
	$response = $ua->simple_request($request);
}

die "Couldn't log in $username\n" if ( !$response->is_success );

my $content = $response->content;

$content = HTML::Entities::decode($content);

die "Wrong password entered for $username\n" if ( $content =~ /Invalid Password/ );

die "Yahoo user $username does not exist\n" if ( $content =~ /ID does not exist/ );


print "Successfully logged in as $username.\n" if $DEBUG; 

if ($GETADULT) {
	$request = POST 'http://groups.yahoo.com/adultconf',
		[
		 'ref' => '',
		 'dest'  => "/group/$group/messages",
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
	
	print "$username confirmed as a adult\n" if $DEBUG;
}

unless ($begin_msgid) {
	$content = $response->content;
	$content = HTML::Entities::decode($content);
	($end_msgid) = $content =~ /\d*-\d* of (\d*) /;
	die "Couldn't get message count" unless $end_msgid;
	$begin_msgid = 1;
}

foreach my $messageid (reverse $begin_msgid..$end_msgid) {
	unless (mkdir $messageid) {
		print STDERR "$! : $messageid\n" if $DEBUG;
	}
	print "$messageid: " if $DEBUG;
	die "$! : $messageid\n" unless chdir $messageid;

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

	my @attachments = $content =~ /Attachment.*?<B>(.*?href=".*?)"/sg;
	foreach my $attach (@attachments) {
		my ($filename, $imageurl) = $attach =~ /(.*?)<\/B>.*?href="(.*)/s;
		$filename =~ s/([^\w.]*)//g;
		if ($DEBUG and -f $filename) {
			print "-";
			next unless $SAVEALL; # Skip if file was downloaded previously
		}
		print "." if $DEBUG;
		$request = GET $imageurl;
		$response = $ua->simple_request($request);
		my $content = $response->content;
		die "Download limit exceeded\n" if ($content =~ /Document Unavailable/);
		die "$! : $filename\n" unless open(IFD, "> $filename");
		print IFD $content;
		close IFD;
	}
	print "\n" if $DEBUG;
	die "$!\n" unless chdir '../';
}

sub GetRedirectUrl($) {
    my $response = $_[0];
    my $url = $response->header('Location') || return undef;
    
    # the Location URL is sometimes non-absolute which is not allowed, fix it
    local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
    my $base = $response->base;
    $url = $HTTP::URI_CLASS->new($url, $base)->abs($base);
    
    return $url;
}

