#!/usr/bin/perl -w

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/download.pl,v 1.15 2011-02-14 00:26:06 mithun Exp $

delete @ENV{ qw(IFS CDPATH ENV BASH_ENV PATH) };

use 5.8.1;

use strict;

use Crypt::SSLeay;
use HTTP::Cookies ();
use LWP::UserAgent ();
use LWP::Simple ();
use HTML::Entities();
use Encode;
use URI::Escape;

use Data::Dumper;
# $Data::Dumper::Useqq = 1;
# $Data::Dumper::Purity = 1;

my $GROUP;

my $logger;
my $client;

my $HTTP_PROXY_URL = ''; # Proxy server if any http://hostname:port/

my $gyg = new GrabYahoo;

$gyg->process();


package GrabYahoo;

use Getopt::Long;
use Term::ReadKey;

sub new {
	# Which module to use ?
	my $MESSAGES;
	my $FILES;
	my $ATTACHMENTS;
	my $PHOTOS;
	my $MEMBERS;

	my $USERNAME = '';
	my $PASSWORD = '';

	my $BEGIN_MSGID;
	my $END_MSGID;
	my $INCREASING;
	my $MBOX = 1;

	my $FORCE_GET;

	my $MANUAL;

	my $QUIET = 1;
	my $VERBOSE = 0;

	my $PHOTO_INDEX = 1;
	my $ATTACH_INDEX = 1;
	my $MEMBER_INDEX = 1;

	my $HELP = 0;


	my $result = GetOptions ('messages!' => \$MESSAGES,
				 'files!' => \$FILES,
				 'attachments!' => \$ATTACHMENTS,
				 'photos!' => \$PHOTOS,
				 'members!' => \$MEMBERS,
				 'begin=i' => \$BEGIN_MSGID,
				 'end=i' => \$END_MSGID,
				 'mbox!' => \$MBOX,
				 'username=s' => \$USERNAME,
				 'password=s' => \$PASSWORD,
				 'group=s' => \$GROUP,
				 'forceget' => \$FORCE_GET,
				 'quiet+' => \$QUIET,
				 'verbose+' => \$VERBOSE,
				 'photo-index!' => \$PHOTO_INDEX,
				 'attach-index!' => \$ATTACH_INDEX,
				 'member-index!' => \$MEMBER_INDEX,
				 'manual-continue!' => \$MANUAL,
				 'increasing!' => \$INCREASING,
				 'help!' => \$HELP,
				);

	die "Can't parse command line parameters\n" unless $result;

	if ($HELP) {
		print qq{
Usage:
	$0 [--messages [[--nombox] [--increasing] [--begin] [--end]]] [--files] [--attachments [--noattach-index]] [--photos [--nophoto-index]] [--members [--nomember-index]] [--username] [--password] [--group] [--manual-continue] [--forceget] [--quiet] [--verbose] [--help]
		messages: Retrieve all the email messages
			begin: Oldest message to pick
			end: Latest message to pick
			increasing: Start from oldest to latest
			nombox: Don't generate mbox format file for the messages
		files: Retrieve everything from the files section
		attachments: Retrieve everything from the attachments section
			noattach-index: Don't generate html index page to browse the downloaded attachments
		photos: Retrieve everything from the photos section
			nophoto-index: Don't generate html index page to browse the downloaded photos
		members: Retrieve everything from the members section including members, moderators, bouncing, pending and banned list
			nomember-index: Don't generate html index page to browse the member list

		username: Login username
		password: Login password

		group: Group to process

		manual-continue: Don't sleep for an hour rather prompt user to hit continue if running under a terminal

		forceget: Will download already downloaded content

		quiet: Decrease logging one level
		verbose: Increase logging one level

		All the above options are optional especially if you are on a console or a terminal.

		Username is optional if you have gone through authentication atleast once in the near past
		Password is optional if you have gone through authentication atleast once in the near past and Yahoo doesn't ask for it again - this is usually once every two weeks

		You can provide either or both the begin and end parameters for messages. Script defaults to 1 for begin and the last available on the website for end.

		Photo Indexing and Attachment Indexing are enabled by default unless you want to dissable by passing --nophoto-index or --noattach-index

		Members retrieval will report more details depending upon whether you are the moderator or creater of the group

		There are five levels of logging debug, info, warn, error and fatal - you can increase or decrease more than one level by providing multiple quiet or verbose parameters. The script will apply the net of the two counts.

MetaData:
	GROUP/USERNAME.cookie: Authentication cookies are stored here - deleting it will force a login (no this wont help if Yahoo is blocking for maxed out quota)
	GROUP/GrabYahooGroup.log: Log file to capture all output - feel free to delete whenever you like (it can get pretty large fast)
	GROUP/[CAPABILITIES]/layout.dump: Human readable metadata used for generating index pages - can be used for custom html pages or other interfaces
	GROUP/MESSAGES/[n]: All files with numbers as names are the individual messages - purging them will cause all message to be re-downloaded in the next run
		\n};

		exit 0;
	}

	die "Invalid begining message id\n" if ($BEGIN_MSGID and ($BEGIN_MSGID < 1));
	die "Invalid end message id\n" if ($END_MSGID and ($END_MSGID < 1));
	die "Begining message id can't be greater than end message id\n" if ($BEGIN_MSGID and $END_MSGID and ($BEGIN_MSGID > $END_MSGID));

	eval { GetTerminalSize(*STDOUT) };

	my $IN_TERMINAL = 1 unless $@;

	die 'Group name is mandatory' unless $GROUP or $IN_TERMINAL;

	unless ($GROUP) {
		print "Group to download : ";
		$GROUP = <STDIN>;
		chomp $GROUP;
	}

	die 'Group name is mandatory' unless $GROUP;

	mkdir $GROUP or die "$GROUP: $!\n" unless -d $GROUP;

	if ($VERBOSE > $QUIET) {
		$QUIET = 0;
	} else {
		$QUIET -= $VERBOSE;
	}
	$logger = new GrabYahoo::Logger('file' => qq{$GROUP/GrabYahooGroup.log}, 'quiet' => $QUIET, 'in_terminal' => $IN_TERMINAL);
	$logger->group($GROUP);
	$logger->section(' ');

	unless ($USERNAME) {
		opendir(UD, $GROUP) or $logger->fatal(qq/$GROUP: $!/);
		while (my $record = readdir UD) { last if (($USERNAME) = $record =~ /^(.+)\.cookie$/); }
		closedir UD;
	}

	$logger->fatal('Username not provided and not running in terminal') unless $USERNAME or $IN_TERMINAL;

	unless ($USERNAME) {
		print "Enter username : ";
		$USERNAME = <STDIN>;
		chomp $USERNAME;
	}

	unless ($MESSAGES or $FILES or $ATTACHMENTS or $PHOTOS or $MEMBERS) {
		foreach ($MESSAGES, $FILES, $ATTACHMENTS, $PHOTOS, $MEMBERS) { $_ = 1 };
	}

	my $self = {};

	$client = new GrabYahoo::Client('user' => $USERNAME, 'password' => $PASSWORD, 'in_terminal' => $IN_TERMINAL, 'manual' => $MANUAL);

	my $content = $client->response()->content();

	$logger->fatal('Group not found') if $content =~ m!<h3>Group Not Found</h3>!;

	my ($capabilities) = $content =~ m!<div class="ygrp-contentblock">\s+<ul class="ygrp-ul menulist">\s+(.+?)\s+</ul>!s;

	$logger->fatal(q/This shouldn't happen - capabilities section missing ?/) unless $capabilities;

	# Ensure we use the group name Yahoo is familiar with
	($GROUP) = $capabilities =~ m!<li class="active"> <a href="/group/(.+?)/!s;
	unless ($GROUP) {
		$logger->debug($capabilities);
		$logger->fatal('Group capabilities missing');
	}

	$logger->info('Detecting server side capabilities');
	# Detect capabilities
	$MESSAGES = ($MESSAGES and $capabilities =~ m!/group/$GROUP/messages!s) ? 1: 0;
	$FILES = ($FILES and $capabilities =~ m!/group/$GROUP/files">!s) ? 1: 0;
	$ATTACHMENTS = ($ATTACHMENTS and $capabilities =~ m!/group/$GROUP/attachments/folder/0/list!s) ? 1: 0;
	$PHOTOS = ($PHOTOS and $capabilities =~ m!/group/$GROUP/photos!s) ? 1: 0;
	$MEMBERS = ($MEMBERS and $capabilities =~ m!/group/$GROUP/members!s) ? 1: 0;

	if ($MESSAGES) {
		$logger->info('MESSAGES enabled');
		my $object = eval { new GrabYahoo::Messages (force => $FORCE_GET, begin => $BEGIN_MSGID, end => $END_MSGID, mbox => $MBOX, increasing => $INCREASING); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($FILES) {
		$logger->info('FILES enabled');
		my $object = eval { new GrabYahoo::Files(force => $FORCE_GET); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($ATTACHMENTS) {
		$logger->info('ATTACHMENTS enabled');
		my $object = eval { new GrabYahoo::Attachments(force => $FORCE_GET, index => $ATTACH_INDEX); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($PHOTOS) {
		$logger->info('PHOTOS enabled');
		my $object = eval { new GrabYahoo::Photos(force => $FORCE_GET, index => $PHOTO_INDEX); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	if ($MEMBERS) {
		$logger->info('MEMBERS enabled');
		my $object = eval { new GrabYahoo::Members(force => $FORCE_GET, index => $MEMBER_INDEX); };
		if ($@) {
			$logger->error( $@ );
		} else {
			push @{ $self->{'SECTIONS'} }, $object;
		}
	}

	$logger->warn('Group homepage has no valid sections') unless $self->{'SECTIONS'};

	return bless $self;
}


sub process {
	my $self = shift;
	foreach ( @{$self->{'SECTIONS'}} ) { $_->process() };
}


package GrabYahoo::Client;

use HTTP::Request::Common qw(GET POST);
use Time::HiRes qw(usleep);

sub new {
	my $package = shift;
	my %args = @_;
	my $user = $args{'user'};
	my $password = $args{'password'};
	my $in_terminal = $args{'in_terminal'};
	my $manual = $args{'manual'};

	my $self = bless {};

	my @accessors = ('user', 'pass', 'ua', 'cookie_jar', 'response', 'in_terminal', 'manual');
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
	$self->pass($password);
	$self->in_terminal($in_terminal);
	$self->manual($manual);

	my $ua = new LWP::UserAgent;
	$ua->proxy('http', $HTTP_PROXY_URL) if $HTTP_PROXY_URL;	
	$ua->agent('GrabYahoo/2.00');
	my $cookie_file = "$GROUP/$user.cookie";
	my $cookie_jar = HTTP::Cookies->new( 'file' => $cookie_file );
	$cookie_jar->load();
	$ua->cookie_jar($cookie_jar);
	my $response = $ua->simple_request(GET qq{http://www.yahoo.com/});
	$self->response($response);

	$self->ua($ua);
	$self->cookie_jar($cookie_jar);

	my $content = $self->fetch(qq{https://login.yahoo.com/config/verify?.done=http%3a%2F%2Fgroups.yahoo.com%2Fgroup%2F$GROUP%2F});

	$content = $self->fetch(qq{https://login.yahoo.com/config/login?.done=http%3a%2F%2Fgroups.yahoo.com%2Fgroup%2F$GROUP%2F}) if $content !~ m!login.yahoo.com/config/login\?logout=1!s;

	return $self;
}


sub fetch {
	my $self = shift;
	my ($url, $referrer, $is_image) = @_;

	my $ua = $self->ua();
	my $cookie_jar = $self->cookie_jar();

        $self->random_sleep_wait();

	$url = $self->get_absurl($url);
	$referrer = $self->get_absurl($referrer) if $referrer;

	my @headers = ('Referer' => $referrer) if $referrer;

	my $request = GET $url, @headers;
	my $response = $ua->simple_request($request);
	$cookie_jar->extract_cookies($response);
	$cookie_jar->save();
	$self->response($response) unless $is_image;

	my $content = $response->content();

	if ($response->is_error()) {
		if ($response->code() > 499 and $response->code() < 600) {
			$logger->warn($url . ': Document Not Accessible - report to Yahoo - code ' . $response->code());
			$self->error_count();
			$logger->info('Sleeping for 1 min');
			$self->pause(60);
			$content = $client->fetch($url,$referrer,$is_image);
		} elsif ($response->code() == 404 || 403 and $is_image) {
			return '';
		} else {
			$logger->fatal(qq/[$url] / . $response->as_string()) if $response->is_error();
		}
	}

	my ($message_block) = $content =~ m#<!-- start content include -->.+?<div class="ygrp-contentblock">(.+?)</div>#s;

	if ($message_block and $message_block !~ /</s and $content =~ m!<td class="ygrp-topic-title entry-title" align=left>!s) {
		$message_block =~ s/^\s+//;
		$message_block =~ s/\s+$//;
		$logger->error($message_block);
		$self->error_count();
		$logger->warn(qq/Sleeping for one hour/);
		$self->pause();
		$content = $self->fetch($url,$referrer,$is_image);
	}

	if ($content =~ /error 999/s) {
		$logger->error('Yahoo quota block kicked in');
		$self->error_count();
		$logger->warn(qq/Sleeping for one hour/);
		$self->pause();
		$content = $self->fetch($url,$referrer,$is_image);
	}

	if(my ($message) = $content =~ m!<div class="ygrp-errors">(.+?)</div>!s) {
		$message =~ s!<.+?>!!sg;
		$message =~ s!&.+?;!!sg;
		$logger->error($message);
	}

	if (my ($login_url) = $content =~ m!<h4><a href="(http://login.yahoo.com/config/.+?)"!s) {
		$logger->info('Redirecting to login page');
		$self->fetch($login_url);
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
		$redirect = HTML::Entities::decode($redirect);
		if ($redirect =~ m!errors/framework_error!) {
			$logger->warn('Yahoo framework error');
			$self->pause(5);
			$logger->info('Attempting to retrieve original URL');
			$redirect = $url;
			$self->error_count();
		}
		if ($redirect =~ m!interrupt!) {
			$logger->info('Advertisements interrupt: ' . $redirect);
			$content = $self->fetch($redirect,$referrer,$is_image);
			($url) = $redirect =~ /done=(.+)$/;
			$url = URI::Escape::uri_unescape($url);
		} else {
			$url = $self->get_absurl($redirect);
		}
		$logger->info(qq/Redirected to: $url/);
		$content = $self->fetch($url,$referrer,$is_image);
	}

	$self->reset_error_count();

	return $content;
}


sub error_count {
	my $self = shift;
	$self->{'ERROR_COUNTER'}++;
	$logger->fatal('Too many errors from server') if $self->{'ERROR_COUNTER'} > 10;
	return $self->{'ERROR_COUNTER'};
}


sub reset_error_count {
	my $self = shift;
	$self->{'ERROR_COUNTER'} = 0;
}


sub pause {
	my $self = shift;
	my $duration = shift || 60*60;
	if ($self->in_terminal() and $self->manual()) {
		print "Hit [ENTER] when ready to continue: ";
		my $response = <>;
	} else {
		$logger->info( 'Sleeping till - ' . scalar(localtime(time()+$duration)) );
		sleep $duration;
	}
}

sub random_sleep_wait {
        my $self = shift;
	my $range = 2500;
	my $minimum = 500;
	my $random = int(rand($range)) + $minimum;
	usleep($random * 1000);
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

	$logger->fatal('[/adultconf] ' . $response->as_string()) if $response->is_error();

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
		$logger->fatal('Password not provided and not running in terminal') unless $self->in_terminal();
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

	$logger->fatal(qq/[$post] / . $response->as_string()) if $response->is_error();

	return $response->content();
}


package GrabYahoo::Logger;


sub new {
	my $package = shift;
	my $self = bless {};
	my %args = @_;

	$self->{'IN_TERMINAL'} = $args{'in_terminal'};

	my $logfile = $args{'file'};
	my $quiet = $args{'quiet'};

	my @accessors = ('group', 'section');
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

	$self->{'HANDLES'} = [ *STDOUT ] if $self->{'IN_TERMINAL'};

	my $file_handle;
	open ($file_handle, ">>", $logfile) or die qq/$logfile: $!\n/;
	push @{ $self->{'HANDLES'} }, $file_handle;

	# Various loggers
	my @loggers = ('debug', 'info', 'warn', 'error');
	no strict 'refs';
	foreach my $level (@loggers) {
		my $tag = uc($level);
		if ($quiet) {
			*$level = sub {};
			$quiet--;
			next;
		};
		*$level = sub {
			my $self = shift;
			my $group = $self->group();
			my $section = $self->section();
			$self->dispatch(qq/[$tag]/, qq/[$group]/, qq/[$section]/, @_, "\n");
		};
	}
	use strict;
	sub fatal {
		my $self = shift;
		my $group = $self->group();
		my $section = $self->section();
		$self->dispatch('[FATAL]', qq/[$group]/, qq/[$section]/, @_, "\n");
		exit 255;
	}

	$self->group(' ');
	$self->section(' ');
	$self->info('Started: ' . localtime() );

	return $self;
}


sub DESTROY {
	my $self = shift;
	$self->group(' ');
	$self->section(' ');
	$self->info('Finished: ' . localtime() );
}


sub dispatch {
	my $self = shift;
	foreach my $handle ( @{$self->{'HANDLES'}} ) {
		print $handle @_;
	}
}


package GrabYahoo::Messages;


sub new {
	my $package = shift;
	my %args = @_;
	my $self->{'FORCE_GET'} = $args{'force'};
	$self->{'BEGIN_MSGID'} = $args{'begin'};
	$self->{'END_MSGID'} = $args{'end'};
	$self->{'MBOX'} = $args{'mbox'};
	$self->{'INCREASING'} = $args{'increasing'};
	return bless $self;
}


sub process {
	my $self = shift;

	$logger->section('Messages');
	$logger->info('Processing MESSAGES');

	my $force = $self->{'FORCE_GET'};
	my $begin_msg = $self->{'BEGIN_MSGID'} || 1;
	my $end_msg = $self->{'END_MSGID'};
	my $increasing = $self->{'INCREASING'};

	unless (-d qq{$GROUP/MESSAGES}) {
		mkdir qq{$GROUP/MESSAGES} or $logger->fatal(qq{$GROUP/MESSAGES: } . $!);
		$increasing = 1;
	}
	my $content = $client->fetch(qq{/group/$GROUP/messages/1?xm=1&m=s&l=1&o=1});
	($end_msg) = $content =~ m!<td class="viewright" .+?>\s+[^\s]+ <em>\d+ - \d+</em> [^\s]+ (\d+) !s unless $end_msg;
	my @msg_list = reverse($begin_msg..$end_msg);
	@msg_list = ($begin_msg..$end_msg) if $increasing;
	foreach my $msg_idx (@msg_list) {
		next if (!$force and -f qq!$GROUP/MESSAGES/$msg_idx!);
		$self->save_message($msg_idx);
	}

	if ($self->{'MBOX'}) {
		$self->mboxify();
	}
}


sub mboxify {
	my $self = shift;

	open(MD, '>', qq{$GROUP/MESSAGES/$GROUP.mbox}) or $logger->fatal(qq{$GROUP/MESSAGES/$GROUP.mbox: } . $!);

	my @sources;

	opendir(MR, qq{$GROUP/MESSAGES/}) or $logger->fatal(qq{$GROUP/MESSAGES/: } . $!);
	while (my $file = readdir MR) {
		next if $file eq '.';
		next if $file eq '..';
		next if $file eq 'ATTACHMENTS';
		next if $file eq qq/$GROUP.mbox/;
		push @sources, $file;
	}
	closedir MR;

	$logger->info('Generating mbox file');

	foreach my $file (sort {$a <=> $b} @sources) {
		$logger->debug('Sourcing: ' . $file);
		open(SD, '<', qq{$GROUP/MESSAGES/$file}) or $logger->fatal(qq{$GROUP/MESSAGES/$file: } . $!);
		my $from_line = <SD>;
		$from_line =~ s/From [^\s]+/From -/;
		print MD $from_line;
		my $line_terminator = $/;
		$/ = undef;
		my $msg = <SD>;
		$/ = $line_terminator;
		$msg =~ s/^(>*)From />$1From /mg;
		print MD $msg;
		print MD "\n";
		close SD;
	}

	close MD;
}


sub save_message {
	my $self = shift;

	my ($idx) = @_;

	my $content = $client->fetch(qq{/group/$GROUP/message/$idx?source=1});
	my ($message) = $content =~ m!<td class="source user" .+?>\s+(From .+?)</td>!s;
	unless ($message) {
		my ($message_block) = $content =~ m#<!-- start content include -->.+?<div class="ygrp-contentblock">(.+?)</div>#s;
		$message_block =~ s/^\s+//;
		$message_block =~ s/\s+$//;
		$logger->warn($idx . ': ' . $message_block);
		return;
	}
	#Strip all Yahoo tags
	$message =~ s!<.+?>!!sg;
	# Get original HTML back
	$message = HTML::Entities::decode($message);
	my ($header, $body) = $message =~ m!^(.+?)\n\n(.+)$!s;
	#Yahoo gobbles the whitespace on continuation line
	$header =~ s!\n([\w-]+) !\n    $1 !sg;
	my ($subject) = $header =~ m!\nSubject: (.*?)\n[\w-]+:!s;
	$subject = '[NO SUBJECT]' unless $subject;
	$subject =~ s!\n!!sg;
	$subject = Encode::decode('MIME-Header', $subject);
	$logger->info($idx . ':' . $subject);
	open(MH, '>', qq!$GROUP/MESSAGES/$idx!) or $logger->fatal(qq{$GROUP/MESSAGES/$idx: } . $!);
	print MH $header;
	print MH "\n\n";
	print MH $body;
	close MH;
}


package GrabYahoo::Files;


sub new {
	my $package = shift;
	my %args = @_;
	my $self = { 'FORCE_GET' => $args{'force'} };
	$self->{'MSFILES'} = 0;
	if ($^O eq 'MSWin32' or $^O eq 'cygwin' or $^O eq 'dos') {
		$self->{'MSFILES'} = 1;
		$logger->warn('Restricted filesystem - some filenames will be modified if downloaded');
	}
	return bless $self;
}


sub process {
	my $self = shift;
	$logger->section('Files');
	$logger->info('Processing FILES');
	mkdir qq{$GROUP/FILES} or $logger->fatal(qq{$GROUP/FILES: } . $!) unless -d qq{$GROUP/FILES};
	$self->process_folder(qq{/group/$GROUP/files/});
}


sub process_folder {
	my $self = shift;
	my ($url) = @_;

	my $force = $self->{'FORCE_GET'};

	my ($folder) = $url =~ m{/files/(.+?)$};
	$folder ||= '';
	# unescape URI
	$folder =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

	$logger->debug($folder);
	mkdir qq{$GROUP/FILES/$folder} or $logger->fatal(qq{$GROUP/FILES/$folder: } . $!) unless -d qq{$GROUP/FILES/$folder};

	my $content = $client->fetch($url);

	my ($body) = $content =~ m{<!-- start content include -->\s+(<div .+?</div>)\s+<!-- end content include -->}s;

	while ($body =~ m!<span class="title">\s+<a href="(.+?)">(.+?)</a>\s+</span>!sg) {
		my $link = $1;
		my $description = $2;
		$description = HTML::Entities::decode($description);
		if ($link =~ m!/group/$GROUP/files/!) {
			$self->process_folder($link);
		} else {
			my $fs_name = $description;
			$fs_name = $self->msfiles($description) if $self->{'MSFILES'};
			if (!$force and -f qq{$GROUP/FILES/$folder$fs_name}) {
				$logger->debug(qq{$folder$fs_name - exists [skipped]});
				next;
			}
			$logger->info($folder . $description);
			my $file = $client->fetch($link, $url, 1);
			next unless $file;
			open(ID, '>', qq{$GROUP/FILES/$folder$fs_name}) or $logger->fatal(qq{$GROUP/FILES/$folder$fs_name: } . $!);
			binmode(ID);
			print ID $file;
			close ID;
		}
	}
}


sub msfiles {
	my $self = shift;
	my ($file_name) = @_;
	return $file_name;
}


package GrabYahoo::Attachments;


sub new {
	my $package = shift;
	my %args = @_;
	my $self = {
		'FORCE_GET' => $args{'force'},
		'INDEX' => $args{'index'},
	};
	if (-f qq{$GROUP/MESSAGES/ATTACHMENTS/layout.dump}) {
		my $buf = $/;
		$/ = undef;
		open(LAY, '<', qq{$GROUP/MESSAGES/ATTACHMENTS/layout.dump}) or $logger->fatal(qq{$GROUP/PHOTOS/layout.dump: } . $!);
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

	my $LAYOUT = $self->{'LAYOUT'};

	return unless $LAYOUT;

	my $layout = Data::Dumper->Dump([$LAYOUT]);
	open (LAY, '>', qq{$GROUP/MESSAGES/ATTACHMENTS/layout.dump}) or $logger->fatal(qq{$GROUP/MESSAGES/ATTACHMENTS/layout.dump: } . $!);
	print LAY $layout;
	close LAY;
}


sub process {
	my $self = shift;

	$logger->section('Attachments');
	$logger->info('Processing ATTACHMENTS');

	mkdir qq{$GROUP/MESSAGES} or $logger->fatal(qq{$GROUP/MESSAGES: } . $!) unless -d qq{$GROUP/MESSAGES};
	mkdir qq{$GROUP/MESSAGES/ATTACHMENTS} or $logger->fatal(qq{$GROUP/MESSAGES/ATTACHMENTS: } . $!) unless -d qq{$GROUP/MESSAGES/ATTACHMENTS};
	my $start = 1;
	my $next_page = 1;
	while ($next_page) {
		$next_page = $self->process_folder(qq{/group/$GROUP/attachments/folder/0/list?mode=list&order=mtime&start=$start&count=20&dir=desc});
		$start += 20;
	}

	$self->save_layout();

	if ($self->{'INDEX'}) {
		$logger->info('Generating index page');
		$self->generate_index();
	}
}


sub generate_index {
	my $self = shift;

	my $layout = $self->{'LAYOUT'};

	open (HD, '>', $GROUP . '/MESSAGES/ATTACHMENTS/index.html') or $logger->fatal($GROUP . '/MESSAGES/ATTACHMENTS/index.html: ' . $!);
	print HD q{
<HTML>
<BODY BACKGROUND='WHITE'>
	};

	if (scalar keys %{$layout->{'FOLDER'}}) {
		print HD q{
<TABLE ALIGN='CENTER' BORDER='2' WIDTH='100%' CELLPADDING='0' CELLSPACING='0'>
<THEAD>
	<TR BGCOLOR='BLACK'>
		<TD ALIGN='CENTER' WIDTH='50%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Mail Subject</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Attachments</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='20%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Creator</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Date</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Original Mail</STRONG></FONT></TD>
	</TR>
</THEAD>
<TBODY>
		};
		foreach my $folder_id (keys %{$layout->{'FOLDER'}}) {
			my $album = $layout->{'FOLDER'}->{$folder_id};
			my $subject = HTML::Entities::encode($album->{'FOLDER_NAME'});
			my $number_attach = HTML::Entities::encode($album->{'NUMBER_ATTACHMENTS'});
			my $creator = HTML::Entities::encode($album->{'FOLDER_CREATOR'});
			my $profile = $album->{'CREATOR_PROFILE'};
			my $create_date = HTML::Entities::encode($album->{'CREATE_DATE'});
			my $message = HTML::Entities::encode($album->{'MESSAGE'});
			$message = 'http://groups.yahoo.com' . $message if $message !~ /^http/;

			my $creator_profile = ($profile) ? qq#<TD><A HREF="$profile">$creator</A></TD>#: qq#<TD>$creator</TD>#;

			print HD qq{
	<TR>
		<TD><A HREF="#$folder_id">$subject</A></TD>
		<TD>$number_attach</TD>
		$creator_profile
		<TD>$create_date</TD>
		<TD><A HREF="$message">View</A></TD>
	</TR>
			};
		}

		print HD q{
</TBODY>
</TABLE>
		};

		foreach my $folder_id (keys %{$layout->{'FOLDER'}}) {
			my $folder = $layout->{'FOLDER'}->{$folder_id};
			next unless $folder->{'ITEM'};
			my $subject = HTML::Entities::encode($folder->{'FOLDER_NAME'});
			print HD qq{
<P ALIGN="CENTER">
<A NAME="$folder_id">$subject</A>
</P>

<TABLE ALIGN='CENTER' BORDER='2' WIDTH='100%' CELLPADDING='0' CELLSPACING='0'>
<THEAD>
	<TR BGCOLOR='BLACK'>
		<TD ALIGN='CENTER' WIDTH='30%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Photo Name</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Creator</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='30%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>File Name</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Size</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Resolution</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Posted</STRONG></FONT></TD>
	</TR>
</THEAD>
<TBODY>
			};
			foreach my $picid (keys %{$folder->{'ITEM'}}) {
				my $picture = $folder->{'ITEM'}->{$picid};
				my $title = HTML::Entities::encode($picture->{'PHOTO_TITLE'});
				my $creator = HTML::Entities::encode($picture->{'USER'});
				my $profile = $picture->{'PROFILE'};
				my $name = HTML::Entities::encode($picture->{'FILE_NAME'});
				my $size = HTML::Entities::encode($picture->{'SIZE'});
				my $posted = HTML::Entities::encode($picture->{'POSTED'});
				my $resolution = HTML::Entities::encode($picture->{'RESOLUTION'});
				my $extension = HTML::Entities::encode($picture->{'FILE_EXT'});

				print HD qq{
	<TR>
		<TD><A HREF="$folder_id/$picid.$extension">$title</A></TD>
		<TD><A HREF="$profile">$creator</A></TD>
		<TD>$name</TD>
		<TD>$size</TD>
		<TD>$resolution</TD>
		<TD>$posted</TD>
	</TR>
				};
			}

			print HD q{
</TBODY>
</TABLE>
			};

		}
	}

	print HD q{
</BODY>
</HTML>
	};

	close HD;
}


sub process_folder {
	my $self = shift;
	my ($url) = @_;

	my $force = $self->{'FORCE_GET'};

	my $content = $client->fetch($url);

	my $more_pages = 0;

	while ($content =~ m!<a href="(/group/$GROUP/attachments/folder/\d+/item/\d+/view)!sg) { $more_pages++; $self->process_pic($1 . '?picmode=original&mode=list&order=ordinal&start=1&dir=asc'); };

	# Yahoo sometimes looses track of the picture details
	while ($content =~ m!<a href="(http://[^/]+?.yimg.com/kq/groups/\d+/(\d+)/name/[^"]+?)".*?>(.+?)</a>!sg) {
		my ($img_url, $pic_id, $file_name) = ($1, $2, $3);
		$file_name = HTML::Entities::decode($file_name);
		my ($photo_title, $file_ext) = $file_name =~ m{^(.+?)\.([^.]+)$};
		$file_ext ||= 'jpg';
		my ($profile, $user, $posted) = $content =~ m!<div class="ygrp-description">.+?&nbsp;\s+<a href="(.+?)">(.+?)</a>\s+-\s+(.+?)&nbsp;!s;
		$user = HTML::Entities::decode($user);
		$posted = HTML::Entities::decode($posted);
		my ($folder_id) = $url =~ m!/group/$GROUP/attachments/folder/(\d+)/item/list!;
		$self->process_broken_pic($url, $img_url, $file_name, $photo_title, $file_ext, $profile, $user, $posted, $folder_id, $pic_id);
	};

	while ($content =~ m!<tr class="ygrp-photos-list-row hbox">\s+(<td .+?</td>)\s+</tr>!sg) {
		my $record = $1;
		next if $record =~ / header /s;
		$more_pages++;
		my ($folder_url, $folder_id, $folder_name) = $record =~ m!<a href="(/group/$GROUP/attachments/folder/(\d+)/item/list)">(.+?)</a>!sg;
		$folder_name = HTML::Entities::decode($folder_name);
		my ($number_attachments) = $record =~ m!<td class="ygrp-photos-attachments ">\s+(\d+)</td>!s;
		my ($folder_creator) = $record =~ m!<td class="ygrp-photos-author ">(.+?)</td>!s;
		my $creator_profile;
		($creator_profile, $folder_creator) = $folder_creator =~ m!<a\s+href="(.+?)">(.+?)</a>!s if $folder_creator =~ /href/;
		$folder_creator = HTML::Entities::decode($folder_creator);
		my ($create_date) = $record =~ m!<td class="ygrp-photos-date selected">\s+(.+?)</td>!s;
		my ($message) = $record =~ m!<td class="ygrp-photos-view-original">\s+<a href="(.+?)"+?>!s;
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_NAME'} = $folder_name;
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'NUMBER_ATTACHMENTS'} = $number_attachments;
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'CREATOR_PROFILE'} = $creator_profile || '';
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_CREATOR'} = $folder_creator;
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'CREATE_DATE'} = $create_date;
		$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'MESSAGE'} = $message;
		$logger->debug($folder_name);
		next if !$force and $self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'} and ($number_attachments == scalar (keys %{$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}}) );
		mkdir qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id} or $logger->fatal(qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id: } . $!) unless -d qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id};
		my $start = 1;
		my $next_page = 1;
		while ($next_page) {
			$next_page = $self->process_folder($folder_url . qq#?mode=list&order=mtime&start=$start&count=20&dir=desc#);
			$start += 20;
		}
	};

	$self->save_layout();

	return $more_pages;
}


sub process_broken_pic {
	my $self = shift;
	my ($url, $img_url, $file_name, $photo_title, $file_ext, $profile, $user, $posted, $folder_id, $pic_id) = @_;

	my $force = $self->{'FORCE_GET'};

	my ($resolution, $photo_size) = ('', '');

	if (!$force and $self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id} and
		-f qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.} . $self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id}->{'FILE_EXT'}) {
			$logger->debug($self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_NAME'} . '/' . $photo_title . ' - exists (skipped)');
			return;
	}

	my $image = $client->fetch($img_url, $url, 1);

	return unless $image;

	$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id} = {
					'USER' => $user,
					'PROFILE' => $profile,
					'PHOTO_TITLE' => $photo_title,
					'FILE_NAME' => $file_name,
					'POSTED' => $posted,
					'RESOLUTION' => $resolution,
					'SIZE' => $photo_size,
					'FILE_EXT' => $file_ext,
				};

	$logger->info($self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_NAME'} . qq{/$photo_title - $resolution px / $photo_size});

	open(IFD, '>', qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.$file_ext}) or $logger->error(qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.$file_ext: $!}) and return;
	binmode(IFD);
	print IFD $image;
	close IFD;

	$self->save_layout();
}


sub process_pic {
	my $self = shift;
	my ($url) = @_;

	my $force = $self->{'FORCE_GET'};

	my ($folder_id, $pic_id) = $url =~ m!/group/$GROUP/attachments/folder/(\d+)/item/(\d+)/view!;

	my $content = $client->fetch($url);

	my ($img_url) = $content =~ m!<div class="ygrp-photos-body-image".+?>\s+<img src="(.+?)"!s;
	my ($profile, $user) = $content =~ m!<div id="ygrp-photos-by">.+?:&nbsp;<a\s+href="(.+?)">(.+?)<!s;
	$user = HTML::Entities::decode($user);
	my ($photo_title) = $content =~ m!<div id="ygrp-photos-title">(.+?)</div>!s;
	$photo_title = HTML::Entities::decode($photo_title);
	my ($file_name) = $content =~ m!<div id="ygrp-photos-filename">.+?:&nbsp;(.+?)<!s;
	$file_name = HTML::Entities::decode($file_name);
	my ($file_ext) = $file_name =~ m{\.([^.]+)$};
	$file_ext ||= 'jpg';
	my ($posted) = $content =~ m!<div id="ygrp-photos-posted">.+?:&nbsp;(.+?)<!s;
	$posted = HTML::Entities::decode($posted);
	my ($resolution) = $content =~ m!<div id="ygrp-photos-resolution">.+?:&nbsp;(.+?)<!s;
	$resolution = HTML::Entities::decode($resolution);
	my ($photo_size) = $content =~ m!<div id="ygrp-photos-size">.+?:&nbsp;(.+?)<!s;
	$photo_size = HTML::Entities::decode($photo_size);

	if (!$force and $self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id} and
		-f qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.} . $self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id}->{'FILE_EXT'}) {
			$logger->debug($self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_NAME'} . '/' . $photo_title . ' - exists (skipped)');
			return;
	}

	my $image = $client->fetch($img_url, $url, 1);

	return unless $image;

	$self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'ITEM'}->{$pic_id} = {
					'USER' => $user,
					'PROFILE' => $profile,
					'PHOTO_TITLE' => $photo_title,
					'FILE_NAME' => $file_name,
					'POSTED' => $posted,
					'RESOLUTION' => $resolution,
					'SIZE' => $photo_size,
					'FILE_EXT' => $file_ext,
				};

	$logger->info($self->{'LAYOUT'}->{'FOLDER'}->{$folder_id}->{'FOLDER_NAME'} . qq{/$photo_title - $resolution px / $photo_size});

	open(IFD, '>', qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.$file_ext}) or $logger->error(qq{$GROUP/MESSAGES/ATTACHMENTS/$folder_id/$pic_id.$file_ext: $!}) and return;
	binmode(IFD);
	print IFD $image;
	close IFD;

	$self->save_layout();
}


package GrabYahoo::Members;


sub new {
	my $package = shift;
	my %args = @_;
	my $self = {
		'FORCE_GET' => $args{'force'},
		'INDEX' => $args{'index'},
	};
	return bless $self;
}


sub save_layout {
	my $self = shift;

	my $LAYOUT = $self->{'LAYOUT'};

	return unless $LAYOUT;

	my $layout = Data::Dumper->Dump([$LAYOUT]);
	open (LAY, '>', qq{$GROUP/MEMBERS/layout.dump}) or $logger->fatal(qq{$GROUP/MEMBERS/layout.dump: } . $!);
	print LAY $layout;
	close LAY;
}


sub process {
	my $self = shift;

	$logger->section('Members');

	mkdir qq{$GROUP/MEMBERS} or $logger->fatal(qq{$GROUP/MEMBERS: } . $!) unless -d qq{$GROUP/MEMBERS};

	$logger->info('Processing MEMBERS');
	my $start = 1;
	my $next_page = 1;
	while ($next_page) {
		$next_page = $self->process_members('MEMBERS', qq{/group/$GROUP/members?group=sub&xm=1&o=5i&m=e&start=$start});
		$start += 10;
	}
	$self->save_layout();

	$logger->info('Processing MODERATORS');
	$start = 1;
	$next_page = 1;
	while ($next_page) {
		$next_page = $self->process_members('MODERATORS', qq{/group/$GROUP/members?group=mod&xm=1&o=5i&m=e&start=$start});
		$start += 10;
	}
	$self->save_layout();

	$logger->info('Processing BOUNCING');
	$start = 1;
	$next_page = 1;
	while ($next_page) {
		$next_page = $self->process_members('BOUNCING', qq{/group/$GROUP/members?group=bounce&xm=1&o=5i&m=e&start=$start});
		$start += 10;
	}
	$self->save_layout();

	$logger->info('Processing PENDING');
	$start = 1;
	$next_page = 1;
	while ($next_page) {
		$next_page = $self->process_members('PENDING', qq{/group/$GROUP/members?group=pending&xm=1&o=5i&m=e&start=$start});
		$start += 10;
	}
	$self->save_layout();

	$logger->info('Processing BANNED');
	$start = 1;
	$next_page = 1;
	while ($next_page) {
		$next_page = $self->process_members('BANNED', qq{/group/$GROUP/members?group=ban&xm=1&o=5i&m=e&start=$start});
		$start += 10;
	}
	$self->save_layout();

	if ($self->{'INDEX'}) {
		$logger->info('Generating index page');
		$self->generate_index();
	}
}


sub generate_index {
	my $self = shift;

	my $layout = $self->{'LAYOUT'};

	open (HD, '>', $GROUP . '/MEMBERS/index.html') or $logger->fatal($GROUP . '/MEMBERS/index.html: ' . $!);
	print HD q{
<HTML>
<HEAD>
	<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF8">
</HEAD>
<BODY BACKGROUND='WHITE'>
};

	if (scalar keys %{$layout}) {
		print HD q{
<TABLE BORDER='2' CELLPADDING='0' CELLSPACING='0'>
	<TR><TD ALIGN="RIGHT" WIDTH='25%'><FONT COLOR='WHITE' SIZE='-1'><STRONG><A HREF="#members">MEMBERS</A></STRONG></FONT></TD></TR>
	<TR><TD ALIGN="RIGHT" WIDTH='25%'><FONT COLOR='WHITE' SIZE='-1'><STRONG><A HREF="#moderators">MODERATORS</A></STRONG></FONT></TD></TR>
	<TR><TD ALIGN="RIGHT" WIDTH='25%'><FONT COLOR='WHITE' SIZE='-1'><STRONG><A HREF="#bouncing">BOUNCING</A></STRONG></FONT></TD></TR>
	<TR><TD ALIGN="RIGHT" WIDTH='25%'><FONT COLOR='WHITE' SIZE='-1'><STRONG><A HREF="#pending">PENDING</A></STRONG></FONT></TD></TR>
	<TR><TD ALIGN="RIGHT" WIDTH='25%'><FONT COLOR='WHITE' SIZE='-1'><STRONG><A HREF="#banned">BANNED</A></STRONG></FONT></TD></TR>
</TABLE>
		};
		foreach my $type ('MEMBERS', 'MODERATORS', 'BOUNCING', 'PENDING', 'BANNED') {
			my $anchor = lc($type);
			print HD qq{
<P ALIGN="CENTER"><A NAME="$anchor">$type<A></P>
<TABLE ALIGN='CENTER' BORDER='2' WIDTH='100%' CELLPADDING='0' CELLSPACING='0'>
<THEAD>
	<TR BGCOLOR='BLACK'>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>YAHOO ID</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>NAME</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>REAL NAME</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>AGE</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>GENDER</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>LOCATION</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>EMAIL</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>EMAIL_DELIVERY</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='11%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>EMAIL_PREFS</STRONG></FONT></TD>
	</TR>
</THEAD>
<TBODY>
			};

			foreach my $yid (keys %{ $layout->{$type} }) {
				my $profile1 = $self->{'LAYOUT'}->{$type}->{$yid}->{'PROFILE1'} || '&nbsp;';
				my $profile2 = $self->{'LAYOUT'}->{$type}->{$yid}->{'PROFILE2'} || '&nbsp;';
				my $name = $self->{'LAYOUT'}->{$type}->{$yid}->{'NAME'} || '&nbsp;';
				my $rname = $self->{'LAYOUT'}->{$type}->{$yid}->{'REAL_NAME'} || '&nbsp;';
				my $age = $self->{'LAYOUT'}->{$type}->{$yid}->{'AGE'} || '&nbsp;';
				my $gender = $self->{'LAYOUT'}->{$type}->{$yid}->{'GENDER'} || '&nbsp;';
				my $location = $self->{'LAYOUT'}->{$type}->{$yid}->{'LOCATION'} || '&nbsp;';
				my $email = $self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL'} || '&nbsp;';
				my $email_delivery = $self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL_DELIVERY'} || '&nbsp;';
				my $email_prefs = $self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL_PREFS'} || '&nbsp;';
				print HD qq{
	<TR>
		<TD>$yid</TD>
		<TD><A HREF="$profile1">$name</A></TD>
		<TD><A HREF="$profile2">$rname</A></TD>
		<TD>$age</TD>
		<TD>$gender</TD>
		<TD>$location</TD>
		<TD><A HREF="mailto:$email">$email</A></TD>
		<TD>$email_delivery</TD>
		<TD>$email_prefs</TD>
	</TR>
				};
			}

			print HD q{
</TBODY>
</TABLE>
			};

		}
	}

	print HD q{
</BODY>
</HTML>
	};

	close HD;
}


sub process_members {
	my $self = shift;
	my ($type, $url) = @_;

	my $content = $client->fetch($url);

	my ($body) = $content =~ m#<!-- start content include -->\s+(<.+?>)\s+<!-- end content include -->#s;

	my $more_pages = 0;
	while ($body =~ m!(<td class="info">\s+.+?</tr>)!sg) {
		my $row = $1;
		$more_pages++;
		my ($name_details) = $row =~ m!<span class="name">(.+?)</span>!s;
		my ($profile1, $name) = $name_details =~ m!<a href="(.+?)".*?>(.+)</a>!s;
		$profile1 ||= '';
		$name ||= '';
		my ($full_name) = $name_details =~ m!<a href=".+?" title="(.+?)">!s;
		$name = $full_name if $full_name;
		my ($user_details) = $row =~ m!<div class="demo">\s+<div class="form-hr"></div>\s+(.+?<br>.+?)</div>!s;
		my @items = $user_details =~ /(.+)<br>(.+)/s;
		@items = map {my @parts = split / &middot; /, $_; @parts; } @items;
		@items = map {my @parts = split /<.?span.*?>/, $_; @parts; } @items;
		@items = grep { $_ !~ /^\s*$/ } @items;
		@items = map {$_=~ s/^\s//; $_ =~ s/\s$//; $_; } @items;
		my ($rname, $age, $gender, $location) = @items;
		my ($profile2, $yid) =  $row =~ m!<td class="yid ygrp-nowrap">\s+<a href="(.+?)".*?>(.+?)</a> </td>!s;
		my ($email_title, $email) = $row =~ m!<td class="email ygrp-nowrap">\s+<a href=".+?"(.*?)>(.+?)</a>!s;
		$email = $1 if $email_title =~ /title="(.+?)"/;
		unless ($yid) {
			$profile2 = 'PROFILE DELETED';
			$profile1 = 'PROFILE DELETED';
			$name = $email;
			$yid = $email;
		}
		my ($email_delivery) = $row =~ m!<select name="submode.0".+?<option value="\d" selected>\s+([^\s].+?)</option>!s;
		my ($email_prefs) = $row =~ m!<select name="emailPref.0" >.+?<option value="\d" selected>\s+([^\s].+?)</option>!s;

		$profile2 ||= '';
		$rname ||= '';
		$age ||= '';
		$gender ||= '';
		$location ||= '';
		$email ||= '';
		$email_delivery ||= '';
		$email_prefs ||= '';

		$logger->info(join '|', ($email, $name, $rname, $age, $gender, $location));

		$self->{'LAYOUT'}->{$type}->{$yid}->{'PROFILE1'} = $profile1;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'PROFILE2'} = $profile2;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'NAME'} = $name;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'REAL_NAME'} = $rname;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'AGE'} = $age;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'GENDER'} = $gender;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'LOCATION'} = $location;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL'} = $email;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL_DELIVERY'} = $email_delivery;
		$self->{'LAYOUT'}->{$type}->{$yid}->{'EMAIL_PREFS'} = $email_prefs;
	}

	$self->save_layout();

	return $more_pages;
}


