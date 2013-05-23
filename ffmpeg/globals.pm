package globals;

use strict;

use Tkx;
require command;
require settings;
require trace;

my $mw;
my $options;

my $spinThreads;
my $entOutDir;
my $bOutDir;
my $cbOWOut;
my $cbTrace;
my $cbShutdown;
my $cbExitWhenDone;

my $nThreads;
my $OutDir;

my $flagOWOut = 0;
my $flagTrace = 0;
my $flagExitWhenDone = 0;
my $flagShutdown = 0;

sub SetUpGlobals {
	$mw = shift;
	$options = shift;
	
	my $nproc = 1;
	if (exists($ENV{NUMBER_OF_PROCESSORS})) {
		$nproc = $ENV{NUMBER_OF_PROCESSORS};
	}

	if (exists($options->{threads})) {
		if ($options->{threads} > $nproc) {
			$options->{threads} = $nproc;
		}
	}
	else {
		$options->{threads} = $nproc;
	}	
	$nThreads = $options->{threads};

	my $frame = $mw->new_ttk__labelframe(-padding => "10 5 10 5", -borderwidth => 4, -relief => "groove", -text => "");

	my $lblOutDir = $frame->new_ttk__label(-text => "Output Directory:");
	$lblOutDir->g_grid(-column => 0, -row => 0, -sticky => "w", -padx => 5);
	$OutDir = $options->{outdir};
	$entOutDir = $frame->new_ttk__entry(-width => 50, -textvariable => \$OutDir, -state => "readonly");
	$entOutDir->g_grid(-column => 1, -columnspan => 6, -row => 0, -sticky => "w", -padx => 10);

	$bOutDir = $frame->new_ttk__button(-text => "...", -command => \&PushOutDir, -width => 10);
	$bOutDir->g_grid(-column => 7, -row => 0, -padx => 10, -sticky => "w");

	$flagOWOut = (exists ($options->{overwrite})? $options->{overwrite} : 0);	
	$cbOWOut = $frame->new_ttk__checkbutton(-text => "Overwrite existing file", -variable => \$flagOWOut, -command => \&ClickOWOut);
	$cbOWOut->g_grid(-column => 0, -columnspan => 2, -row => 1, -padx => 5, -sticky => "w");

	$flagShutdown = (exists ($options->{shutdown})? $options->{shutdown} : 0);	
	$cbShutdown = $frame->new_ttk__checkbutton(-text => "Shutdown when finished", -variable => \$flagShutdown, -command => \&ClickShutdown);
	$cbShutdown->g_grid(-column => 0, -columnspan => 2, -row => 2, -padx => 5, -sticky => "w");
	
	$flagExitWhenDone = (exists ($options->{exitwhendone})? $options->{exitwhendone} : 0);	
	$cbExitWhenDone = $frame->new_ttk__checkbutton(-text => "Exit when finished", -variable => \$flagExitWhenDone, -command => \&ClickExitWhenDone);
	$cbExitWhenDone->g_grid(-column => 2, -columnspan => 3, -row => 2, -padx => 5, -sticky => "w");
	
	my $lblThreads = $frame->new_ttk__label(-text => "Cores");
	$lblThreads->g_grid(-column => 5, -row => 2, -sticky => "e", -padx => "5");
	$spinThreads = $frame->new_tk__spinbox(-from => 0, -to => $nproc, 
			-width => 4, -textvariable => \$nThreads, -command => \&ModThreads);
	$spinThreads->g_grid(-column => 6, -row => 2, -sticky => "w");
	
	$flagTrace = 0;	
	$cbTrace = $frame->new_ttk__checkbutton(-text => "Trace Outout", -variable => \$flagTrace, -command => \&ClickTrace);
	$cbTrace->g_grid(-column => 7, -columnspan => 2, -row => 2, -padx => 5, -sticky => "w");
	
	$frame;
}

sub ModThreads {
	$options->{threads} = $nThreads;
	command::FormatCommandString(settings::GetSettings(), undef, 1);
}

sub PushOutDir {
	my $nd = Tkx::tk___chooseDirectory(-initialdir => $OutDir, -title => "Choose Output Directory");
	if ($nd ne "") {
		$options->{outdir} = $nd;
		$OutDir = $nd;
		command::FormatCommandString(settings::GetSettings(), undef, 1);
	}
}

sub ClickOWOut {
	$options->{overwrite} = $flagOWOut;
	command::FormatCommandString(settings::GetSettings(), undef, 1);
}

sub ClickTrace {
	if ($flagTrace) {
		trace::ShowTraceFrame();
	}
	else {
		trace::HideTraceFrame();
	};
}

sub ClickShutdown {
	$options->{shutdown} = $flagShutdown;
}

sub ClickExitWhenDone {
	$options->{exitwhendone} = $flagExitWhenDone;
}

1;
