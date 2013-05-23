package convert;

use strict;

use Tkx;
use Data::Dumper;
use File::Spec;
use File::Basename;
use threads;
use threads::shared;
use Thread::queue;
use Win32::OLE;

require command;
require mediainfo;

my $qCommand;
my $qResults;
my $thrConvert;

my $queueFiles;
my $cbUpdate;
my $options;
my $settings;

my $localsettings;
my $localoptions;

my $cancelFlag :shared;

sub Init {
	$options = shift;
	$settings = shift;
	$cbUpdate = shift;

	$qCommand = Thread::Queue->new();
	$qResults = Thread::Queue->new();
	
	$cancelFlag = 0;
	
	my $thrConvert = threads->create( \&ConvertThread, $qCommand, $qResults );
	$thrConvert->detach();
	repeat(500, \&ConvertResult, 0);
}

sub ConvertFiles {
	$queueFiles = shift;
	
	$cancelFlag = 0;
	
	ConvertNextFile();
}

sub Cancel {
	$cancelFlag = 1;
}

sub ConvertNextFile {
	my $qentry = pop @{$queueFiles};
	
	unless(defined($qentry)) {
		&{$cbUpdate}({updatetype => "queuecomplete"});
		return 0;
	}
	
	my $ifn = $qentry->{name};
	$localsettings = $qentry->{settings};
	$localoptions = $qentry->{options};
	
	if (exists($localsettings->{qsfix})) {
		QSFixFile($ifn);
	}
	else {
		ConvertPassOne($ifn, $ifn);
	}
}

sub QSFixFile {
	my $ifn = shift;
	
	my $outdir = $options->{outdir};
	my ($vol, $path, $file) = File::Spec->splitpath($ifn);
	my ($name, undef, $suffix) = fileparse($file, qr/\.[^.]*/);
	my $ofn = File::Spec->rel2abs(File::Spec->catfile($outdir, $name . '.qsfix' . $suffix));	
	
	my ($width, $height) = mediainfo::getVidSize($ifn);
	
	if ($width == -1 || $height == -1) {
		my $msg = "Unable to determine video dimensions for '" . $ifn . "'";
		&{$cbUpdate}({updatetype => "error", message => $msg});
		&{$cbUpdate}({updatetype => "qsfcomplete", file => $ifn, ofile => $ofn});
		ConvertNextFile();
	}
	else {
		mediainfo::setVidSize($ofn, $width, $height);
		&{$cbUpdate}({updatetype => "qsfstart", file => $ifn, ofile => $ofn, width => $width, height => $height});
		SendToConvert({action => "qsfix", file => $ifn, ofile => $ofn});		
	}
	
}

sub ConvertPassOne {
	my $ifn = shift;
	my $origfn = shift;
		
	my ($cmd, $ofn, $targetduration) = command::FormatCommandString($localsettings, $ifn, 1);
	if ($cmd eq "None") {
		&{$cbUpdate}({updatetype => "filecomplete", pass => 0, file => $ifn});
		ConvertNextFile()
	}
	else {
		my $pass = 0;
		if (exists($localsettings->{twopass})) {
			$pass = 1;
		}
		
		&{$cbUpdate}({updatetype => "filestart", pass => $pass, file => $ifn, ofile => $ofn, cmd => $cmd});
		SendToConvert({action => "convert", command => $cmd, duration => $targetduration, pass => $pass, file => $ifn, ofile => $ofn, origfile => $origfn});
	}
}

sub ConvertPassTwo {
	my $ifn = shift;
	my $origfn = shift;
	
	my ($cmd, $ofn, $targetduration) = command::FormatCommandString($localsettings, $ifn, 2);

	&{$cbUpdate}({updatetype => "filestart", pass => 2, file => $ifn, ofile => $ofn, cmd => $cmd});
	SendToConvert({action => "convert", command => $cmd, duration => $targetduration, pass => 2, file => $ifn, ofile => $ofn, origfile => $origfn});
}

sub PlayFile {
	my $fn = shift;
	
	my $ffplay = $options->{ffplay};
	
	my $cmd = '"' . $ffplay . '" -autoexit "' . $fn . '"';
	
	SendToConvert({action => "play", command => $cmd, file => $fn});
}

sub SendToConvert {
	my $cmd = shift;
	my $cmdstring = join("::", %{$cmd});
		
	$qCommand->enqueue($cmdstring);
}

sub SendToMain {
	my $q = shift;
	my $cmd = shift;
	my $cmdstring = join("::", %{$cmd});
		
	$q->enqueue($cmdstring);
}


