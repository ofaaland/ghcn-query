#!/usr/bin/perl -w

use strict;
use Data::Dumper;

my $data_file_path="../ghcnd_hcn/";
my $station_file_path="../ghcnd-stations.txt";

sub usage()
{
	print "$0 key1=value1 [key2=value2 [key3=value3 ...]]\n";
	exit 1;
}

my %query;
my %stations;
my %data_filenames;

sub trim
{
	my $s = shift;
	$s =~ s/^\s+|\s+$//g;
	return $s
};

sub parse_args()
{
	foreach my $clause (@ARGV) {
		my @parts=split(/=/,$clause);
		if (@parts != 2) {
			print "bad query: $clause\n";
			usage();
		}
		$query{$parts[0]}=$parts[1];
	}
}

# translate from (start column, end column) semantics
# to (start column, character count) semantics
# where column numbers given are 1-based, but
# substr() takes 0-based column numbers
#
# The ghcn readme.txt uses the (start,end) description method.
# This also makes it easy to see if a column is missed or used twice
sub ghcn_substr($$$)
{
	my $record = shift;
	my $startcol = shift;
	my $endcol = shift;
	return substr($record, $startcol-1, ($endcol-$startcol+1));
}

sub parse_data_record($)
{
# fields are fixed-width
# see readme.txt for specification
#USC00118740190208TMAX  300  6  322  6  322  6  256  6  289  6  250  6  272  6  289  6  267  6  267  6  222  6  261  6  278  6  222  6  228  6  261  6  233  6  239  6  294  6  306  6  272  6  211  6  211  6  250  6  267  6  267  6  294  6  300  6  294  6  306  6  289  6

	my $record=shift;
	my $station_id	= trim(ghcn_substr($record, 1,11));
	my $year	= trim(ghcn_substr($record,12,15));
	my $month	= trim(ghcn_substr($record,16,17));
	my $element	= trim(ghcn_substr($record,18,21));
	my %entries;

	my $base=21;
	my $entry_length=8;
	for (my $i=01; $i<=31; $i++)
	{
		my $index = $base+($i-1)*$entry_length;
		my $value = trim(substr($record, $index, 5));
		$entries{$i} = {	'value' => $value,
					'mflag' => substr($record, $index+5, 1),
					'qflag' => substr($record, $index+6, 1),
					'sflag' => substr($record, $index+7, 1)};
	}
	return ($station_id, {	'year' => $year,
				'month' => $month,
				'element' => $element,
				'entries' => \%entries });
}

sub parse_station($)
{
#USC00043862  37.6833 -122.0833   39.3 CA HAYWARD                                     
#USW00093228  37.6542 -122.1150   13.1 CA HAYWARD AIR TERMINAL                   72585
#USW00094973  46.0261  -91.4442  367.0 WI HAYWARD MUNI AP                             

# fields are fixed-width
# First field is ID; United States stations start with US
	my $record=shift;
	my $station_id = trim(substr($record,0,11));
	my $country = trim(substr($station_id,0,2));

	return unless (uc($country) eq 'US');

	my $state = trim(substr($record,38,2));
	my $station_name = trim(substr($record,41,(81-42)));

#	print "record         $record\n";
#	print "station_id     $station_id\n";
#	print "country        $country\n";
#	print "state          $state\n";
#	print "station_name   $station_name\n";

	return ($station_id,
		{"state"=>$state, "country"=>$country, "station_id"=>$station_id, "station_name"=>$station_name});
}

sub get_data_filenames($)
{
	my $dirname = shift;
	opendir(my $dh,$dirname);
	while (readdir $dh)
	{
		my $name = $_;
		my (@splitted) = split(/\./,$name);
		print "skipping bad filename: $name\n" if (@splitted != 2);
		next if (@splitted != 2);
		$data_filenames{$splitted[0]} = $name;
	}
	closedir($dh);
}

sub read_stations($)
{
	my $stations_file = shift;
	open(STATIONS,$stations_file);
	while(<STATIONS>)
	{
		my ($id, $details) = parse_station($_);
		if ($id)
		{
			$stations{$id} = $details;
		}
	}
}

sub filter_stations()
{
	my %matching_keys;
	for my $id (keys %stations)
	{
		my $include=1;
		for my $query_field (keys %query)
		{
			next unless (exists ${$stations{$id}}{$query_field});
			$include = 0 unless ( uc(${$stations{$id}}{$query_field}) eq
						uc($query{$query_field}))
		}
		$matching_keys{$id} = $id if ($include==1);
	}
	return %matching_keys;
}

sub filter_by_keys($$)
{
	my $source_hash_ref = shift;
	my $constraint_keys = shift;
	my %target_hash;

	foreach my $key (@$constraint_keys)
	{
		$target_hash{$key} = $$source_hash_ref{$key} if
					(exists $$source_hash_ref{$key});
	}

	return %target_hash;
}


if (@ARGV<1) {
	usage();
}

$Data::Dumper::Sortkeys = 1;

parse_args();
print "Query is: ";
print Dumper(\%query);

get_data_filenames($data_file_path);
read_stations($station_file_path);
my %selected_stations = filter_stations();
my %selected_data_filenames = filter_by_keys(\%data_filenames,[keys %selected_stations]);

#print Dumper(parse_station('USW00093228  37.6542 -122.1150   13.1 CA ' . 
#				'HAYWARD AIR TERMINAL                   72585'));
#print Dumper(\%stations);
#print Dumper(\%selected_stations);
#print Dumper(\%data_filenames);
#print Dumper(\%selected_data_filenames);
#print Dumper(parse_data_record('USC00118740190208TMAX  300  6  322  6  322  6  256  6  289  6  250  6  272  6  289  6  267  6  267  6  222  6  261  6  278  6  222  6  228  6  261  6  233  6  239  6  294  6  306  6  272  6  211  6  211  6  250  6  267  6  267  6  294  6  300  6  294  6  306  6  289  6'));

foreach my $data_file (values %selected_data_filenames)
{
	open(DATA, "$data_file_path/$data_file") || die "failed to open $data_file: $!";
	while (my $record = <DATA>)
	{
		my ($id, $entries) = parse_data_record($record);
		next unless (substr(uc($$entries{'element'}),0,2) eq "AC");
		my $year = $$entries{'year'};
		my $month = $$entries{'month'};
		my @cloud_coverage;
		for my $index (1..31)
		{
			my $cloudvalue = $$entries{'entries'}{$index}{'value'};
			push(@cloud_coverage, $cloudvalue) unless ($cloudvalue==-9999);
		}
		print "id $id year $year month $month pct_cloudy ", join(',', @cloud_coverage), "\n";
	}
	close(DATA);
}
