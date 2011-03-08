#!/usr/bin/perl -w

$| = 1;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

my ($folder, $output_file) = @ARGV;

unless($folder and $output_file) {
	print STDERR "$0 [Source Maildir Folder] [Destination Mbox file]\n";
	exit 255;
}

die "$folder: Invalid source directory\n" unless -d $folder;
die "$output_file: Invalid destination mbox file\n" if(-e $output_file and not -f $output_file);

open(MBFD, '>', $output_file) or die "$output_file: $!\n";

my @files;

opendir(GHD, $folder) or die "$folder: $!\n";
while (my $file = readdir GHD) {
	next if $file eq '.';
	next if $file eq '..';
	next if $file eq 'ATTACHMENTS';
	next if $file =~ /\.mbox/;
	die "$file: invalid message file found\n" if $file !~ /^\d+$/;
	push @files, $file;
}
closedir GHD;

print "Processing " . scalar @files . " messages\n";

foreach my $file (sort {$a <=> $b} @files) {
	print ".";
	open MSFD, "< $folder/$file" or die "$file : $!\n";
	my $from_line = <MSFD>;
	$from_line =~ s/From [^\s]+/From -/;
	print MBFD $from_line;
	my $t = $/;
	$/ = undef;
	my $msg = <MSFD>;
	$/ = $t;
	$msg =~ s/^(>*)From />$1From /mg;
	print MBFD $msg;
	print MBFD "\n";
	close MSFD;
}

close MBFD;

print "\n";