sub ConvertThread {
	my $qCmd = shift;
	my $qRes = shift;
	my $cmd = shift;
	
	while (1) {
		my $cmdString = $qCmd->dequeue();
		my %cmd = split /::/, $cmdString;
		my %result = ();
		
		if ($cmd{action} eq "convert") {
			my $FFCmd = $cmd{command};
			
			my $fn = $cmd{file};
			my $ofn = $cmd{ofile};
			my $origfn = $cmd{origfile};

			SendToMain($qRes, {result => "trace", message => $FFCmd});
			my $pass = $cmd{pass};
			my $targetdur = $cmd{duration};
			my $pid = open PIPE, $FFCmd . " 2>&1 |";
			if ($pid != 0) {
				my $buffer = "";
				my $flag = 0;
				my $errMsg = "";
				my $char;
				my $duration = 0;
				while (read(PIPE, $char, 1) && $cancelFlag == 0) {
# if ($char eq "\r") { print "\n"; } else { print $char; }
					if ($char eq "\n") {
						SendToMain($qRes, {result => "trace", message => $buffer});
						if ($buffer =~ /Press .q. to stop/) {
							$flag = 1;
						}
						elsif ($buffer =~ /Duration: (\S*),/) {
							my ($hr, $mn, $sec) = split /:/, $1; #/
							$duration = ($hr * 3600) + ($mn * 60) + $sec;
						}
						else {
							$errMsg = $buffer; #potential error message
						}
						$buffer = "";
					}
					elsif ($char eq "\r") {
						if ($flag) {
							my $frame = -1;
							my $elapsed = -1;
							if ($buffer =~ /^frame=\s*(\S*) .*time=(\S*)/) {
								$frame = $1;
								$elapsed = countSeconds($2);
							}
							elsif ($buffer =~ /^.*time=(\S*)/) {
								$elapsed = countSeconds($1);
							}
							if ($elapsed != -1) {
								if ($frame != 0) {
									if ($targetdur == -1) {
										if ($duration != 0) {
											my $pct = ($elapsed/$duration)*100.0;
											SendToMain($qRes, {result => "status", pct => $pct});
										}
									}
									else {
										if ($targetdur != 0) {
											my $pct = ($elapsed/$targetdur)*100.0;
											SendToMain($qRes, {result => "status", pct => $pct});
										}										
									}
								}
							}
						}
						$buffer = "";
					}
					else {
						$buffer = $buffer . $char;
					}
				}
				if ($cancelFlag == 0) {
					close PIPE;
					if ($flag) {
						SendToMain($qRes, {result => "status", pct => 100});
						SendToMain($qRes, {result => "complete", pass => $pass, file => $fn, ofile => $ofn, origfile => $origfn});
					}
					else {
						SendToMain($qRes, {result => "error", message => $errMsg});
						SendToMain($qRes, {result => "complete", pass => 0, file => $fn, ofile => $ofn, origfile => $origfn});
					}
				}
				else {
					kill (-9, $pid);
					close PIPE;
					SendToMain($qRes, {result => "cancelled"});
				}
			}
			else {
				SendToMain($qRes, {result => "error", message => "Pipe open error: $!"});
				SendToMain($qRes, {result => "complete", pass => 0, file => $fn, ofile => $ofn, origfile => $origfn});
			}
		}
		elsif ($cmd{action} eq "qsfix") {
			my $ifn = $cmd{file};
			my $ofn = $cmd{ofile};
			my $width = $cmd{width};
			my $height = $cmd{height};
			
			SendToMain($qRes, {result => "trace", message => "Starting VideoReDo..."});

			my $v = Win32::OLE->new('VideoReDo.VideoReDoSilent');
			my $vrd = $v->VRDInterface;
	
			$vrd->{AudioAlert} = 0;
	
			my $rc = $vrd->FileOpenBatch($ifn);
			if ($rc != 1) {
				$vrd->Close;
				my $errMsg = "VRD Error opening '" . $ifn . "' for input";
				SendToMain($qRes, {result => "error", message => $errMsg});
				SendToMain($qRes, {result => "qsfcomplete", file => $ifn, ofile => $ofn});
			}
	
			$vrd->SetFilterDimensions($width, $height);
	
			my $res = $vrd->FileSaveProfile($ofn, "MPEG2 Program Stream");
			if (substr($res, 0, 1) eq "*") {
				$vrd->Close;
				my $errMsg = "VRD Error (" . $res . ") opening '" . $ofn . "' for input";
				SendToMain($qRes, {result => "error", message => $errMsg});
				SendToMain($qRes, {result => "qsfcomplete", file => $ifn, ofile => $ofn});
			}
	
			while ($vrd->IsOutputInProgress && $cancelFlag == 0) {
				my $pct = $vrd->OutputPercentComplete;
				SendToMain($qRes, {result => "qsfstatus", pct => $pct});
				sleep 1;
			}
			$vrd->Close;
			if ($cancelFlag == 1) {
				SendToMain($qRes, {result => "cancelled"});
				SendToMain($qRes, {result => "trace", message => "VideoReDo cancelled"});
			}
			else {
				SendToMain($qRes, {result => "qsfstatus", pct => 100});
				SendToMain($qRes, {result => "qsfcomplete", file => $ifn, ofile => $ofn});
				SendToMain($qRes, {result => "trace", message => "VideoReDo completed"});
			}
			
		}
		elsif ($cmd{action} eq "play") {
			my $FFCmd = $cmd{command};
			my $fn = $cmd{file};
			my $pid = open PIPE, $FFCmd . " 2>&1 |";
			if ($pid != 0) {
				my $char;
				while (read(PIPE, $char, 1)) { 
				}
				SendToMain($qRes, {result => "playcomplete", file => $fn});
			}
			else {
				SendToMain($qRes, {result => "error", message => "Pipe open error: $!"});
				SendToMain($qRes, {result => "playcomplete", file => $fn});
			}
		}
		else {
			SendToMain($qRes, {result => "error", message => "unknown action: $cmdString"});
		}
	}
}

