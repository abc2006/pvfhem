##############################################
# $Id: 15_effekta.pm 2016-01-14 09:25:24Z stephanaugustin $
package main;

use strict;
use warnings;

#####################################
sub
effekta_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "effekta_Define";
  $hash->{SetFn}     = "effekta_Set";
  $hash->{GetFn}     = "effekta_Get";
  $hash->{UndefFn}   = "effekta_Undef";
  $hash->{ReadFn}    = "effekta_Read";
  $hash->{ReadyFn}    = "effekta_Ready";
  $hash->{AttrList}  = "Anschluss ".
                        $readingFnAttributes;

}

#####################################
sub
effekta_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> effekta <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{name} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
	
#close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "effekta_DoInit" );
  Log3($name, 1, "effekta DevIO_OpenDev_Define $ret"); 
  return $ret;
}


sub
effekta_DoInit($)
{
 Log3 undef, 2, "DoInitfkt";
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub
effekta_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
#	if(DevIo_IsOpen($hash)){
#		Log3($name,1, "effekta_Ready Device is open");
#		return "device already open";
#	} else {
#		Log3($name,1, "effekta_Ready  Device is closed, trying to open");
	$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
#		while(!DevIo_IsOpen($hash)){
#			Log3($name,1, "effekta_Ready  Device is closed, opening failed, retrying");
#			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
#			sleep 1;
#		}
#		return "device automatically opened $ret";
#	}
}



#####################################
sub
effekta_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  RemoveInternalTimer($hash);
  return undef;
}
#####################################
sub effekta_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of qpi:noArg"; 
	my $ret;
	Log3($name,1, "effekta argument $a[1]");
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen");
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "effekta_Set Device is open");
			return "device already open";
		} else {
			Log3($name,1, "effekta_Set  Device is closed, trying to open");
			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
			while(!DevIo_IsOpen($hash)){
				Log3($name,1, "effekta_Set  Device is closed, opening failed, retrying");
				$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
				sleep 1;
			}
			return "device opened $ret";
		}
	}
}
#####################################
sub effekta_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of qpi:noArg update:all,qpiri,qmod"; 
	Log3($name,1, "effekta argument $a[1]");
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen");
	return $usage;
	}
	if($a[1] eq "update") { effekta_updateReadings($hash, $a[2]); }

#	if(DevIo_IsOpen($hash)){
#		Log3($name,1, "effekta Device is open");
#		my $get_cmd = lc($a[1]);
#		Log3($name,1, "effekta jetzt wird geschrieben");
#		DevIo_SimpleWrite($hash,"515049beac0d",1);
#		##my $data = DevIo_SimpleRead($hash);
#		return;
#	} else {
#		Log3($name,1, "effekta Device is closed ");
#		return;
#	}

#	effekta_updateReadings($hash);
}
#####################################
sub effekta_updateReadings($$){

	my ($hash, $order) = @_;
	my $name = $hash->{NAME};
	my $key;
	my $QPIRI = "5150495249f8540d"; ## Device rating information Inquiry
	my $QPIGS = "5150494753b7a90d"; ## Device general Status parameters inquiry
	my $QMOD = "514d4f4449c10d"; ## Device Mode inquiry
	my $QPIWS = "5150495753b4da0d"; ##Device Warning Status inquiry
	my $QPGS0 = "51504753303fda0d";## Parallel Information inquiry
	my $QSID = "51534944bb050d"; ## nicht dokumentiert
	my $QBEQI = "51424851492ea90d"; 
	my $QVFW = "5156465732c3f50d";
	my $QDI = "514449711b0d";
	my $QFLAG = "51464c414798740d";
	my $QBEGI = "51424551492ea90d"; 
	my $QMUCHGCR = "514d55434847435226340d"; ## Setting utility max charge current
	my $QMCHGC = "514d4348474352d8550d"; ## Setting Max Charge Current
	

my %requests = (
	'QPIRI' => "5150495249f8540d",
	'QPIGS' => "5150494753b7a90d",
	'QMOD' => "514d4f4449c10d",
	'QPIWS' => "5150495753b4da0d",
	'QPGS0' => "51504753303fda0d",
	'QSID' => "51534944bb050d",
	'QBEQI' => "51424851492ea90d", 
	'QVFW' => "5156465732c3f50d",
	'QDI' => "514449711b0d",
	'QFLAG' => "51464c414798740d",
	'QBEGI' => "51424551492ea90d", 
	'QMUCHGCR' => "514d55434847435226340d",
	'QMCHGC' => "514d4348474352d8550d"
	);

	if ($order eq "all"){	
		foreach $key (keys %requests)
		{	
		DevIo_SimpleWrite($hash,$requests{$key},1);
		my $buf = DevIo_SimpleRead($hash);
		readingsSingeUpdate($hash,$key,$buf);
		}
	}elsif ($order eq "qpiri"){
		$hash->{helper}{lastreq} = "qpiri";
		DevIo_SimpleWrite($hash,$QPIRI,1);
	}
}


#####################################
sub effekta_write($){

  my ($hash, $name) = @_;
  return;
}


#####################################
sub effekta_Read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3($name,1, "effekta jetzt wird gelesen");
	# read from serial device
	#
	
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,1, "effekta buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "effekta Fehler beim lesen");
		return "error" ;
	}
 	# es geht los mit einem ( und hört auf mit 0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,1, "effekta helper: $hash->{helper}{recv} "); 
	my $hexstring = unpack ('H*', $hash->{helper}{recv});

	Log3($name,1, "effekta hexstring: $hexstring");
	my $begin = substr($hexstring,0,2); ## die ersten zwei Zeichen
	Log3($name,1, "effekta begin: $begin");
	my $end = substr($hexstring,-2);# die letzten zwei Zeichen
	Log3($name,1, "effekta end: $end");
	if ($begin =~ "28" && $end eq "0d") {
		my $asciistring = $hash->{helper}{recv};
		my $value = substr($hexstring,2,length($hexstring)-6);
		my @var = split(/20/,$value);

		readingsSingleUpdate($hash,"hexstring",$value,1);
		my $result;
		foreach (@var)
		{
		my $zahl;
			if($_ =~ /2e/)
			{
				my ($vor,$nach) = split(/2e/,$_);
				$zahl = hex($vor) . "." . hex($nach);
			} else {
				$zahl = hex($_);
			}
		$result .= "_" . $zahl;
		}
		
		Log3($name,1, "effekta value: @var");
		##my $ascii = hex($value); geht nicht ...
		readingsSingleUpdate($hash,$hash->{helper}{lastreq},$result,1);
		$hash->{helper}{recv} = "";

	} else {
	$begin = "";
	$end="";
	}	
	return "";
	
	
}




1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
