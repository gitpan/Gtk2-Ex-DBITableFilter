use strict;
use warnings;
use Carp;
use Gtk2::Ex::Simple::List;
use Glib qw(TRUE FALSE);
use Gtk2 qw/-init -threads-init/;
use Data::Dumper;
use Gtk2::Ex::Threads::DBI;
use Gtk2::Ex::DBITableFilter;
use DBD::SQLite2;

# This line is required on win32. I don't know why...
Gtk2::Gdk::Threads->enter if $^O =~ /Win32/;

createdatabase();

my $slist = Gtk2::Ex::Simple::List->new (
	 undef			=> 'bool',
	'ID'			=> 'text',
	'Name'			=> 'text',
	'Description'	=> 'text',
	'Quantity'		=> 'int',
	 ''				=> 'text',
);

my $mythread = Gtk2::Ex::Threads::DBI->new( {
	dsn		=> "dbi:SQLite2:data.dbl",
	user	=> undef,
	passwd	=> undef,
	attr	=> { RaiseError => 1, AutoCommit => 1 }
});

# ----------------------- #
my $pagedlist = Gtk2::Ex::DBITableFilter->new($slist);
$pagedlist->make_checkable;
$pagedlist->add_filter(2, 
	[[0,'cat'], [1,'rat'], [1,'dog'], [0,'elephant'], [0,'lion'], [0,'tiger']]
);
$pagedlist->add_search_box(3);
$pagedlist->add_filter(4, 
	[[1,' >= 0 '], [0, ' >= 10 '], [0, ' >= 80 ']]
);
$pagedlist->set_simple_sql(\&fetch_easy);
$pagedlist->set_thread($mythread);
# ----------------------- #

$mythread->start;

my $window = Gtk2::Window->new;
$window->signal_connect('destroy' => \&terminate);

my $refreshbutton = Gtk2::Button->new_from_stock('gtk-refresh');
$refreshbutton->signal_connect (clicked => 
	sub { 
		$pagedlist->refresh;
	}
);
my $quitbutton = Gtk2::Button->new_from_stock('gtk-quit');
$quitbutton->signal_connect (clicked => \&terminate);

my $hbox = Gtk2::HBox->new (TRUE, 0);
$hbox->pack_start ($refreshbutton, FALSE, TRUE, 0);    
$hbox->pack_start ($quitbutton, FALSE, TRUE, 0);    
my $vbox = Gtk2::VBox->new (FALSE, 0);
$vbox->pack_start ($hbox, FALSE, TRUE, 0);    
$vbox->pack_start ($pagedlist->get_widget, TRUE, TRUE, 0);
$window->add ($vbox);
$window->set_default_size(300, 400);
$window->show_all;
Gtk2->main;

sub terminate {
	$mythread->stop;
	print "Wait for child thread to die...\n";
	sleep 1;
	erasedatabase();
	Gtk2->main_quit;
}

sub fetch_easy {
	my ($params) = @_;
	my $names 		= $params->{params}->{columnfilter}->{2};
	my $descpattern	= $params->{params}->{columnfilter}->{3} || '';
	my $valuelimit	= $params->{params}->{columnfilter}->{4}->[0];
	my $names_str = combine(@$names);
	return (qq{
		select 
			selected, id, name, description, quantity
		from 
			animals
		where 
			name in $names_str and 
			description like '%$descpattern%'
	});
}

sub combine {
	my (@list) = @_;
	my $str = join '\',\'', @list;
	$str = '(\''.$str.'\')';
	return $str;
}

sub createdatabase {
	my $dbh = DBI->connect( 
		"dbi:SQLite2:data.dbl", 
		undef, 
		undef, 
		{ AutoCommit => 0 } 
	) || die "Cannot connect: $DBI::errstr";

	eval {
		local $dbh->{PrintError} = 0;
		$dbh->do("DROP TABLE animals");
	};
	$dbh->do( "CREATE TABLE animals ( selected,id,name,description,quantity )" );
	print "Loading data into SQLite table ... Will take a while\n";
	my @names = qw /cat rat dog elephant lion tiger/;
	my @descs = qw /furry big small herbivore/;
	my $count = 0;
	my $sth = $dbh->prepare( "INSERT INTO animals VALUES ( ?, ?, ?, ?, ? ) " );
	for my $i (0..100) {
		for my $j (0..110) {
			my $selected = int rand(2);
			my $name = $names[int rand(6)];
			my $desc = $descs[int rand(4)];				
			my $qty = int rand(100);
			$sth->execute($selected, $count, $name, $desc,$qty);
			$count++;
		}
	}
	$dbh->commit;
	print "...Done.\n";
}

sub erasedatabase {
	my $dbh = DBI->connect( 
		"dbi:SQLite2:data.dbl", 
		undef, 
		undef, 
		{ AutoCommit => 0 } 
	) || die "Cannot connect: $DBI::errstr";
	eval {
		local $dbh->{PrintError} = 0;
		$dbh->do("DROP TABLE animals");
	};
	$dbh->disconnect;
}	
