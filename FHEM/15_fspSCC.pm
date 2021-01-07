##############################################
# $Id: 15_fspSCC.pm 2021-01-02 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use Digest::CRC qw(crc);
# für AX-M 5000;
#
##--##my %requests = (
##--##	'QPI' => "515049beac0d", ##  Device Protocol ID Inquiry
##--####	'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
##--##	'QVFW' => "5156465762990d", ## Main CPU Firmware version Inqiry
##--##	'QVFW2' => "5156465732c3f50d", ## Another CPU Firmware version Inqiry
##--##	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
##--##	'QFLAG' => "51464c414798740d", ##Device Flag status Inquiry
##--##	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
##--##	'QPIWS' => "5150495753b4da0d", ##Device Warning Status Inquiry
##--###	'QDI' => "514449711b0d", ## Default Setting Value Information - default settings - needed to restore defaults, in the software
##--###	'QMCHGCR' => "514d4348474352d8550d", ## Enquiry selectable value about max charging current - needed for creating the dropdown in the software
##--###	'QMUCHGCR' => "514d55434847435226340d", ##Enquiry selectable value about max utility charging current - needed for creating the dropdown in the software
##--###	'QBOOT' => "51424f4f540a88", ## Enquiry DSP has bootstrap or not
##--###	'QOPM' => "514f504da5c50d", ## Enquiry output mode (For 4000/5000)
##--###	'QPGS0' => "51504753303fda0d", ## Parallel Information Inquiry. same values as in QPIGS
##--###	'QRST' => "5152535472bc0d", ## nicht dokumentiert, NAKss
##--###	'QMN' => "514d4ebb640d", ##nicht dokumentiert, NAKss 
##--##	'QGMNI' => "51474d4e49290d", ##  nicht dokumentiert
##--##	'QSID' => "51534944bb050d", ## nicht dokumentiert
##--##	'QBEQI' => "51424551492ea90d", ## nicht dokumentiert VERMUTUNG: Equalisation function - liefert keine Antwort
##--##	'QMOD' => "514d4f4449c10d" ## Device Mode inquiry
##--##	);
# für SCC3k
my %requests = (
	'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
	'QVFW' => "5156465762990d", ## Main CPU Firmware version Inqiry
	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry
	'QPIWS' => "5150495753b4da0d", ##Device Warning Status Inquiry
	'QDI' => "514449711b0d", ## Default Setting Value Information - default settings - needed to restore defaults, in the software
	'QBEQI' => "51424551492ea90d", ## nicht dokumentiert VERMUTUNG: Equalisation function - liefert keine Antwort
	);
#####################################
sub
fspSCC_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "fspSCC_Define";
  $hash->{SetFn}     = "fspSCC_Set";
  $hash->{GetFn}     = "fspSCC_Get";
  $hash->{UndefFn}   = "fspSCC_Undef";
  $hash->{NotifyFn}  = "fspSCC_Notify";
  $hash->{ReadFn}    = "fspSCC_Read";
  $hash->{ReadyFn}   = "fspSCC_Ready";
  $hash->{AttrList}  = "interval unknown_as_reading:yes,no disable:0,1".
                        $readingFnAttributes;
  $hash->{helper}{value} = "";
  $hash->{helper}{key} = "";
  $hash->{helper}{retrycount} = 0;
}

#####################################
sub
fspSCC_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> fspSCC <device>";
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
  my $ret = DevIo_OpenDev($hash, 0, "fspSCC_DoInit" );
  Log3($name, 1, "fspSCC DevIO_OpenDev_Define" . __LINE__); 
  return $ret;
}


sub
fspSCC_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
 fspSCC_TimerGetData($hash);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub fspSCC_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "fspSCC_DoInit" );
}
###################################
sub fspSCC_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};

