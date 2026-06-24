#!/usr/bin/perl
use strict;

my $sum;
my $cnt;
my $all; # yes, I know $. :)

while(<>)
  {
  $all++;
  next unless /\d+/;
  $sum += $_;
  $cnt++;
  }

my $avg = $sum / $cnt;
print "$avg   $sum   $cnt   $all\n";
