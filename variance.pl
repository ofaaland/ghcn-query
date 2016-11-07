#!/usr/bin/perl -w

use strict;

sub count_sum_sqr
{
	my ($count, $sum, $sumsqr) = (0,0,0);
	foreach my $num (@_)
	{
		$count += 1;
		$sum += $num;
		$sumsqr += $num*$num;
	}
	return ($count, $sum, $sumsqr);
}

sub variance
{
	my $count = shift;
	my $sum = shift;
	my $sumsqr = shift;

	if ($count==1)
	{
		return 0;
	} else {
		return ($sumsqr-$sum*$sum/$count)/($count-1);
	}
}

sub test
{
	my @a=(1,2,3,4,5,6,7,8,9,10);
	my @b=(1,1,1,1,1,10,10,10,10,10);
	my @c=(4,4,4,4,4,6,6,6,6,6);
	my @d=(4,5,3,6,5);

	foreach my $testarr (\@a,\@b,\@c, \@d)
	{
		print join(',',@$testarr),":\n";
		my ($count,$sum,$sumsqr) = count_sum_sqr(@$testarr);
		print "count: $count  sum: $sum  sumsqr: $sumsqr ";
		print "mean " . ($sum/$count) ."  variance: " .
				variance($count,$sum,$sumsqr);
		print "\n";
	}
}

1;
