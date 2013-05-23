package options;

use strict;

use XML::Simple;

my $options;

use constant XMLFILE => "ffmpeg.xml";

sub LoadOptions {
	$options = XMLin(XMLFILE, ForceArray => ["profiles"]);
}

sub SaveOptions {
	XMLout($options, OutputFile => XMLFILE, RootName => "options");
}

1;