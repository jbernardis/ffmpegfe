package mediainfo;

use strict;

use Tkx;

my $mw;
my $options;

my %VSizeX;
my %VSizeY;

sub init {
	$options = shift;
	
	%VSizeX = ();
	%VSizeY = ();
}

sub AddMediaInfo {
	my $tree = shift;
	my $id = shift;
	my $fn = shift;
	
	my %idSType  = ();
	my $tid;
	my $sid;
	
	my $cmd = '"' . $options->{ffmpeg} . '" -i "' . $fn . '"';
	
	my $pid = open IPIPE, $cmd . " 2>&1 |";
	if ($pid != 0) {
		while (<IPIPE>) {
			chomp;
			if (/Duration:\s*(\S*),\s*start:\s*(\S*),\s*bitrate:\s*(.*)/) {
				$tree->insert($id, "end", -text => "Duration: $1");
				$tree->insert($id, "end", -text => "Bit Rate: $3");
			}
			elsif (/Stream (\S*):\s*(\S*):\s*(.*)/) {
				my $strType = $2;
				if (exists($idSType{$strType})) {
					$tid = $idSType{$strType};
				}
				else {
					$tid = $tree->insert($id, "end", -text => "$strType streams");
					$idSType{$strType} = $tid;
				}
				
				$sid = $tree->insert($tid, "end", -text => "$1");
				my @attrs = split /,\s*/, $3;
				foreach my $a (@attrs) {
					$tree->insert($sid, "end", -text => $a);
					if ($strType eq "Video") {
						if ($a =~ m/(\d+)x(\d+).*/) {
							$VSizeX{$fn} = $1;
							$VSizeY{$fn} = $2;
						}
					}
				}
			}
		}
		close IPIPE;
	}
	else {
		$tree->insert($id, "end", -text => "Pipe open error: $!");
	}
}

sub getVidSize {
	my $fn = shift;
	
	if (exists($VSizeX{$fn})) {
		return ($VSizeX{$fn}, $VSizeY{$fn});
	}
	else {
		return (-1, -1);
	}
}

sub setVidSize {
	my $fn = shift;
	my $width = shift;
	my $height = shift;
	
	$VSizeX{$fn} = $width;
	$VSizeY{$fn} = $height;
}

1;
