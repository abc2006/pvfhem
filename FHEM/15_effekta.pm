##############################################
# $Id: 15_effekta.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use Digest::CRC qw(crc);

my %requests = (
	'QPI' => "515049beac0d", ##  Device Protocol ID Inquiry
##	'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
	'QVFW' => "5156465762990d", ## Main CPU Firmware version Inqiry
	'QVFW2' => "5156465732c3f50d", ## Another CPU Firmware version Inqiry
	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
	'QFLAG' => "51464c414798740d", ##Device Flag status Inquiry
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
	'QPIWS' => "5150495753b4da0d", ##Device Warning Status Inquiry
#	'QDI' => "514449711b0d", ## Default Setting Value Information - default settings - needed to restore defaults, in the software
#	'QMCHGCR' => "514d4348474352d8550d", ## Enquiry selectable value about max charging current - needed for creating the dropdown in the software
#	'QMUCHGCR' => "514d55434847435226340d", ##Enquiry selectable value about max utility charging current - needed for creating the dropdown in the software
#	'QBOOT' => "51424f4f540a88", ## Enquiry DSP has bootstrap or not
#	'QOPM' => "514f504da5c50d", ## Enquiry output mode (For 4000/5000)
#	'QPGS0' => "51504753303fda0d", ## Parallel Information Inquiry. same values as in QPIGS
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'' => "", ## 
#	'QRST' => "5152535472bc0d", ## nicht dokumentiert, NAKss
#	'QMN' => "514d4ebb640d", ##nicht dokumentiert, NAKss 
	'QGMNI' => "51474d4e49290d", ##  nicht dokumentiert
	'QSID' => "51534944bb050d", ## nicht dokumentiert
#	'QBEQI' => "51424851492ea90d", ## nicht dokumentiert VERMUTUNG: Equalisation function - liefert keine Antwort
	'QBEGI' => "51424551492ea90d", ## nicht dokumentierti
	'QMOD' => "514d4f4449c10d" ## Device Mode inquiry
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
  $hash->{AttrList}  = "Anschluss unknown_as_reading:yes,no orders:multiple,QPI,QVFW,QVFW2,QPIRI,QFLAG,QPIGS,QPIWS,QGMNI,QSID,QBEGI,QMOD ".
                        $readingFnAttributes;

  $hash->{helper}{value} = "";
  $hash->{helper}{key} = "";
  $hash->{helper}{retrycount} = 0;
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
  $hash->{INTERVAL} = AttrVal($name,"interval",60);
  $hash->{actionQueue} 	= [];	
#close connection if maybe open (on definition modify)
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "effekta_DoInit" );
  Log3($name, 1, "effekta DevIO_OpenDev_Define" . __LINE__); 
  return $ret;
}


sub
effekta_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
 effekta_TimerGetData($hash);
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
	Log3 $name, 4, "effekta ($name) - effekta_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",60);
}

if( grep /^ATTR.$name.orders/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "effekta ($name) - effekta_Notify change orders to @{$events} _Line: " . __LINE__;	
}

Log3 $name, 4, "effekta ($name) - effekta_Notify got events @{$events} Line: " . __LINE__;	
effekta_TimerGetData($hash) if( grep /^INITIALIZED$/,@{$events}
				or grep /^CONNECTED$/,@{$events}
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
  RemoveInternalTimer("resend:$name");
  RemoveInternalTimer("next:$name");
  RemoveInternalTimer("first:$name");
  return undef;
}
#####################################
sub effekta_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "effekta argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "effekta argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "Device is open, closing ... Line: " . __LINE__);
			DevIo_CloseDev($hash);
			Log3($name,1, "effekta Device closed Line: " . __LINE__);
		} 
		Log3($name,1, "effekta_Set  Device is closed, trying to open Line: " . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "effekta_Set  Device is closed, opening failed, retrying" . __LINE__);
			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
			sleep 1;
		}
		return "device opened";
	} elsif ($a[1] eq "reset"){
	$hash->{helper}{value} = "";
	$hash->{helper}{key} = "";
	@{$hash->{actionQueue}} = ();
	Log3($name,1, "effekta_Set actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__);
	effekta_TimerGetData($hash);
	}
	
}
#####################################
sub effekta_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of calcHex"; 
	Log3($name,5, "effekta argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "effekta argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}
