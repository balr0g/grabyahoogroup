#!/usr/bin/perl -wT

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/download.pl,v 1.1.1.4 2005-04-04 09:33:38 mithun Exp $

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



	my $MODULE = { "MESSAGES" => {'SUB' => sub { my $module = new GrabYahoo::Messages($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE, $BEGIN_MSGID, $END_MSGID);
					return $module; },
				      'ACTIVE' => $MESSAGES},
		       "FILES"    => {'SUB' => sub { my $module = new GrabYahoo::Files($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);
					return $module; },
				      'ACTIVE' => $FILES},
		       "PHOTOS"   => {'SUB' => sub { my $module = new GrabYahoo::Photos($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);
					return $module; },
				      'ACTIVE' => $PHOTOS},
		       "MEMBERS"  => {'SUB' => sub { my $module = new GrabYahoo::Members($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);
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

	my $client = $self->{'CLIENT'};

	$client->set_group_url($group);

	return $self;
}

1;


package GrabYahoo::Messages;

sub new {
	my $self = {};

	my ($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE, $BEGIN_MSGID, $END_MSGID) = @_;

	my $client = new GrabYahoo::Client($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);

	$self->{'CLIENT'} = $client;

	$client->retrieve("/group/$group/message");

	return bless $self;
}

sub process {
	my $self = shift;
}

1;


package GrabYahoo::Files;

sub new {
	my $self = {};

	my ($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE) = @_;

	my $client = new GrabYahoo::Client($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);

	$self->{'CLIENT'} = $client;

	$client->retrieve("/group/$group/message");

	return bless $self;
}

sub process {
	my $self = shift;
}

1;

package GrabYahoo::Photos;

sub new {
	my $self = {};

	my ($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE) = @_;

	my $client = new GrabYahoo::Client($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);

	$self->{'CLIENT'} = $client;

	$client->retrieve("/group/$group/message");

	return bless $self;
}

sub process {
	my $self = shift;
}

1;

package GrabYahoo::Members;

sub new {
	my $self = {};

	my ($group, $VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE) = @_;

	my $client = new GrabYahoo::Client($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE);

	$self->{'CLIENT'} = $client;

	$client->retrieve("/group/$group/message");

	return bless $self;
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

	my ($VERBOSE, $REFRESH, $GETADULT, $COOKIE_SAVE, $COOKIE_LOAD, $HUMAN_WAIT, $HUMAN_REFLEX, $HUMAN_BEHAVIOR, $BATCH_MODE, $USERNAME, $PASSWORD, $PROXY, $TIMEOUT, $USER_AGENT, $SNOOZE, $COOKIE_FILE) = @_;

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

	$self->{'UA'} = $ua;

	$self->{'GROUP_URL'} = 'groups.yahoo.com';

	return bless $self;
}

sub set_group_url {
	my $self = shift;

	my ($group) = @_;

	my $result = $self->retrieve("/group/$group/");

	($self->{'GROUP_URL'}) = $result->{'LAST_URL'} =~ /http:\/\/(.+?groups\.yahoo\.com)/;
}

sub retrieve {
	my $self = shift;

	my ($url) = @_;

	my $result->{'LAST_URL'} = $url;

	return $result;
}

1;
