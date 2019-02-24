##############################################
# $Id: 15_effekta.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use v5.10;
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
sub effekta_Ready($)
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
sub effekta_Undef($$)
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
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg interval"; 
	my $ret;
	Log3($name,1, "effekta argument $a[1]");
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen");
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			DevIo_CloseDev($hash);
			Log3($name,1, "effekta Device closed");
		} 
		Log3($name,1, "effekta_Set  Device is closed, trying to open");
		$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "effekta_Set  Device is closed, opening failed, retrying");
			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
			sleep 1;
		}
		return "device opened $ret";
	} elsif ($a[1] eq "interval")
	{
		Log3($name,3, "INterval changed to $a[2]");
		#	readingsSingleUpdate($hash,"Interval",$a[2],1);
		$hash->{INTERVAL} = $a[2];
	}
	
}
#####################################
sub effekta_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of update:QMOD,QPIRI,QPIGS"; 
	Log3($name,1, "effekta argument $a[1]");
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen");
	return $usage;
	}
	if($a[1] eq "update") { effekta_updateReadings($hash, $a[2]); }
}
#####################################
sub effekta_nb_doInternalUpdate($){
	my ($hash) = @_;
	$hash->{helper}{RUNNING_PID} = BlockingCall("blck_doInternalUpdate",$hash) unless(exists($hash->{helper}{RUNNING_PID}));
	InternalTimer(gettimeofday()+$hash->{INTERVAL},"effekta_nb_doInternalUpdate",$hash);
}
#*********************************************************************
sub effekta_blck_doInternalUpdate($){
my ($hash) = @_;
my $name = $hash->{NAME};
my %requests = (
	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
	'QMOD' => "514d4f4449c10d" ## Device Mode inquiry
	);
	
#	'QPIWS' => "5150495753b4da0d", ##Device Warning Status Inquiry
#	'QPGS0' => "51504753303fda0d", ## Parallel Information Inquiry
#	'QSID' => "51534944bb050d", ## nicht dokumentiert
#	'QBEQI' => "51424851492ea90d", 
#	'QVFW' => "5156465732c3f50d",
#	'QDI' => "514449711b0d",
#	'QFLAG' => "51464c414798740d",
#	'QBEGI' => "51424551492ea90d", 
#	'QMUCHGCR' => "514d55434847435226340d",
#	'QMCHGC' => "514d4348474352d8550d"
#	);

		Log3($name,1, "effekta automatisches Update");
		foreach (keys %requests) {
			$hash->{helper}{recv_finished} = 0;
			Log3($name,1, "effekta: loope durch die Befehle %requests{$_}");
			Log3($name,1, "effekta recv:$hash->{helper}{recv} _ ist leer, führe write aus.");
			$hash->{helper}{lastreq} = $_;
			DevIo_SimpleWrite($hash,%requests{$_},1);
			until($hash->{helper}{recv_finished}){
				Log3($name,1, "effekta recv:$hash->{helper}{recv_finished} _... warte noch eine sekunde");
				sleep 1;
			}	
		
		}



return; 
}

#**********************************************************************
sub updateDone($){
my ($hash) = @_;
my $name = $hash->{NAME};

	Log3($name,1, "effekta updateDone(); Lösche hash helper runningpid");
	delete($hash->{helper}{RUNNING_PID});

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
		my $a = $hash->{helper}{recv};
		my $asciistring = substr($a,1,length($a)-8);
		Log3($name,1, "effekta ascii: $asciistring");
		my @splits = split(" ",$asciistring);
		Log3($name,1, "effekta splits: $splits[0]");
	effekta_analyze_answer($hash,$hash->{helper}{lastreq}, @splits);
		$hash->{helper}{recv} = "";
	} else {
	$begin = "";
	$end="";
	}	




	return "";
	
	
}


