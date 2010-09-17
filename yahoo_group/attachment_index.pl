#!/usr/bin/perl -w

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/attachment_index.pl,v 1.1 2010-09-17 06:07:25 mithun Exp $

delete @ENV{ qw(IFS CDPATH ENV BASH_ENV PATH) };

use strict; 
use utf8;
use HTML::Entities;

my ($group) = @ARGV;

my $buf = $/;
$/ = undef;
open (LD, '<', $group . '/MESSAGES/ATTACHMENTS/layout.dump') or die $group . '/MESSAGES/ATTACHMENTS/layout.dump: ' . $! . "\n";
my $dump = <LD>;
close LD;
$/ = $buf;

my $VAR1;
eval { eval $dump };
my $layout = $VAR1;

open (HD, '>', $group . '/MESSAGES/ATTACHMENTS/index.html') or die $group . '/MESSAGES/ATTACHMENTS/index.html: ' . $! . "\n";
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
		my $subject = encode_entities($album->{'FOLDER_NAME'});
		my $number_attach = encode_entities($album->{'NUMBER_ATTACHMENTS'});
		my $creator = encode_entities($album->{'FOLDER_CREATOR'});
		my $profile = $album->{'CREATOR_PROFILE'};
		my $create_date = encode_entities($album->{'CREATE_DATE'});
		my $message = encode_entities($album->{'MESSAGE'});
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
		my $subject = encode_entities($folder->{'FOLDER_NAME'});
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
			my $title = encode_entities($picture->{'PHOTO_TITLE'});
			my $creator = encode_entities($picture->{'USER'});
			my $profile = $picture->{'PROFILE'};
			my $name = encode_entities($picture->{'FILE_NAME'});
			my $size = encode_entities($picture->{'SIZE'});
			my $posted = encode_entities($picture->{'POSTED'});
			my $resolution = encode_entities($picture->{'RESOLUTION'});
			my $extension = encode_entities($picture->{'FILE_EXT'});

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
