#!/usr/bin/perl
use strict;

$| = 1;

#-----------------------------------------------------------------------------

my $DEBUG    = $ENV{ 'DEBUG' } || 0;

our $HELP = <<END;
usage: $0 <options> <input files or nothing to read from stdin>
options:
    -f fields -- fields to print: -f 1,5,7-11,2
    -0        -- use 0-based indexes, default is to start from 1 as cut(1)
    -k        -- skip blank (whitespace only) input lines
    -k -k     -- if used twice, skip blank (whitespace only) output lines
    -d regexp -- regexp delimiter, any whitespace by default
    -D delim  -- delimiter, fixed string
    -j jstr   -- join string to glue result parts, TAB by default
    -J        -- use default (debug) join string ' <|> '
    -d        -- debug mode
    -o        -- do nothing, print unmodified input
    -s fields -- sort output by listed fields in the order given
    -r        -- reverse sort
    -n        -- numeric sort
    -a        -- sample first few lines to display indexes
    -e N      -- print first N lines only (head)
    -t N      -- print last N lines only (tail)
    -h        -- help, prints this screen
    --        -- end of options
notes:
  * fields indexes start from 1 unless -0 is given
  * -s uses memory to store entire input stream data (-t does also, see below)
  * -s can specify different fields than -f
  * -d can be used multiple times to increase debug level
  * 'fields' can be comma separated list of field numbers and ranges:
             5,1-3,9  -- will produce fields 5,1,2,3,9
             10,-4    -- fields 10,0,1,2,3,4
             15-,4    all fields from 15 to the end and then field 4
  * fields ranges can use either dash (-) or multi dots (..), (...), etc. ;)
  * -a will override all of the rest options, idea is to check indexes 
             without losing current command line
  * -e and -t can be used simultaneously but they will limit head and tail 
             parts from the same stram, not the head part of the tail or the
             tail part of the head...
  * -e is cheap and fast
  * -t is uses memory (like -s) and is slow(er)
  * -e can modify -a output but needs to be after -a
  * -k -k has no effect on -a when lines contain only delimiters
  * -e and -t will not see blank lines if -k or -k -k are in use
END

my @opt_fields;
my $opt_regexp;
my $opt_nop;
my $opt_join = "\t";
my $opt_base = 1;
my $opt_sample;
my $opt_head;
my $opt_tail;
my $opt_skip;

my @opt_sort_fields;
my $opt_sort_reverse;
my $opt_sort_numeric;

our @args;
while( @ARGV )
  {
  $_ = shift;
  if( /^--+$/io )
    {
    push @args, @ARGV;
    last;
    }
  if( /-f/ )
    {
    @opt_fields = shift;
    next;
    }
  if( /-0/ )
    {
    $opt_base = 0;
    next;
    }
  if( /-d/ )
    {
    my $pat = shift();
    $opt_regexp = qr/$pat/;
    next;
    }
  if( /-D/ )
    {
    my $pat = shift();
    $pat =~ s/([^0-9_a-zA-Z])/\\$1/g;
    $opt_regexp = qr/$pat/;
    next;
    }
  if( /-n/ )
    {
    $opt_nop++;
    next;
    }
  if( /-j/ )
    {
    $opt_join = shift();
    next;
    }
  if( /-J/ )
    {
    $opt_join = ' <|> ';
    next;
    }
  if( /-a/ )
    {
    $opt_sample++;
    $opt_head = 8;
    next;
    }
  if( /-s/ )
    {
    @opt_sort_fields = shift;
    next;
    }
  if( /-r/ )
    {
    $opt_sort_reverse++;
    next;
    }
  if( /-n/ )
    {
    $opt_sort_numeric++;
    next;
    }
  if( /-e/ )
    {
    $opt_head = shift();
    next;
    }
  if( /-t/ )
    {
    $opt_tail = shift();
    next;
    }
  if( /-k/ )
    {
    $opt_skip++;
    next;
    }
  if( /^-d/ )
    {
    $DEBUG++;
    print "OPT: DEBUG\n";
    next;
    }
  if( /^(--?h(elp)?|help)$/io )
    {
    print $HELP;
    exit;
    }
  push @args, $_;
  }

die "$0: missing fields list, use -f\n" unless @opt_fields;

@opt_fields      = parse_fields( shift( @opt_fields      ) );
@opt_sort_fields = parse_fields( shift( @opt_sort_fields ) );

if( $opt_base ) 
  { 
  $_-- for @opt_fields; 
  $_-- for @opt_sort_fields; 
  }

#-----------------------------------------------------------------------------

$opt_regexp ||= qr/\s+/;

