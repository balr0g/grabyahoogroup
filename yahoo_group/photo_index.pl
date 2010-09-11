#!/usr/bin/perl -w

# $Header: /home/mithun/MIGRATION/grabyahoogroup-cvsbackup/yahoo_group/photo_index.pl,v 1.1 2010-09-11 16:38:38 mithun Exp $

delete @ENV{ qw(IFS CDPATH ENV BASH_ENV PATH) };

use strict; 
use utf8;
use HTML::Entities;

my ($group) = @ARGV;

my $buf = $/;
$/ = undef;
open (LD, '<', $group . '/PHOTOS/layout.dump') or die $group . '/PHOTOS/layout.dump: ' . $! . "\n";
my $dump = <LD>;
close LD;
$/ = $buf;

my $VAR1;
eval { eval $dump };
my $layout = $VAR1;

open (HD, '>', $group . '/PHOTOS/index.html') or die $group . '/PHOTOS/index.html: ' . $! . "\n";
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
		my $name = encode_entities($album->{'ALBUM_NAME'});
		my $access = encode_entities($album->{'ALBUM_ACCESS'});
		my $creator = encode_entities($album->{'ALBUM_CREATOR'});
		my $profile = $album->{'CREATOR_PROFILE'};
		my $number = encode_entities($album->{'NUMBER_PHOTOS'});
		my $modified = encode_entities($album->{'LAST_MODIFIED'});

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
		my $album_name = encode_entities($album->{'ALBUM_NAME'});
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