package GrabYahoo::Photos;


sub new {
	my $package = shift;
	my %args = @_;
	my $self = {
		'FORCE_GET' => $args{'force'},
		'INDEX' => $args{'index'},
	};
	if (-f qq{$GROUP/PHOTOS/layout.dump}) {
		my $buf = $/;
		$/ = undef;
		open(LAY, '<', qq{$GROUP/PHOTOS/layout.dump}) or $logger->fatal(qq{$GROUP/PHOTOS/layout.dump: } . $!);
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

	my $LAYOUT = $self->{'LAYOUT'};

	return unless $LAYOUT;

	my $layout = Data::Dumper->Dump([$LAYOUT]);
	open (LAY, '>', qq{$GROUP/PHOTOS/layout.dump}) or $logger->fatal(qq{$GROUP/PHOTOS/layout.dump: } . $!);
	print LAY $layout;
	close LAY;
}


sub process {
	my $self = shift;

	$logger->section('Photos');
	$logger->info('Processing PHOTOS');

	mkdir qq{$GROUP/PHOTOS} or $logger->fatal(qq{$GROUP/PHOTOS: } . $!) unless -d qq{$GROUP/PHOTOS};
	my $start = 1;
	my $next_page = 1;
	while ($next_page) {
		$next_page = $self->process_album(qq{/group/$GROUP/photos/album/0/list?mode=list&order=mtime&start=$start&count=20&dir=desc});
		$start += 20;
	}

	$self->save_layout();

	if ($self->{'INDEX'}) {
		$logger->info('Generating index page');
		$self->generate_index();
	}
}


sub generate_index {
	my $self = shift;

	my $layout = $self->{'LAYOUT'};

	open (HD, '>', $GROUP . '/PHOTOS/index.html') or $logger->fatal($GROUP . '/PHOTOS/index.html: ' . $!);
	print HD q{
<HTML>
<BODY BACKGROUND='WHITE'>
};

	if (scalar keys %{$layout->{'ALBUM'}}) {
		print HD q{
<TABLE ALIGN='CENTER' BORDER='2' WIDTH='100%' CELLPADDING='0' CELLSPACING='0'>
<THEAD>
	<TR BGCOLOR='BLACK'>
		<TD ALIGN='CENTER' WIDTH='50%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Album Name</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='20%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Creator</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Access</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Photos</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Last Modified</STRONG></FONT></TD>
	</TR>
</THEAD>
<TBODY>
};
		foreach my $aid (keys %{$layout->{'ALBUM'}}) {
			my $album = $layout->{'ALBUM'}->{$aid};
			my $name = HTML::Entities::encode($album->{'ALBUM_NAME'});
			my $access = HTML::Entities::encode($album->{'ALBUM_ACCESS'});
			my $creator = HTML::Entities::encode($album->{'ALBUM_CREATOR'});
			my $profile = $album->{'CREATOR_PROFILE'};
			my $number = HTML::Entities::encode($album->{'NUMBER_PHOTOS'});
			my $modified = HTML::Entities::encode($album->{'LAST_MODIFIED'});

			print HD qq{
	<TR>
		<TD><A HREF="#$aid">$name</A></TD>
		<TD><A HREF="$profile">$creator</A></TD>
		<TD>$access</TD>
		<TD>$number</TD>
		<TD>$modified</TD>
	</TR>
			};
		}

		print HD q{
</TBODY>
</TABLE>
		};

		foreach my $aid (keys %{$layout->{'ALBUM'}}) {
			my $album = $layout->{'ALBUM'}->{$aid};
			next unless $album->{'PICTURES'};
			my $album_name = HTML::Entities::encode($album->{'ALBUM_NAME'});
			print HD qq{
<P ALIGN="CENTER">
<A NAME="$aid">$album_name</A>
</P>

<TABLE ALIGN='CENTER' BORDER='2' WIDTH='100%' CELLPADDING='0' CELLSPACING='0'>
<THEAD>
	<TR BGCOLOR='BLACK'>
		<TD ALIGN='CENTER' WIDTH='30%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Photo Name</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Creator</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='30%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>File Name</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Size</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Resolution</STRONG></FONT></TD>
		<TD ALIGN='CENTER' WIDTH='10%'><FONT COLOR='WHITE' SIZE='-1'><STRONG>Posted</STRONG></FONT></TD>
	</TR>
</THEAD>
<TBODY>
			};
			foreach my $picid (keys %{$album->{'PICTURES'}}) {
				my $picture = $album->{'PICTURES'}->{$picid};
				my $title = HTML::Entities::encode($picture->{'PHOTO_TITLE'});
				my $creator = HTML::Entities::encode($picture->{'USER'});
				my $profile = $picture->{'PROFILE'};
				my $name = HTML::Entities::encode($picture->{'FILE_NAME'});
				my $size = HTML::Entities::encode($picture->{'SIZE'});
				my $posted = HTML::Entities::encode($picture->{'POSTED'});
				my $resolution = HTML::Entities::encode($picture->{'RESOLUTION'});
				my $extension = HTML::Entities::encode($picture->{'FILE_EXT'});

				print HD qq{
	<TR>
		<TD><A HREF="$aid/$picid.$extension">$title</A></TD>
		<TD><A HREF="$profile">$creator</A></TD>
		<TD>$name</TD>
		<TD>$size</TD>
		<TD>$resolution</TD>
		<TD>$posted</TD>
	</TR>
				};
			}

			print HD q{
</TBODY>
</TABLE>
			};

		}
	}

	print HD q{
</BODY>
</HTML>
	};

	close HD;
}


sub process_album {
	my $self = shift;
	my ($url) = @_;

	my $content = $client->fetch($url);

	my $more_pages = 0;

	while ($content =~ m!<a href="(/group/$GROUP/photos/album/\d+/pic/\d+/view)!sg) { $more_pages++; $self->process_pic($1 . '?picmode=original&mode=list&order=ordinal&start=1&dir=asc'); };

	while ($content =~ m!(<div class="ygrp-photos-title ">.+?<br class="clear-both"/>)!sg) {
		my $record = $1;
		$more_pages++;
		my ($album_url, $album_id, $album_name) = $record =~ m!<div class="ygrp-photos-title ">.+?<a href="(/group/$GROUP/photos/album/(\d+)/pic/list).*?>(.+?)</a>!sg;
		$album_name = HTML::Entities::decode($album_name);
		my ($album_access) = $record =~ m!<div class="ygrp-photos-access">\s+(.+?)</div>!s;
		my ($creator_profile, $album_creator) = $record =~ m!<div class="ygrp-photos-creator "><a\s+href="(.+?)">(.+?)</a>!s;
		$album_creator = HTML::Entities::decode($album_creator);
		my ($number_photos) = $record =~ m!<div class="ygrp-photos-size">(\d+)</div>!s;
		my ($last_modified) = $record =~ m!<div class="ygrp-photos-modified-date selected">\s+(.+?)</div>!s;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} = $album_name;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_ACCESS'} = $album_access;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'CREATOR_PROFILE'} = $creator_profile;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_CREATOR'} = $album_creator;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'NUMBER_PHOTOS'} = $number_photos;
		$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'LAST_MODIFIED'} = $last_modified;
		$logger->debug($album_name);
		my $start = 1;
		my $next_page = 1;
		mkdir qq{$GROUP/PHOTOS/$album_id} or $logger->fatal(qq{$GROUP/PHOTOS/$album_id: } . $!) unless -d qq{$GROUP/PHOTOS/$album_id};
		while ($next_page) {
			$next_page = $self->process_album($album_url . qq#?mode=list&order=mtime&start=$start&count=20&dir=desc#);
			$start += 20;
		}
	};

	$self->save_layout();

	return $more_pages;
}


