##############################################
# $Id: 15_fsp_devel.pm 2016-01-14 09:25:24Z stephanaugustin $
# test 
package main;

use strict;
use warnings;
use Digest::CRC qw(crc);

my %requests_02 = (
	'P003GS' => "5e5030303347530d", # Query General Status ##2 sek
	'P003PS' => "5e5030303350530d" # Query Power Status ## 2 sek
);

my %requests_30 = (
	'P003WS' => "5e5030303357530d", # Query Warning Status ##30 sek
	'P004MOD' => "5e503030344d4f440d" # Query Working Mode ## 30 sek
);


sub
fsp_devel_Initialize($)
{
  my ($hash) = @_;
  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{DefFn}     = "fsp_devel_Define";
  $hash->{SetFn}     = "fsp_devel_Set";
  $hash->{GetFn}     = "fsp_devel_Get";
  $hash->{UndefFn}   = "fsp_devel_Undef";
  $hash->{NotifyFn}    = "fsp_devel_Notify";
  $hash->{ReadFn}    = "fsp_devel_Read";
  $hash->{ReadyFn}    = "fsp_devel_Ready";
$hash->{AttrList}	= $readingFnAttributes;
}

#####################################
sub
fsp_devel_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t][ \t]*", $def);
	
if(@a < 3 || @a > 5){
	my $msg = "wrong syntax: define <name> fsp_devel <device>";
	return $msg;
}	
	my $name = $a[0];
	my $device = $a[2];
 
  $hash->{NAME} = $name;
  ## $hash->DeviceName keeps the name of the io-Device. Without this, DevIO does not work.
  $hash->{DeviceName} = $device;
  $hash->{NOTIFYDEV} 	= "global";
  $hash->{actionQueue} 	= [];
  DevIo_CloseDev($hash) if(DevIo_IsOpen($hash));  
  my $ret = DevIo_OpenDev($hash, 0, "fsp_devel_DoInit" );
  Log3($name, 1, "fsp_devel DevIO_OpenDev_Define" . __LINE__); 
  return $ret;
}


