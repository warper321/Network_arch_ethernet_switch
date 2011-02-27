#!/usr/local/bin/perl 

#Learning ethenet switch program control

use strict;
use Getopt::Std;

# declare the perl command line flags/options we want to allow
my %options=();
getopts("drcl:", \%options);

if ($options{d})
{
	display_forward();
}

elsif ($options{r})
{
	display_registers();
}

elsif ($options{c})
{
	clear_forward();
}

elsif ($options{l})
{
	load_forward(@ARGV);
}

else 
{
}

sub display_forward
{
	$table = `regread x y `;
	print $table;
}

sub display_registers
{
	$register = `regread x y`;
	print $register;
}

sub clear_forward
{
	$forward = `regwrite x y`;
	print "forwarding tables cleard\n";
}

sub load_forward
{
	
}
