package trace;

use strict;

use Tkx;
require command;
require settings;

my $mw;
my $options;

my $txtTrace;

my $traceFrame;

sub SetUpTraceFrame {
	$mw = shift;
	$options = shift;
	
	$traceFrame = $mw->new_ttk__labelframe(-padding => "10 5 10 5", -borderwidth => 4, -relief => "groove", -text => "");

	my $lblTrc = $traceFrame->new_ttk__label(-text => "Trace Output:");
	$lblTrc->g_grid(-column => 0, -row => 0, -sticky => "w", -padx => 5);
	
	$txtTrace = $traceFrame->new_tk__text(-width => 90, -height => 46, -state => "disabled");
	$txtTrace->g_grid(-column => 0, -row => 1, -sticky => "wens", -padx => "10 0");
	my $sbvTrc = $traceFrame->new_ttk__scrollbar(-command => [$txtTrace, "yview"], 
	        -orient => "vertical");
	$sbvTrc->g_grid(-column => 1, -row => 1, -sticky => "nse");
	
	$txtTrace->configure(-yscrollcommand => [$sbvTrc, "set"]);
	
	$traceFrame;
}

sub ShowTraceFrame {
	$traceFrame->g_grid(-column => 1, -row => 0, -rowspan => 6, -sticky => "wens", -padx => 5, -pady => "0 5");
}

sub HideTraceFrame {
	$traceFrame->g_grid_forget();
}

sub ClearDisplay {
    $txtTrace->configure(-state => "normal");
    $txtTrace->delete("1.0", "end");
    $txtTrace->configure(-state => "disabled");
}

sub UpdateDisplay {
	my $text = shift;
	
    $txtTrace->configure(-state => "normal");
    
	my $numlines = $txtTrace->index("end - 1 line");
	while ($numlines > 500) {
		$txtTrace->delete("1.0", "2.0");
		$numlines = $txtTrace->index("end - 1 line");
	}
	$txtTrace->insert_end($text . "\n");
	$txtTrace->see("end");

    $txtTrace->configure(-state => "disabled");
}

1;