sub
fsp_devel_DoInit($)
{
 my ($hash) = @_;
 my $name = $hash->{NAME};
 Log3($name, 2, "DoInitfkt");
## InternalTimer(gettimeofday()+2,'fsp_devel_TimerSendRequests',$hash);
}
###########################################
#_ready-function for reconnecting the Device
# function is called, when connection is down.
sub fsp_devel_Ready($)
{
  my ($hash) = @_;

	my $name = $hash->{NAME};
	my $ret;
	$ret = DevIo_OpenDev($hash, 1, "fsp_devel_DoInit" );
}
###################################
sub fsp_devel_Notify($$){
my ($hash,$dev) = @_;
my $name = $hash->{NAME};
return;

}
#####################################
sub fsp_devel_Undef($$)
{
  my ($hash, $name) = @_;
  DevIo_CloseDev($hash);         
  return undef;
}
#####################################
sub fsp_devel_Set($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of cmd timer:noArg S005LON:0,1 S012FPADJ"; 
	my $ret;
	my $minInterval = 30;
	Log3($name,5, "fsp_devel argument $a[1] _Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fsp_devel argument fragezeichen" . __LINE__);
	return $usage;
	}
  	if ($a[1] eq "cmd"){
	Log3($name,5, "fsp_devel argument cmd" . __LINE__);
	RemoveInternalTimer($hash); # Stoppe Timer
	DevIo_SimpleWrite($hash,$a[2],1); #sende den Befehl
	$hash->{helper}{recv} = ""; 
	InternalTimer(gettimeofday()+2,'fsp_devel_prepareRequests',$hash);
	
	}
  	if ($a[1] eq "timer"){
	Log3($name,5, "fsp_devel argument timer" . __LINE__);
	InternalTimer(gettimeofday()+2,'fsp_devel_prepareRequests',$hash);
	}
	my $setcmd = $a[1];
	my $setvalue_hex;

	if(defined($a[2]) && $a[2] ne ""){
		$setvalue_hex = unpack "H*", $a[2];
	Log3($name,5, "fsp_devel setvalue $a[2] _Line: " . __LINE__);
	Log3($name,5, "fsp_devel setvalue $setvalue_hex _Line: " . __LINE__);
	}



	if ($setcmd eq "S005LON"){ #en/dis-able power supply to load
		$hash->{helper}{addCMD} = "5e533030354c4f4e". $setvalue_hex ."0d";
	}
	if ($setcmd eq "S012FPADJ"){ # Feeding Grid power Calibrationi
		#S012FPADJm,nnnn
		#m = direktion => +=1; -=0
		#calibration power, range 0-1000
		my $sendstring = "5e53303132465041444a";
		if(defined($a[2]) && $a[2] ne "" && $a[2] != 0 && abs($a[2]) < 1000){
			if($a[2] > 0){
				$sendstring .= "312c"; ## hex für 1
			} else {
				$sendstring .= "302c"; ## hex für 0
			}
			Log3($name,5, "fsp_devel setFn S012FPADJ a2 $a[2] _Line: " . __LINE__);
			my @digits = split ("", $a[2]);
			my $value;
			foreach(@digits) {
				if($_ =~ /[0-9]/){
					$value .= unpack "H*", $_;
				}
			}
			while(length($value) < 8){
				$value = "30" . $value;
			}
			
			
			my $lenval = length($value);
			Log3($name,5, "fsp_devel setFn S012FPADJ laenge $lenval _Line: " . __LINE__);
			$sendstring .= $value;			
			$sendstring .= "0d";
			Log3($name,5, "fsp_devel setFn S012FPADJ $sendstring _Line: " . __LINE__);
		}
		## den Befehl wegsenden
		$hash->{helper}{addCMD} = $sendstring;
		## und danach direkt abfragen, wie die aktuellen Werte sind
		$hash->{helper}{addCMD} = "5e50303036465041444a0d";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
	if ($setcmd eq ""){ #
		$hash->{helper}{addCMD} = "";
	}
}
#####################################
sub fsp_devel_Get($@){
	my ($hash, @a) = @_;
	my $name = $hash->{NAME};
	my $usage = "Unknown argument $a[1], choose one of P003PI:noArg P003ID:noArg P004VFW:noArg P005VFW2:noArg P003MD:noArg P005PIRI:noArg P005FLAG:noArg P002T:noArg P003ET:noArg P004GOV:noArg P004GOF:noArg P005OPMP:noArg P005GPMP:noArg P006MPPTV:noArg P004LST:noArg P003SV:noArg P003DI:noArg P005BATS:noArg P003DM:noArg P004MAR:noArg P004CFS:noArg P005HECS:noArg P006GLTHV:noArg P004FET:noArg P003FT:noArg P005ACCT:noArg P005ACLT:noArg P006FPADJ:noArg P006FPPF:noArg P005AAPF:noArg";
	Log3($name,5, "fsp_devel argument $a[1]_Line: " . __LINE__);
  	if ($a[1] eq "?"){
	Log3($name,5, "fsp_devel argument fragezeichen _Line: " . __LINE__);
	return $usage;
	}

	my $getcmd = $a[1];
	if ($getcmd eq "P003PI"){ # Query Protocol ID
		$hash->{helper}{addCMD} = "5e5030303350490d";
	}

	if ($getcmd eq "P003ID"){ #Query Series Number
		$hash->{helper}{addCMD} = "5e5030303349440d";
		$hash->{helper}{addCMD} = "5e5030303349440d";
	}
	
	if ($getcmd eq "P004VFW"){ #Query CPU Version
		$hash->{helper}{addCMD} = "5e503030345646570d";
	}

	if ($getcmd eq "P005VFW2"){ #Query secondary CPU Version
		$hash->{helper}{addCMD} = "5e50303035564657320d";
	}
	
	if ($getcmd eq "P003MD"){ #Query Device Model
		$hash->{helper}{addCMD} = "5e503030334d440d";
	}

	if ($getcmd eq "P005PIRI"){ # Query rated information
		$hash->{helper}{addCMD} = "5e50303035504952490d";
	}
	if ($getcmd eq "P005FLAG"){ # Query Flag Status
		$hash->{helper}{addCMD} = "5e50303035464c41470d";
	}
	if ($getcmd eq "P002T"){ # Query current Time
		$hash->{helper}{addCMD} = "5e50303032540d";
	}
	if ($getcmd eq "P003ET"){ # Query total generated Energy
		$hash->{helper}{addCMD} = "5e5030303345540d";
	}
	if ($getcmd eq "P010EYyyyynnn"){ # Query generated Energy of year
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P012EMyyyymmnnn"){ #  Query generated Energy of month 
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P014EDyyyymmddnnn"){ #  Query generated Energy of day 
		## Implementierung ist mir grade unwichtig
		#das hier scheint aber interessant
	}
	if ($getcmd eq ""){ #  Query generated Energy of hour 
		## Implementierung ist mir grade unwichtig
	}
	if ($getcmd eq "P004GOV"){ # Query AC input Voltage acceptable range for feed Power
		$hash->{helper}{addCMD} = "5e50303034474f560d";
	}
	if ($getcmd eq "P004GOF"){ # Query AC input frequency acceptable range for feed Power
		$hash->{helper}{addCMD} = "5e50303034474f460d";
	}
	if ($getcmd eq "P005OPMP"){ #Query the maximum output power - durchgestrichen.. 
		$hash->{helper}{addCMD} = "5e503030354f504d500d";
	}
	if ($getcmd eq "P005GPMP"){ # Query the maximum output Power for feeding Grid
		$hash->{helper}{addCMD} = "5e5030303547504d500d";
	}
	if ($getcmd eq "P006MPPTV"){ #Query Solar input MPP acceptable Range
		$hash->{helper}{addCMD} = "5e3030364d505054560d";
	}
	if ($getcmd eq "P004LST"){ #Query LCD Sleeping Time
		$hash->{helper}{addCMD} = "5e503030344c53540d";
	}
	
	if ($getcmd eq "P003SV"){ # Query Solar input Voltage acceptable Range
		$hash->{helper}{addCMD} = "5e5030303353560d";
	}
	if ($getcmd eq "P003DI"){ # Query default Value for changeable Parameter
		$hash->{helper}{addCMD} = "5e5030303344490d";
	}
	if ($getcmd eq "P005BATS"){ # Query Battery Setting
		$hash->{helper}{addCMD} = "5e50303035424154530d";
	}
	if ($getcmd eq "P003DM"){ # Query Machine Model
		$hash->{helper}{addCMD} = "5e50303033444d0d";
	}
	if ($getcmd eq "P004MAR"){ # Query Maschine Adjustable range
		$hash->{helper}{addCMD} = "5e503030344d41520d";
	}
	if ($getcmd eq "P004CFS"){ # Query current Fault Status
		$hash->{helper}{addCMD} = "5e503030344346530d";
	}
	if ($getcmd eq "P006HFSnn"){ # Query history fault parameter
		# unwichtig ?!?
	}
	if ($getcmd eq "P005HECS"){ # Query Energy control Status
		$hash->{helper}{addCMD} = "5e50303035484543530d";
	}
	if ($getcmd eq "P006GLTHV"){ # Query AC input long-lime highest average Power
		$hash->{helper}{addCMD} = "5e50303036474c5448560d";
	}
	if ($getcmd eq "P004FET"){ #Query first generated energy save time
		$hash->{helper}{addCMD} = "5e503030344645540d";
	}
	if ($getcmd eq "P003FT"){ # Query wait time for Feed Power
		$hash->{helper}{addCMD} = "5e5030303346540d";
	}
	if ($getcmd eq "P005ACCT"){ #Query AC charge time bucket
		$hash->{helper}{addCMD} = "5e50303035414343540d";
	}
	if ($getcmd eq "P005ACLT"){ #Query AC supply load time bucket
		$hash->{helper}{addCMD} = "5e5030303541434c540d";
	}
	if ($getcmd eq "P006FPADJ"){ #Query feeding grid power calibration
		## kandidat für automatik? 
		$hash->{helper}{addCMD} = "5e50303036465041444a0d";
	}
	if ($getcmd eq "P006FPPF"){ #Query feed in Power factor
		$hash->{helper}{addCMD} = "5e50303036465050460d";
	}
	if ($getcmd eq "P005AAPF"){ #query auto-adjust PF with power Information (rot gefärbt)
		## kandidat für automatik? 
		$hash->{helper}{addCMD} = "5e50303035414150460d";
	}
}
#######################################
sub fsp_devel_prepareRequests{
	
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,4, "fsp_devel prepareRequests _Line:" . __LINE__);
	#leere das array
	#$hash->{actionQueue} 	= [];
	#fülle das array mit den abzufragenden werten
	foreach my $key (keys %requests_02){ 
		push(@{$hash->{actionQueue}}, $requests_02{$key} );
		Log3($name,4, "fsp_devel prepareRequests key $key value $requests_02{$key}_Line:" . __LINE__);
	}
	my $now = gettimeofday();
	if($now - $hash->{helper}{timer1} > 30){
		foreach my $key (keys %requests_30){ 
			push(@{$hash->{actionQueue}}, $requests_30{$key} );
			Log3($name,4, "fsp_devel prepareRequests key $key value $requests_30{$key}_Line:" . __LINE__);
		}
	$hash->{helper}{timer1} = gettimeofday();
	}
	#rufe sendRequests auf
	fsp_devel_sendRequests($hash);
}