flat_sample(), exit 0 if   $opt_sample;
flat_cut(),    exit 0 if ! @opt_sort_fields;
sort_cut(),    exit 0 if   @opt_sort_fields or $opt_tail;

sub flat_sample
{
  my @res;
  my $c;
  my $x;
  while(<>)
    {
    chomp;
    next if $opt_skip > 0 and ! /\S/;

    my @row = split /$opt_regexp/, $_;
    push @res, \@row;
    my $n = @row;
    $x = $n if $n > $x;
    last if ++$c >= $opt_head;
    }
  
  unshift @res, [ $opt_base ? 1 .. $x : 0 .. $x - 1 ];

  print format_ascii_table( \@res );
  return 1;
}

sub flat_cut
{
  while(<>)
    {
    next if $opt_skip > 0 and ! /\S/;

    print(), next if $opt_nop;

    my @row = (split /$opt_regexp/, $_)[@opt_fields];

    # check if output has non-whitespace text
    my $skip_blank = join '', @row;
    next if $opt_skip > 1 and $skip_blank !~ /\S/;

    print join $opt_join, @row;
    print "\n";
    }
  return 1;
}

sub sort_cut
{
  my @data;
  while(<>)
    {
    next if $opt_skip > 0 and ! /\S/;

    my @row = split /$opt_regexp/, $_;
    push @data, \@row, next if $opt_nop;

    my @map;
    $map[$_]++ for ( @opt_fields, @opt_sort_fields ); 
    for( my $c = 0; $c < @row; $c++ )
      {
      # keeps only data needed for output and for sorting
      $row[ $c ] = undef unless $map[ $c ];
      }

    # check if output has non-whitespace text
    my $skip_blank = join '', @row[@opt_fields];
    next if $opt_skip > 1 and $skip_blank !~ /\S/;

    push @data, \@row;
    }

  if( ( $opt_head or $opt_tail ) and @data > $opt_head + $opt_tail )
    {
    @data = ( @data[ 0 .. $opt_head - 1 ], @data[ - $opt_tail .. -1 ] );
    }

  return unless @opt_sort_fields;

  for( sort { __cmp( $a, $b ) } @data )
    {
    print join $opt_join, (@$_)[@opt_fields];
    print "\n";
    }

  return 1;
}

sub __cmp
{
  for( @opt_sort_fields )
    {
    my $r = $opt_sort_numeric ? $_[0]->[$_] <=> $_[1]->[$_] : $_[0]->[$_] cmp $_[1]->[$_];
    next unless $r;
    return $opt_sort_reverse ? - $r : $r;
    }
  return 0;
}

sub parse_fields
{
  my @res;
  for( split /\s*,\s*/, shift )
    {
    push @res, 0+$1     if /^\s*(\d+)\s*$/;
    push @res, $1||$3 ? ($1||$opt_base)..($3||1024) : () if /^\s*(\d+)?(-|\.\.+)(\d+)?\s*$/;
    }
  return @res;  
}

#-----------------------------------------------------------------------------

# the following taken as-is from Data::Tools to reduce dependency

sub str_pad
{
  my $str = shift;
  my $len = shift;
  my $pad = shift;
  $pad = ' ' unless defined $pad;

  $str = reverse $str if $len < 0;
  $str = substr( $str . ($pad x abs($len)), 0, abs($len) );
  $str = reverse $str if $len < 0;

  return $str;
}

sub format_ascii_table
{
  my $data = shift;

  my @ws; # widths
  my $wt; # width total
  my $cs; # columns
  
  for my $row ( @$data )
    {
    my $c = 0;
    for my $d ( @$row )
      {
      my $l = length( $d );
      $ws[ $c ] = $l if $l > $ws[ $c ];
      $c++;
      }
    $cs = $c if $c > $cs;
    }
  
  $wt += $_ + 2 for @ws; # plus 2 for one char spacing around borders
  $wt += @ws + 1; # plus border chars

  my $sep = '+' . ( '-' x ( $wt - 2 ) ) . '+' . "\n";
  my $tx;
  
  my $r = 0;
  $tx .= $sep;
  for my $row ( @$data )
    {
    $tx .= '|';
    for my $c ( 0 .. $cs - 1 )
      {
      my $w = $ws[ $c ];
      $w = - $w if $row->[ $c ] =~ /^([\+\-])?[\d\.]+$/; # only plain number, no exp
      $tx .= ' ' . str_pad( $row->[ $c ], $w ) . ' |';
      }
    $tx .= "\n";
    $tx .= $sep if $r == 0;
    $r++;
    }
  $tx .= $sep;
  
  return $tx;
}

### EOF ######################################################################
