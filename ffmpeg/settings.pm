package settings;

use strict;

use Tkx;
use XML::Simple;
require options;
require command;
require filelist;
require globals;

my $flagProfChanges = 0;

my $mw;
my $options;
my %settings = ();

########################################################
# widgets on main settings page
my $bApply;
my $cboxProf;
my $entNewProf;
my $cbOverwrite;
my $bSave;
my $cbDelete;
my $bDelete;

# associated variables for main page
my $flagOverwrite = 0;
my $currentProfile = "";
my $flagDelete = 0;

########################################################
# widgets for the format tab	
my $cboxFormat;
my $cboxACodec;
my $cboxVCodec;
my $cboxTarget;
			
########################################################
# widgets for the video options tab
my $entVBit;
my $entFRate;
my $entVSizeX;
my $entVSizeY;
my $entVFactor;
my $cbMaintAR;
my $cboxAspRat;
my $cbDeinterlace;

# associated variables for the video options tab
my $flagDeinterlace = 0;
my $flagMaintAR = 0;

########################################################
# widgets for the audio options tab
my $entABit;
my $entSampRate;
my $entChans;
my $spinVolume;
my $entASync;

# associated variables for the audio options tab
my $volume;

########################################################
# widgets for the cropping tab
my $spinCropOffY;
my $spinCropHeight;
my $spinCropOffX;
my $spinCropWidth;
my $spinSeekHour;
my $spinSeekMin;
my $spinSeekSec;
my $spinRecHour;
my $spinRecMin;
my $spinRecSec;

# associated variables for the cropping tab
my $cropOffY;
my $cropHeight;
my $cropOffX;
my $cropWidth;
my $seekHour;
my $seekMin;
my $seekSec;
my $recHour;
my $recMin;
my $recSec;

#########################################################
# widgets for Other tab
my $entOther;
my $cbTwoPass;
my $cbQSFix;

# associated variables for the Other tab
my $flagTwoPass = 0;
my $flagQSFix = 0;

#########################################################################################################################
#
# main settings section
#
sub SetUpSettingsFrame {
	$mw = shift;
	$options = shift;

	my $frame = $mw->new_ttk__labelframe(-padding => "10 10 10 10", -borderwidth => 4, -relief => "groove", -text => "Settings");

	$bApply = $frame->new_ttk__button(-text => "Apply", -command => \&PressApply);
	$bApply->g_grid(-column => 0, -row => 0, -padx => "10 0", -sticky => "w");
	my $lblApply = $frame->new_ttk__label(-text => "Apply changed settings to selected files");
	$lblApply->g_grid(-column => 0, -columnspan => 2, -row => 0, -sticky => "e");
	
	my $lblProf = $frame->new_ttk__label(-text => "Profile:");
	$lblProf->g_grid(-column => 0, -row => 1, -sticky => "w", -padx => 10);

	$cboxProf = $frame->new_ttk__combobox();
	LoadProfiles();
	$cboxProf->configure(-state => "readonly");
	$cboxProf->g_grid(-column => 0, -row => 2, -padx => 10, -sticky => "w");
	$cboxProf->g_bind("<<ComboboxSelected>>", \&SelectProfile);

	my $lblNewProf = $frame->new_ttk__label(-text => "New Profile Name:");
	$lblNewProf->g_grid(-column => 1, -row => 1, -sticky => "w", -padx => 10);
	$entNewProf = $frame->new_ttk__entry(-width => 16, -text => "");
	$entNewProf->g_grid(-column => 1, -row => 2, -padx => 10, -sticky => "w");
	$entNewProf->g_bind("<KeyRelease>", \&ModNewProf);

	$cbOverwrite = $frame->new_ttk__checkbutton(-text => "Overwrite", -variable => \$flagOverwrite, -command => \&ClickOverwrite);
	$cbOverwrite->g_grid(-column => 2, -row => 2, -padx => 10, -sticky => "w");
	$cbOverwrite->configure(-state => "disabled");

	$bSave = $frame->new_ttk__button(-text => "Save", -command => \&NewProfSave);
	$bSave->g_grid(-column => 3, -row => 2, -padx => 10, -sticky => "w");
	$bSave->configure(-state => "disabled");
	
	$cbDelete = $frame->new_ttk__checkbutton(-text => "Delete", -variable => \$flagDelete, -command => \&ClickDelete);
	$cbDelete->g_grid(-column => 0, -row => 3, -padx => 10, -sticky => "w");
	$cbDelete->configure(-state => "disabled");

	$bDelete = $frame->new_ttk__button(-text => "Delete", -command => \&ProfDelete);
	$bDelete->g_grid(-column => 0, -row => 3, -padx => 10, -sticky => "e");
	$bDelete->configure(-state => "disabled");
	
	my $nb = $frame->new_ttk__notebook(-width => 600);
	$nb->g_grid(-column => 0, -columnspan => 4, -row => 4, -sticky => "wens", -pady => "10 0");

	my $fmttab = SetUpFormatTab($nb, $options);
	$nb->add($fmttab, -text => " Output Format ");
	
	my $vidtab = SetUpVideoTab($nb, $options);
	$nb->add($vidtab, -text => " Video Settings ");
	
	my $audtab = SetUpAudioTab($nb, $options);
	$nb->add($audtab, -text => " Audio Settings ");
	
	my $croptab = SetUpCropTab($nb, $options);
	$nb->add($croptab, -text => " Cropping ");	
	
	my $othertab = SetUpOtherTab($nb, $options);
	$nb->add($othertab, -text => " Other Options ");	
	
	$frame;
}