sub process_pic {
	my $self = shift;
	my ($url) = @_;

	my $force = $self->{'FORCE_GET'};

	my ($album_id, $pic_id) = $url =~ m!/group/$GROUP/photos/album/(\d+)/pic/(\d+)/view!;

	if (!$force and $self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'PICTURES'}->{$pic_id} and
		-f qq{$GROUP/PHOTOS/$album_id/$pic_id.} . $self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'PICTURES'}->{$pic_id}->{'FILE_EXT'}) {
			$logger->debug($self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} . '/' .
				$self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'PICTURES'}->{$pic_id}->{'PHOTO_TITLE'} . ' - exists (skipped)');
			return;
	}

	my $content = $client->fetch($url);

	my ($img_url) = $content =~ m!<div id="spotlight" class="ygrp-photos-body-image".+?><img src="(.+?)"!s;
	my ($profile, $user) = $content =~ m!<div id="ygrp-photos-by">.+?:&nbsp;<a\s+href="(.+?)">(.+?)<!s;
	$user = HTML::Entities::decode($user);
	my ($photo_title) = $content =~ m!<div id="ygrp-photos-title">(.+?)</div>!s;
	$photo_title = HTML::Entities::decode($photo_title);
	my ($file_name) = $content =~ m!<div id="ygrp-photos-filename">.+?:&nbsp;(.+?)<!s;
	$file_name = HTML::Entities::decode($file_name);
	my ($file_ext) = $file_name =~ m!\.([^.]+)$!;
	$file_ext ||= 'jpg';
	my ($posted) = $content =~ m!<div id="ygrp-photos-posted">.+?:&nbsp;(.+?)<!s;
	$posted = HTML::Entities::decode($posted);
	my ($resolution) = $content =~ m!<div id="ygrp-photos-resolution">.+?:&nbsp;(.+?)<!s;
	$resolution = HTML::Entities::decode($resolution);
	my ($photo_size) = $content =~ m!<div id="ygrp-photos-size">.+?:&nbsp;(.+?)<!s;
	$photo_size = HTML::Entities::decode($photo_size);

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

	if (!$force and -f "$GROUP/PHOTOS/$album_id/$pic_id.$file_ext") {
		$logger->debug($self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} . qq{/$photo_title - exists ... skipped});
		return;
	}

	my $image = $client->fetch($img_url, $url, 1);
	unless ($image) {
		$img_url =~ s!/or/!/hr/!;
		$logger->warn('Original image missing - trying high resolution');
		$image = $client->fetch($img_url, $url, 1);
	}
	unless ($image) {
		$img_url =~ s!/hr/!/sn/!;
		$logger->warn('HiRes image missing - trying low resolution');
		$image = $client->fetch($img_url, $url, 1);
	}

	return unless $image;

	$logger->info($self->{'LAYOUT'}->{'ALBUM'}->{$album_id}->{'ALBUM_NAME'} . qq{/$photo_title - $resolution px / $photo_size});

	open(IFD, '>', "$GROUP/PHOTOS/$album_id/$pic_id.$file_ext") or $logger->error("$GROUP/PHOTOS/$album_id/$pic_id.$file_ext: $!") and return;
	binmode(IFD);
	print IFD $image;
	close IFD;

	$self->save_layout();
}


1;
