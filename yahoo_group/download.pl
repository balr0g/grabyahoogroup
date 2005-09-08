#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/download.pl,v 1.2 2005-09-08 13:01:03 mithun Exp $

delete @ENV{ qw(IFS CDPATH ENV BASH_ENV PATH) };

use strict;

my $gyg = new GrabYahoo;
if ( ref($gyg) eq 'GrabYahoo' ) {
	$gyg->process();
} else {
	print $gyg . "\n";
}


package GrabYahoo;

use Getopt::Long;

sub new {

	my $VERBOSE = 1;

	my $begin_message_id;
	my $end_message_id;

	my $REFRESH = 1; # Download only new content

	my $GETADULT = 1; # Get adult content

	my $COOKIE_SAVE = 1; # Save cookies to local filesystem
	my $COOKIE_LOAD = 1; # Load cookies from previous session

	my $HUMAN_WAIT = 40; # Seconds to read an average page in YG
	my $HUMAN_REFLEX = 20; # Random seconds to wait before next request
	my $HUMAN_BEHAVIOR = 1; # Disable emulation of human behavior

	my $BLOCK_PERIOD = 60*60; # One hour

	my $BATCH_MODE = 0;
	my $USERNAME = '';
	my $PASSWORD = '';

	my $PROXY = ''; # In format http://hostname:port/

	my $TIMEOUT = 10; # In minutes for slow download connections

	my $USER_AGENT = 'GrabYahoo/2.00'; # Check legal implication of what you wish to set this value to
	my $SNOOZE = 60*60; # How long to snooze if Yahoo is blocking your request

	my $BEGIN_MSGID;
	my $END_MSGID;

	# Which module to use ?
	my $MESSAGES = 0;
	my $FILES = 0;
	my $PHOTOS = 0;
	my $MEMBERS = 0;

	my $result = GetOptions ('messages' => \$MESSAGES,
				 'files' => \$FILES,
				 'photos' => \$PHOTOS,
				 'members' => \$MEMBERS,
				 'verbose' => \$VERBOSE,
				 'refresh' => \$REFRESH,
				 'getadult' => \$GETADULT,
				 'cookie_save' => \$COOKIE_SAVE,
				 'cookie_load' => \$COOKIE_LOAD,
				 'human_wait=i' => \$HUMAN_WAIT,
				 'human_reflex=i' => \$HUMAN_REFLEX,
				 'human_behavior' => \$HUMAN_BEHAVIOR,
				 'block_period=i' => \$BLOCK_PERIOD,
				 'batch_mode' => \$BATCH_MODE,
				 'begin=i' => \$BEGIN_MSGID,
				 'end=i' => \$END_MSGID,
				 'username=s' => \$USERNAME,
				 'password=s' => \$PASSWORD,
				 'proxy=s' => \$PROXY,
				 'timeout=i' => \$TIMEOUT,
				 'user_agent=s' => \$USER_AGENT,
				 'snooze=i' => \$SNOOZE);

	return "Can't parse command line parameters" unless $result;

	my ($user_group) = @ARGV;
	return "Please specify a group to process" unless $user_group;
	my ($group) = $user_group =~ /^([\w_\-]+)$/;
	return "Group name provided is not valid" if $user_group ne $group;
	unless ($group or $BATCH_MODE) {
		print "Group to process : ";
		$user_group = <STDIN>;
		($group) = $user_group =~ /^([\w_\-]+)$/;
		unless ($group) {
			print "Group name is necessary to proceed\n";
			exit;
		}
	}

	my $COOKIE_FILE = "$group/yahoogroups.cookies";
	
	my $client = new GrabYahoo::Client($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BLOCK_PERIOD, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);

	my $MODULE = { "MESSAGES" => {'SUB' => sub { my $module = new GrabYahoo::Messages($group, $client, $BEGIN_MSGID, $END_MSGID);
					return $module; },
				      'ACTIVE' => $MESSAGES},
		       "FILES"    => {'SUB' => sub { my $module = new GrabYahoo::Files($group, $client);
					return $module; },
				      'ACTIVE' => $FILES},
		       "PHOTOS"   => {'SUB' => sub { my $module = new GrabYahoo::Photos($group, $client);
					return $module; },
				      'ACTIVE' => $PHOTOS},
		       "MEMBERS"  => {'SUB' => sub { my $module = new GrabYahoo::Members($group, $client);
					return $module; },
				      'ACTIVE' => $MEMBERS}
		  };

	my $active_module = '';
	foreach my $module (keys %$MODULE) {
		next unless $MODULE->{$module}->{'ACTIVE'};
		unless ($active_module) {
			$active_module = $module;
		} else {
			return "Please select only one module : Messages, Files, Photos, Members";
		}
	}

	unless ($active_module) {
		print STDERR "Warning no module specified falling back to MESSAGES\n";
		$active_module = "MESSAGES";
	}

	$| = 1 if $VERBOSE;

	my $module = $MODULE->{$active_module}->{'SUB'};
	my $self = &$module;
	
	return $self if ref($self) eq undef;

	my $client = $self->{'CLIENT'};

	$client->set_group_url($group);

	return $self;
}