sub PressApply {
	filelist::UpdateSettings($currentProfile, \%settings);
}

sub SelectProfile {
	my $rv = "yes";
	if ($flagProfChanges) {
		$rv = Tkx::tk___messageBox(-type => "yesno",
	    	-message => "Are you sure you want to select a new profile with unsaved profile changes?",
	    	-icon => "question", -title => "Unsaved Profile Changes");
	}
	if ($rv eq "yes") {
		my $nProf = $cboxProf->get();
		FillSettingsWidgetsFromProfile($nProf);
	}
	else {
		$cboxProf->set("");
		$flagDelete = 0;
		$cbDelete->configure(-state => "disabled");
		$bDelete->configure(-state => "disabled");
	}
}

sub OkToExit {
	my $rv = "yes";
	if ($flagProfChanges) {
		$rv = Tkx::tk___messageBox(-type => "yesno",
	    	-message => "Are you sure you want to exit with unsaved profile changes?",
	    	-icon => "question", -title => "Unsaved Profile Changes");
	}
	return ($rv eq "yes"? 1 : 0);
}

sub LoadProfiles {
	my $profiles = '';
	foreach my $i (sort keys %{$options->{profiles}}) {
		$profiles = $profiles . ' {' . $i . '}';
	};
	$cboxProf->configure(-values => $profiles);
}

sub ModNewProf {
	my $nprof = $entNewProf->get();
	$flagOverwrite = 0;
	if ($nprof eq "") {
		$cbOverwrite->configure(-state => "disabled");
		$bSave->configure(-state => "disabled");
	}
	else {
		if (exists($options->{profiles}{$nprof})) {
			$cbOverwrite->configure(-state => "active");
			$bSave->configure(-state => "disabled");
		}
		else {
			$cbOverwrite->configure(-state => "disabled");
			$bSave->configure(-state => "active");
		}
	}
}

sub ClickOverwrite {
	if ($flagOverwrite) {
		$bSave->configure(-state => "active");
	}
	else {
		$bSave->configure(-state => "disabled");
	}
}

sub ClickDelete {
	if ($flagDelete) {
		$bDelete->configure(-state => "active");
	}
	else {
		$bDelete->configure(-state => "disabled");
	}
}

sub countProfiles {
	my @kl = keys %{$options->{profiles}};

	my $ct = @kl;

	$ct;
}

sub NewProfSave {
	my $nprof = $entNewProf->get();
	if (exists($options->{profiles}{$nprof})) {
		delete($options->{profiles}{$nprof});
	}
	
	foreach my $k (keys %settings) {
		if ($settings{$k} ne "") {
			$options->{profiles}{$nprof}{$k} = $settings{$k};
		}
	}
	$options->{profile} = $nprof;
	
	options::SaveOptions();
	
	LoadProfiles();
	$currentProfile = $nprof;
	$cboxProf->set($nprof);
	$flagOverwrite = 0;
	$cbOverwrite->configure(-state => "disabled");
	$bSave->configure(-state => "disabled");
	$entNewProf->delete(0, "end");

	$cbDelete->configure(-state => "active");
	$flagDelete = 0;
	$bDelete->configure(-state => "disabled");
	
	$flagProfChanges = 0;
}

sub ProfDelete {
	my $nprof = $cboxProf->get();
	if (exists($options->{profiles}{$nprof})) {
		delete($options->{profiles}{$nprof});
	}

	# determine first entry in profile array
	my @kl = keys %{$options->{profiles}};

	$nprof = $kl[0];
	$options->{profile} = $nprof;
	
	options::SaveOptions();
	
	LoadProfiles();
	$currentProfile = $nprof;
	$cboxProf->set($nprof);
	$flagOverwrite = 0;
	$cbOverwrite->configure(-state => "disabled");
	$bSave->configure(-state => "disabled");
	$entNewProf->delete(0, "end");

	if (countProfiles() > 1) {
		$cbDelete->configure(-state => "active");
	}
	else {
		$cbDelete->configure(-state => "disabled");
	}
	$flagDelete = 0;
	$bDelete->configure(-state => "disabled");
}

sub SettingsChanged {
	$cboxProf->set("");
	$currentProfile = "";
	$cbDelete->configure(-state => "disabled");
	$bDelete->configure(-state => "disabled");
	$flagDelete = 0;
	$flagProfChanges = 1;
	command::FormatCommandString(\%settings, undef, 1);
}

sub CurrentProfile {
	$currentProfile;
}

