use strict;

use Tkx;
use XML::Simple;
use Data::Dumper;
use File::Spec;
use File::Basename;
use File::Temp;
use Win32::ShutDown;

hide_console();

use options;
use toolbar;
use filelist;
use globals;
use status;
use command;
use settings;
use convert;
use trace;

my $autoShutdown = 0;
my $saveYourselfMode = 0;

my $convertStartTime = 0;
my $qsfStartTime = 0;

my $options = options::LoadOptions();
$options->{shutdown} = 0;
$options->{exitwhendone} = 0;
$options->{preview} = 0;

my $traceframe;

my $convertActive = 0;

my $prof = $options->{profile};
unless (exists($options->{profiles}{$prof})) {
	# Profile $prof does not exist - default to first profile in list
	my @kl = keys %{$options->{profiles}};
	my $nprof = $kl[0];
	$prof = $nprof;
	$options->{profile} = $nprof;
}

my $mw = Tkx::widget->new(".");
$mw->g_wm_title("ffmpeg front end");
$mw->g_wm_minsize(100, 100);
$mw->g_wm_protocol("WM_DELETE_WINDOW", \&DelWindow);
$mw->g_wm_protocol("WM_SAVE_YOURSELF", \&SaveYourself);

my $tbframe = toolbar::SetUpToolBar($mw, $options);
$tbframe->g_grid(-column => 0, -row => 0, -sticky => "we");

my $flframe = filelist::SetUpFileList($mw, $options);
$flframe->g_grid(-column => 0, -row => 1, -sticky => "wens");

my $glbframe = globals::SetUpGlobals($mw, $options);
$glbframe->g_grid(-column => 0, -row => 2, -sticky => "wens", -padx => 5);

my $statusframe = status::SetUpStatusFrame($mw, $options);
$statusframe->g_grid(-column => 0, -row => 3, -sticky => "wens", -padx => 5);

my $cmdframe = command::SetUpCommandFrame($mw, $options);
$cmdframe->g_grid(-column => 0, -row => 4, -sticky => "wens", -padx => 5);

my $settingsframe = settings::SetUpSettingsFrame($mw, $options);
$settingsframe->g_grid(-column => 0, -row => 5, -sticky => "wens", -padx => 5, -pady => "0 5");

$traceframe = trace::SetUpTraceFrame($mw, $options);

my $settings = settings::GetSettings();
convert::Init($options, $settings, \&UpdateStatusFromConvert);

settings::FillSettingsWidgetsFromProfile($prof);

Tkx::MainLoop();

$options->{profile} = settings::CurrentProfile();
options::SaveOptions();

show_console();

if ($autoShutdown) {
	Win32::ShutDown::ForceShutDown();	
}

exit 0;

sub DelWindow {
	unless ($saveYourselfMode || $autoShutdown) {
		return if ($convertActive);
		return unless (settings::OkToExit());
	}
	$mw->g_destroy;
}

sub SaveYourself {
	$saveYourselfMode = 1;
	convert::Cancel();
	$convertActive = 0;
}

