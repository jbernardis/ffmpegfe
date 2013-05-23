package filelist;

use strict;

use Tkx;
use Data::Dumper;

require mediainfo;
require settings;

my $first = 1;
my $initDir = "c:/";
my $fileId = 0;

my $vidtypes = "";
my @vidtypes;

my $mw;
my $options;

my %FileList = ();
my %FileSettings = ();
my %FileOptions = ();

my $treeFiles;
my $sbvFiles;

sub SetUpFileList {
	$mw = shift;
	$options = shift;
	
	mediainfo::init($options);

	$vidtypes = "mpg,mp4,wmv,avi,mkv,flv,m2ts";
	if (exists($options->{videotypes})) {
		$vidtypes = $options->{videotypes};
	}
	@vidtypes = split /,/, $vidtypes; #/

	my $frame = $mw->new_ttk__frame(-padding => "10 10 5 5");
	
	$treeFiles = $frame->new_ttk__treeview(-height => 8, -columns => "profile", -selectmode => "extended");
	$treeFiles->column("#0", -width => 480);
	$treeFiles->heading("#0", -text => "Input Queue");
	$treeFiles->column("profile", -width => 104);
	$treeFiles->heading("profile", -text => "Profile");
	$treeFiles->g_grid(-column => 0, -row => 0, -sticky => "nsew");
	
	$sbvFiles = $frame->new_ttk__scrollbar(-command => [$treeFiles, "yview"], 
	        -orient => "vertical");
	$sbvFiles->g_grid(-column =>1, -row => 0, -sticky => "nse");
	
	$treeFiles->configure(-yscrollcommand => [$sbvFiles, "set"]);
	$treeFiles->tag_bind("file", "<ButtonRelease>", \&fileClicked);
	
	$frame;
}

sub fileClicked {
	my $idFocus = $treeFiles->focus();

	if (defined($idFocus) && $idFocus ne "") {
		foreach my $f (keys %FileList) {
			if ($idFocus eq $FileList{$f}) {
				settings::FillSettingsWidgetsFromNewSettings($FileOptions{$f}, $FileSettings{$f}, $f);
				last;
			}		
		}
	}
}

sub AddFiles {
	my $types = [
		['MPEG Files', ['.mpg']],
		['Video Files', \@vidtypes],
		['All files', ['*']],
	];
		
	my @filenames = Tkx::SplitList(Tkx::tk___getOpenFile(
		-title => "Choose Input Files",
		-multiple => 1,
		-filetypes => $types,
		-initialdir => $initDir,
	));
	
	my %lSettings = ();
	my $gs = settings::GetSettings();
	
	foreach my $k (keys %{$gs}) {
		$lSettings{$k} = $gs->{$k};
	}

	foreach my $f (@filenames) {	
		$f =~ s{//}{/}g;
		
		my ($vol, $path, $file) = File::Spec->splitpath($f);
		$initDir = $vol . $path;
		unless(exists($FileList{$f})) {
			my $id = $fileId++;

			my $values = settings::CurrentProfile();
			$treeFiles->insert("", "end", -id => $id, -text => $f,
				-tags => "file", -values => $values);
			$FileList{$f} = $id;
			mediainfo::AddMediaInfo($treeFiles, $id, $f);
		}
		else {
			my $id = $FileList{$f};
			$treeFiles->set($id, "profile", settings::CurrentProfile());		
		}
		$FileSettings{$f} = \%lSettings;
		$FileOptions{$f}{profile} = settings::CurrentProfile();
	}
}

sub UpdateSettings {
	my $nprof = shift;
	my $nsettings = shift;
	
	my $list = $treeFiles->selection();
	
	my %lSettings = ();
	foreach my $k (keys %{$nsettings}) {
		$lSettings{$k} = $nsettings->{$k};
	}

	if (defined($list) && $list ne "") {
		foreach my $id (@{$list}) {
			foreach my $f (keys %FileList) {
				if ($id eq $FileList{$f}) {
					$treeFiles->set($id, "profile", $nprof);		
					$FileSettings{$f} = \%lSettings;
					$FileOptions{$f}{profile} = $nprof;
				}		
			}
		}
	}
}

sub DeleteFiles {
	my $list = $treeFiles->selection();

	if (defined($list) && $list ne "") {
		foreach my $i (@{$list}) {		
			foreach my $fi (keys %FileList) {
				if ($FileList{$fi} == $i) {
					$treeFiles->delete($i);
					delete $FileList{$fi};
					last;
				}
			}
		}
	}
}

sub GetFileList {
	my @fnq = ();
	
	my $files = $treeFiles->children("");
	my @files = Tkx::SplitList($files);

	foreach my $fx (@files) {
		foreach my $fn (keys %FileList) {
			if ($FileList{$fn} == $fx) {
				unshift @fnq, {name => $fn, settings => $FileSettings{$fn}, options => $FileOptions{$fn}};
				last;
			}
		}
	}
	\@fnq;
}

sub DeleteFileEntry {
	my $fn = shift;

	my $i = $FileList{$fn};
	delete $FileList{$fn};
	$treeFiles->delete($i);
}

sub FileCount {
	my $count = 0;
	
	foreach my $fi (keys %FileList) {
		$count++;
	}
	$count;
}

1;
