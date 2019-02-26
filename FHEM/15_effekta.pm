##############################################
# $Id: 15_effekta.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use v5.10;


my %requests = (
	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
	'QMOD' => "514d4f4449c10d" ## Device Mode inquiry
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
	);

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
  $hash->{NotifyFn}    = "effekta_Notify";
  $hash->{ReadFn}    = "effekta_Read";
  $hash->{ReadyFn}    = "effekta_Ready";
  $hash->{AttrList}  = "interval Anschluss ".
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
 
  $hash->{NAME} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
  $hash->{NOTIFYDEV} 	= "global";
  $hash->{INTERVAL} 	= 120 ;
  $hash->{INTERVAL} = AttrVal($name,"interval",120);
  $hash->{actionQueue} 	= [];	
#close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "effekta_DoInit" );
  Log3($name, 1, "effekta DevIO_OpenDev_Define" . __LINE__); 
#	InternalTimer(gettimeofday()+30,"effekta_nb_doInternalUpdate",$hash);
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
	$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
}
###################################
sub effekta_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};

Log3 $name, 4, "effekta ($name) - effekta_Notify  Line: " . __LINE__;	
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "effekta ($name) - effekta_Notify - not disabled  Line: " . __LINE__;	
return if (!$events);
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "effekta ($name) - effekta_Notify change Interval to AttrVal($name,interval,120) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",120);
}


Log3 $name, 4, "effekta ($name) - effekta_Notify got events @{$events} Line: " . __LINE__;	
effekta_TimerGetData($hash) if( grep /^INITIALIZED$/,@{$events}
				or grep /^DELETEATTR.$name.disable$/,@{$events}
				or grep /^DELETEATTR.$name.interval$/,@{$events}
				or (grep /^DEFINED.$name$/,@{$events} and $init_done) );


return;

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
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg stopRequest"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,1, "effekta argument $a[1] _Line: __LINE__" . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			DevIo_CloseDev($hash);
			Log3($name,1, "effekta Device closed" . __LINE__);
		} 
		Log3($name,1, "effekta_Set  Device is closed, trying to open" . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "effekta_Set  Device is closed, opening failed, retrying" . __LINE__);
			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
			sleep 1;
		}
		return "device opened $ret";
	}
	
}
#####################################
sub effekta_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of updateNb updateBlk"; 
	Log3($name,1, "effekta argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}
}

############################################
sub effekta_TimerGetData($){
my $hash = shift;
my $name = $hash->{NAME};
Log3 $name, 4, "effekta ($name) - TimerGetData Line: " . __LINE__;	
Log3 $name, 4, "effekta ($name) - action Queue 1: $hash->{actionQueue} Line: " . __LINE__;	
Log3 $name, 4, "effekta ($name) - TimerGetData @{$hash->{actionQueue}}  Line: " . __LINE__;	
if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ){
	Log3 $name, 4, "effekta ($name) - is defined and empty Line: " . __LINE__;	
	if( not IsDisabled($name) ) {
		Log3 $name, 4, "effekta ($name) - is not disabled Line: " . __LINE__;	
		while( my ($key,$value) = each %requests ){
		Log3 $name, 4, "effekta ($name) - actionQueue filli: $key  Line: " . __LINE__;	
		Log3 $name, 4, "effekta ($name) - actionQueue filli: $value  Line: " . __LINE__;	
			unshift( @{$hash->{actionQueue}}, $value );
			unshift( @{$hash->{actionQueue}}, $key );
			#My $hash = (
			#	foo => [1,2,3,4,5],
			#	bar => [a,b,c,d,e]
			#);
			#@{$hash{foo}} would be (1,2,3,4,5)
		}
		Log3 $name, 4, "effekta ($name) - actionQueue filled: @{$hash->{actionQueue}}  Line: " . __LINE__;	
		Log3 $name, 4, "effekta ($name) - call effekta_sendRequests Line: " . __LINE__;	
		effekta_sendRequests($hash);
	}else{
		readingsSingleUpdate($hash,'state','disabled',1);
	}
	InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'effekta_TimerGetData', $hash);