#########################################################################################################################
#
# format tab section of settings
#
sub SetUpFormatTab {
	my $nb = shift;
	my $options = shift;
	
	my $tab = $nb->new_ttk__frame(-padding => "10 10 10 10");
	
	my ($ac, $vc) = GetCodecs($options);
	my $fmts = GetFormats($options);
	my $tgts = GetTargets($options);
	
	my $lblFormat = $tab->new_ttk__label(-text => "Format:");
	$lblFormat->g_grid(-column => 0, -row => 0, -sticky => "w", -padx => 10);
	$cboxFormat = $tab->new_ttk__combobox();
	$cboxFormat->configure(-values => $fmts, -state => "readonly");
	$cboxFormat->g_grid(-column => 0, -row => 1, -padx => 10);
	$cboxFormat->g_bind("<<ComboboxSelected>>", \&SelectFormat);
	
	my $lblACodec = $tab->new_ttk__label(-text => "Audio Codec:");
	$lblACodec->g_grid(-column => 1, -row => 0, -sticky => "w", -padx => 10);
	$cboxACodec = $tab->new_ttk__combobox();
	$cboxACodec->configure(-values => $ac, -state => "readonly");
	$cboxACodec->g_grid(-column => 1, -row => 1, -padx => 10);
	$cboxACodec->g_bind("<<ComboboxSelected>>", \&SelectACodec);
	
	my $lblVCodec = $tab->new_ttk__label(-text => "Video Codec:");
	$lblVCodec->g_grid(-column => 2, -row => 0, -sticky => "w", -padx => 10);
	$cboxVCodec = $tab->new_ttk__combobox();
	$cboxVCodec->configure(-values => $vc, -state => "readonly");
	$cboxVCodec->g_grid(-column => 2, -row => 1, -padx => 10);
	$cboxVCodec->g_bind("<<ComboboxSelected>>", \&SelectVCodec);

	my $lblTarget = $tab->new_ttk__label(-text => "Target:");
	$lblTarget->g_grid(-column => 0, -row => 2, -sticky => "w", -padx => 10);
	$cboxTarget = $tab->new_ttk__combobox();
	$cboxTarget->configure(-values => $tgts, -state => "readonly");
	$cboxTarget->g_grid(-column => 0, -row => 3, -padx => 10);
	$cboxTarget->g_bind("<<ComboboxSelected>>", \&SelectTarget);
	
	$tab;
}

sub SelectFormat {
	$settings{format} = $cboxFormat->get();
	SettingsChanged();
}

sub SelectACodec {
	$settings{acodec} = $cboxACodec->get();
	SettingsChanged();
}

sub SelectVCodec {
	$settings{vcodec} = $cboxVCodec->get();
	SettingsChanged();
}

sub SelectTarget {
	$settings{target} = $cboxTarget->get();
	SettingsChanged();
}

#########################################################################################################################
#
# video options tab section of settings
#
sub SetUpVideoTab {
	my $nb = shift;
	my $options = shift;
	
	my $tab = $nb->new_ttk__frame(-padding => "10 10 10 10");
	
	my $lblVBit = $tab->new_ttk__label(-text => "Video Bitrate");
	$lblVBit->g_grid(-column => 0, -row => 0, -columnspan => 2, -sticky => "w", -padx => 5);

	$entVBit = $tab->new_ttk__entry(-width => 20, -text => "");
	$entVBit->g_grid(-column => 0, -row => 1, -columnspan => 2, -sticky => "w", -padx => 5);
	$entVBit->g_bind("<KeyRelease>", \&ModVBit);

	my $lblFRate = $tab->new_ttk__label(-text => "Frame Rate");
	$lblFRate->g_grid(-column => 2, -row => 0, -columnspan => 2, -sticky => "w", -padx => 5);

	$entFRate = $tab->new_ttk__entry(-width => 20, -text => "");
	$entFRate->g_grid(-column => 2, -row => 1, -columnspan => 2, -sticky => "w", -padx => 5);
	$entFRate->g_bind("<KeyRelease>", \&ModFRate);
	
	my $lblVSize = $tab->new_ttk__label(-text => "Video Size");
	$lblVSize->g_grid(-column => 4, -row => 0, -columnspan => 3, -sticky => "w", -padx => 5);

	$entVSizeX = $tab->new_ttk__entry(-width => 5, -text => "");
	$entVSizeX->g_grid(-column => 4, -row => 1, -sticky => "w", -padx => "5 0");
	$entVSizeX->g_bind("<KeyRelease>", \&ModVSizeX);

	my $lblX = $tab->new_ttk__label(-text => "x");
	$lblX->g_grid(-column => 5, -row => 1, -sticky => "we", -padx => 1);

	$entVSizeY = $tab->new_ttk__entry(-width => 5, -text => "");
	$entVSizeY->g_grid(-column => 6, -row => 1, -sticky => "w", -padx => "0 5");
	$entVSizeY->g_bind("<KeyRelease>", \&ModVSizeY);

	$cbMaintAR = $tab->new_ttk__checkbutton(-text => "Maintain Aspect Ratio (Pad)", -variable => \$flagMaintAR, -command => \&ClickMaintAR);
	$cbMaintAR->g_grid(-column => 4, -row => 2, -padx => 5, -columnspan => 4, -sticky => "w");
	
	my $lblVFactor = $tab->new_ttk__label(-text => "Factor:");
	$lblVFactor->g_grid(-column => 4, -row => 3, -columnspan => 2, -sticky => "w", -padx => 5);

	$entVFactor = $tab->new_ttk__entry(-width => 5, -text => "");
	$entVFactor->g_grid(-column => 6, -row => 3, -sticky => "w");
	$entVFactor->g_bind("<KeyRelease>", \&ModVFactor);
	
	my $lblAspRat = $tab->new_ttk__label(-text => "Aspect Ratio");
	$lblAspRat->g_grid(-column => 7, -row => 0, -columnspan => 2, -sticky => "w", -padx => 5);

	$cboxAspRat = $tab->new_ttk__combobox();
	$cboxAspRat->configure(-values => '{} {16:9} {4:3}');
	$cboxAspRat->configure(-state => "readonly", -width => 6);
	$cboxAspRat->g_grid(-column => 8, -row => 1, -padx => 5, -sticky => "w");
	$cboxAspRat->g_bind("<<ComboboxSelected>>", \&SelectAspRat);

	$cbDeinterlace = $tab->new_ttk__checkbutton(-text => "Deinterlace", -variable => \$flagDeinterlace, -command => \&ClickDeinterlace);
	$cbDeinterlace->g_grid(-column => 0, -row => 2, -padx => 5, -sticky => "w");

	$tab;
}