Log3 $name, 4, "fspSCC ($name) - fspSCC_Notify  Line: " . __LINE__;	
return if (IsDisabled($name));
my $devname = $dev->{NAME};
my $devtype = $dev->{TYPE};
my $events = deviceEvents($dev,1);
Log3 $name, 4, "fspSCC ($name) - fspSCC_Notify - not disabled  Line: " . __LINE__;	
return if (!$events);
if( grep /^ATTR.$name.interval/,@{$events} or grep /^INITIALIZED$/,@{$events}) {
	Log3 $name, 4, "fspSCC ($name) - fspSCC_Notify change Interval to AttrVal($name,interval,60) _Line: " . __LINE__;	
	$hash->{INTERVAL} = AttrVal($name,"interval",60);
}


Log3 $name, 4, "fspSCC ($name) - fspSCC_Notify got events @{$events} Line: " . __LINE__;	
fspSCC_TimerGetData($hash) if( grep /^INITIALIZED$/,@{$events}
				or grep /^CONNECTED$/,@{$events}
				or grep /^DELETEATTR.$name.disable$/,@{$events}
				or grep /^DELETEATTR.$name.interval$/,@{$events}
				or (grep /^DEFINED.$name$/,@{$events} and $init_done) );


return;

}
#####################################
sub fspSCC_Undef($$)
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
sub fspSCC_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of reopen:noArg reset:noArg"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "fspSCC argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fspSCC argument fragezeichen" . __LINE__);
	return $usage;
	}
	if($a[1] eq "reopen"){
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "Device is open, closing ... Line: " . __LINE__);
			DevIo_CloseDev($hash);
			Log3($name,1, "fspSCC Device closed Line: " . __LINE__);
		} 
		Log3($name,1, "fspSCC_Set  Device is closed, trying to open Line: " . __LINE__);
		$ret = DevIo_OpenDev($hash, 1, "fspSCC_DoInit" );
		if(!DevIo_IsOpen($hash)){
			$ret = DevIo_OpenDev($hash, 1, "fspSCC_DoInit" );
		}
		if(DevIo_IsOpen($hash)){
			Log3($name,1, "fspSCC_Set  Device opened. Line: " . __LINE__);
			readingsSingleUpdate($hash, "_status","Device opened",1);
			return;
		}
		Log3($name,1, "fspSCC_Set  Opening failed. Line: " . __LINE__);
		readingsSingleUpdate($hash, "_status","Opening failed",1);
		return;
	} elsif ($a[1] eq "reset"){
	$hash->{helper}{value} = "";
	$hash->{helper}{key} = "";
	$hash->{helper}{recv} = "";
	@{$hash->{actionQueue}} = ();
	Log3($name,1, "fspSCC_Set actionQueue is empty: @{$hash->{actionQueue}} Line:" . __LINE__);
	fspSCC_TimerGetData($hash);
	}
	
}
#####################################
sub fspSCC_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of calcHex QID"; 
	Log3($name,5, "fspSCC argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fspSCC argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}elsif($a[1] eq "QID"){
	Log3($name,5, "fspSCC inserting QID into actionQueue Line: " . __LINE__);
	#'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
			unshift( @{$hash->{actionQueue}}, "514944d6ea0d" );
			unshift( @{$hash->{actionQueue}}, "QID" );
	}
#my $value="QPI";
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
#	Log3($name,1, "fspSCC get $crc _Line: " . __LINE__);



}

