#!/usr/bin/perl -w

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/download.pl,v 1.4 2010-09-11 20:02:41 mithun Exp $

delete @ENV{ qw(IFS CDPATH ENV BASH_ENV PATH) };

use strict;
use utf8;

use Crypt::SSLeay;
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities;

my $GROUP;

my $logger;
my $client;


my $gyg = new GrabYahoo;

$gyg->process();


package GrabYahoo;

use Getopt::Long;
use Term::ReadKey;

sub new {
	# Which module to use ?
	my $MESSAGES;
	my $FILES;
	my $PHOTOS;
	my $MEMBERS;

	my $VERBOSE = 1;

	my $USERNAME = '';
	my $PASSWORD = '';

	my $BEGIN_MSGID;
	my $END_MSGID;

	my $ALL = 1;

	my $result = GetOptions ('messages!' => \$MESSAGES,
				 'files!' => \$FILES,
				 'photos!' => \$PHOTOS,
				 'members!' => \$MEMBERS,
				 'verbose!' => \$VERBOSE,
				 'begin=i' => \$BEGIN_MSGID,
				 'end=i' => \$END_MSGID,
				 'username=s' => \$USERNAME,
				 'password=s' => \$PASSWORD,
				 'group=s' => \$GROUP,
				);

	die "Can't parse command line parameters" unless $result;

	die 'Group name is mandatory' unless $GROUP;

	mkdir $GROUP or die "$GROUP: $!\n" unless -d $GROUP;

	unless ($USERNAME) {
		opendir(UD, $GROUP) or die $GROUP . ': ' . $! . "\n";
		while (my $record = readdir UD) { last if (($USERNAME) = $record =~ /^(.+)\.cookie$/); }
		closedir UD;
	}

	my @terminals = GetTerminalSize(*STDOUT);
	die 'Username not provided and not running in terminal' unless $USERNAME and scalar @terminals;

	unless ($USERNAME) {
		print "Enter username : ";
		$USERNAME = <STDIN>;
		chomp $USERNAME;
	}

	foreach ($MESSAGES, $FILES, $PHOTOS, $MEMBERS) { $ALL = 0 if $_; };
	foreach ($MESSAGES, $FILES, $PHOTOS, $MEMBERS) { $_ = 1 if $ALL; };

	my $self = {};

	$logger = new GrabYahoo::Logger($GROUP . '/GrabYahooGroup.log');

	$client = new GrabYahoo::Client($USERNAME, $PASSWORD);

	my $content = $client->response()->content();

	$logger->info('Detecting server capabilities');
	# Detect capabilities
	$MESSAGES = ($MESSAGES and $content =~ m!<a href="/group/$GROUP/messages">.+?</a>!s) ? 1: 0;
	$FILES = ($FILES and $content =~ m!<a href="/group/$GROUP/files">.+?</a>!s) ? 1: 0;
	$PHOTOS = ($PHOTOS and $content =~ m!<a href="http://.+?/group/$GROUP/photos">.+?</a>!s) ? 1: 0;
	$MEMBERS = ($MEMBERS and $content =~ m!<a href="/group/$GROUP/members">.+?</a>!s) ? 1: 0;

	if ($MESSAGES) {
		$logger->info('MESSAGES enabled');
		my $object = eval { new GrabYahoo::Messages ($BEGIN_MSGID, $END_MSGID); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($FILES) {
		$logger->info('FILES enabled');
		my $object = eval { new GrabYahoo::Files; };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($PHOTOS) {
		$logger->info('PHOTOS enabled');
		my $object = eval { new GrabYahoo::Photos; };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($MEMBERS) {
		$logger->info('MEMBERS enabled');
		my $object = eval { new GrabYahoo::Members; };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	die 'Group homepage has no valid sections' unless $self->{'SECTIONS'};

	return bless $self;
}


sub process {
	my $self = shift;
	foreach ( @{$self->{'SECTIONS'}} ) { $_->process() };
}


package GrabYahoo::Client;

use HTTP::Request::Common qw(GET POST);

sub new {
	my $package = shift;
	my ($user, $pass) = @_;

	my $self = bless {};

	my @accessors = ('user', 'pass', 'ua', 'cookie_jar', 'response');
	no strict 'refs';
	foreach my $accessor (@accessors) {
		*$accessor = sub {
			my $self = shift;
			my ($data) = @_;
			$self->{uc($accessor)} = $data if $data;
			return $self->{uc($accessor)};
		};
	}
	use strict;

	$self->user($user);
	$self->pass($pass);

	my $ua = new LWP::UserAgent;
	$ua->agent('GrabYahoo/2.00');
	my $cookie_file = "$GROUP/$user.cookie";
	my $cookie_jar = HTTP::Cookies->new( 'file' => $cookie_file );
	$cookie_jar->load();
	$ua->cookie_jar($cookie_jar);
	my $response = $ua->simple_request(GET 'http://groups.yahoo.com/group/' . $GROUP);
	$self->response($response);

	$self->ua($ua);
	$self->cookie_jar($cookie_jar);

	my $content = $self->fetch(qq{https://login.yahoo.com/config/verify?.done=http%3a%2F%2Fgroups.yahoo.com%2Fgroup%2F$GROUP%2F});

	return $self;
}


sub fetch {
	my $self = shift;
	my ($url, $referrer, $is_image) = @_;

	my $ua = $self->ua();
	my $cookie_jar = $self->cookie_jar();

	my $SLEEP_COUNT = 1;

	$url = $self->get_absurl($url);
	$referrer = $self->get_absurl($referrer) if $referrer;

	my @headers = ('Referer' => $referrer) if $referrer;

	my $request = GET $url, @headers;
	my $response = $ua->simple_request($request);
	$cookie_jar->extract_cookies($response);
	$cookie_jar->save();
	$self->response($response) unless $is_image;

	die '[' . $url . '] ' . $response->as_string() if $response->is_error();
	my $content = $response->content();

	while($response->code() == 999 or $content =~ /Unfortunately, we are unable to process your request at this time/i) {
		$logger->debug($response->code());
		$logger->warn('Yahoo SPAM block - trying to check after ' . $SLEEP_COUNT . ' hours');
		sleep 60*60*$SLEEP_COUNT;
		$content = $self->fetch($url);
	}

	if ($content =~ /Yahoo! Groups is an advertising supported service/ or $content =~ /Continue to message/s) {
		$logger->debug($response->code());
		$content = $self->fetch($url);
	}

	if ($content =~ m!<form .+? name="login_form"!) {
		$logger->info('Performing login');
		$content = $self->process_loginform();
	}

	if ($content =~ m!<form action="/adultconf"!) {
		$logger->info('Confirming as adult');
		$content = $self->process_adultconf();
	}

	my $redirect;
	while ( $self->response()->is_redirect or $content =~ /location.replace/) {
		if ($self->response()->is_redirect()) {
			$redirect = $self->response()->header('Location');
		} else {
			($redirect) = $content =~ m!location\.replace\((.+?)\)!;
			$redirect =~ s/"//g;
			$redirect =~ s/'//g;
		}
		if ($url =~ m!errors/framework_error!) {
			$logger->warn('Yahoo framework error');
			$logger->info('Sleeping for 5 seconds');
			sleep 5;
			$logger->info('Attempting to retrieve original URL');
			$redirect = $url;
			$self->error_count();
		}
		$url = $self->get_absurl($redirect);
		$logger->info('Redirected to: ' . $url);
		$content = $self->fetch($url);
	}

	$self->reset_error_count();

	return $content;
}


sub error_count {
	my $self = shift;
	$self->{'ERROR_COUNTER'}++;
	die 'Too many errors from server' if $self->{'ERROR_COUNTER'} > 10;
}


sub reset_error_count {
	my $self = shift;
	$self->{'ERROR_COUNTER'} = 0;
}


sub process_adultconf {
	my $self = shift;
	my $response = $self->response();

	my $ua = $self->ua();
	my $cookie_jar = $self->cookie_jar();

	my $content = $response->content();

	my %params;

	my ($form) = $content =~ m!(<form action="/adultconf".+?>.+?</form>)!s;

	while ($form =~ m!<input.+?type="hidden" name="(.+?)" value="(.+?)">!g) {
		my $name = $1;
		my $value = $2;
		$params{$name} = $value;
	}
	$params{'accept'} = 'I Accept';

	my $request = POST $self->get_absurl('/adultconf', $response), [%params];
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	$cookie_jar->extract_cookies($response);
	$self->response($response);

	die '[/adultconf] ' . $response->as_string() if $response->is_error();

	return $response->content();
}


sub get_absurl {
	my $self = shift;
	my ($url) = @_;
	local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	my $base = $self->response()->base();
	$url = $HTTP::URI_CLASS->new($url, $base)->abs($base);

	return $url;
}


sub process_loginform {
	my $self = shift;
	my $response = $self->response();

	my $ua = $self->ua();
	my $cookie_jar = $self->cookie_jar();

	my $content = $response->content();

	my ($form) = $content =~ m!(<form .+?login_form.+?>.+?</form>)!s;

	my ($post) = $form =~ m!<form.+?action=(.+?) !;
	$post =~ s/"//g;
	$post =~ s/'//g;

	my %params;

	while ($form =~ m!<input.+?name="(.+?)".+?value="(.+?)">!g) {
		my $name = $1;
		my $value = $2;
		$params{$name} = $value;
	}

	unless ($self->pass()) {
		my @terminals = GetTerminalSize(*STDOUT);
		die 'Password not provided and not running in terminal' unless scalar @terminals;
		unless ($self->pass()) {
			use Term::ReadKey;
			ReadMode('noecho');
			print "Enter password : ";
			my $pass = ReadLine(0);
			ReadMode('restore');
			chomp $pass;
			$self->pass($pass);
			print "\n";
		}
	}

	$params{'.persistent'} = 'y';
	$params{'login'} = $self->user();
	$params{'passwd'} = $self->pass();

	my $request = POST $post, [%params];
	$request->content_type('application/x-www-form-urlencoded');
	$request->header('Accept' => '*/*');
	$request->header('Allowed' => 'GET HEAD PUT');
	$response = $ua->simple_request($request);
	$cookie_jar->extract_cookies($response);
	$self->response($response);

	die '[' . $post . '] ' . $response->as_string() if $response->is_error();

	return $response->content();
}


package GrabYahoo::Logger;

use Term::ReadKey;


sub new {
	my $package = shift;
	my $self = {};
	my ($logfile) = @_;

	my @terminals = GetTerminalSize(*STDOUT);
	$self->{'HANDLES'} = [ *STDOUT ] if scalar @terminals;

	my $file_handle;
	open ($file_handle, ">>", $logfile) or die $logfile . ": $!\n";
	push @{ $self->{'HANDLES'} }, $file_handle;

	# Various loggers
	my @loggers = ('debug', 'info', 'warn', 'error', 'fatal');
	no strict 'refs';
	foreach my $level (@loggers) {
		my $tag = uc($level);
		*$level = sub {my $self = shift; $self->dispatch("[$tag]", @_, "\n"); };
	}
	use strict;

	return bless $self;
}


sub dispatch {
	my $self = shift;
	foreach my $handle ( @{$self->{'HANDLES'}} ) {
		print $handle @_;
	}
}


package GrabYahoo::Messages;


sub new {
	my $self = {};
	return bless $self;
}


sub process {
	$logger->info('Processing MESSAGES');
}


package GrabYahoo::Files;


sub new {
	my $self = {};
	return bless $self;
}


sub process {
	my $self = shift;
	$logger->info('Processing FILES');
	mkdir $GROUP . '/FILES' or die "$GROUP/FILES: $!\n" unless -d $GROUP . '/FILES';
	$self->process_folder(qq{/group/$GROUP/files});
}


sub process_folder {
}


package GrabYahoo::Members;


sub new {
	my $self = {};
	return bless $self;
}


sub process {
	$logger->info('Processing MEMBERS');
}


package GrabYahoo::Photos;

use Data::Dumper;
use HTML::Entities;

sub new {
	my $self = {};
	if (-f $GROUP . '/PHOTOS/layout.dump') {
		my $buf = $/;
		$/ = undef;
		open(LAY, '<', $GROUP . '/PHOTOS/layout.dump') or die $GROUP . '/PHOTOS/layout.dump' . $! . "\n";
		my $dump = <LAY>;
		close LAY;
		$/ = $buf;
		my $VAR1;
		eval $dump;
		$self->{'LAYOUT'} = $VAR1;
	}
	return bless $self;
}


sub save_layout {
	my $self = shift;
	my ($final) = @_;

	my $LAYOUT = $self->{'LAYOUT'};

	return unless $LAYOUT;

	my $layout = Data::Dumper->Dump([$LAYOUT]);
	open (LAY, '>', $GROUP . '/PHOTOS/layout.dump') or die $GROUP . '/PHOTOS/layout.xml: ' . $! . "\n";
	print LAY $layout;
	close LAY;
}


sub process {
	my $self = shift;
	$logger->info('Processing PHOTOS');
	my $start = 1;
	my $next_page = 1;
	mkdir $GROUP . '/PHOTOS' or die "$GROUP/PHOTOS: $!\n" unless -d $GROUP . '/PHOTOS';
	while ($next_page) {
		$next_page = $self->process_album(qq{/group/$GROUP/photos/album/0/list?mode=list&order=mtime&start=$start&count=20&dir=desc});
		$start += 20;
	}

	$self->save_layout(1);
}


sub process_album {
	my $self = shift;
	my ($url) = @_;

	my $content = $client->fetch($url);

	my $more_pages = 0;

	while ($content =~ m!<a href="(/group/$GROUP/photos/album/\d+/pic/\d+/view)!sg) { $self->process_pic($1 . '?picmode=original&mode=list&order=ordinal&start=1&dir=asc'); };

	while ($content =~ m!(<div class="ygrp-photos-title ">.+?<br class="clear-both"/>)!sg) {
		my $record = $1;
		my ($album_url, $album_id, $album_name) = $record =~ m!<div class="ygrp-photos-title ">.+?<a href="(/group/$GROUP/photos/album/(\d+)/pic/list).*?>(.+?)</a>!sg;
		$album_name = decode_entities($album_name);
		my ($album_access) = $record =~ m!<div class="ygrp-photos-access">\s+(.+?)</div>!s;
		my ($creator_profile, $album_creator) = $record =~ m!<div class="ygrp-photos-creator "><a\s+href="(.+?)">(.+?)</a>!s;
		$album_creator = decode_entities($album_creator);
		my ($number_photos) = $record =~ m!<div class="ygrp-photos-size">(\d+)</div>!s;
		my ($last_modified) = $record =~ m!<div class="ygrp-photos-modified-date selected">\s+(.+?)</div>!s;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} = $album_name;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_ACCESS'} = $album_access;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'CREATOR_PROFILE'} = $creator_profile;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_CREATOR'} = $album_creator;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'NUMBER_PHOTOS'} = $number_photos;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'LAST_MODIFIED'} = $last_modified;
		$logger->info('[' . $GROUP . '] ' . $album_name);
		my $start = 1;
		my $next_page = 1;
		mkdir $GROUP . '/PHOTOS/' . $album_id or die "$GROUP/PHOTOS/$album_id: $!\n" unless -d $GROUP . '/PHOTOS/' . $album_id;
		while ($next_page) {
			$next_page = $self->process_album($album_url . qq#?mode=list&order=mtime&start=$start&count=20&dir=desc#);
			$start += 20;
		}
	};

	$more_pages = 1 if $content =~ m!<a href="(/group/$GROUP/photos/album/(\d+)/pic/list).*?>Next<!sg;

	$self->save_layout();

	return $more_pages;
}


sub process_pic {
	my $self = shift;
	my ($url) = @_;

	my ($album_id, $pic_id) = $url =~ m!/group/$GROUP/photos/album/(\d+)/pic/(\d+)/view!;

	opendir(AD, $GROUP . '/PHOTOS/' . $album_id) or die $GROUP . '/PHOTOS/' . $album_id . ': ' . $! . "\n";
	while (my $entry = readdir(AD)) {
		if ($entry =~ /^$pic_id\./) {
			$logger->info('[' . $GROUP . '] ' . $self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} . '/' . $pic_id . ' - exists (skipped)');
			return;
		}
	}
	closedir AD;

	my $content = $client->fetch($url);

	my ($img_url) = $content =~ m!<div id="spotlight" class="ygrp-photos-body-image".+?><img src="(.+?)"!s;
	my ($profile, $user) = $content =~ m!<div id="ygrp-photos-by">.+?:&nbsp;<a\s+href="(.+?)">(.+?)<!s;
	$user = decode_entities($user);
	my ($photo_title) = $content =~ m!<div id="ygrp-photos-title">(.+?)</div>!s;
	$photo_title = decode_entities($photo_title);
	my ($file_name) = $content =~ m!<div id="ygrp-photos-filename">.+?:&nbsp;(.+?)<!s;
	$file_name = decode_entities($file_name);
	my ($file_ext) = $file_name =~ m!\.([^.]+)$!;
	$file_ext ||= 'jpg';
	$file_ext = decode_entities($file_ext);
	my ($posted) = $content =~ m!<div id="ygrp-photos-posted">.+?:&nbsp;(.+?)<!s;
	$posted = decode_entities($posted);
	my ($resolution) = $content =~ m!<div id="ygrp-photos-resolution">.+?:&nbsp;(.+?)<!s;
	$resolution = decode_entities($resolution);
	my ($photo_size) = $content =~ m!<div id="ygrp-photos-size">.+?:&nbsp;(.+?)<!s;
	$photo_size = decode_entities($photo_size);

	$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'PICTURES'}->{$pic_id} = {
					'USER' => $user,
					'PROFILE' => $profile,
					'PHOTO_TITLE' => $photo_title,
					'FILE_NAME' => $file_name,
					'POSTED' => $posted,
					'RESOLUTION' => $resolution,
					'SIZE' => $photo_size,
					'FILE_EXT' => $file_ext,
				};

	my $image = $client->fetch($img_url, $url, 1);

	$logger->info('[' . $GROUP . '] ' . $self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} . '/' . $photo_title . " - $resolution px / $photo_size");

	open(IFD, '>', "$GROUP/PHOTOS/$album_id/$pic_id.$file_ext") or $logger->error("$GROUP/$album_id/$pic_id.$file_ext: $!") and return;
	print IFD $image;
	close IFD;

	$self->save_layout();
}


1;