sub fsp_devel_sendRequests{

	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,4, "fsp_devel sendRequests _Line:" . __LINE__);
	# anzahl der Items bestimmen
	if(defined($hash->{helper}{addCMD}) && $hash->{helper}{addCMD} ne ""){
		Log3($name,4, "fsp_devel sendRequests adding manual command _Line:" . __LINE__);
		my $len = @{$hash->{actionQueue}};
		Log3($name,4, "fsp_devel addCMD length $len before adding _Line:" . __LINE__);
		push(@{$hash->{actionQueue}}, $hash->{helper}{addCMD} );
		$len = @{$hash->{actionQueue}};
		Log3($name,4, "fsp_devel addCMD length $len after adding _Line:" . __LINE__);
		$hash->{helper}{addCMD} = "";	
	}
	my $length = @{$hash->{actionQueue}};
	Log3($name,4, "fsp_devel actionQueue length $length _Line:" . __LINE__);
	if($length > 0){
		#nehme den ersten Wert aus dem array und sende ihn
		my $req = pop( @{$hash->{actionQueue}});
		Log3($name,4, "fsp_devel sendRequests sende $req _Line:" . __LINE__);
		DevIo_SimpleWrite($hash,$req,1);
		#tue gar nichts weiter, denn du wirst vom read aufgerufen
	} else {
		#rufe prepareRequests auf
		Log3($name,4, "fsp_devel sendRequests _Line: auf" . __LINE__);
		InternalTimer(gettimeofday()+2,'fsp_devel_prepareRequests',$hash);
	}
}
####################################
sub fsp_devel_Read($$)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	$hash->{CONNECTION} = "established";
	Log3($name,4, "fsp_devel jetzt wird gelesen _Line:" . __LINE__);
        my $buf =  DevIo_SimpleRead($hash);
	Log3($name,5, "fsp_devel buffer: $buf");
	if (!defined($buf)  || $buf eq "")
	{ 
		
		Log3($name,1, "fsp_devel Fehler beim lesen _Line:" . __LINE__);
		$hash->{CONNECTION} = "failed";
		return "error" ;
	}
	$hash->{helper}{recv} .= $buf; 