sub ModVBit {
	my $val = $entVBit->get();
	if ($val eq "") {
		delete $settings{videobr};
	}
	else {
		$settings{videobr} = $val;
	}
	SettingsChanged();
}

sub ModFRate {
	my $val = $entFRate->get();
	if ($val eq "") {
		delete $settings{framerate};
	}
	else {
		$settings{framerate} = $val;
	}
	SettingsChanged();
}

sub ModVSizeX {
	my $val = $entVSizeX->get();
	if ($val eq "") {
		delete $settings{vsizex};
	}
	else {
		$settings{vsizex} = $val;
	}
	SettingsChanged();
}

sub ModVSizeY {
	my $val = $entVSizeY->get();
	if ($val eq "") {
		delete $settings{vsizey};
	}
	else {
		$settings{vsizey} = $val;
	}
	SettingsChanged();
}

sub ModVFactor {
	my $val = $entVFactor->get();
	if ($val eq "") {
		delete $settings{vfactor};
	}
	else {
		$settings{vfactor} = $val;
	}
	SettingsChanged();
}

sub SelectAspRat {
	my $val = $cboxAspRat->get();
	if ($val eq "") {
		delete $settings{aspectratio};
	}
	else {
		$settings{aspectratio} = $val;
	}
	SettingsChanged();
}

sub ClickMaintAR {
	if ($flagMaintAR) {
		$settings{maintar} = "1";
	}
	else {
		if (exists($settings{maintar})) {
			delete $settings{maintar};
		}
	}
	SettingsChanged();
}

sub ClickDeinterlace {
	if ($flagDeinterlace) {
		$settings{deinterlace} = "1";
	}
	else {
		if (exists($settings{deinterlace})) {
			delete $settings{deinterlace};
		}
	}
	SettingsChanged();
}

#########################################################################################################################
#
# audio options tab section of settings
#
sub SetUpAudioTab {
	my $nb = shift;
	my $options = shift;
	
	my $tab = $nb->new_ttk__frame(-padding => "10 10 10 10");
	
	my $lblABit = $tab->new_ttk__label(-text => "Audio Bitrate");
	$lblABit->g_grid(-column => 0, -row => 0, -sticky => "w", -padx => 5);

	$entABit = $tab->new_ttk__entry(-width => 20, -text => "");
	$entABit->g_grid(-column => 0, -row => 1, -sticky => "w", -padx => 5);
	$entABit->g_bind("<KeyRelease>", \&ModABit);
	
	my $lblSampRate = $tab->new_ttk__label(-text => "Sample Rate");
	$lblSampRate->g_grid(-column => 1, -row => 0, -sticky => "w", -padx => 5);

	$entSampRate = $tab->new_ttk__entry(-width => 20, -text => "");
	$entSampRate->g_grid(-column => 1, -row => 1, -sticky => "w", -padx => 5);
	$entSampRate->g_bind("<KeyRelease>", \&ModSampRate);
	
	my $lblChans = $tab->new_ttk__label(-text => "Audio Channels");
	$lblChans->g_grid(-column => 3, -row => 0, -sticky => "w", -padx => 5);

	$entChans = $tab->new_ttk__entry(-width => 20, -text => "");
	$entChans->g_grid(-column => 3, -row => 1, -sticky => "w", -padx => 5);
	$entChans->g_bind("<KeyRelease>", \&ModChans);
	
	my $lblVolume = $tab->new_ttk__label(-text => "Volume");
	$lblVolume->g_grid(-column => 0, -row => 2, -sticky => "w", -padx => 5);

	$spinVolume = $tab->new_tk__spinbox(-from => -256, -to => 256, -justify => "right", 
			-width => 5, -textvariable => \$volume, -command => \&ModVolume);
	$spinVolume->g_grid(-column => 0, -row => 3, -sticky => "w", -padx => 5);
	$spinVolume->g_bind("<KeyRelease>", \&ModVolume);
	
	my $lblASync = $tab->new_ttk__label(-text => "Audio Sync");
	$lblASync->g_grid(-column => 1, -row => 2, -sticky => "w", -padx => 5);

	$entASync = $tab->new_ttk__entry(-width => 20, -text => "");
	$entASync->g_grid(-column => 1, -row => 3, -sticky => "w", -padx => 5);
	$entASync->g_bind("<KeyRelease>", \&ModASync);
	
	$tab;
}

