package command;

use strict;

use Tkx;
use File::Spec;
use File::Basename;

my $mw;
my $options;

my $modelFileName = "filename";

my $txtCommand;

sub SetUpCommandFrame {
	$mw = shift;
	$options = shift;

	my $frame = $mw->new_ttk__labelframe(-padding => "5 5 5 5", -borderwidth => 4, -relief => "groove", -text => "Command String");
	$txtCommand = $frame->new_tk__text(-width => 70, -height => 4, -state => "disabled");
	$txtCommand->g_grid(-column => 0, -row => 0, -sticky => "wens", -padx => "10 0");
	my $sbvCmd = $frame->new_ttk__scrollbar(-command => [$txtCommand, "yview"], 
	        -orient => "vertical");
	$sbvCmd->g_grid(-column => 1, -row => 0, -sticky => "nse");
	
	$txtCommand->configure(-yscrollcommand => [$sbvCmd, "set"]);
	
	ShowCommandLine("");

	$frame;
}

sub ShowCommandLine {
	my $cmd = shift;
    $txtCommand->configure(-state => "normal");
    $txtCommand->replace("1.0", "end", $cmd);
    $txtCommand->configure(-state => "disabled");
}

sub scaleWithPad {
	my $htarget = shift;
	my $vtarget = shift;
	my $hvideo = shift;
	my $vvideo = shift;
	
	my $hframe;
	my $vframe;
	my $hpad;
	my $vpad;
	
	my $ratio = $vtarget / $vvideo;
	if (int($ratio * $hvideo) > $htarget) {
		# scale for proper width, pad top and bottom
		$ratio = $htarget / $hvideo;
		$vframe = int($vvideo * $ratio);
		$hframe = $htarget;
		$vpad = int(($vtarget - $vframe) / 2.0);
		$hpad = 0;
	}
	elsif (int($ratio * $hvideo < $htarget)) {
		# scale for proper height, pad left and right
		$hframe = int($hvideo * $ratio);
		$vframe = $vtarget;
		$hpad = int(($htarget - $hframe) / 2.0);
		$vpad = 0;
	}
	else {
		$hframe = $htarget;
		$vframe = $vtarget;
		$hpad = 0;
		$vpad = 0;
	}
	
	return {htarget => $htarget, vtarget => $vtarget, hframe => $hframe, vframe => $vframe, hpad => $hpad, vpad => $vpad};
}