#	readingsSingleUpdate($hash,"1_recv",$hash->{helper}{recv},1);
	## check if received Data is complete
	#
	my $value = unpack "H*", $hash->{helper}{recv};
	$hash->{helper}{received_hex} = $value;
	if ($value =~ /5e(.*)....0d/){
	
#	readingsSingleUpdate($hash,"1_recv_hex",$1,1);
	
	my @h1 = ($1 =~ /(..)/g);
	my @val2 = map { pack ("H2", $_) } @h1;	
	my $out="";
	foreach my $part (@val2){
		$out .= $part;
	}
	$hash->{helper}{received_ascii} = $out;
#	readingsSingleUpdate($hash,"1_recv_ascii",$out,1);
	fsp_devel_analyzeAnswer($hash);
	$hash->{helper}{recv} = "";
	fsp_devel_sendRequests($hash);
	}
	return;
}
#######################################
sub fsp_devel_analyzeAnswer
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3($name,4, "fsp_devel analyzeAnswer jetzt wird ausgewertet _Line:" . __LINE__);
	my $recString = $hash->{helper}{received_ascii};
	Log3($name,5, "fsp_devel analyzeAnswer ascii $recString _Line:" . __LINE__);
	Log3($name,5, "fsp_devel analyzeAnswer hex $hash->{helper}{received_hex} _Line:" . __LINE__);
	$recString =~ /(....)(.*)/;
	my $order = $1;
	my $data = $2;
	Log3($name,4, "fsp_devel analyzeAnswer_order $1 _Line:" . __LINE__);
	Log3($name,4, "fsp_devel analyzeAnswer_data $2 _Line:" . __LINE__);
	#readingsSingleUpdate($hash,"1_order",$order,1);
	#readingsSingleUpdate($hash,"1_data",$data,1);