#	my $value="QPI";
#	my $hex = unpack("H*", $value);
#my @s=( { 's'=>"An Arbitrary String", 'crc16'=>"DDFC", 'crc32'=>"90415518" },
#       { 's'=>"ZYXWVUTSRQPONMLKJIHGFEDBCA", 'crc16'=>"B199", 'crc32'=>"6632024D (not xored)" },
#   );
#	my @list = (crc16($hex) =~ /(..)/g);

#	my $finale =  map { pack ("H2", $_) } @list;

##	'QPI' => "515049beac0d", ##  Device Protocol ID Inquiry
#	my $input="QPI";
#	my $width=16;
#	my $init="0x0000";
#	my $xorout="0x0000";
#	my $refout="false";
#       	my $poly="0x1021";
#	my $refin="false";
#	my $cont=1;
	#check=0x31c3 
	#residue=0x0000 
	#name="CRC-16/XMODEM"
	
#my 	$crc = crc($input,$width,$init,$xorout,$refout,$poly,$refin,$cont);

#     	my $finale = crc("QPI",16,0x0000,i);
#	Log3($name,1, "effekta get $crc _Line: " . __LINE__);



}


sub effekta_Watchdog{
my ($calltype,$name) = split(':',$_[0]);
my $hash = $defs{$name};
#reset everything

	$hash->{helper}{value} = "";
	$hash->{helper}{key} = "";
	@{$hash->{actionQueue}} = ();
	Log3($name,1, "effekta_Watchdog something failed. _Line:" . __LINE__);
	effekta_TimerGetData($hash);
}


############################################
sub effekta_TimerGetData{
my $hash = shift;
my $name = $hash->{NAME};
Log3 $name, 4, "effekta ($name) _TimerGetData - action Queue 1: $hash->{actionQueue} Line: " . __LINE__;	
Log3 $name, 4, "effekta ($name) _TimerGetData - actionQueue_array  @{$hash->{actionQueue}}  Line: " . __LINE__;	
if(IsDisabled($name)){
readingsSingleUpdate($hash,'state','disabled',1);
Log3 $name, 4, "effekta ($name) _TimerGetData - is disabled. Line: " . __LINE__;	
return;
}
InternalTimer( gettimeofday()+30, 'effekta_Watchdog', "watchdog:$name");

#reload queue
if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ){
	Log3 $name, 4, "effekta ($name) _TimerGetData - is defined and empty. Line: " . __LINE__;	
	Log3 $name, 4, "effekta ($name) _TimerGetData - is not disabled. Line: " . __LINE__;	
	#######################################################
	my $string = AttrVal($name,"orders","");
	my %neuerhash;
	@neuerhash{ split /,/, $string } = ();

	foreach my $key (keys %neuerhash) {
		$neuerhash{$key} = $requests{$key};
		Log3 $name, 4, "effekta ($name) - effekta_Notify orders key:$key value:$neuerhash{$key} _Line: " . __LINE__;	
	}
	########################################################
	while( my ($key,$value) = each %neuerhash ){
		Log3 $name, 4, "effekta ($name) _TimerGetData - actionQueue fill: $key  Line: " . __LINE__;	
		Log3 $name, 4, "effekta ($name) _TimerGetData - actionQueue fill: $value  Line: " . __LINE__;	
		unshift( @{$hash->{actionQueue}}, $value );
			unshift( @{$hash->{actionQueue}}, $key );
			#My $hash = (
			#	foo => [1,2,3,4,5],
			#	bar => [a,b,c,d,e]
			#);
			#@{$hash{foo}} would be (1,2,3,4,5)
	}
	Log3 $name, 4, "effekta ($name) _TimerGetData - actionQueue filled: @{$hash->{actionQueue}}  Line: " . __LINE__;	
}

	$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
	$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
	if(!defined($hash->{helper}{key}) || $hash->{helper}{key} eq "" || !defined($hash->{helper}{value}) || $hash->{helper}{value} eq ""){
		Log3 $name, 4, "effekta ($name) - effekta_TimerGetData key: $hash->{helper}{key} or value: $hash->{helper}{value} not defined or empty, abortin  Line: " . __LINE__;
		return;	
	}
	Log3 $name, 4, "effekta ($name) - effekta_TimerGetData value: $hash->{helper}{value}  Line: " . __LINE__;	
	Log3 $name, 4, "effekta ($name) - effekta_TimerGetData key: $hash->{helper}{key}  Line: " . __LINE__;	
	$hash->{helper}{recv} = "";
	DevIo_SimpleWrite($hash,$hash->{helper}{value},1);
