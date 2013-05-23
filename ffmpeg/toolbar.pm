package toolbar;

use strict;

use Tkx;
require filelist;
require convert;
require settings;
require trace;

my $mw;
my $options;

my $bAdd;
my $bRemove;
my $bConvert;
my $bCancel;
my $bExit;
my $cbPreview;
my $cbRetain;

my $flagPreview = 0;
my $flagRetain = 0;

sub SetUpToolBar {
	$mw = shift;
	$options = shift;

	my $frame = $mw->new_ttk__frame();
	
	Tkx::image_create_photo("imgAdd", -file => "bmp/btn_add.gif");
	$bAdd = $frame->new_button(
		-text => " Add",
		-image => "imgAdd",
		-compound => "left",
		-anchor => "w",
		-command => \&pressAdd,
		-width => 100,
		-height => 36,
	);
	$bAdd->g_grid(-column => 0, -row => 0, -rowspan => 2);
	
	Tkx::image_create_photo("imgRemove", -file => "bmp/btn_remove.gif");
	$bRemove = $frame->new_button(
		-text => " Remove",
		-image => "imgRemove",
		-compound => "left",
		-anchor => "w",
		-command => \&pressRemove,
		-width => 100,
		-height => 36,
	);
	$bRemove->g_grid(-column => 1, -row => 0, -rowspan => 2);
	
	Tkx::image_create_photo("imgConvert", -file => "bmp/btn_convert.gif");
	$bConvert = $frame->new_button(
		-text => " Convert",
		-image => "imgConvert",
		-compound => "left",
		-anchor => "w",
		-command => \&pressConvert,
		-width => 100,
		-height => 36,
	);
	$bConvert->g_grid(-column => 2, -row => 0, -rowspan => 2);
	
	$flagPreview = 0;
	$options->{preview} = 0;
	$cbPreview = $frame->new_ttk__checkbutton(-text => "Preview", -variable => \$flagPreview, -command => \&ClickPreview);
	$cbPreview->g_grid(-column => 3, -row => 0, -padx => 10, -sticky => "w");
	
	$flagRetain = 0;
	$options->{retain} = 0;
	$cbRetain = $frame->new_ttk__checkbutton(-text => "Retain File", -variable => \$flagRetain, -command => \&ClickRetain);
	$cbRetain->g_grid(-column => 3, -row => 1, -padx => 10, -sticky => "w");

	Tkx::image_create_photo("imgCancel", -file => "bmp/btn_cancel.gif");
	$bCancel = $frame->new_button(
		-text => " Cancel",
		-image => "imgCancel",
		-compound => "left",
		-anchor => "w",
		-command => \&pressCancel,
		-width => 100,
		-height => 36,
	);
	$bCancel->g_grid(-column => 3, -row => 0, -padx => "110 0", -rowspan => 2);
	
	Tkx::image_create_photo("imgExit", -file => "bmp/btn_exit.gif");
	$bExit = $frame->new_button(
		-text => " Exit",
		-image => "imgExit",
		-compound => "left",
		-anchor => "w",
		-command => \&pressExit,
		-width => 100,
		-height => 36,
	);
	$bExit->g_grid(-column => 4, -row => 0, -rowspan => 2);
	
	EnableAddButton(1);
	EnableRemoveButton(0);
	EnableConvertButton(0);
	EnableCancelButton(0);
	EnableExitButton(1);
	
	$frame;
}

sub pressAdd {
	filelist::AddFiles();
	if (filelist::FileCount() != 0) {
		EnableConvertButton(1);
		EnableRemoveButton(1);
	}
	else {
		EnableConvertButton(0);
		EnableRemoveButton(0);
	}
}

sub pressRemove {
	filelist::DeleteFiles();
	if (filelist::FileCount() == 0) {
		EnableConvertButton(0);
		EnableRemoveButton(0);
		ClearPreview();
	}
}

sub pressConvert {
	trace::ClearDisplay();

	my $fnq = filelist::GetFileList();
	EnableConvertButton(0);
	EnableAddButton(0);
	EnableRemoveButton(0);
	EnableCancelButton(1);
	EnableExitButton(0);

	convert::ConvertFiles($fnq);
}

sub ClickPreview {
	$options->{preview} = $flagPreview;
	if ($flagPreview) {
		$cbRetain->configure(-state => "active");	
	}
	else {
		$flagRetain = 0;
		$options->{retain} = 0;
		$cbRetain->configure(-state => "disabled");	
	}
	command::FormatCommandString(settings::GetSettings(), undef, 1);
}

sub ClickRetain {
	$options->{retain} = $flagRetain;
}

sub pressCancel {
	EnableCancelButton(0);	
	convert::Cancel();
}

sub pressExit {
	return unless (settings::OkToExit());
	$mw->g_destroy;
}

sub EnableAddButton {
	my $flag = shift;
	
	my $status = ($flag ? "active" : "disabled");
	
	$bAdd->configure(-state => $status);
}

sub EnableRemoveButton {
	my $flag = shift;
	
	my $status = ($flag ? "active" : "disabled");
	
	$bRemove->configure(-state => $status);
}

sub EnableConvertButton {
	my $flag = shift;
	
	my $status = ($flag ? "active" : "disabled");
	
	$bConvert->configure(-state => $status);
	$cbPreview->configure(-state => $status);
	
	if ($flagPreview && $flag) {
		$cbRetain->configure(-state => "active");	
	}
	else {
		$cbRetain->configure(-state => "disabled");	
	}
}

sub isPreviewMode {
	$flagPreview;
}

sub ClearPreview {
	$flagPreview = 0;
	$options->{preview} = 0;
	$flagRetain = 0;
	$options->{retain} = 0;
	$cbRetain->configure(-state => "disabled");	
	command::FormatCommandString(settings::GetSettings(), undef, 1);
}

sub EnableCancelButton {
	my $flag = shift;
	
	my $status = ($flag ? "active" : "disabled");
	
	$bCancel->configure(-state => $status);
}

sub EnableExitButton {
	my $flag = shift;
	
	my $status = ($flag ? "active" : "disabled");
	
	$bExit->configure(-state => $status);
}

1;