## sortieren
	if($order eq "D025"){ ##  Query Series Number, P003ID 
	$data =~ /(..)(.*)/;
	Log3($name,4, "fsp_devel D025 $1 _Line:" . __LINE__);
	Log3($name,4, "fsp_devel D025 $2 _Line:" . __LINE__);
	my $out = substr($2,0,$1);
		readingsSingleUpdate($hash,"SerialNumber",$out,1);
	}elsif($order eq "D101"){ ## Query Power Status, P003PS, 5e5030303350530d
	my @splits = split(",",$data);
	 readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_power_1",int($splits[0]),1);
	 	readingsBulkUpdate($hash,"Solar_input_power_2",int($splits[1]),1);
	 	readingsBulkUpdate($hash,"Solar_input_power_total",int($splits[0]+$splits[1]),1);
	 	readingsBulkUpdate($hash,"Battery_Power",$splits[2],1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_R",int($splits[3]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_S",int($splits[4]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_T",int($splits[5]),1);
	 	readingsBulkUpdate($hash,"AC_input_active_Power_total",int($splits[6]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_R",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_S",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_T",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"AC_output_active_Power_total",int($splits[10]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_R",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_S",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_T",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_output_appearent_Power_total",int($splits[14]),1);
	 	readingsBulkUpdate($hash,"AC_output_power_percentage",int($splits[15]),1);
	 	readingsBulkUpdate($hash,"AC_output_connect_status",$splits[16],1);
	 	readingsBulkUpdate($hash,"Solar_input_work_status_1",$splits[17],1);
	 	readingsBulkUpdate($hash,"Solar_input_work_status_2",$splits[18],1);
	 	readingsBulkUpdate($hash,"Battery_Power_direction",$splits[19],1);
	 	readingsBulkUpdate($hash,"DC-AC_Power_direction",$splits[20],1);
	 	readingsBulkUpdate($hash,"Line_Power_direction",$splits[21],1);
	 readingsEndUpdate($hash,1);
	
	
	}elsif($order eq "D047"){ ## Query Warning Status, P003WS, 5e5030303357530d
	my @splits = split(",",$data);
	 readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_loss_1",int($splits[0]),1);
	 	readingsBulkUpdate($hash,"Solar_input_loss_2",int($splits[1]),1);
	 	readingsBulkUpdate($hash,"Solar_input_too_high_1",$splits[2],1);
	 	readingsBulkUpdate($hash,"Solar_input_too_high_1",int($splits[3]),1);
	 	readingsBulkUpdate($hash,"Battery_under_voltage",int($splits[4]),1);
	 	readingsBulkUpdate($hash,"Battery_low_voltage",int($splits[5]),1);
	 	readingsBulkUpdate($hash,"Battery_disconnected",int($splits[6]),1);
	 	readingsBulkUpdate($hash,"Battery_over_voltage",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"Battery_low_in_hybrid_mode",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"Grid_voltage_too_high",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"Grid_voltage_too_low",int($splits[10]),1);
	 	readingsBulkUpdate($hash,"Grid_frequency_too_high",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"Grid_frequency_too_low",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"Grid_long_time_average_too_high",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_out_of_range",int($splits[14]),1);
	 	readingsBulkUpdate($hash,"AC_input_frequency_out_of_range",int($splits[15]),1);
	 	readingsBulkUpdate($hash,"AC_input_island",int($splits[16]),1);
	 	readingsBulkUpdate($hash,"AC_input_phase_dislocation",$splits[17],1);
	 	readingsBulkUpdate($hash,"Overtemperature",$splits[18],1);
	 	readingsBulkUpdate($hash,"Overload",$splits[19],1);
	 	readingsBulkUpdate($hash,"Emergency_power_off_active",$splits[20],1);
	 	readingsBulkUpdate($hash,"AC_input_wave_terrible",$splits[21],1);
	 readingsEndUpdate($hash,1);
	
	}elsif($order eq "D030"){ ## Query feed in grid calibration, P006FPADJ, 5e50303036465041444a0d
	
	my @splits = split(",",$data);
	
	my $factor= undef;
		$factor = $splits[0] == 0 ? -1 : 1;
		readingsSingleUpdate($hash,"grid_power_calibration_total",int($splits[1])*$factor,1);
		$factor = $splits[2] == 0 ? -1 : 1;
		readingsSingleUpdate($hash,"grid_power_calibration_R",int($splits[3])*$factor,1);
		$factor = $splits[4] == 0 ? -1 : 1;
		readingsSingleUpdate($hash,"grid_power_calibration_S",int($splits[5])*$factor,1);
		$factor = $splits[6] == 0 ? -1 : 1;
		readingsSingleUpdate($hash,"grid_power_calibration_T",int($splits[7])*$factor,1);

	}elsif($order eq "D005"){ ## Query Working Mode, P004MOD, 5e503030344d4f440d
	my $state;
		if($data ==0){
		$state = "Power on Mode";
		} elsif($data ==1){
		$state = "Standby Mode";
		} elsif($data ==2){
		$state = "Bypass Mode";
		} elsif($data ==3){
		$state = "Battery Mode";
		} elsif($data ==4){
		$state = "Fault Mode";
		} elsif($data ==5){
		$state = "Hybrid mode";
		} elsif($data ==6){
		$state = "Charge Mode";
		}

	readingsSingleUpdate($hash,"working_mode",$state,1);
	
	
	}elsif($order eq "D110"){ ## Query Power Status, P003GS, 5e5030303347530d
	my @splits = split(",",$data);

	Log3($name,4, "fsp_devel analyzeAnswer data $data _Line:" . __LINE__);
	my $leng = @splits;
	Log3($name,4, "fsp_devel analyzeAnswer length $leng _Line:" . __LINE__);

	Log3($name,4, "fsp_devel analyzeAnswer 0 $splits[0] _Line:" . __LINE__);

	 readingsBeginUpdate($hash);
	 	readingsBulkUpdate($hash,"Solar_input_voltage_1",int($splits[0])/10,1);
	 	readingsBulkUpdate($hash,"Solar_input_voltage_2",int($splits[1])/10,1);
	 	readingsBulkUpdate($hash,"Solar_input_current_1",int($splits[2])/100,1);
	 	readingsBulkUpdate($hash,"Solar_input_current_2",int($splits[3])/100,1);
	 	readingsBulkUpdate($hash,"Battery_voltage",int($splits[4])/10,1);
	 	readingsBulkUpdate($hash,"Battery_capacity",int($splits[5]),1);
	 	readingsBulkUpdate($hash,"Battery_current",$splits[6]/10,1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_R",int($splits[7]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_S",int($splits[8]),1);
	 	readingsBulkUpdate($hash,"AC_input_voltage_T",int($splits[9]),1);
	 	readingsBulkUpdate($hash,"AC_input_frequency",$splits[10]/100,1);
	 	readingsBulkUpdate($hash,"AC_input_current_R",int($splits[11]),1);
	 	readingsBulkUpdate($hash,"AC_input_current_S",int($splits[12]),1);
	 	readingsBulkUpdate($hash,"AC_input_current_T",int($splits[13]),1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_R",int($splits[14])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_S",int($splits[15])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_voltage_T",int($splits[16])/10,1);
	 	readingsBulkUpdate($hash,"AC_output_frequency",$splits[17]/100,1);
		#Output-Current not available
		#readingsBulkUpdate($hash,"AC_output_current_R",int($splits[18])/10,1);
		#readingsBulkUpdate($hash,"AC_output_current_S",int($splits[19])/10,1);
		#readingsBulkUpdate($hash,"AC_output_current_T",int($splits[20])/10,1);
	 	
		readingsBulkUpdate($hash,"inner_temperature",int($splits[21]),1);
	 	readingsBulkUpdate($hash,"component_max_temperature",int($splits[22]),1);
	 	readingsBulkUpdate($hash,"external_batt_temperature",$splits[23],1);
	 	readingsBulkUpdate($hash,"settings_changed",$splits[24],1);
	 readingsEndUpdate($hash,1);
	}else {
	
		readingsSingleUpdate($hash,"communication",$hash->{helper}{received_hex},1);
	}

	
	
	
	
	return;
}


1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
