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
	if(DevIo_IsOpen($hash)){
		Log3($name,1, "effekta_Ready Device is open");
		return "device already open";
	} else {
		Log3($name,1, "effekta_Ready  Device is closed, trying to open");
		$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
		while(!DevIo_IsOpen($hash)){
			Log3($name,1, "effekta_Ready  Device is closed, opening failed, retrying");
			$ret = DevIo_OpenDev($hash, 1, "effekta_DoInit" );
			sleep 1;
		}
		return "device automatically opened $ret";
	}
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
	my $usage = "Unknown argument $a[1], choose one of qpi:noArg"; 
	Log3($name,1, "effekta argument $a[1]");
  	if ($a[1] eq "?"){
	Log3($name,1, "effekta argument fragezeichen");
	return $usage;
	}
	if(DevIo_IsOpen($hash)){
		Log3($name,1, "effekta Device is open");
		my $get_cmd = lc($a[1]);
		Log3($name,1, "effekta jetzt wird geschrieben");
		DevIo_SimpleWrite($hash,"515049beac0d",1);
		my $data = DevIo_SimpleRead($hash);
		return $data;
	} else {
		Log3($name,1, "effekta Device is closed ");
		return;
	}
##	my @values:

}
#####################################
sub effekta_updateReadings($){
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
	my $buf = DevIo_SimpleRead($hash);
	readingsSingleUpdate($hash,"inputdata",$buf,1);
	
	if(!defined($buf) || $buf eq ""){
	# wird beim versuch, Daten zu lesen, eine geschlossene Verbindung erkannt, wird *undef* zurückgegeben. Es erfolgt ein neuer Verbindungsversuch?
	Log3($name,1, "effekta SimpleRead fehlgeschlagen, was soll ich jetzt tun?");

	return "";
	}
	
}




1;


=pod
=begin html

=end html

=begin html_DE

=end html_DE
=cut
