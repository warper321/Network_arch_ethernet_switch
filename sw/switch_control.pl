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
	print "Mike's ethernet learning switch high level software control script\n";
	print "only one flag at at time! declare flag with -<option> <arguements> \n";
	print "options:\n";
	print "d: display forwarding table\n";
	print "r: display switch registers\n";
	print "c: clear forwarding table\n";
	print "l: add custom forwarding table entries. use like such -l <MAC>:<port>\n";
}

sub display_forward
{
	my($table) = `regread x y `;
	print $table;
}

sub display_registers
{
	my($register) = `regread x y`;
	print $register;
}

sub clear_forward
{
	my($forward) = `regwrite x y`;
	print "forwarding tables cleared\n";
}

sub load_forward
{
	
}
