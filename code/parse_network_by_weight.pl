#####################################
# Script: 	parse_network_by_weight.pl
# Author: 	Kate Cooper
# Created: 	June 26, 2019
# Last edited:	June 26, 2019
# Input:	ingredients.network.sif file from ingredient network R code
# Output: 	an ingredient nodes and edges list (in .sif format) with 
#		edge weights of ew threshold or higher
# Methods:	The purpose of this script is to create a nodes and edges file 
#		(a co-occurring ingredient network)
#		for the file generated from the Open Food Database
# Link:		Placeholder for code and raw data on Github
#####################################
#!/usr/bin/perl

use strict;
use warnings;

#
#Placeholder for the input file to be read from command line
#
my $inputfile = "";
my $netfile = "";
my $ew = -1;

#
#Read in arguments from the command line; if no args, die. 
#
if($#ARGV+1 != 3){
	die "\nERROR! Check command-line arguments.\n
	Usage: perl parse_network_by_weight.pl netfile.sif parsed_netfile.sif ew_threshold \n
	netfile.sif		= the name of the file you want the food read from 
	parsed_netfile.sif	= the name of the file you want the food network written to
	ew_threshold		= the edge weight threshold (edges below this weight will be deleted) 
	\n\n"
}else{
	$inputfile = $ARGV[0];
	$netfile = $ARGV[1];
	$ew = $ARGV[2];
	print "Received the following file as input:		$inputfile\n";
	print "Received the following file for network output:	$netfile\n";
}


#
#Open the file and read it in
#
print("Now reading edges....\n");
my $input = open(IN,$inputfile);
my @edges = <IN>;
close(IN)
	or warn "Error closing input file!\n";
print("Completed reading edges.\n");

#
# Iterate through each edge
# and check what the weight is
# If the weight is less than the ew threshold, do not print it out
#
my $removed_count = 0;
print("Now checking edges....\n");
open(OUT,">$netfile");
foreach(@edges){
	# Get the current line
	my $currLine = $_;
	
	#Make sure the line fits the sif format
	if($currLine =~ m/\S+\s+\S+\s+(\d+).*\n/gi){
		my $cweight = $1;
		if($cweight >= $ew){
			print OUT $currLine;
		}else{
			$removed_count++;
		}
	}else{
		$removed_count++;
	}
}
close OUT;

print "Removed a total of $removed_count lines from the input network.\n";