sub UpdateStatusFromConvert {
	my $cmd = shift;
	
	if ($cmd->{updatetype} eq "queuecomplete") {
		status::UpdateStatus("Queue Completed", "", "", 0, 0);
		my $fc = filelist::FileCount();
		toolbar::EnableConvertButton($fc == 0? 0 : 1);
		toolbar::EnableAddButton(1);
		toolbar::EnableRemoveButton($fc == 0? 0 : 1);	
		toolbar::EnableCancelButton($fc == 0? 0 : 1);	
		toolbar::EnableExitButton(1);	
		$convertActive = 0;
		unless (toolbar::isPreviewMode()) {
			if ($options->{shutdown}) {
				$autoShutdown = 1;
				$mw->g_destroy;
			}
			if ($options->{exitwhendone}) {
				$mw->g_destroy;
			}
		}
		toolbar::ClearPreview();
	}
	elsif ($cmd->{updatetype} eq "cancelled") {
		status::UpdateStatus("Cancelled", "", "", 0, 0);
		toolbar::EnableAddButton(1);
		toolbar::EnableCancelButton(0);	
		toolbar::EnableExitButton(1);
		if (filelist::FileCount() == 0) {	
			toolbar::EnableConvertButton(0);
			toolbar::EnableRemoveButton(0);	
		}
		else {
			toolbar::EnableConvertButton(1);
			toolbar::EnableRemoveButton(1);	
		}
		$convertActive = 0;
	}
	elsif ($cmd->{updatetype} eq "qsfstatus") {
		my $elapsedTime = time() - $qsfStartTime;
		status::UpdateStatus(undef, undef, undef, $cmd->{pct}, $elapsedTime);
	}
	elsif ($cmd->{updatetype} eq "qsfstart") {
		my $msg = "QSFix";
		$qsfStartTime = time();
		my $fn = $cmd->{file};
		$fn =~ s/\\/\//g;
		my $ofn = $cmd->{ofile};
		$ofn =~ s/\\/\//g;
		status::UpdateStatus($msg, $fn, $ofn, 0, 0);
		$convertActive = 1;
	}
	elsif ($cmd->{updatetype} eq "qsfcomplete") {
		my $msg = "QSFix Completed";
		status::UpdateStatus($msg, "", "", 0, 0);
	}
	elsif ($cmd->{updatetype} eq "status") {
		my $elapsedTime = time() - $convertStartTime;
		status::UpdateStatus(undef, undef, undef, $cmd->{pct}, $elapsedTime);
	}
	elsif ($cmd->{updatetype} eq "filestart") {
		my $msg = "Converting";
		my $pass = 0;
		$convertStartTime = time();
		if (exists($cmd->{pass})) {
			$pass = $cmd->{pass};
		}
		unless ($pass == 0) {
			$msg .= " (Pass " . $pass . ")";
		}
		my $fn = $cmd->{file};
		$fn =~ s/\\/\//g;
		my $ofn = $cmd->{ofile};
		$ofn =~ s/\\/\//g;
		status::UpdateStatus($msg, $fn, $ofn, 0, 0);
		$convertActive = 1;
	}
	elsif ($cmd->{updatetype} eq "filecomplete") {
		my $msg = "File Completed";
		my $pass = 0;
		if (exists($cmd->{pass})) {
			$pass = $cmd->{pass};
		}
		unless ($pass == 0) {
			$msg = "Pass " . $pass . " Completed";
		}
		my $fn = $cmd->{file};
		status::UpdateStatus($msg, "", "", 0, 0);
		if (($pass == 0 or $pass == 2) && !toolbar::isPreviewMode()) {
			filelist::DeleteFileEntry($fn);
		}
	}
	elsif ($cmd->{updatetype} eq "previewstart") {
		status::UpdateStatus("Previewing", $cmd->{file}, "", 0, 0);
	}
	elsif ($cmd->{updatetype} eq "previewcomplete") {
		status::UpdateStatus("Preview Complete", "", "", 0, 0);
	}
	elsif ($cmd->{updatetype} eq "trace") {
		trace::UpdateDisplay($cmd->{message});
	}
	elsif ($cmd->{updatetype} eq "error") {
		trace::UpdateDisplay("Error: " . $cmd->{message});
		status::UpdateStatus("Error", $cmd->{message}, "", 0, 0);
		Tkx::tk___messageBox(-message => $cmd->{message}, -title => "FFMPEG Error", -icon => "error");
	}
}

use Win32::GUI();
use Win32;

my $wConsole;

sub hide_console {
	$wConsole = Win32::GUI::GetPerlWindow();
	Win32::GUI::Hide($wConsole);
	Win32::SetChildShowWindow(0) 
}

sub show_console {
	Win32::GUI::Show($wConsole);
}
