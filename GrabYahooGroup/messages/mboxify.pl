#!/usr/bin/perl -w

$| = 1;

delete @ENV{qw(IFS CDPATH ENV BASH_ENV PATH)};

use strict;

my ($folder, $output_file) = @ARGV;

die "Folder contains invalid characters $1\n" if $folder =~ /([^\w_\-]+)/;
die "Invalid character in output file $1\n" if $output_file =~ /([^\/\w_\-.]+)/;

open MBFD, "> $output_file" or die "$output_file : $!\n";

my @files;

opendir GHD, $folder;
while (my $file = readdir GHD) {
	next if $file =~ /^\./;
	next if $file eq "yahoogroups.cookies";
	next if -z "$folder/$file";
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
