                                                                     
                                                                     
                                                                     
                                             
#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

require reg_defines_ethernet_switch;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

my $length = 100;
my $DA_sub1 = ':dd:dd:dd:dd:dd';
my $SA_sub1 = ':55:55:55:55:55';
my $DA_sub2 = ':55:55:55:55:55';
my $SA_sub2 = ':55:55:55:55:55';
my $DA_sub3 = ':ff:ff:ff:ff:ff';
my $SA_sub3 = ':55:55:55:55:55';
my $DA;
my $SA;
my $pkt;
my $pkt1;
my $pkt2;
my $pkt3;
my $in_port;
my $out_port;
my $i = 0;
my $temp;

# send and receive 3 pkts, one with and unknown destination, one with a know destination, and one broadcast
$delay = '@17us';
$length = 60;
  $temp = sprintf("%02x", 1);
  $DA = $temp . $DA_sub1;
  $SA = $temp . $SA_sub1;
  $in_port = 1;
#unknown destination packet
  $pkt1 = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt1);

  for($i=2; $i<5; $i++){
  	$out_port = $i;  
  	nf_expected_packet($out_port, $length, $pkt1);
}

  $DA = $temp . $DA_sub2;
  $SA = $temp . $SA_sub2;
#loop back packet
  $pkt2 = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt2);
  nf_expected_packet(1, $length, $pkt2);
  $DA = $temp . $DA_sub3;
  $SA = $temp . $SA_sub3;
#broadcast packet
  $pkt3 = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt3);

  for($i=2; $i<5; $i++){
  	$out_port = $i;  
  	nf_expected_packet($out_port, $length, $pkt3);
}

# check counter values
$delay='@120us';

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