1;


package GrabYahoo::Messages;

sub new {
	my $self = {};

	my ($group, $client, $BEGIN_MSGID, $END_MSGID) = @_;

	$self->{'GROUP'} = $group;

	$self->{'CLIENT'} = $client;

	my $result = $client->retrieve("/group/$group/message/1");
	
	my $response;
	
	if ((ref $result) eq 'HASH') {
		$response = $result->{'RESPONSE'};
	} elsif (defined $result) {
		return $result;
	}

	my $content = $response->content();

	return 'Not a member of the group : $group' if $content =~ /You are not a member of the group <b>$group/;
	
	my ($b, $e) = $content =~ /(\d+)-\d+ of (\d+) /;
	
	return q{Couldn't retrieve message begin page};
	
	$BEGIN_MSGID = $b if((!defined $BEGIN_MSGID) or ($b > $BEGIN_MSGID));
	$END_MSGID = $e if ((!defined $END_MSGID) or ($e < $END_MSGID));
	
	$self->{'BEGIN_MSGID'} = $BEGIN_MSGID;
	$self->{'END_MSGID'} = $END_MSGID;
	
	return bless $self;
}

sub process {
	my $self = shift;
	
	my $REFRESH = $self->{'REFRESH'};
	my $VERBOSE = $self->{'VERBOSE'};
	my $BEGIN_MSGID = $self->{'BEGIN_MSGID'};
	my $END_MSGID = $self->{'END_MSGID'};
	my $group = $self->{'GROUP'};
	
	print "Processing messages between $BEGIN_MSGID and $END_MSGID\n" if $VERBOSE;
	
	foreach my $messageid ($BEGIN_MSGID..$END_MSGID) {
		next if $REFRESH and -f "$group/$messageid";
		my $result = $self->retrieve("/group/$group/message/$messageid?source=1&unwrap=1");
		my $response;	
		if ((ref $result) eq 'HASH') {
			$response = $result->{'RESPONSE'};
		} elsif (defined $result) {
			return $result;
		}
		my $content = $response->content();
		
	}
}

1;


package GrabYahoo::Files;

sub new {
	my $self = {};

	my ($group, $client) = @_;

	$self->{'GROUP'} = $group;

	$self->{'CLIENT'} = $client;

	my $result = $client->retrieve("http://login.yahoo.com/config/login?.intl=us&.src=ygrp&.done=http%3a//groups.yahoo.com%2Fgroup%2F$group%2Ffiles");
	
	my $response;
	
	if ((ref $result) eq 'HASH') {
		$response = $result->{'RESPONSE'};
	} elsif (defined $result) {
		return $result;
	}

	my $content = $response->content();

	return bless $self unless $content =~ /You are not a member of the group <b>$group/;
	
	return 'Not a member of this group';
}

sub process {
	my $self = shift;
}

1;

package GrabYahoo::Photos;

sub new {
	my $self = {};

	my ($group, $client) = @_;

	$self->{'GROUP'} = $group;

	$self->{'CLIENT'} = $client;

	my $result = $client->retrieve("http://login.yahoo.com/config/login?.intl=us&.src=ygrp&.done=http%3a//groups.yahoo.com%2Fgroup%2F$group%2Ffiles");
	
	my $response;
	
	if ((ref $result) eq 'HASH') {
		$response = $result->{'RESPONSE'};
	} elsif (defined $result) {
		return $result;
	}

	my $content = $response->content();

	return bless $self unless $content =~ /You are not a member of the group <b>$group/;
	
	return 'Not a member of this group';
}

sub process {
	my $self = shift;
}

1;

package GrabYahoo::Members;

sub new {
	my $self = {};

	my ($group, $client) = @_;

	$self->{'GROUP'} = $group;

	$self->{'CLIENT'} = $client;

	my $result = $client->retrieve("http://login.yahoo.com/config/login?.intl=us&.src=ygrp&.done=http%3a//groups.yahoo.com%2Fgroup%2F$group%2Fmembers");
	
	my $response;
	
	if ((ref $result) eq 'HASH') {
		$response = $result->{'RESPONSE'};
	} elsif (defined $result) {
		return $result;
	}

	my $content = $response->content();

	return bless $self unless $content =~ /You are not a member of the group <b>$group/;
	
	return 'Not a member of this group';
}

sub process {
	my $self = shift;
}

1;

package GrabYahoo::Client;

use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();

sub new {
	my $package = shift;

	my ($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BLOCK_PERIOD, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE) = @_;

	srand(time() . $$) if $HUMAN_BEHAVIOR;

	my $self = {};

	$self->{'VERBOSE'} = $VERBOSE;
	$self->{'REFRESH'} = $REFRESH;
	$self->{'GETADULT'} = $GETADULT;
	$self->{'COOKIE_SAVE'} = $COOKIE_SAVE;
	$self->{'COOKIE_LOAD'} = $COOKIE_LOAD;
	$self->{'HUMAN_WAIT'} = $HUMAN_WAIT;
	$self->{'HUMAN_REFLEX'} = $HUMAN_REFLEX;
	$self->{'HUMAN_BEHAVIOR'} = $HUMAN_BEHAVIOR;
	$self->{'BLOCK_PERIOD'} = $BLOCK_PERIOD;
	$self->{'BATCH_MODE'} = $BATCH_MODE;
	$self->{'USERNAME'} = $USERNAME;
	$self->{'PASSWORD'} = $PASSWORD;
	$self->{'PROXY'} = $PROXY;
	$self->{'TIMEOUT'} = $TIMEOUT;
	$self->{'USER_AGENT'} = $USER_AGENT;
	$self->{'SNOOZE'} = $SNOOZE;

	my $ua = new LWP::UserAgent;
	$ua->proxy('http', $PROXY) if $PROXY;
	$ua->agent($USER_AGENT);
	$ua->timeout($TIMEOUT*60);
	my $cookie_jar = HTTP::Cookies->new( 'file' => $COOKIE_FILE );
	$ua->cookie_jar($cookie_jar);

	if ($COOKIE_LOAD and -f $COOKIE_FILE) {
		$cookie_jar->load();
	}

	$self->{'UA'} = $ua;

	$self->{'GROUP_URL'} = 'groups.yahoo.com';

	return bless $self;
}

sub set_group_url {
	my $self = shift;

	my ($group) = @_;

	my $result = $self->retrieve("/group/$group/");
	
	return unless defined $result;
	
	return if (ref $result) ne 'HASH';

	($self->{'GROUP_DOMAIN'}) = $result->{'REQUEST'}->uri() =~ /http:\/\/(.+?groups\.yahoo\.com)/;
}

sub retrieve {
	my $self = shift;

	my ($url) = @_;
	my $result;

	my $group_domain = $self->{'GROUP_DOMAIN'};
	my $ua = $self->{'UA'};
	my $HUMAN_WAIT = $self->{'HUMAN_WAIT'};
	my $HUMAN_REFLEX = $self->{'HUMAN_REFLEX'};
	my $HUMAN_BEHAVIOR = $self->{'HUMAN_BEHAVIOR'};
	
	my $cookie_jar = $ua->cookie_jar();
	
	my $VERBOSE = $self->{'VERBOSE'};
	
	sleep($HUMAN_WAIT + int(rand($HUMAN_REFLEX))) if $HUMAN_BEHAVIOR;

	my $request = GET "$group_domain$url";
	my $response = $ua->simple_request($request);
	$cookie_jar->extract_cookies($response);

	return "[$group_domain$url] " . $response->as_string if $response->is_error;
	
	$self->{'CYCLE'} = 1;

	$result = $self->holding_pages($request, $response);
	
	if ((ref $result) eq 'HASH') {
		$request = $result->{'REQUEST'};
		$response = $result->{'RESPONSE'};
	} elsif ((defined $result) and ((ref $result) ne 'HASH')) {
		return $result;
	}

	while ( $response->is_redirect ) {
		$url = GetRedirectUrl($response);
		$result->{'LAST_URL'} = $url;
		$request = GET $url;
		$response = $ua->simple_request($request);
		$cookie_jar->extract_cookies($response);
		return "[$url] " . $response->as_string if $response->is_error;

		$self->{'CYCLE'} = 1;

		$result = $self->holding_pages($request, $response);
	
		if ((ref $result) eq 'HASH') {
			$request = $result->{'REQUEST'};
			$response = $result->{'RESPONSE'};
		} elsif (defined $result) {
			return $result;
		}
	}

	$result->{'REQUEST'}  = $request;
	$result->{'RESPONSE'} = $response;

	return $result;
}


sub holding_pages {
	my $self = shift;
	
	my ($request, $response) = @_;
	
	my $result;
	
	my $ua = $self->{'UA'};
	my $VERBOSE = $self->{'VERBOSE'};
	my $username = $self->{'USERNAME'};
	my $password = $self->{'PASSWORD'};
	my $BATCH_MODE = $self->{'BATCH_MODE'};
	my $group_domain = $self->{'GROUP_DOMAIN'};
	my $HUMAN_WAIT = $self->{'HUMAN_WAIT'};
	my $HUMAN_REFLEX = $self->{'HUMAN_REFLEX'};
	my $HUMAN_BEHAVIOR = $self->{'HUMAN_BEHAVIOR'};
	my $GETADULT = $self->{'GETADULT'};
	my $BLOCK_PERIOD = $self->{'BLOCK_PERIOD'};
	
	sleep($HUMAN_WAIT + int(rand($HUMAN_REFLEX))) if $HUMAN_BEHAVIOR;
	
	my $content = $response->content();
	
	# Login Page
	if ($content =~ /<form method=post action="https:\/\/login.yahoo.com\/config\/login\?"/) {
		my ($u) = $content =~ /<input type=hidden name=.u value="(.+?)" >/s;
		my ($challenge) = $content =~ /<input type=hidden name=.challenge value="(.+?)" >/s;
		my ($done) = $content =~ /<input type=hidden name=.done value="(.+?)">/;
	
		unless ($username) {
			my ($slogin) = $content =~ /<input type=hidden name=".slogin" value="(.+?)" >/;
			$username = $slogin if $slogin;
		}

		unless ($BATCH_MODE) {
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
		}
		
		return 'No username provided' unless $username;
	
		$request = POST 'http://login.yahoo.com/config/login?',
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
			 '.done'  => $done,
			 'login'  => $username,
			 'passwd' => $password,
			 '.persistent' => 'y',
			 '.save'  => 'Sign In'
			];
		
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD PUT');
		$response = $ua->simple_request($request);
		$cookie_jar->extract_cookies($response);
		return "[http://login.yahoo.com/config/login] " . $response->as_string if $response->is_error;
		
		$result->{'REQUEST'} = $request;
		$result->{'RESPONSE'} = $response;
	
		$content = $response->content();
	}
	
	# Adult Confirmation Page
	if ($content =~ /<form action="\/adultconf" method="post">/) {
		return 'Adult Group confirmation required' unless $GETADULT;
		my ($dest) = $content =~ /<input type="hidden" name="dest" value="(.+?)">/;
		$request = POST 'http://groups.yahoo.com/adultconf',
				[ 'dest'  => $dest,
				  'accept' => 'I Accept'
				];
		$request->content_type('application/x-www-form-urlencoded');
		$request->header('Accept' => '*/*');
		$request->header('Allowed' => 'GET HEAD');
		$response = $ua->simple_request($request);
		$cookie_jar->extract_cookies($response);
		return "[http://groups.yahoo.com/adultconf] " . $response->as_string if $response->is_error;

		$result->{'REQUEST'} = $request;
		$result->{'RESPONSE'} = $response;
	
		$content = $response->content();
	}

	# Yahoo blocked for spamming
	my $CYCLE = $self->{'CYCLE'}; # Blocking cycle currently running

	while($content =~ /Unfortunately, we are unable to process your request at this time/i) {
		print STDERR "[$uri] Yahoo has blocked us, sleeping for " . $BLOCK_PERIOD*$CYCLE . " seconds\n" if $VERBOSE;
		sleep($BLOCK_PERIOD*$CYCLE);
		$response = $ua->simple_request($request);
		$cookie_jar->extract_cookies($response);
		return "[$uri] " . $response->as_string if $response->is_error;

		$content = $response->content();

		$self->{'CYCLE'}++;

		return;
	}

	$self->{'CYCLE'} = 0; # Reset blocking cycle currently running

	$result->{'REQUEST'} = $request;
	$result->{'RESPONSE'} = $response;

	# Advertizement Page

	if ($content =~ /Yahoo! Groups is an advertising supported service/ or $content =~ /Continue to message/s) {
		$response = $ua->simple_request($request);
		$cookie_jar->extract_cookies($response);
		return "[$uri] " . $response->as_string if $response->is_error;

		$result->{'REQUEST'} = $request;
		$result->{'RESPONSE'} = $response;

		$content = $response->content();
	}

	return $result;
}



1;
