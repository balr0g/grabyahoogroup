#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/GrabYahooGroup/files/yahoogroups_files.pl,v 1.12 2009-10-01 05:09:09 mithun Exp $

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

# By default works in verbose mode unless VERBOSE=0 via environment variable for cron job.
my $VERBOSE = 1;

# There is always something breaking - might as well have a file to email out
my $DEBUG = 1;

my $GETADULT = 1; # Allow adult groups to be downloaded.

my $COOKIE_SAVE = 1; # Save cookies before finishing - wont if aborted.
my $COOKIE_LOAD = 1; # Load cookies if saved from previous session.

my $username = '';
my $password = '';
my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/
my $TIMEOUT = 10; # Connection timeout changed from default 3 min for slow connection/server
my $USER_AGENT = 'GrabYahoo/1.00'; # Changing this value is probably unethical at the least and possible illegal at the worst

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

my ($user_group) = @ARGV;

terminate("Please specify a group to process") unless $user_group;

my ($group) = $user_group =~ /^([\w_\-]+)$/;

unless (-d $group or mkdir $group) {
	print "$! : $group\n" if $VERBOSE;
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
my $group_domain;

if ($COOKIE_LOAD and -f $Cookie_file) {
	$cookie_jar->load();
}

{
	$request = GET "http://login.yahoo.com/config/login?.done=http://groups.yahoo.com/group/$group/";
	$response = $ua->simple_request($request);
	terminate("[http://login.yahoo.com/config/login?.done=http://groups.yahoo.com/group/$group/] " . $response->as_string) if $response->is_error;
	
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		terminate("[$url] " . $response->as_string) if ($response->is_error);
	}
	$cookie_jar->extract_cookies($response);
	$cookie_jar->save if $COOKIE_SAVE;
	
	$content = $response->content;
	
	my $login_rand;
	my $u;
	my $challenge;
	my $pd;
	
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
}

($group_domain) = $url =~ /\/\/(.*?groups.yahoo.com)\//;

download_folder('');

sub download_folder {
	my ($sub_folder) = @_;
	# print "[$group]$sub_folder\n" if $VERBOSE;

	terminate("$! : $group$sub_folder") unless (-d $group . $sub_folder or mkdir $group . $sub_folder);

	$request = GET "http://$group_domain/group/$group/files$sub_folder/";
	$response = $ua->simple_request($request);
	terminate("[http://$group_domain/group/$group/files$sub_folder/] " . $response->as_string) if $response->is_error;
	
	while ( $response->is_redirect ) {
		$cookie_jar->extract_cookies($response);
		$cookie_jar->save if $COOKIE_SAVE;
		$url = GetRedirectUrl($response);
		$request = GET $url;
		$response = $ua->simple_request($request);
		terminate("[$url] " . $response->as_string) if ($response->is_error);
	}
	$cookie_jar->extract_cookies($response);
	$cookie_jar->save if $COOKIE_SAVE;
	
	$content = $response->content;
	
	eval {
		terminate("Yahoo error : not a member of this group") if $content =~ /You are not a member of the group /;
		terminate("Yahoo error : nonexistant group") if $content =~ /There is no group called /;
		terminate("Yahoo error : database unavailable") if $content =~ /The database is unavailable at the moment/;
		return if $content =~ /This folder is empty/;
		my ($cells) = $content =~ /<!-- start content include -->\s+(.+?)\s+<!-- end content include -->/s;
		while ($cells =~ /<tr>.+?<span class="title">\s+<a href="(.+?)">(.+?)<\/a>\s+<\/span>.+?<\/tr>/sg) {
			my $file_url = $1;
			my $file_name = decode_entities($2);
			utf8::encode($file_name) unless utf8::is_utf8($file_name);
			next if -e $group . $sub_folder . '/' . $file_name;
			if ($file_url =~ /\/$/) {
				download_folder("$sub_folder/$file_name");
				next;
			}
			print "[$group]$sub_folder/$file_name\n" if $VERBOSE;
	
			$request = GET $file_url;
			$response = $ua->simple_request($request);
			terminate("\n\t[$file_url] " . $response->as_string) if ($response->is_error);
			while ( $response->is_redirect ) {
				$cookie_jar->extract_cookies($response);
				$cookie_jar->save if $COOKIE_SAVE;
				$url = GetRedirectUrl($response);
				$request = GET $url;
				$response = $ua->simple_request($request);
				terminate("\n\t[$url] " . $response->as_string) if ($response->is_error);
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;
			$content = $response->content;
			# If the page comes up with just a advertizement without the message.
			if ($content =~ /Continue to message/s) {
				$request = GET $file_url;
				$response = $ua->simple_request($request);
				terminate("\n\t[$file_url] " . $response->as_string) if ($response->is_error);
				$content = $response->content;
			}
			$cookie_jar->extract_cookies($response);
			$cookie_jar->save if $COOKIE_SAVE;

			terminate("Yahoo error : group download limit exceeded") if (($content =~ /The document you requested is temporarily unavailable because this group\s+has exceeded its download limit/s) and $VERBOSE);
			if (($content =~ /The document you requested is temporarily unavailable because you\s+has exceeded its download limit/s) and $VERBOSE) {
				print STDERR "Yahoo error : user download limit exceeded";
				next;
			}
		
			terminate("$! : $file_name") unless open(IFD, "> $group$sub_folder/$file_name");
			binmode(IFD);
			print IFD $content;
			close IFD;
		
			$cookie_jar->save if $COOKIE_SAVE;
		}
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