sub ModABit {
	my $val = $entABit->get();
	if ($val eq "") {
		delete $settings{audiobr};
	}
	else {
		$settings{audiobr} = $val;
	}
	SettingsChanged();
}

sub ModSampRate {
	my $val = $entSampRate->get();
	if ($val eq "") {
		delete $settings{samplerate};
	}
	else {
		$settings{samplerate} = $val;
	}
	SettingsChanged();
}

sub ModChans {
	my $val = $entChans->get();
	if ($val eq "") {
		delete $settings{channels};
	}
	else {
		$settings{channels} = $val;
	}
	SettingsChanged();
}

sub ModVolume {
	if ($volume == 0) {
		delete $settings{volume};
	}
	else {
		$settings{volume} = $volume;
	}
	SettingsChanged();
}

sub ModASync {
	my $val = $entASync->get();
	if ($val eq "") {
		delete $settings{audiosync};
	}
	else {
		$settings{audiosync} = $val;
	}
	SettingsChanged();
}

#########################################################################################################################
#
# cropping tab section of settings
#
sub SetUpCropTab {
	my $nb = shift;
	my $options = shift;
	
	my $tab = $nb->new_ttk__frame(-padding => "10 10 10 10");
	
	my $lblOffset = $tab->new_ttk__label(-text => "Offset:");
	$lblOffset->g_grid(-column => 0, -row => 2, -sticky => "e", -padx => 5);
	my $lblFSize = $tab->new_ttk__label(-text => "Frame Size:");
	$lblFSize->g_grid(-column => 0, -row => 3, -sticky => "e", -padx => 5);
	
	my $lblHoriz = $tab->new_ttk__label(-text => "horiz(x)");
	$lblHoriz->g_grid(-column => 1, -row => 1, -sticky => "we", -padx => 5);
	my $lblVert = $tab->new_ttk__label(-text => "vert(y)");
	$lblVert->g_grid(-column => 2, -row => 1, -sticky => "we", -padx => 5);

	$spinCropOffX = $tab->new_tk__spinbox(-from => 0, -to => 999, -justify => "right", 
			-width => 4, -textvariable => \$cropOffX, -command => \&ModCropOffX);
	$spinCropOffX->g_grid(-column => 1, -row => 2, -sticky => "we", -padx => 5);
	$spinCropOffX->g_bind("<KeyRelease>", \&ModCropOffX);
		
	$spinCropOffY = $tab->new_tk__spinbox(-from => 0, -to => 999, -justify => "right", 
			-width => 4, -textvariable => \$cropOffY, -command => \&ModCropOffY);
	$spinCropOffY->g_grid(-column => 2, -row => 2, -sticky => "we", -padx => 5);
	$spinCropOffY->g_bind("<KeyRelease>", \&ModCropOffY);
	
	$spinCropWidth = $tab->new_tk__spinbox(-from => 0, -to => 999, -justify => "right", 
			-width => 4, -textvariable => \$cropWidth, -command => \&ModCropWidth);
	$spinCropWidth->g_grid(-column => 1, -row => 3, -sticky => "we", -padx => 5);
	$spinCropWidth->g_bind("<KeyRelease>", \&ModCropWidth);
	
	$spinCropHeight = $tab->new_tk__spinbox(-from => 0, -to => 999, -justify => "right", 
			-width => 4, -textvariable => \$cropHeight, -command => \&ModCropHeight);
	$spinCropHeight->g_grid(-column => 2, -row => 3, -sticky => "we", -padx => 5);
	$spinCropHeight->g_bind("<KeyRelease>", \&ModCropHeight);
	
	my $lblSeekTo = $tab->new_ttk__label(-text => "Seek to:");
	$lblSeekTo->g_grid(-column => 5, -row => 2, -sticky => "e", -padx => "20 5");
	my $lblRecord = $tab->new_ttk__label(-text => "Time to Record:");
	$lblRecord->g_grid(-column => 5, -row => 3, -sticky => "e", -padx => "20 5");
	
	my $lblHour = $tab->new_ttk__label(-text => "hour");
	$lblHour->g_grid(-column => 6, -row => 1, -sticky => "we", -padx => 5);
	$spinSeekHour = $tab->new_tk__spinbox(-from => 0, -to => 99, -justify => "right",
			-width => 3, -textvariable => \$seekHour, -command => \&ModSeekHour);
	$spinSeekHour->g_grid(-column => 6, -row => 2, -sticky => "we", -padx => 5);
	$spinSeekHour->g_bind("<KeyRelease>", \&ModSeekHour);
	$spinRecHour = $tab->new_tk__spinbox(-from => 0, -to => 99, -justify => "right", 
			-width => 3, -textvariable => \$recHour, -command => \&ModRecHour);
	$spinRecHour->g_grid(-column => 6, -row => 3, -sticky => "we", -padx => 5);
	$spinRecHour->g_bind("<KeyRelease>", \&ModRecHour);
	
	my $lblMin = $tab->new_ttk__label(-text => "min");
	$lblMin->g_grid(-column => 7, -row => 1, -sticky => "we", -padx => 5);
	$spinSeekMin = $tab->new_tk__spinbox(-from => 0, -to => 59, -justify => "right", 
			-width => 3, -textvariable => \$seekMin, -command => \&ModSeekMin);
	$spinSeekMin->g_grid(-column => 7, -row => 2, -sticky => "we", -padx => 5);
	$spinSeekMin->g_bind("<KeyRelease>", \&ModSeekMin);
	$spinRecMin = $tab->new_tk__spinbox(-from => 0, -to => 59, -justify => "right", 
			-width => 3, -textvariable => \$recMin, -command => \&ModRecMin);
	$spinRecMin->g_grid(-column => 7, -row => 3, -sticky => "we", -padx => 5);
	$spinRecMin->g_bind("<KeyRelease>", \&ModRecMin);
	
	my $lblSec = $tab->new_ttk__label(-text => "sec");
	$lblSec->g_grid(-column => 8, -row => 1, -sticky => "we", -padx => 5);
	$spinSeekSec = $tab->new_tk__spinbox(-from => 0, -to => 59, -justify => "right", 
			-width => 3, -textvariable => \$seekSec, -command => \&ModSeekSec);
	$spinSeekSec->g_grid(-column => 8, -row => 2, -sticky => "we", -padx => 5);
	$spinSeekSec->g_bind("<KeyRelease>", \&ModSeekSec);
	$spinRecSec = $tab->new_tk__spinbox(-from => 0, -to => 59, -justify => "right", 
			-width => 3, -textvariable => \$recSec, -command => \&ModRecSec);
	$spinRecSec->g_grid(-column => 8, -row => 3, -sticky => "we", -padx => 5);
	$spinRecSec->g_bind("<KeyRelease>", \&ModRecSec);
	
	$tab;
}