Log3 $name, 4, "effekta ($name) - call InternalTimer effekta_TimerGetData Line: " . __LINE__;	
}
}
####################################
sub effekta_sendRequests($){
my ($hash) = @_;
my $name = $hash->{NAME};

if($hash->{helper}{key} eq ""){
	$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
	$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
}
Log3 $name, 4, "effekta ($name) - effekta_sendRequests value: $hash->{helper}{value}  Line: " . __LINE__;	
Log3 $name, 4, "effekta ($name) - effekta_sendRequests key: $hash->{helper}{key}  Line: " . __LINE__;	
$hash->{helper}{recv} = "";
DevIo_SimpleWrite($hash,$hash->{helper}{value},1);
}
#####################################
sub effekta_Read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	Log3($name,4, "effekta jetzt wird gelesen _Line:" . __LINE__);
	# read from serial device
	#
	
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "effekta buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "effekta Fehler beim lesen _Line:" . __LINE__);
		return "error" ;
	}
 	# es geht los mit 0x28 und hört auf mit 0x0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,5, "effekta helper: $hash->{helper}{recv}"); 
	my $hex_before = unpack "H*", $hash->{helper}{recv};
	Log3($name,5, "effekta hex_before: $hex_before");
	## now we can modify the hex string ... 
	if($hex_before =~ /28(.*)....0d/){
	Log3($name,5, "effekta hex without start and CRC: $1");

		my @h1 = ($1 =~ /(..)/g);
		my @ascii_ary = map { pack ("H2", $_) } @h1;
		my $asciistring;
	foreach my $part (@ascii_ary){
		$asciistring .= $part;
		##Log3($name,5, "effekta hex_re: $part");
	}
##	if ($hash->{helper}{recv} =~ /\((.*)\r/) {
##		my $hexstring = unpack "H*", $1;
##		Log3($name,5, "effekta hex_after: $hexstring");
##		my $asciistring = $1;
		Log3($name,5, "effekta ascii: $asciistring");
		my @splits = split(" ",$asciistring);
		Log3($name,5, "effekta splits: @splits");
		effekta_analyze_answer($hash, @splits);
	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) != 0 ){
		Log3 $name, 4, "effekta ($name) - effekta_ReadFn Noch nicht alle Abfragen gesendet, rufe sendRequests wieder auf  Line: " . __LINE__;	
		effekta_sendRequests($hash);
	}
	}
 
	return;
}
##########################################################################################
sub effekta_analyze_answer($@){

	my ($hash,@values) = @_;
	my $name = $hash->{NAME};
	my $cmd = $hash->{helper}{key};
	my $success = "failed";
	Log3($name,1, "effekta cmd: $cmd _Line:" . __LINE__);

		Log3($name,1, "effekta analysiere ueberhaupt mal irgendwas _Line:" . __LINE__);

	if($values[0] =~ /NAK/){
		Log3($name,1, "effekta analysiere $values[0] _Line:" . __LINE__);
		Log3($name,1, "effekta Keine Gültige Antwort. Abbruch. _Line:" . __LINE__);
		##effekta_blck_doInternalUpdate($hash); 
		return;
	}

if($cmd eq "QPIRI") {

		Log3($name,1, "effekta cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"Grid_rating_Voltage",$values[0],1);
						readingsBulkUpdate($hash,"Grid_rating_Current",$values[1],1);
						readingsBulkUpdate($hash,"AC_output_rating_Voltage",$values[2],1);
						readingsBulkUpdate($hash,"AC_output_rating_Frequency",$values[3],1);
						readingsBulkUpdate($hash,"AC_output_rating_current",$values[4],1);
						readingsBulkUpdate($hash,"AC_output_rating_appearent_Power",$values[5],1);
						readingsBulkUpdate($hash,"AC_output_rating_active_Power",$values[6],1);
						readingsBulkUpdate($hash,"Battery_rating_voltage",$values[7],1);
						readingsBulkUpdate($hash,"Battery_re-charge_voltage",$values[8],1);
						readingsBulkUpdate($hash,"Battery_under_voltage",$values[9],1);
						readingsBulkUpdate($hash,"Battery_bulk_voltage",$values[10],1);
						readingsBulkUpdate($hash,"Battery_float_voltage",$values[11],1);
			
						## 0 = AGM, 1 = Flooded, 2 = User
						readingsBulkUpdate($hash,"Battery_type",$values[12],1);
						readingsBulkUpdate($hash,"Current_max_AC_charging_current",$values[13],1);
						readingsBulkUpdate($hash,"Current_max_charging_current",$values[14],1);
						
						# 0 = Appliance, 1 = UPS
						readingsBulkUpdate($hash,"Input_voltage_range",$values[15],1);
						#0 = Utility first, 1 = Solar first, 2 = SBU
						readingsBulkUpdate($hash,"Output_Source_priority",$values[16],1);
						#0 = Utility first, 1 = Solar first, 2 = Solar + Utility, 3: = only solar charging permitted
						readingsBulkUpdate($hash,"Charger_source_priority",$values[17],1);
						readingsBulkUpdate($hash,"Parallel_max_num",$values[18],1);
						#00 Grid tie, 01 off grid 10 Hybrid
						readingsBulkUpdate($hash,"Machine_type",$values[19],1);
						# 0 transformerless, 1 transformer
						readingsBulkUpdate($hash,"Topology",$values[20],1);
						# 0 single machine 01 parallel output 02 phase 1 of 3 03 phase 2 of 3 04 phase 3 of 3
						readingsBulkUpdate($hash,"Output_Mode",$values[21],1);
						readingsBulkUpdate($hash,"Battery_re-discharge_voltage",$values[22],1);
						# 0 = as long as one unit has PV connected, parallel system will consider PV OK
						# 1 = inly all of inverters ghave connected pv, parallel system will consider PV OK
						readingsBulkUpdate($hash,"PV_OK_condition_for_parallel",$values[23],1);
						# 0 = PV ionput max current wl be the max charged current
						# 1 = PV input max power will be the sum of the max charged power and loads power.
						readingsBulkUpdate($hash,"PV_power_balance",$values[24],1);
					readingsEndUpdate($hash,1);
		Log3($name,1, "effekta $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd eq "QMOD") {
	Log3($name,1, "effekta cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,1, "effekta uebergeben: $a _Line:" . __LINE__);
	my $r;
	given($a) {
		when($a eq "P") {$r = "Power on Mode";}
		when($a eq "S") {$r = "Standby Mode";}
		when($a eq "L") {$r = "Line Mode";}
		when($a eq "B") {$r = "Battery Mode";}
		when($a eq "F") {$r = "Fault Mode";}
		when($a eq "H") {$r = "Power saving Mode";}
	}
	Log3($name,1, "effekta analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,1, "effekta $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIGS") {
	Log3($name,1, "effekta cmd: analysiere QPIGS _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Grid_voltage",$values[0],1);
		readingsBulkUpdate($hash,"Grid_frequency",$values[1],1);
		readingsBulkUpdate($hash,"AC_output_voltage",$values[2],1);
		readingsBulkUpdate($hash,"AC_output_frequency",$values[3],1);
		readingsBulkUpdate($hash,"AC_output_appearent_power",$values[4],1);
		readingsBulkUpdate($hash,"AC_output_active_power",$values[5],1);
		readingsBulkUpdate($hash,"Output_load_percent",$values[6],1);
		readingsBulkUpdate($hash,"BUS_voltage",$values[7],1);
		readingsBulkUpdate($hash,"Battery_actual_voltage",$values[8],1);
		readingsBulkUpdate($hash,"Battery_charging_current",$values[9],1);
		readingsBulkUpdate($hash,"Battery_capacity_percent",$values[10],1);
		readingsBulkUpdate($hash,"Inverter_heat_sink_temperature",$values[11],1);
		readingsBulkUpdate($hash,"PV_Input_current_for_battery",$values[12],1);
		readingsBulkUpdate($hash,"PV_Input_voltage",$values[13],1);
		readingsBulkUpdate($hash,"Battery_voltage_from_SCC",$values[14],1);
		readingsBulkUpdate($hash,"Battery_discharge_current",$values[15],1);
		readingsBulkUpdate($hash,"Device_Status",$values[16],1);
	readingsEndUpdate($hash,1);
	Log3($name,1, "effekta $cmd successful _Line:" . __LINE__);
	$success="success";
	}	

Log3($name,1, "effekta receive ready. success: $success _Line:" . __LINE__);
if($success eq "success"){
	$hash->{helper}{key} = "";
	$hash->{helper}{value} = "";
}


}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