sub FormatCommandString {
	my $settings = shift;
	my $ifn = shift;
	my $pass = shift;
	
	if (defined($ifn)) {
		$modelFileName = $ifn;
	}
	else {
		$ifn = $modelFileName;
	}
	
	my $targetdur = -1;
	
	my $outdir = $options->{outdir};
	my $threads = $options->{threads};
	my $format = $settings->{format};
	my $acodec = $settings->{acodec};
	my $vcodec = $settings->{vcodec};
	my $target = $settings->{target};
	
	my $extension = $format;
	if ($format eq "none") {
		$extension = "mpg"
	}
	elsif (exists($options->{extensions}{$format})) {
		$extension = $options->{extensions}{$format};
	}
	
	my ($vol, $path, $file) = File::Spec->splitpath($ifn);
    my ($name, undef, $suffix) = fileparse($file, qr/\.[^.]*/);
	my $ofn = File::Spec->rel2abs(File::Spec->catfile($outdir, $name . '.' . $extension));
	my $logpfx = File::Spec->rel2abs(File::Spec->catfile($outdir, $name));
	
	unless ($options->{overwrite}) {
		my $version = 0;
		while (-f $ofn) {
			$ofn = File::Spec->rel2abs(File::Spec->catfile($outdir, $name . '-' . $version . '.' . $extension));
			$version++;
		}
	}
	
	my ($vidx, $vidy) = mediainfo::getVidSize($ifn);
	
	my $ffmpeg = $options->{ffmpeg};
	
	my $vfilters = "";
	my $nullCmd = 1;
	
	# executable
	my $cmd = '"' . $ffmpeg;
	
	# input file
	$cmd .= '" -i "' . $ifn . '"';

	# pass number
	if (exists($settings->{twopass})) {
		$cmd .= " -pass " . $pass . ' -passlogfile "' . $logpfx . '"';
		$nullCmd = 0;
	}
	
	# cores	
	unless ($threads == 0) {
		$cmd .= " -threads " . $threads;
	}
	
	unless ($acodec eq "none") {
		$cmd .= " -acodec " . $acodec;
		$nullCmd = 0;
	}
	
	unless ($vcodec eq "none") {
		$cmd .= " -vcodec " . $vcodec;
		$nullCmd = 0;
	}
	
	# do cropping first so we know video size for scaling/padding
	if (exists($settings->{cropoffx}) || exists($settings->{cropoffy}) || exists($settings->{cropwidth}) || exists($settings->{cropheight})) {
		my $offy = 0;
		my $offx = 0;
		my $height = ($vidy == -1 ? 0 : $vidy);
		my $width = ($vidx == -1 ? 0 : $vidx);
		if (exists($settings->{cropoffy})) {
			$offy = $settings->{cropoffy};
		}
		if (exists($settings->{cropoffx})) {
			$offx = $settings->{cropoffx};
		}
		if (exists($settings->{cropheight})) {
			$height = $settings->{cropheight};
		}
		if (exists($settings->{cropwidth})) {
			$width = $settings->{cropwidth};
		}
		$vfilters .= ", " if ($vfilters ne "");
		$vfilters .= 'crop=' . $width . ':' . $height . ':' . $offx . ':' . $offy;
		$nullCmd = 0;

		# this is the new video size for subsequent operations
		$vidy = $height;
		$vidx = $width;
	}

	# options from video options panel	
	if (exists($settings->{videobr})) {
		$cmd .= ' -b ' . $settings->{videobr};
		$nullCmd = 0;
	}
	if (exists($settings->{framerate})) {
		$cmd .= ' -r ' . $settings->{framerate};
		$nullCmd = 0;
	}
	if (exists($settings->{vsizex}) || exists($settings->{vsizey})) {
		my $x = 0;
		if (exists($settings->{vsizex})) {
			$x = $settings->{vsizex};
		}
		my $y = 0;
		if (exists($settings->{vsizey})) {
			$y = $settings->{vsizey};
		}
		if (exists($settings->{maintar}) && $settings->{maintar} == 1) {
			my $p = scaleWithPad($x, $y, $vidx, $vidy);
			$vfilters .= ", " if ($vfilters ne "");
			$vfilters .= "scale=" . $p->{hframe} . ':' . $p->{vframe};
			if ($p->{hpad} != 0 || $p->{vpad} != 0) {
				$vfilters .= ", " if ($vfilters ne "");
				$vfilters .= "pad=" . $p->{htarget} . ':' . $p->{vtarget} .
					':' . $p->{hpad} . ':' . $p->{vpad};
			}
		}
		else {
			$vfilters .= ", " if ($vfilters ne "");
			$vfilters .= 'scale=' . $x . ':' . $y;
		}
		$nullCmd = 0;
	}
	elsif (exists($settings->{vfactor})) {
		unless ($vidx == -1 || $vidx == -1) {
			my $x = int($vidx * $settings->{vfactor});
			my $y = int($vidy * $settings->{vfactor});
			$vfilters .= ", " if ($vfilters ne "");
			$vfilters .= 'scale=' . $x . ':' . $y;
			$nullCmd = 0;
		}
	}
	
	if ($vfilters ne "") {
		$cmd .= ' -vf "' . $vfilters . '"';
		$nullCmd = 0;
	}
	if (exists($settings->{aspectratio})) {
		$cmd .= ' -aspect "' . $settings->{aspectratio} . '"';
		$nullCmd = 0;
	}
	if (exists($settings->{deinterlace})) {
		$cmd .= ' -deinterlace';
		$nullCmd = 0;
	}
	
	# options from audio options panel	
	if (exists($settings->{audiobr})) {
		$cmd .= ' -ab ' . $settings->{audiobr};
		$nullCmd = 0;
	}
	if (exists($settings->{samplerate})) {
		$cmd .= ' -ar ' . $settings->{samplerate};
		$nullCmd = 0;
	}
	if (exists($settings->{channels})) {
		$cmd .= ' -ac ' . $settings->{channels};
		$nullCmd = 0;
	}
	if (exists($settings->{volume})) {
		my $vol = $settings->{volume} + 256;
		$cmd .= ' -vol ' . $vol;
		$nullCmd = 0;
	}
	if (exists($settings->{audiosync})) {
		$cmd .= ' -async ' . $settings->{audiosync};
		$nullCmd = 0;
	}
	
	# remaining options from cropping options panel	
	if ($options->{preview}) {
		$cmd .= " -ss 0:01:00 -t 0:00:30";
		$targetdur = 30;
		$nullCmd = 0;
	}
	else {
		if (exists($settings->{seekhour}) || exists($settings->{seekmin}) || exists($settings->{seeksec})) {
			my $h = 0;
			my $m = 0;
			my $s = 0;
			if (exists($settings->{seekhour})) {
				$h = $settings->{seekhour};
			}
			if (exists($settings->{seekmin})) {
				$m = $settings->{seekmin};
			}
			if (exists($settings->{seeksec})) {
				$s = $settings->{seeksec};
			}
			my $ss = sprintf "%d:%02d:%02d", $h, $m, $s;
			$cmd .= ' -ss ' . $ss;
			$nullCmd = 0;
		}
		if (exists($settings->{rechour}) || exists($settings->{recmin}) || exists($settings->{recsec})) {
			my $h = 0;
			my $m = 0;
			my $s = 0;
			if (exists($settings->{rechour})) {
				$h = $settings->{rechour};
			}
			if (exists($settings->{recmin})) {
				$m = $settings->{recmin};
			}
			if (exists($settings->{recsec})) {
				$s = $settings->{recsec};
			}
			my $rec = sprintf "%d:%02d:%02d", $h, $m, $s;
			$cmd .= ' -t ' . $rec;
			$targetdur = $h * 3600 + $m * 60 + $s;
			$nullCmd = 0;
		}
	}
	
	# options from other options panel	
	if (exists($settings->{otheropts})) {
		$cmd .= ' ' . $settings->{otheropts};
		$nullCmd = 0;
	}

	# format, target, and output file
	unless ($format eq "none") {
		$cmd .= ' -f ' . $format;	
		$nullCmd = 0;
	}
	unless ($target eq "none") {
		$cmd .= " -target " . $target;
		$nullCmd = 0;
	}
	if (exists($settings->{twopass}) && $pass == 1) {
		$cmd .= ' -y "NUL.avi"';
		$nullCmd = 0;
	}
	else {
		if ($options->{overwrite}) {
			$cmd .= " -y";
		}
		$cmd .= ' "' . $ofn . '"';
	}

	$cmd = "None" if ($nullCmd);
		
	ShowCommandLine($cmd);
	
	if (wantarray) {
		return ($cmd, $ofn, $targetdur);
	}
	else {
		return $cmd;
	}
}

sub CleanUp {
	my $ifn = shift;
	
	my $outdir = $options->{outdir};
	
	my ($vol, $path, $file) = File::Spec->splitpath($ifn);
    my ($name, undef, $suffix) = fileparse($file, qr/\.[^.]*/);
	my $logpat = File::Spec->rel2abs(File::Spec->catfile($outdir, $name . '-*.log'));
	my @files = glob($logpat);
	
	foreach my $f (@files) {
		unlink $f;
	}
}

1;