sub ModCropOffY {
	if ($cropOffY == 0) {
		delete $settings{cropoffy};
	}
	else {
		$settings{cropoffy} = $cropOffY;
	}
	SettingsChanged();
}

sub ModCropOffX {
	if ($cropOffX == 0) {
		delete $settings{cropoffx};
	}
	else {
		$settings{cropoffx} = $cropOffX;
	}
	SettingsChanged();
}

sub ModCropWidth {
	if ($cropWidth == 0) {
		delete $settings{cropwidth};
	}
	else {
		$settings{cropwidth} = $cropWidth;
	}
	SettingsChanged();
}

sub ModCropHeight {
	if ($cropHeight == 0) {
		delete $settings{cropheight};
	}
	else {
		$settings{cropheight} = $cropHeight;
	}
	SettingsChanged();
}

sub ModSeekHour {
	if ($seekHour == 0) {
		delete $settings{seekhour};
	}
	else {
		$settings{seekhour} = $seekHour;
	}
	SettingsChanged();
}

sub ModSeekMin {
	if ($seekMin == 0) {
		delete $settings{seekmin};
	}
	else {
		$settings{seekmin} = $seekMin;
	}
	SettingsChanged();
}

sub ModSeekSec {
	if ($seekSec == 0) {
		delete $settings{seeksec};
	}
	else {
		$settings{seeksec} = $seekSec;
	}
	SettingsChanged();
}

sub ModRecHour {
	if ($recHour == 0) {
		delete $settings{rechour};
	}
	else {
		$settings{rechour} = $recHour;
	}
	SettingsChanged();
}

sub ModRecMin {
	if ($recMin == 0) {
		delete $settings{recmin};
	}
	else {
		$settings{recmin} = $recMin;
	}
	SettingsChanged();
}

sub ModRecSec {
	if ($recSec == 0) {
		delete $settings{recsec};
	}
	else {
		$settings{recsec} = $recSec;
	}
	SettingsChanged();
}


#########################################################################################################################
#
# other options tab section of settings
#
sub SetUpOtherTab {
	my $nb = shift;
	my $options = shift;
	
	my $tab = $nb->new_ttk__frame(-padding => "10 5 10 5");
	
	my $lblOther = $tab->new_ttk__label(-text => "Other Options");
	$lblOther->g_grid(-column => 0, -row => 0, -sticky => "w", -padx => 5);

	$entOther = $tab->new_ttk__entry(-width => 80, -text => "");
	$entOther->g_grid(-column => 0, -row => 1, -columnspan => 3, -sticky => "w", -padx => 5);
	$entOther->g_bind("<KeyRelease>", \&ModOther);
	
	$cbTwoPass = $tab->new_ttk__checkbutton(-text => "Two Pass", -variable => \$flagTwoPass, -command => \&ClickTwoPass);
	$cbTwoPass->g_grid(-column => 0, -row => 2, -padx => 5, -sticky => "w");
	
	$cbQSFix = $tab->new_ttk__checkbutton(-text => "Quick Stream Fix", -variable => \$flagQSFix, -command => \&ClickQSFix);
	$cbQSFix->g_grid(-column => 1, -row => 2, -padx => 5, -sticky => "w");

	$tab;
}