return;

}
#####################################
sub effekta_Read{
my ($hash) = @_;
my $name = $hash->{NAME};
$hash->{CONNECTION} = "established";
readingsSingleUpdate($hash, "_status","communication in progress",1);
Log3($name,4, "effekta_read jetzt wird gelesen _Line:" . __LINE__);
# read from serial device
#

my $buf =  DevIo_SimpleRead($hash);
Log3($name,5, "effekta_read buffer: $buf");
if (!defined($buf)  || $buf eq "")
{ 
	Log3($name,1, "effekta_read Fehler beim lesen _Line:" . __LINE__);
	$hash->{CONNECTION} = "failed";
	return "error" ;
}
	# es geht los mit 0x28 und hört auf mit 0x0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,5, "effekta_read helper: $hash->{helper}{recv}"); 
	my $hex_before = unpack "H*", $hash->{helper}{recv};
	Log3($name,5, "effekta_read hex_before: $hex_before");
	## now we can modify the hex string ... 
	if($hex_before =~ /28(.*)....0d/){
	Log3($name,5, "effekta_read hex without start and CRC: $1");

		my @h1 = ($1 =~ /(..)/g);
		my @ascii_ary = map { pack ("H2", $_) } @h1;
		my $asciistring;
	foreach my $part (@ascii_ary){
		$asciistring .= $part;
	}
		Log3($name,5, "effekta_read ascii: $asciistring");
		my @splits = split(" ",$asciistring);
		Log3($name,5, "effekta_read splits: @splits");
		effekta_analyze_answer($hash, @splits);
	}
return;
}
##########################################################################################
sub effekta_analyze_answer($@){

	my ($hash,@values) = @_;
	my $name = $hash->{NAME};
	my $cmd = $hash->{helper}{key};
	RemoveInternalTimer("watchdog:$name");
	Log3($name,4, "effekta_analyze_answer cmd: $cmd _Line:" . __LINE__);

		Log3($name,5, "effekta_analyze_answer analysiere ueberhaupt mal irgendwas _Line:" . __LINE__);

	if($values[0] =~ /NAK/){
		Log3($name,5, "effekta_analyze_answer analysiere $values[0] _Line:" . __LINE__);
		Log3($name,5, "effekta_analyze_answer Keine Gültige Abfrage, Antwort fehlerfrei. Abbruch. _Line:" . __LINE__);
		$hash->{helper}{key} = "";
		$hash->{helper}{value} = "";
		effekta_TimerGetData($hash);
	return;
	}

if($cmd eq "QPIRI") {

		Log3($name,4, "effekta_analyze_answer cmd: analysiere qpiri _Line:" . __LINE__);
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
						readingsBulkUpdate($hash,"Current_max_AC_charging_current",int($values[13]),1);
						readingsBulkUpdate($hash,"Current_max_charging_current",int($values[14]),1);
						
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
		Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QMOD") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "effekta_analyze_answer analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QFLAG") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	my ($E,$D) = split(/D/, $a);
	my %flags = ();
##		'Silence_Buzzer' => "",
##		'Overload_Bypass_Function' => "",	
##		'Power_Saving' => "",	
##		'LCD_escape_to_default' => "",	
##		'Overload_restart' => "",	
###		'Overtemperature_restart' => "",	
##		'backlight_always_on' => "",	
##		'Alarm_on_pri_src_interrupt' => "",	
##		'Fault_Code_Record' => "",	
##	);
	if($E =~ m/a/) {$flags{'Silence_Buzzer'} = "enabled";} elsif($D =~ m/a/)  {$flags{'Silence_Buzzer'} = "disabled";} 
	if($E =~ m/b/) {$flags{'Overload_Bypass_Function'} = "enabled";} elsif($D =~ m/b/)  {$flags{'Overload_Bypass_Function'} = "disabled";} 
	if($E =~ m/j/) {$flags{'Power_Saving'} = "enabled";} elsif($D =~ m/j/)  {$flags{'Power_Saving'} = "disabled";} 
	if($E =~ m/k/) {$flags{'LCD_escape_to_default'} = "enabled";} elsif($D =~ m/k/)  {$flags{'LCD_escape_to_default'} = "disabled";} 
	if($E =~ m/u/) {$flags{'Overload_restart'} = "enabled";} elsif($D =~ m/u/)  {$flags{'Overload_restart'} = "disabled";} 
	if($E =~ m/v/) {$flags{'Overtemperature_restart'} = "enabled";} elsif($D =~ m/v/)  {$flags{'Overtemperature_restart'} = "disabled";} 
	if($E =~ m/x/) {$flags{'backlight_always_on'} = "enabled";} elsif($D =~ m/x/)  {$flags{'backlight_always_on'} = "disabled";} 
	if($E =~ m/y/) {$flags{'Alarm_on_pri_src_interrupt'} = "enabled";} elsif($D =~ m/y/)  {$flags{'Alarm_on_pri_src_interrupt'} = "disabled";} 
	if($E =~ m/z/) {$flags{'Fault_Code_Record'} = "enabled";} elsif($D =~ m/z/)  {$flags{'Fault_Code_Record'} = "disabled";} 

	readingsBeginUpdate($hash);
	foreach my $key (%flags){
		readingsBulkUpdate($hash,$key,$flags{$key},1);
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QPIGS") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere QPIGS _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Grid_voltage",$values[0],1);
		readingsBulkUpdate($hash,"Grid_frequency",$values[1],1);
		readingsBulkUpdate($hash,"AC_output_voltage",$values[2],1);
		readingsBulkUpdate($hash,"AC_output_frequency",$values[3],1);
		readingsBulkUpdate($hash,"AC_output_appearent_power",int($values[4]),1);
		readingsBulkUpdate($hash,"AC_output_active_power",int($values[5]),1);
		readingsBulkUpdate($hash,"Output_load_percent",int($values[6]),1);
		readingsBulkUpdate($hash,"BUS_voltage",$values[7],1);
		readingsBulkUpdate($hash,"Battery_actual_voltage",$values[8],1);
		readingsBulkUpdate($hash,"Battery_charging_current",int($values[9]),1);
		readingsBulkUpdate($hash,"Battery_capacity_percent",int($values[10]),1);
		readingsBulkUpdate($hash,"Inverter_heat_sink_temperature",int($values[11]),1);
		readingsBulkUpdate($hash,"PV_Input_current_for_battery",int($values[12]),1);
		readingsBulkUpdate($hash,"PV_Input_voltage",int(10*$values[13])/10,1);
		readingsBulkUpdate($hash,"Battery_voltage_from_SCC",$values[14],1);
		readingsBulkUpdate($hash,"Battery_discharge_current",int($values[15]),1);
		readingsBulkUpdate($hash,"Device_Status",$values[16],1);
		readingsBulkUpdate($hash,"QPIGS_17",$values[17],1);
		readingsBulkUpdate($hash,"QPIGS_18",$values[18],1);
		readingsBulkUpdate($hash,"PV_input_actual_power",int($values[19]),1);
		readingsBulkUpdate($hash,"QPIGS_20",$values[20],1);
	readingsEndUpdate($hash,1);
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QPIWS") {
	Log3($name,3, "effekta_analyze_answer cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,4, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	my $r; 
	if(int($a) == 0){
	$r = "no Error";
	}else{
	my @b = split(//,$a);
	if($b[0] == 1) {$r = "Reserved - no Error";}
	elsif($b[1] == 1) {$r = "Inverter - Fault";}
	elsif($b[2] == 1) {$r = "Bus Over (Voltage?) - Fault";}
	elsif($b[3] == 1) {$r = "Bus Under (Voltage?) - Fault";}
	elsif($b[4] == 1) {$r = "Bus Soft Fail - Fault";}
	elsif($b[5] == 1) {$r = "LINE_FAIL - Warning";}
	elsif($b[6] == 1) {$r = "OPVShort - Warning";}
	elsif($b[7] == 1) {$r = "Inverter Voltage too low - Fault";}
	elsif($b[8] == 1) {$r = "Inverter Voltage too high - Fault";}
	elsif($b[9] == 1) {
		$r = "Over temperature -";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
		}
	elsif($b[10] == 1) {
		$r = "Fan locked";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[11] == 1) {
		$r = "Battery Voltage High";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[12] == 1) {$r = "Battery Low Alarm - Warning";}
	elsif($b[13] == 1) {$r = "Reserved - no Error";}
	elsif($b[14] == 1) {$r = "Battery under shutdown - Warning";}
	elsif($b[15] == 1) {$r = "Reserved, but still a Warning";}
	elsif($b[16] == 1) {
		$r = "Overload - ";
		$r .= $b[1] == 1 ? "Fault":"Warning";			
	}
	elsif($b[17] == 1) {$r = "EEPROM - Fault";}
	elsif($b[18] == 1) {$r = "Inverter Over Current - Fault";}
	elsif($b[19] == 1) {$r = "Inverter Soft Fail - Fault";}
	elsif($b[20] == 1) {$r = "Self Test Fail - Fault";}
	elsif($b[21] == 1) {$r = "OP DC Voltage Over - Fault";}
	elsif($b[22] == 1) {$r = "Bat Open - Fault";}
	elsif($b[23] == 1) {$r = "Current Sensor Fail - Fault";}
	elsif($b[24] == 1) {$r = "Battery Short - Fault";}
	elsif($b[25] == 1) {$r = "Power Limit - Warning";}
	elsif($b[26] == 1) {$r = "PV Voltage High - Warning";}
	elsif($b[27] == 1) {$r = "MPPT Overload Fault - Warning";}
	elsif($b[28] == 1) {$r = "MPPT Overload Warning - Warning";}
	elsif($b[29] == 1) {$r = "Battery too low to charge - Warning";}
	elsif($b[30] == 1) {$r = "Reserved - no Error";}
	elsif($b[31] == 1) {$r = "Reserved - no Error";}
	}
	Log3($name,5, "effekta_analyze_answer analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_warning",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QVFW") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Main_CPU_Firmware_Version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QVFW2") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Another_Firmware_CPU_version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QID") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Serial_Number",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QPI") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Protocol_ID",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QGMNI") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QGMNI_unknown",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QBEQI") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach(@values)
	{
		Log3($name,5, "effekta $a _Line:" . __LINE__);
		readingsBulkUpdate($hash,$cmd . "_$i",$values[$i],1);
		$i++;
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QBEGI") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QBEGI_0",$values[0],1);
		readingsBulkUpdate($hash,"Battery_equalisation_duration_minutes",$values[1],1);
		readingsBulkUpdate($hash,"Battery_equalisation_interval_days",$values[2],1);
		readingsBulkUpdate($hash,"Battery_charge_maximum_total_current",$values[3],1);
		readingsBulkUpdate($hash,"QBEGI_4",$values[4],1);
		readingsBulkUpdate($hash,"Battery_equalisation_voltage",$values[5],1);
		readingsBulkUpdate($hash,"QBEGI_0",$values[6],1);
		readingsBulkUpdate($hash,"Battery_equalisation_timeout_minutes",$values[7],1);
		readingsBulkUpdate($hash,"QBEGI_0",$values[8],1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "QSID") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach(@values)
	{
		Log3($name,5, "effekta $cmd _$i $values[$i] _Line:" . __LINE__);
		readingsBulkUpdate($hash,"QSID_$i",$values[$i],1);
		$i++;
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}elsif($cmd eq "SPARE") {
	Log3($name,4, "effekta_analyze_answer cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "effekta_analyze_answer uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "effekta_analyze_answer analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
} else {
	Log3($name,1,"effekta_analyze_answer cmd " . $cmd . " not implemented yet, putting values in _devel<nr>, Line: " . __LINE__);	
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach (@values) 
	{
 		Log3($name,1,"effekta_analyze_answer cmd  $cmd unknown, putting $values[$i] in _devel_$i");	
		if( AttrVal($name,"unknown_as_reading",0) eq "yes" ){
			readingsBulkUpdate($hash, "_devel_" . $i,$values[$i],1);
		}
		$i++;
	}
	readingsEndUpdate($hash,1);
	Log3($name,5, "effekta_analyze_answer $cmd successful _Line:" . __LINE__);
}
#{{{
Log3($name,5, "effekta_analyze_answer analyze ready. _Line:" . __LINE__);
$hash->{CONNECTION} = "established";
$hash->{helper}{key} = "";
$hash->{helper}{value} = "";
$hash->{helper}{recv} = "";
effekta_TimerGetData($hash);
return;

}

1;


=pod
=begin html
<ul>
<a name="effekta_set"></a>
<b>Set</b>
</ul>

<ul>
<a name="effekta_get"></a>
<b>Get</b>
</ul>

<ul>
<a name="effekta_attr"></a>
<b>Attributes</b>
<br><br>
	<ul>
	<a name="orders"></a>
	<li><b>orders</b>
		<ul>
		<code>
		attr &lt;device&gt; orders
		</code><br>
		Hier werden die abzufragenden Befehle ausgewählt<br>
		<br>
		
			<ul>
			<li>
				QPIRI<br>
				Voltages and currents
			</li
			<li>
				QMOD<br>
				Working modes, eg. Standby, Line, Battery Mode etc.
			</li>
			<li>
				QFLAG<br>
				AlarmFlags, as Buzzer, Bypass etc.
			</li>
			<li>
				QPIGS<br>
				Essential Values, as Output Power , Battery Voltage, PV-Power etc
			</li>
			<li>
				QPIWS<br>
				Warnings, less important
			</li>
			<li>
				QVFW<br>
				Firmware, not important
			</li>
			<li>
				QVFW2<br>
				Another Firmware, not important
			</li>
			<li>
				QID<br>
				Serial Number, not important
			</li>
			<li>
				QPI<br>
				Device Protocol ID, not important
			</li>
			<li>
				QGMNI<br>
				yet unknown
			</li>
			<li>
				QBEQI<br>
				yet unknown
			</li>
			<li>
				QBEGI<br>
				Battery Equalisation. Not Used for Li-Ion.
			</li>
			<li>
				QSID<br>
				unknown
			</li>
			</ul>

		</ul>
	</li>
	</ul>
</ul>
<br>





<ul>
<a name="reopen"></a>
<li><b>reopen</b>
<ul>
<code>
set &lt;device&gt; reopen
</code><br>
Wenn das Device offen ist, wird es geschlossen<br>
Wenn das Device jetzt geschlossen ist, wird es geöffnet<br>
effekta_TimerGetData() wird NICHT aufgerufen.<br>
</ul>
</li>
</ul>
<br>


<ul>
<a name="reset"></a>
<li><b>reset</b>
<ul>
<code>
set &lt;device&gt; reset
</code><br>
Löscht (helper)(value);<br>
Löscht (helper)(key);<br>
löscht die actionQueue;<br>
ruft effekta_TimerGetData() ohne Delay auf.<br>
</ul>
</li>
</ul>
<br>

=end html

=begin html_DE

=end html_DE
=cut
