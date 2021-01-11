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
	## QPIRI kann mal in eine langsame schleife gebaut werden. Alle 5 Minuten sollte reichen.
##	'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry 2.4
	'QPIGS' => "5150494753b7a90d", ## Device general Status parameters Inquiry 2.5
	'QPIWS' => "5150495753b4da0d" ##Device Warning Status Inquiry 2.7
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

	} elsif ($a[1] eq "reset"){ ## set device Serial Number 3.1

	} elsif ($a[1] eq "reset"){ ## set Battery Type 3.2
		##PBT<TT><cr>
	} elsif ($a[1] eq "reset"){ ## set Battery absorption charging Voltage 3.3
		## PBAV<AA.AA><CRC><cr>
	} elsif ($a[1] eq "reset"){ ## set Set battery floating charging Voltage 3.4
		## PBFV<FF.FF><CRC><cr>
	} elsif ($a[1] eq "reset"){ ## set rated Battery voltage 3.5
		## PBRV<NN><CRC><cr>
		#NN-> 00=auto sensing, 01=12 02=24 03=36 04=48V
	} elsif ($a[1] eq "reset"){ ## set max charging Current 3.6
		## MCHGC<NNN><CRC><cr>
		#NNN= 010-060 Ampere
	} elsif ($a[1] eq "reset"){ ## set BTS temperature compensation ratio 3.7
	} elsif ($a[1] eq "reset"){ ## enable/disable remote battery voltage detect 3.8
	} elsif ($a[1] eq "reset"){ ## set battery low warning Voltage 3.9
	} elsif ($a[1] eq "reset"){ ## set battery low shutdown detect enable/disable 3.10
	}
	
}
#####################################
sub fspSCC_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of calcHex QID QPI QVFW QBEGI QPIRI QDI"; 
	Log3($name,5, "fspSCC argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fspSCC argument fragezeichen_Line: " . __LINE__);
	return $usage;
	}elsif($a[1] eq "QID"){
	Log3($name,5, "fspSCC inserting QID into actionQueue Line: " . __LINE__);
	#'QID' => "514944d6ea0d", ## Device Serial Number Inquiry
			unshift( @{$hash->{actionQueue}}, "514944d6ea0d" );
			unshift( @{$hash->{actionQueue}}, "QID" );
	}elsif($a[1] eq "QPI"){
	Log3($name,5, "fspSCC inserting QPI into actionQueue Line: " . __LINE__);
	#'QPI' => "", ## Device Serial Number Inquiry
			unshift( @{$hash->{actionQueue}}, "515049beac0" );
			unshift( @{$hash->{actionQueue}}, "QPI" );
	}elsif($a[1] eq "QVFW"){
	Log3($name,5, "fspSCC inserting QVFW into actionQueue Line: " . __LINE__);
	#'QVFW' => "", ## Device Serial Number Inquiry
			unshift( @{$hash->{actionQueue}}, "5156465762990d" );
			unshift( @{$hash->{actionQueue}}, "QVFW" );
	}elsif($a[1] eq "QBEGI"){
	Log3($name,5, "fspSCC inserting QBEGI into actionQueue Line: " . __LINE__);
	##'QBEQI' => "51424551492ea90d", ## nicht dokumentiert VERMUTUNG: Equalisation function - liefert keine Antwort 2.8
			unshift( @{$hash->{actionQueue}}, "51424551492ea90d" );
			unshift( @{$hash->{actionQueue}}, "QBEGI" );
	}elsif($a[1] eq "QPIRI"){
	Log3($name,5, "fspSCC inserting QPIRI into actionQueue Line: " . __LINE__);
	#'QPIRI' => "5150495249f8540d", ## Device rating information Inquiry 2.4
			unshift( @{$hash->{actionQueue}}, "5150495249f8540d" );
			unshift( @{$hash->{actionQueue}}, "QPIRI" );
	}elsif($a[1] eq "QDI"){
	Log3($name,5, "fspSCC inserting QDI into actionQueue Line: " . __LINE__);
	#'QDI' => "514449711b0d", ## Default Setting Value Information - default settings - needed to restore defaults, in the software 2.6
			unshift( @{$hash->{actionQueue}}, "514449711b0d" );
			unshift( @{$hash->{actionQueue}}, "QDI" );
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

# n   	my $finale = crc("QPI",16,0x0000,i);
#	Log3($name,1, "fspSCC get $crc _Line: " . __LINE__);
return;


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

if($cmd eq "QDI") { # new, used for SCC default setting Value 2.6

		Log3($name,4, "fspSCC cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						my $bvs;
						if($values[9] eq "00"){
							$bvs = "auto";
						}elsif($values[9] eq "01"){
							$bvs = "12V";
						}elsif($values[9] eq "02"){
							$bvs = "24V";
						}elsif($values[9] eq "03"){
							$bvs = "36V";
						}elsif($values[9] eq "04"){
							$bvs = "48V";
						}
						readingsBulkUpdate($hash,"QDI_Battery_rated_voltage",$bvs,1);
						readingsBulkUpdate($hash,"QDI_max_charging_current",$values[1],1);
						my $type;
						if($values[5] eq "00"){
							$type = "AGM Battery";
						}elsif($values[5] eq "01"){
							$type = "Flooded Battery";
						}elsif($values[5] eq "02"){
							$type = "Custom Battery";
						}
						readingsBulkUpdate($hash,"QDI_Battery_type",$type,1);
						readingsBulkUpdate($hash,"QDI_Absorption_voltage",$values[3],1);
						readingsBulkUpdate($hash,"QDI_Floating_voltage",$values[4],1);
						readingsBulkUpdate($hash,"QDI_Remote_Battery_Voltage_detect_disable",$values[5],1);
						readingsBulkUpdate($hash,"QDI_Battery_temperature_compensation_ratio_mV",$values[6],1);
						##readingsBulkUpdate($hash,"QDI_reservd",$values[7],1);
					readingsEndUpdate($hash,1);
		Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
		$success="success";
}elsif($cmd eq "QPIRI") { # Device Rated information Inquiry 2.4 checked, used for SCC, but changed

		Log3($name,4, "fspSCC cmd: analysiere qpiri _Line:" . __LINE__);
					readingsBeginUpdate($hash);
						readingsBulkUpdate($hash,"QPIRI_PV_rated_power",$values[0],1);
						readingsBulkUpdate($hash,"QPIRI_DC_rated_voltage",$values[1],1);
						readingsBulkUpdate($hash,"QPIRI_DC_rated_current",$values[2],1);
						readingsBulkUpdate($hash,"QPIRI_Battery_absorption_charge_voltage",$values[3]*$hash->{helper}{batfactor},1);
						readingsBulkUpdate($hash,"QPIRI_Battery_floating_charge_voltage",$values[4]*$hash->{helper}{batfactor},1);
						my $type;
						if($values[5] eq "00"){
							$type = "AGM Battery";
						}elsif($values[5] eq "01"){
							$type = "Flooded Battery";
						}elsif($values[5] eq "02"){
							$type = "Custom Battery";
						}
						readingsBulkUpdate($hash,"QPIRI_Battery_type",$type,1);
						my $detect;
						if($values[6]){
							$detect = "enabled";
						}else{	
							$detect = "disabled";
						}
						readingsBulkUpdate($hash,"QPIRI_Remote_Battery_sensing",$detect,1);
						readingsBulkUpdate($hash,"QPIRI_Battery_Temperature_compensation_mV",$values[7],1);
						my $temp_detect;
						if($values[8]){
							$temp_detect = "enabled";
						}else{	
							$temp_detect = "disabled";
						}
						readingsBulkUpdate($hash,"QPIRI_remote_temperature_sensing",$temp_detect,1);
						my $bvs;
						if($values[9] eq "00"){
							$bvs = "auto";
						}elsif($values[9] eq "01"){
							$bvs = "12V";
						}elsif($values[9] eq "02"){
							$bvs = "24V";
						}elsif($values[9] eq "03"){
							$bvs = "36V";
						}elsif($values[9] eq "04"){
							$bvs = "48V";
						}
						readingsBulkUpdate($hash,"QPIRI_Battery_rated_Voltage",$bvs,1);
						
						readingsBulkUpdate($hash,"QPIRI_The_Piece_of_Battery_in_Serial",$values[10],1);
						readingsBulkUpdate($hash,"QPIRI_Battery_low_warning_voltage",$values[11],1);
						readingsBulkUpdate($hash,"QPIRI_Battery_low_shutdown_detect",$values[12],1);
					readingsEndUpdate($hash,1);
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIGS") {## device general Status inquiry, 2.5 ##checked, used for SCC, changed
	Log3($name,4, "fspSCC cmd: analysiere QPIGS _Line:" . __LINE__);
	$hash->{helper}{batfactor} = int(0.5+($values[1]/12));
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QPIGS_actual_PV_voltage",int(10*$values[0])/10,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Bat_voltage",$values[1],1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_current_total",int(100*$values[2])/100,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_current1",int(100*$values[3])/100,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_current2",int(100*$values[4])/100,1);
		readingsBulkUpdate($hash,"QPIGS_actual_Battery_charging_power",int($values[5]),1);
		readingsBulkUpdate($hash,"QPIGS_actual_SCC_Temperature",$values[6],1);
		readingsBulkUpdate($hash,"QPIGS_Remote_Battery_voltage",$values[7],1);
		readingsBulkUpdate($hash,"QPIGS_Remote_Battery_temperature",$values[8],1);
	my $a = $values[10];
	Log3($name,4, "fspSCC uebergeben: $a _Line:" . __LINE__);
	my $r; 
	if(int($a) == 0){
	$r = "no Status";
	}else{
	my @b = split(//,$a);
	if($b[0]) {$r .= "Reserved - no Error";}
	if($b[1]) {$r .= "Reserved - no Error";}
	if($b[2]) {$r .= "Reserved - no Error";}
	if($b[3]) {$r .= "Reserved - no Error";}
	if($b[4]) {$r .= "Reserved - no Error";}
	if($b[5]) {$r .= "time to allow equalisation";}
	if($b[6]) {$r .= "Charger Working -Reserved - no Error";}
	if($b[7]) {$r .= "Parameter have been modified";}
	}	
		readingsBulkUpdate($hash,"QPIGS_status",$r,1);
		readingsBulkUpdate($hash,"_batfactor",$hash->{helper}{batfactor},1);
	readingsEndUpdate($hash,1);
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPIWS") {## checked, used for SCC, not changed by now 
	Log3($name,3, "fspSCC cmd: analysiere QPIWS _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,4, "fspSCC uebergeben: $a _Line:" . __LINE__);
	my $r; 
	if(int($a) == 0){
	$r = "no Error";
	}else{
	my @b = split(//,$a);
	if($b[0]) {$r = "Over charge Current - Fault";}
	if($b[1]) {$r .= "Over Temperature - Fault";}
	if($b[2]) {$r .= "Battery Voltage under - Fault";}
	if($b[3]) {$r .= "Battery Voltage over - Fault";}
	if($b[4]) {$r .= "PV high loss - Fault";}
	if($b[5]) {$r .= "Battery Temperature too low - Fault";}
	if($b[6]) {$r .= "Battery Temperature too high - Fault";}
	if($b[20]) {$r .= "PV low loss - Warning";}
	if($b[21]) {$r .= "PV high derating - Warnung";}
	if($b[22]) {$r .= "Temperature high derating - Warning";}
	if($b[23]) {$r .= "Battery_temperature_low_alarm";}
	}
	Log3($name,5, "fspSCC analyse: QPIWS. Entscheidung für $r _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QPIWS_Device_warnings",$r,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QVFW") {#MPPT CPU firmware version inquiry 2.3 checked, used for SCC without change
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my ($b,$a) =split(":",$values[0]);
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"QVFW_Main_CPU_Firmware_Version",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QID") { # Device Serial Number Inquiry 2.2 -> checked, used for SCC without change
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Serial_Number",$a,1);
	readingsEndUpdate($hash,1);
			
	Log3($name,5, "fspSCC $cmd successful _Line:" . __LINE__);
	$success="success";
}elsif($cmd eq "QPI") { ## Device Protocol ID Inquiry 2.1 -> checked, used for SCC without change
	Log3($name,4, "fspSCC cmd: analysiere $cmd _Line:" . __LINE__);
	my $a = $values[0];
	Log3($name,5, "fspSCC uebergeben: $a _Line:" . __LINE__);
	readingsBeginUpdate($hash);
		readingsBulkUpdate($hash,"Device_Protocol_ID",$a,1);
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