sub ModOther {
	my $val = $entOther->get();
	if ($val eq "") {
		delete $settings{otheropts};
	}
	else {
		$settings{otheropts} = $val;
	}
	SettingsChanged();
}

sub ClickTwoPass {
	$cboxProf->set("");
	if ($flagTwoPass) {
		$settings{twopass} = "1";
	}
	else {
		if (exists($settings{twopass})) {
			delete $settings{twopass};
		}
	}
	SettingsChanged();
}

sub ClickQSFix {
	$cboxProf->set("");
	if ($flagQSFix) {
		$settings{qsfix} = "1";
	}
	else {
		if (exists($settings{qsfix})) {
			delete $settings{qsfix};
		}
	}
	SettingsChanged();
}
	
#########################################################################################################################

sub GetSettings {
	\%settings;
}

sub FillSettingsWidgetsFromProfile {
	my $prof = shift;
	
	$cboxProf->set($prof);
	$currentProfile = $prof;
	$flagProfChanges = 0;

	if (countProfiles() > 1) {
		$cbDelete->configure(-state => "active");
	}
	else {
		$cbDelete->configure(-state => "disabled");
	}
	$flagDelete = 0;
	$bDelete->configure(-state => "disabled");
	
	%settings = ();

	if (exists($options->{profiles}{$prof})) {
		$settings{format} = $options->{profiles}{$prof}{format};	
		$settings{acodec} = $options->{profiles}{$prof}{acodec};
		$settings{vcodec} = $options->{profiles}{$prof}{vcodec};
		if (exists($options->{profiles}{$prof}{target})) {
			$settings{target} = $options->{profiles}{$prof}{target};
		}
		else {
			$settings{target} = "none";
		}
		
		if (exists($options->{profiles}{$prof}{videobr})) {
			$settings{videobr} = $options->{profiles}{$prof}{videobr};
		}
		if (exists($options->{profiles}{$prof}{framerate})) {
			$settings{framerate} = $options->{profiles}{$prof}{framerate};
		}
		if (exists($options->{profiles}{$prof}{vsizex})) {
			$settings{vsizex} = $options->{profiles}{$prof}{vsizex};
		}
		if (exists($options->{profiles}{$prof}{vsizey})) {
			$settings{vsizey} = $options->{profiles}{$prof}{vsizey};
		}
		if (exists($options->{profiles}{$prof}{vfactor})) {
			$settings{vfactor} = $options->{profiles}{$prof}{vfactor};
		}
		if (exists($options->{profiles}{$prof}{aspectratio})) {
			$settings{aspectratio} = $options->{profiles}{$prof}{aspectratio};
		}
		if (exists($options->{profiles}{$prof}{maintar})) {
			$settings{maintar} = $options->{profiles}{$prof}{maintar};
		}
		if (exists($options->{profiles}{$prof}{deinterlace})) {
			$settings{deinterlace} = $options->{profiles}{$prof}{deinterlace};
		}
		
		if (exists($options->{profiles}{$prof}{audiobr})) {
			$settings{audiobr} = $options->{profiles}{$prof}{audiobr};
		}
		if (exists($options->{profiles}{$prof}{samplerate})) {
			$settings{samplerate} = $options->{profiles}{$prof}{samplerate};
		}
		if (exists($options->{profiles}{$prof}{channels})) {
			$settings{channels} = $options->{profiles}{$prof}{channels};
		}
		if (exists($options->{profiles}{$prof}{volume})) {
			$settings{volume} = $options->{profiles}{$prof}{volume};
		}
		if (exists($options->{profiles}{$prof}{audiosync})) {
			$settings{audiosync} = $options->{profiles}{$prof}{audiosync};
		}
		
		if (exists($options->{profiles}{$prof}{cropoffy})) {
			$settings{cropoffy} = $options->{profiles}{$prof}{cropoffy};
		}
		if (exists($options->{profiles}{$prof}{cropoffx})) {
			$settings{cropoffx} = $options->{profiles}{$prof}{cropoffx};
		}
		if (exists($options->{profiles}{$prof}{cropwidth})) {
			$settings{cropwidth} = $options->{profiles}{$prof}{cropwidth};
		}
		if (exists($options->{profiles}{$prof}{cropheight})) {
			$settings{cropheight} = $options->{profiles}{$prof}{cropheight};
		}
		if (exists($options->{profiles}{$prof}{seekhour})) {
			$settings{seekhour} = $options->{profiles}{$prof}{seekhour};
		}
		if (exists($options->{profiles}{$prof}{seekmin})) {
			$settings{seekmin} = $options->{profiles}{$prof}{seekmin};
		}
		if (exists($options->{profiles}{$prof}{seeksec})) {
			$settings{seeksec} = $options->{profiles}{$prof}{seeksec};
		}
		if (exists($options->{profiles}{$prof}{rechour})) {
			$settings{rechour} = $options->{profiles}{$prof}{rechour};
		}
		if (exists($options->{profiles}{$prof}{recmin})) {
			$settings{recmin} = $options->{profiles}{$prof}{recmin};
		}
		if (exists($options->{profiles}{$prof}{recsec})) {
			$settings{recsec} = $options->{profiles}{$prof}{recsec};
		}
		
		if (exists($options->{profiles}{$prof}{otheropts})) {
			$settings{otheropts} = $options->{profiles}{$prof}{otheropts};
		}
		if (exists($options->{profiles}{$prof}{twopass})) {
			$settings{twopass} = $options->{profiles}{$prof}{twopass};
		}
		if (exists($options->{profiles}{$prof}{qsfix})) {
			$settings{qsfix} = $options->{profiles}{$prof}{qsfix};
		}
	}
	FillWidgets();
	
	command::FormatCommandString(\%settings, undef, 1);
}

