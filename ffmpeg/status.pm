package status;

use strict;

use Tkx;

my $mw;
my $origTitle;

my $statusValue;
my $statusFromFile;
my $statusToFile;
my $pctConvert;
my $pctConvertStr;
my $ElapsedStr;
my $RemainingStr;

my $lblStatusLbl;
my $entStatusVal;
my $lblFromFileLbl;
my $entFromFileVal;
my $lblToFileLbl;
my $entToFileVal;
my $progConvert;
my $entProgVal;
my $entElapsed;
my $entRemaining;

sub SetUpStatusFrame {
	$mw = shift;
	my $options = shift;
	
	$origTitle = $mw->g_wm_title;

	my $frame = $mw->new_ttk__labelframe(-padding => "10 5 10 5", -borderwidth => 4, -relief => "groove", -text => "Status");
	
	$statusValue = "Waiting...";
	$lblStatusLbl = $frame->new_ttk__label(-text => "Status:");
	$entStatusVal = $frame->new_ttk__entry(-width => 60, -textvariable => \$statusValue, -state => "readonly");
	$statusFromFile = "";
	$lblFromFileLbl = $frame->new_ttk__label(-text => "Source:");
	$entFromFileVal = $frame->new_ttk__entry(-width => 60, -textvariable => \$statusFromFile, -state => "readonly");
	$statusToFile = "";
	$lblToFileLbl = $frame->new_ttk__label(-text => "Destination:");
	$entToFileVal = $frame->new_ttk__entry(-width => 60, -textvariable => \$statusToFile, -state => "readonly");
	$pctConvert = 0;
	$pctConvertStr = "";
	$progConvert = $frame->new_ttk__progressbar(-orient => 'horizontal',
						-length => 500,
						-mode => 'determinate',
						-variable => \$pctConvert,
	);
	$entProgVal = $frame->new_ttk__entry(-width => 9, -justify => "right", -textvariable => \$pctConvertStr, -state => "readonly");
	$lblStatusLbl->g_grid(-column => 0, -row => 0, -sticky => "e", -padx => 10);
	$entStatusVal->g_grid(-column => 1, -row => 0, -sticky => "w");
	$lblFromFileLbl->g_grid(-column => 0, -row => 1, -sticky => "e", -padx => 10);
	$entFromFileVal->g_grid(-column => 1, -row => 1, -sticky => "w");
	$lblToFileLbl->g_grid(-column => 0, -row => 2, -sticky => "e", -padx => 10);
	$entToFileVal->g_grid(-column => 1, -row => 2, -sticky => "w");
	$progConvert->g_grid(-column => 0, -columnspan => 5, -row => 3, -sticky => "we", -padx => "5 0");
	$entProgVal->g_grid(-column => 5, -row => 3, -sticky => "w");
	
	$ElapsedStr = "";
	$entElapsed = $frame->new_ttk__entry(-width => 9, -justify => "right", -textvariable => \$ElapsedStr, -state => "readonly");
	$entElapsed->g_grid(-column => 5, -row => 1, -sticky => "w");
	my $lblElapsed = $frame->new_ttk__label(-text => "Elapsed");
	$lblElapsed->g_grid(-column => 6, -row => 1, -sticky => "w");
	$RemainingStr = "";
	$entRemaining = $frame->new_ttk__entry(-width => 9, -justify => "right", -textvariable => \$RemainingStr, -state => "readonly");
	$entRemaining->g_grid(-column => 5, -row => 2, -sticky => "w");
	my $lblRemaining = $frame->new_ttk__label(-text => "Remains");
	$lblRemaining->g_grid(-column => 6, -row => 2, -sticky => "w");
	
	$frame;
}

sub UpdateStatus {
	my $message = shift;
	my $FromFile = shift;
	my $ToFile = shift;
	my $pct = shift;
	my $elapsed = shift;

	if (defined($message)) {
		$statusValue = $message;
	}

	if (defined($FromFile)) {
		$statusFromFile = $FromFile;
	}

	if (defined($ToFile)) {
		$statusToFile = $ToFile;
	}

	$pctConvert = $pct;
	if ($pct == 0) {
		$pctConvertStr = "";
		$mw->g_wm_title($origTitle);
		$RemainingStr = "";
		$ElapsedStr = "";
	}
	else {
		$pctConvertStr = sprintf "%7.2f\%", $pct;
		$mw->g_wm_title("ffmpeg ". $pctConvertStr);
		$ElapsedStr = FormatTime($elapsed);
		if ($pct < 2) {
			$RemainingStr = "???";
		}
		else {
			$RemainingStr = FormatTime((100 - $pct)/$pct * $elapsed);
		}
	}
}

sub FormatTime {
	my $seconds = shift;
	
	my $osec = $seconds % 60;
	my $omin = int($seconds / 60);
	
	my $ohour = int($omin / 60);
	$omin = $omin % 60;
	
	my $ret = sprintf "%3d:%02d:%02d", $ohour, $omin, $osec;
	
	$ret;
}

1;