sub effekta_analyze_answer($$@){

	my ($hash,$cmd,@values) = @_;
	my $name = $hash->{NAME};
		Log3($name,1, "effekta cmd: $cmd");

		Log3($name,1, "effekta analysiere ueberhaupt mal irgendwas");
given($cmd){
	when($cmd eq "QPIRI") {

		Log3($name,1, "effekta cmd: analysiere qpiri");
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"Grid rating Voltage",$values[0]);
						readingsBulkUpdate($hash,"Grid rating Current",$values[1]);
						readingsBulkUpdate($hash,"AC output rating Voltage",$values[2]);
						readingsBulkUpdate($hash,"AC output rating Frequency",$values[3]);
						readingsBulkUpdate($hash,"AC output rating current",$values[4]);
						readingsBulkUpdate($hash,"AC output rating appearent Power",$values[5]);
						readingsBulkUpdate($hash,"AC output rating active Power",$values[6]);
						readingsBulkUpdate($hash,"Battery rating voltage",$values[7]);
						readingsBulkUpdate($hash,"Battery re-charge voltage",$values[8]);
						readingsBulkUpdate($hash,"Battery under voltage",$values[9]);
						readingsBulkUpdate($hash,"Battery bulk voltage",$values[10]);
						readingsBulkUpdate($hash,"Battery float voltage",$values[11]);
			
						## 0 = AGM, 1 = Flooded, 2 = User
						readingsBulkUpdate($hash,"Battery type",$values[12]);
						readingsBulkUpdate($hash,"Current max AC charging current",$values[13]);
						readingsBulkUpdate($hash,"Current max charging current",$values[14]);
						
						# 0 = Appliance, 1 = UPS
						readingsBulkUpdate($hash,"Input voltage range",$values[15]);
						#0 = Utility first, 1 = Solar first, 2 = SBU
						readingsBulkUpdate($hash,"Output Source priority",$values[16]);
						#0 = Utility first, 1 = Solar first, 2 = Solar + Utility, 3: = only solar charging permitted
						readingsBulkUpdate($hash,"Charger source priority",$values[17]);
						readingsBulkUpdate($hash,"Parallel max num",$values[18]);
						#00 Grid tie, 01 off grid 10 Hybrid
						readingsBulkUpdate($hash,"Machine type",$values[19]);
						# 0 transformerless, 1 transformer
						readingsBulkUpdate($hash,"Topology",$values[20]);
						# 0 single machine 01 parallel output 02 phase 1 of 3 03 phase 2 of 3 04 phase 3 of 3
						readingsBulkUpdate($hash,"Output Mode",$values[21]);
						readingsBulkUpdate($hash,"Battery re-discharge voltage",$values[22]);
						# 0 = as long as one unit has PV connected, parallel system will consider PV OK
						# 1 = inly all of inverters ghave connected pv, parallel system will consider PV OK
						readingsBulkUpdate($hash,"PV OK condition for parallel",$values[23]);
						# 0 = PV ionput max current wl be the max charged current
						# 1 = PV input max power will be the sum of the max charged power and loads power.
						readingsBulkUpdate($hash,"PV power balance",$values[24]);
					readingsEndUpdate($hash,1);
				}
	when($cmd eq "QMOD") {
		Log3($name,1, "effekta cmd: analysiere QMOD");
					my $a = $values[0];
					Log3($name,1, "effekta uebergeben: $a");
					my $r;
					given($a) {
							when($a eq "P") {$r = "Power on Mode";}
							when($a eq "S") {$r = "Standby Mode";}
							when($a eq "L") {$r = "Line Mode";}
							when($a eq "B") {$r = "Battery Mode";}
							when($a eq "F") {$r = "Fault Mode";}
							when($a eq "H") {$r = "Power saving Mode";}
					}
					Log3($name,1, "effekta analyse: QMOD. Entscheidung für $r");
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"Device Mode",$r,1);
					readingsEndUpdate($hash,1);
					
	}	
	when($cmd eq "QPIGS") {
	
		Log3($name,1, "effekta cmd: analysiere QPIGS");
					readingsBeginUpdate($hash);
					
						readingsBulkUpdate($hash,"Grid voltage",$values[0],1);
						readingsBulkUpdate($hash,"Grid frequency",$values[1],1);
						readingsBulkUpdate($hash,"AC output voltage",$values[2],1);
						readingsBulkUpdate($hash,"AC output frequency",$values[3],1);
						readingsBulkUpdate($hash,"AC output appearent power",$values[4],1);
						readingsBulkUpdate($hash,"AC output active power",$values[5],1);
						readingsBulkUpdate($hash,"Output load percent",$values[6],1);
						readingsBulkUpdate($hash,"BUS voltage",$values[7],1);
						readingsBulkUpdate($hash,"Battery voltage",$values[8],1);
						readingsBulkUpdate($hash,"Battery charging current",$values[9],1);
						readingsBulkUpdate($hash,"Battery capacity",$values[10],1);
						readingsBulkUpdate($hash,"Inverter heat sink temperature",$values[11],1);
						readingsBulkUpdate($hash,"PV Input current for battery",$values[12],1);
						readingsBulkUpdate($hash,"PV Input voltage 1",$values[13],1);
						readingsBulkUpdate($hash,"Battery voltage from SCC",$values[14],1);
						readingsBulkUpdate($hash,"Battery discharge current",$values[15],1);
						# 
						readingsBulkUpdate($hash,"Device Status",$values[16]);
					readingsEndUpdate($hash,1);
	}	
}
}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