sub FillSettingsWidgetsFromNewSettings {
	my $lopts = shift;
	my $newsettings = shift;
	my $fn = shift;
	
	my $prof = $lopts->{profile};
	
	$cboxProf->set($prof);
	$currentProfile = $prof;
	$flagProfChanges = 0;

	$flagDelete = 0;
	$bDelete->configure(-state => "disabled");
	
	%settings = ();
	
	foreach my $k (keys %{$newsettings}) {
		$settings{$k} = $newsettings->{$k};
	}

	FillWidgets();
	
	command::FormatCommandString(\%settings, $fn, 1);
}

sub FillWidgets {
	SetComboBox($cboxFormat, "format");
	SetComboBox($cboxACodec, "acodec");
	SetComboBox($cboxVCodec, "vcodec");
	SetComboBox($cboxTarget, "target");
	
	SetEntry($entVBit, "videobr");
	SetEntry($entFRate, "framerate");
	SetEntry($entVSizeX, "vsizex");
	SetEntry($entVSizeY, "vsizey");
	SetEntry($entVFactor, "vfactor");
	SetComboBox($cboxAspRat, "aspectratio");	
	SetCheckBox(\$flagMaintAR, "maintar");
	SetCheckBox(\$flagDeinterlace, "deinterlace");
	
	SetEntry($entABit, "audiobr");
	SetEntry($entSampRate, "samplerate");
	SetEntry($entChans, "channels");
	SetSpinner(\$volume, "volume");
	SetEntry($entASync, "audiosync");
	
	SetSpinner(\$cropOffY, "cropoffy");	
	SetSpinner(\$cropOffX, "cropoffx");	
	SetSpinner(\$cropWidth, "cropwidth");	
	SetSpinner(\$cropHeight, "cropheight");	
	SetSpinner(\$seekHour, "seekhour");	
	SetSpinner(\$seekMin, "seekmin");	
	SetSpinner(\$seekSec, "seeksec");	
	SetSpinner(\$recHour, "rechour");	
	SetSpinner(\$recMin, "recmin");	
	SetSpinner(\$recSec, "recsec");	
	
	SetEntry($entOther, "otheropts");
	SetCheckBox(\$flagTwoPass, "twopass");
	SetCheckBox(\$flagQSFix, "qsfix");
}

sub SetComboBox {
	my $w = shift;
	my $tag = shift;
	
	if (exists($settings{$tag})) {		
		$w->set($settings{$tag});
	}
	else {
		$w->set("");
	}
}

sub SetEntry {
	my $w = shift;
	my $tag = shift;
	
	$w->delete(0, "end");
	
	if (exists($settings{$tag})) {
		$w->insert(0, $settings{$tag});
	}
}

sub SetCheckBox {
	my $flagref = shift;
	my $tag = shift;
	
	${$flagref} = 0;
	if (exists($settings{$tag})) {
		${$flagref} = 1;
	}
}

sub SetSpinner {
	my $spinref = shift;
	my $tag = shift;
	
	${$spinref} = 0;
	if (exists($settings{$tag})) {
		${$spinref} = $settings{$tag};
	}
}

sub GetCodecs {
	my $opts = shift;
	
	my $acs = "{none} {copy}";
	
	foreach my $c (sort split /,/, $opts->{acodecs}) {
		$acs .= " {" . $c . "}";
	}
	
	my $vcs = "{none} {copy}";
	
	foreach my $c (sort split /,/, $opts->{vcodecs}) {
		$vcs .= " {" . $c . "}";
	}
	
	($acs, $vcs);
}

sub GetFormats {
	my $opts = shift;
	
	my $fmts = "{none}";
	
	foreach my $f (sort split /,/, $opts->{formats}) {
		$fmts .= " {" . $f . "}";
	}
	$fmts;
}

sub GetTargets {
	my $opts = shift;
	
	my $tgts = "{none}";
	
	foreach my $t (sort split /,/, $opts->{targets}) {
		$tgts .= " {" . $t . "}";
	}
	$tgts;
}

1;