############################################
sub fspSCC_TimerGetData($){
my $hash = shift;
my $name = $hash->{NAME};
Log3 $name, 4, "fspSCC ($name) _TimerGetData - action Queue 1: $hash->{actionQueue} Line: " . __LINE__;	
Log3 $name, 4, "fspSCC ($name) _TimerGetData - actionQueue_array  @{$hash->{actionQueue}}  Line: " . __LINE__;	
if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ){
	Log3 $name, 4, "fspSCC ($name) _TimerGetData - is defined and empty. Line: " . __LINE__;	
	if( not IsDisabled($name) ) {
		Log3 $name, 4, "fspSCC ($name) _TimerGetData - is not disabled. Line: " . __LINE__;	
		while( my ($key,$value) = each %requests ){
		Log3 $name, 4, "fspSCC ($name) _TimerGetData - actionQueue fill: $key  Line: " . __LINE__;	
		Log3 $name, 4, "fspSCC ($name) _TimerGetData - actionQueue fill: $value  Line: " . __LINE__;	
			unshift( @{$hash->{actionQueue}}, $value );
			unshift( @{$hash->{actionQueue}}, $key );
			#My $hash = (
			#	foo => [1,2,3,4,5],
			#	bar => [a,b,c,d,e]
			#);
			#@{$hash{foo}} would be (1,2,3,4,5)
		}
		Log3 $name, 4, "fspSCC ($name) _TimerGetData - actionQueue filled: @{$hash->{actionQueue}}  Line: " . __LINE__;	
		Log3 $name, 4, "fspSCC ($name) _TimerGetData - call fspSCC_sendRequests Line: " . __LINE__;	
		fspSCC_sendRequests("first:$name");
	}else{
		readingsSingleUpdate($hash,'state','disabled',1);
	}
	InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'fspSCC_TimerGetData', $hash);
	Log3 $name, 4, "fspSCC ($name) _TimerGetData - call InternalTimer fspSCC_TimerGetData Line: " . __LINE__;	
}else {
	Log3 $name, 4, "fspSCC ($name) _TimerGetData - call fspSCC_sendRequests Line: " . __LINE__;	
	fspSCC_sendRequests("next:$name");
}
}
####################################
sub fspSCC_sendRequests($){
my ($calltype,$name) = split(':', $_[0]);
my $hash = $defs{$name};
Log3 $name, 5, "fspSCC ($name) - fspSCC_sendRequests calltype $calltype  Line: " . __LINE__;	

#Wenn aufgerufen wird, dass die nächste Abfrage erfolgt, und der Empfangsbuffer leer ist
if($calltype eq "next" && $hash->{helper}{recv} eq ""){ 
	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) > 0 ){
		$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{retrycount} = 0;
		if(!defined($hash->{helper}{key}) || $hash->{helper}{key} eq ""){
			Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests_next key not defined or empty, finish  Line: " . __LINE__;
			return;	
		}
	}else{
	Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests actionQueue not defined or empty, finish  Line: " . __LINE__;
	}
}elsif($calltype eq "resend" && $hash->{helper}{recv} eq ""){ 
	my $delta = gettimeofday() - $hash->{helper}{resend};
	Log3 $name, 5, "fspSCC ($name) - fspSCC_sendRequests_resend delta: $delta   Line: " . __LINE__;
	$hash->{CONNECTION} = "timeout";
	readingsSingleUpdate($hash, "_status","communication failed",1);
	if($hash->{helper}{retrycount} > 10) {
		Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests retryCount reached, next one  Line: " . __LINE__;	
	
		$hash->{helper}{value} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{key} = pop( @{$hash->{actionQueue}} );
		$hash->{helper}{retrycount} = 0;
		if(!defined($hash->{helper}{key}) || $hash->{helper}{key} eq ""){
			Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests_resend key not defined or empty, finish  Line: " . __LINE__;
			return;	
		}
	}else{
	$hash->{helper}{retrycount}++;
	Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests receivebuffer $hash->{helper}{recv}. retryCount is  $hash->{helper}{retrycount} Line: " . __LINE__;	
	}
}else{
	Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests receivebuffer not empty: _$hash->{helper}{recv}_ Line: " . __LINE__;	
}


Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests value: $hash->{helper}{value}  Line: " . __LINE__;	
Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests key: $hash->{helper}{key}  Line: " . __LINE__;	
$hash->{helper}{recv} = "";
$hash->{helper}{resend} = gettimeofday();
DevIo_SimpleWrite($hash,$hash->{helper}{value},1);
if($hash->{helper}{value} ne "" &&  $hash->{helper}{key} ne ""){ 
	InternalTimer(gettimeofday()+2,'fspSCC_sendRequests',"resend:$name");
	Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests starte resend-timer. Line: " . __LINE__;	
} else {
	Log3 $name, 4, "fspSCC ($name) - fspSCC_sendRequests key or value empty. Aborting. Line: " . __LINE__;	
	return;
}	
}
#####################################
sub fspSCC_Read($$)
{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	readingsSingleUpdate($hash, "_status","communication in progress",1);
	Log3($name,4, "fspSCC jetzt wird gelesen _Line:" . __LINE__);
	# read from serial device
	#
	
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "fspSCC buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "fspSCC Fehler beim lesen _Line:" . __LINE__);
		$hash->{CONNECTION} = "failed";
		return "error" ;
	}
 	# es geht los mit 0x28 und hört auf mit 0x0d - eigentlich.	
	$hash->{helper}{recv} .= $buf; 
	
	Log3($name,5, "fspSCC helper: $hash->{helper}{recv}"); 
	my $hex_before = unpack "H*", $hash->{helper}{recv};
	Log3($name,5, "fspSCC hex_before: $hex_before");
	## now we can modify the hex string ... 
	if($hex_before =~ /28(.*)....0d/){
	Log3($name,5, "fspSCC hex without start and CRC: $1");

		my @h1 = ($1 =~ /(..)/g);
		my @ascii_ary = map { pack ("H2", $_) } @h1;
		my $asciistring;
	foreach my $part (@ascii_ary){
		$asciistring .= $part;
	}
		Log3($name,5, "fspSCC ascii: $asciistring");
		my @splits = split(" ",$asciistring);
		Log3($name,5, "fspSCC splits: @splits");
		fspSCC_analyze_answer($hash, @splits);
	if(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) != 0 ){
		Log3 $name, 4, "fspSCC ($name) - fspSCC_ReadFn Noch nicht alle Abfragen gesendet, rufe sendRequests wieder auf  Line: " . __LINE__;	
		Log3 $name, 4, "fspSCC ($name) - fspSCC_ReadFn Noch anstehende Abfragen:  @{$hash->{actionQueue}} Line: " . __LINE__;	
		fspSCC_sendRequests("next:$name");
	}else{
		Log3 $name, 4, "fspSCC ($name) - fspSCC_ReadFn Alle Einträge bearbeitet, starte nächste Abfrage  Line: " . __LINE__;	
		readingsSingleUpdate($hash, "_status","communication finished, starte nächste Abfrage",1);
		fspSCC_TimerGetData($hash);
	}
	}
 
	return;
}
##########################################################################################
sub fspSCC_analyze_answer($@){

	my ($hash,@values) = @_;
	my $name = $hash->{NAME};
	my $cmd = $hash->{helper}{key};
	my $success = "failed";
	Log3($name,4, "fspSCC cmd: $cmd _Line:" . __LINE__);

		Log3($name,5, "fspSCC analysiere ueberhaupt mal irgendwas _Line:" . __LINE__);

	if($values[0] =~ /NAK/){
		Log3($name,5, "fspSCC analysiere $values[0] _Line:" . __LINE__);
		Log3($name,5, "fspSCC Keine Gültige Abfrage, Antwort fehlerfrei. Abbruch. _Line:" . __LINE__);
		##fspSCC_blck_doInternalUpdate($hash); 
			$hash->{helper}{key} = "";
		$hash->{helper}{value} = "";
		$hash->{helper}{retrycount} = "";
		Log3($name, 5, "fspSCC ($name) - fspSCC_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
		RemoveInternalTimer("resend:$name");
return;
	}

if($cmd eq "QDI") { # new, used for SCC

		Log3($name,4, "fspSCC cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"QDI_1",$values[0],1);
						readingsBulkUpdate($hash,"QDI_2",$values[1],1);
						readingsBulkUpdate($hash,"QDI_3",$values[2],1);
						readingsBulkUpdate($hash,"QDI_4",$values[3],1);
						readingsBulkUpdate($hash,"QDI_5",$values[4],1);
						readingsBulkUpdate($hash,"QDI_6",$values[5],1);
						readingsBulkUpdate($hash,"QDI_7",$values[6],1);
						readingsBulkUpdate($hash,"QDI_8",$values[7],1);
					readingsEndUpdate($hash,1);
		Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd eq "QPIRI") { # checked, used for SCC, but changed

		Log3($name,4, "fspSCC cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"QPIRI_PV_rated_power",$values[0],1);
						readingsBulkUpdate($hash,"QPIRI_DC_rated_voltage",$values[1],1);
						readingsBulkUpdate($hash,"QPIRI_DC_rated_current",$values[2],1);
						readingsBulkUpdate($hash,"QPIRI_Battery_absorption_charge_voltage",$values[3]*$hash->{helper}{batfactor},1);
						readingsBulkUpdate($hash,"QPIRI_Battery_floating_charge_voltage",$values[4]*$hash->{helper}{batfactor},1);
						readingsBulkUpdate($hash,"QPIRI_Value6",$values[5],1);
						readingsBulkUpdate($hash,"QPIRI_Value7",$values[6],1);
						readingsBulkUpdate($hash,"QPIRI_Value8",$values[7],1);
						readingsBulkUpdate($hash,"QPIRI_Value9",$values[8],1);
						readingsBulkUpdate($hash,"QPIRI_Value10",$values[9],1);
						readingsBulkUpdate($hash,"QPIRI_Value11",$values[10],1);
						readingsBulkUpdate($hash,"QPIRI_Value12",$values[11],1);
					readingsEndUpdate($hash,1);
		Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd eq "QMOD") {
	Log3($name,4, "fspSCC cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "fspSCC analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QFLAG") {
	Log3($name,4, "fspSCC cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
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
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIGS") {##checked, used for SCC, changed
	Log3($name,4, "fspSCC cmd: analysiere QPIGS _Line:" . __LINE__);
	$hash->{helper}{batfactor} = int(0.5+($values[1]/12));
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QPIGS_actual_PV_voltage",int(10*$values[0])/10,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Bat_voltage",$values[1],1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_current1",int(100*$values[2])/100,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_current2",int(100*$values[3])/100,1);
		readingsBulkUpdate($hash,"QPIGS_5_bleibt_null",$values[4],1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_power",int($values[5]),1);
		readingsBulkUpdate($hash,"QPIGS_actual_SCC_Temperature",$values[6],1);
		readingsBulkUpdate($hash,"QPIGS_8_bleibt_nicht_immer_null",$values[7],1);
		readingsBulkUpdate($hash,"QPIGS_unk_external_battery_temperature",$values[8],1);
		readingsBulkUpdate($hash,"QPIGS_10_status",$values[9],1);
		readingsBulkUpdate($hash,"QPIGS_11_status",$values[10],1);
		readingsBulkUpdate($hash,"_batfactor",$hash->{helper}{batfactor},1);
##		readingsBulkUpdate($hash,"PV_Input_current_for_battery",int($values[12]),1);
##		readingsBulkUpdate($hash,"PV_Input_voltage",int(10*$values[13])/10,1);
##		readingsBulkUpdate($hash,"Battery_voltage_from_SCC",$values[14],1);
##		readingsBulkUpdate($hash,"Battery_discharge_current",int($values[15]),1);
##		readingsBulkUpdate($hash,"Device_Status",$values[16],1);
##		readingsBulkUpdate($hash,"QPIGS_17",$values[17],1);
##		readingsBulkUpdate($hash,"QPIGS_18",$values[18],1);
##		readingsBulkUpdate($hash,"PV_input_actual_power",int($values[19]),1);
##		readingsBulkUpdate($hash,"QPIGS_20",$values[20],1);
	readingsEndUpdate($hash,1);
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIWS") {## checked, used for SCC, not changed by now 
	Log3($name,3, "fspSCC cmd: analysiere QMOD _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,4, "fspSCC uebergeben: $a _Line:" . __LINE__);
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
	Log3($name,5, "fspSCC analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_warning",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QVFW") {# checked, used for SCC without change
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Main_CPU_Firmware_Version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
#}elsif($cmd eq "QVFW2") {
#	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
#	my ($b,$a) =split(":",$values[0]);
#	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
#	readingsBeginUpdate($hash);
#		readingsBulkUpdate($hash,"Another_Firmware_CPU_version",$a,1);
#	readingsEndUpdate($hash,1);
#			
#	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
#	$success="success";
}elsif($cmd eq "QID") { # checked, used for SCC without change
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Serial_Number",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPI") {
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Protocol_ID",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QGMNI") {
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QGMNI_unknown",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QBEQI") {## checked, used for SCC, changed
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QBEQI_Equalisation activated",$values[0],1);
		readingsBulkUpdate($hash,"QBEQI_Battery_equalisation_duration_minutes",$values[1],1);
		readingsBulkUpdate($hash,"QBEQI_2unk_Battery_equalisation_interval_days",$values[2],1);
		readingsBulkUpdate($hash,"QBEQI_Battery_equalisation_maximum_total_current",$values[3],1);
		readingsBulkUpdate($hash,"QBEQI_unk_next_Battery_equalisation_interval_days",$values[4],1);
		readingsBulkUpdate($hash,"QBEQI_Battery_equalisation_voltage",$values[5],1);
		readingsBulkUpdate($hash,"QBEQI_Battery_CV_charging_time",$values[6],1);
		readingsBulkUpdate($hash,"QBEQI_Battery_equalized_timeout_minutes",$values[7],1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QSID") {
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach(@values)
	{
		Log3($name,5, "fspSCC $cmd _$i $values[$i] _Line:" . __LINE__);
		readingsBulkUpdate($hash,"QSID_$i",$values[$i],1);
		$i++;
	}
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "SPARE") {
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	my $r;
	if($a eq "P") {$r = "Power on Mode";}
	elsif($a eq "S") {$r = "Standby Mode";}
	elsif($a eq "L") {$r = "Line Mode";}
	elsif($a eq "B") {$r = "Battery Mode";}
	elsif($a eq "F") {$r = "Fault Mode";}
	elsif($a eq "H") {$r = "Power saving Mode";}

	Log3($name,5, "fspSCC analyse: QMOD. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Mode",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
} else {
	Log3($name,1,"fspSCC cmd " . $cmd . " not implemented yet, putting values in _devel<nr>, Line: " . __LINE__);	
	readingsBeginUpdate($hash);
	my $i = 0;
	foreach (@values) 
	{
 		Log3($name,1,"fspSCC cmd  $cmd unknown, putting $values[$i] in _devel_$i");	
		if( AttrVal($name,"unknown_as_reading",0) eq "yes" ){
			readingsBulkUpdate($hash, "_devel_" . $i,$values[$i],1);
		}
		$i++;
	}
	readingsEndUpdate($hash,1);
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}

Log3($name,5, "fspSCC analyze ready. success: $success _Line:" . __LINE__);
if($success eq "success"){
	$hash->{CONNECTION} = "established";
	$hash->{helper}{key} = "";
	$hash->{helper}{value} = "";
	$hash->{helper}{retrycount} = 0;
	$hash->{helper}{recv} = "";
	Log3($name, 5, "fspSCC ($name) - fspSCC_analyze_answer stoppe resend-timer. Line: " . __LINE__);	
	RemoveInternalTimer("resend:$name");
}


}

1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
