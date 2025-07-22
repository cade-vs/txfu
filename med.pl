#!/usr/bin/perl
use strict;

my @its;
my $cnt;
my $all; # yes, I know $. :)

while(<>)
  {
  $all++;
  next unless /\d+/;
  chomp;
  push @its, $_;
  $cnt++;
  }

@its = sort { $a <=> $b } @its;
my $its = @its;
my $med = $its[$its/2];
my $min = $its[0];
my $max = $its[-1];
print "$med   $min   $max   $its   $all\n";