sub countSeconds {
	my $t = shift;
	
	my @tv = split /:/, $t; #/
	
	my $ct = @tv;
	return (0)if ($ct <= 0);

	if ($ct == 1) {
		return $tv[0];
	}
	elsif ($ct == 2) {
		return $tv[0] * 60 + $tv[1];
	}
	else {
		return $tv[0] * 3600 + $tv[1] * 60 + $tv[2];
	}
}

# Emulate Perl/Tk's repeat() method
sub repeat {
	my $ms  = shift;
	my $sub = shift;
	my $params = [ @_ ];
	my $repeater; # repeat wrapper
        
	$repeater = sub {
		if (($sub->($params)) == 0) {
			Tkx::after($ms, $repeater);
		}
	};
        
	Tkx::after($ms, $repeater);
}

sub ConvertResult {
	my $prm = shift;
	
	while ($qResults->pending()) {
		my $resString = $qResults->dequeue();
		my %res = split /::/, $resString;
		
		if ($res{result} eq "status") {
			my $pct = $res{pct};
			&{$cbUpdate}({updatetype => "status", pct => $pct});
		}
		elsif ($res{result} eq "complete") {
			&{$cbUpdate}({updatetype => "filecomplete", pass => $res{pass}, file => $res{origfile}});
			unless ($cancelFlag) {
				if ($res{pass} == 1) {
					ConvertPassTwo($res{file}, $res{origfile});
				}
				else {
					command::CleanUp($res{file});
					if ($options->{preview}) {
						&{$cbUpdate}({updatetype => "previewstart", file => $res{ofile}});
						PlayFile($res{ofile});
					}
					else {
						ConvertNextFile();
					}
				}
			}
		}
		elsif ($res{result} eq "playcomplete") {
			&{$cbUpdate}({updatetype => "previewcomplete", file => $res{file}});
			unless ($options->{retain}) {
				unlink $res{file};
			}
			unless ($cancelFlag) {
				ConvertNextFile();
			}
		}
		elsif ($res{result} eq "qsfstatus") {
			my $pct = $res{pct};
			&{$cbUpdate}({updatetype => "qsfstatus", pct => $pct});
		}
		
		elsif ($res{result} eq "qsfcomplete") {
			&{$cbUpdate}({updatetype => "qsfcomplete", file => $res{file}, ofile => $res{ofile}});
			unless ($cancelFlag) {
				ConvertPassOne($res{ofile}, $res{file});
			}
		}
		elsif ($res{result} eq "cancelled") {
			&{$cbUpdate}({updatetype => "cancelled"});
		}
		elsif ($res{result} eq "trace") {
			&{$cbUpdate}({updatetype => "trace", message => $res{message}});
		}
		elsif ($res{result} eq "error") {
			&{$cbUpdate}({updatetype => "error", message => $res{message}});
		}
	}
	return 0;
}

1;
