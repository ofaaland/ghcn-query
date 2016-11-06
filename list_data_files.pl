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

sub parse_station($)
{
#USC00043862  37.6833 -122.0833   39.3 CA HAYWARD                                     
#USW00093228  37.6542 -122.1150   13.1 CA HAYWARD AIR TERMINAL                   72585
#USW00094973  46.0261  -91.4442  367.0 WI HAYWARD MUNI AP                             

# fields are fixed-width
# First field is ID; United States stations start with US
	my $record=shift;
	my $station_id = substr($record,0,11);
	chomp($station_id);

	my $country = substr($station_id,0,2);
	chomp($country);

	return unless ($country eq 'US');

	my $state = substr($record,38,2);
	chomp($state);

	my $station_name = substr($record,41,(81-42));
	chomp($station_name);

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
print Dumper(\%selected_data_filenames);

