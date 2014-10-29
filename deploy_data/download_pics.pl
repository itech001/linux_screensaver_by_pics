#!/usr/bin/perl 

use strict; # Good practice 
use warnings; # Good practice 
use LWP::Simple; # from CPAN 
use LWP::Simple qw($ua); #from CPAN
use JSON qw( decode_json ); # From CPAN 
use Data::Dumper; # Perl core module 
use File::Path qw(make_path remove_tree); 
use POSIX qw(strftime);
use Getopt::Long;
use Data::GUID; #from CPAN
use File::Basename;
use Sys::HostAddr; #from CPAN
use Fcntl ':flock';
use Fcntl qw(LOCK_EX LOCK_NB);
use File::NFSLock;

### get options 
my $url = 'http://localhost:8000/online_pics.json'; 
my $save_to = "/mnt/screensaver/";
my $random_delay = 5; #minutes
my $verbose = 0;
my $help  = 0; 
my $debug = 0;
my $timeout = 15; #15 minutes for this script
my $log_file = '';
my $progname = $0; $progname =~ s@.*/@@g;

my $min_image_width  = 255;
my $min_image_height = 255;

sub usage(){
  print "$progname -json_url <string> -save_to <string> [-log_file <string>] [-debug] [-random_delay <int>]";
}

my $result = GetOptions(
   "json_url=s" => \$url,#string
   "save_to=s" => \$save_to,#string
   "log_file=s" => \$log_file, #string
   "random_delay=i" => \$random_delay, #int
   "quiet"     => sub { $verbose = 0 },
   "debug"     => \$debug,
   "help|?"    => \$help
);
if(!$result){ print STDERR "parameters error\n"; &usage(); exit 1;}

if($help){&usage(); exit 0;}

### check parameters
if(!-e "$save_to"){
 my $err;
 make_path("$save_to",{error => \$err});
 if(!$err){ print STDERR "$err\n"; exit 1; }
}
my $save_to_current = "$save_to/current";
my $save_to_default = "$save_to/default";
my $save_to_used = "$save_to/used";
if(!-e "$save_to_current") { make_path("$save_to_current");}
if(!-e "$save_to_default") { make_path("$save_to_default");}

my $sysaddr = Sys::HostAddr->new();
my $log_name = $sysaddr->main_ip();
$log_file = "$save_to/.${log_name}.log";
open(my $fh, "+>", "$log_file");
if(!$fh){ print STDERR "failed to open log file $log_file\n";}

&log("url: $url\n");
&log("save to: $save_to\n");
&log("max delay: $random_delay minutes\n");
&log("log file: $log_file\n");


### random delay to avoid too many server requests at the same time
my $start_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
&log( "start time: $start_time\n" );
if($random_delay > 0){
  my $seconds = $random_delay * 60;
  my $random = rand($seconds);
  &log("delay $random seconds\n");
  sleep($random);
}


### checking if other processes are running
my $run_flag = "$save_to/.running";
my $times = 0;
while(-e "$run_flag"){
  my $threshhold = $timeout * 60;
  my $currenttime = time;
  my $mtime = (stat($run_flag))[9];
  my $delta =  $currenttime - $mtime;
  &log("the running flag was created " . $delta/60 . " minutes ago\n");
  if( ($delta) > $threshhold){
      &log("the running flag is too old, touch running flag file $run_flag\n");
      system("touch $run_flag; chmod a+w $run_flag");
      last;
  }else{
    if($times >= 3){
      &log("tried 3 times, but still has new running flags, will exit\n");
      &end(1);
    }
    &log("other instances are running, will wait $timeout minutes and then check running flag again\n");
    sleep($timeout * 60); # assume the script finishes in timeout minutes
  }
  $times++; 
}

if(!-e "$run_flag"){
  &log("touch running flag file $run_flag\n");
  system("touch $run_flag; chmod a+w $run_flag");
}


### start time
my $start_time_delay = strftime "%Y-%m-%d %H:%M:%S", localtime;
&log( "start time after delay: $start_time_delay\n" );


### get json
$ua->timeout (120);
my $json = get($url);
if(! defined($json)){
 &log_error("cannot get json with the error $!\n");
 end(1);
}
my $decoded_json = decode_json( $json );
&log( Dumper $decoded_json);

### get image list
my $version = 0;
my $version_old = 0;
my $img_list = [];
my $img_default = [];
$version = $decoded_json->{"version"};
$img_list = $decoded_json->{"pictures"};
$img_default = $decoded_json->{"image_default"};
if ( ! defined($version) || !defined($img_list)){
  &log_error( "json format error\n" );
  end(1);
}


### check if need download
&log( "latest version is $version\n" );
my $version_file = "$save_to/.version_file";
$version_old = &get_current_version();
&log( "old version is $version_old\n" );
if($version eq '' or $version <= $version_old){
  &log( "no new version was found.\n" );
  end(0);
}


### check if need switch to default
if(scalar(@$img_list) == 0 ){
  &log("no new images, will use default, symlink from $save_to_default to $save_to_used\n");
  if ( -l "$save_to_used" ) {
     #unlink("$save_to_used") or &log("failed to remove file $save_to_used: $!\n");
     my $ret = system("rm -rf $save_to_used");
     if($ret){&log("failed to remove link $save_to_used\n");}
  } 
  #symlink("$save_to_default", "$save_to_used");   
  my $ret = system("ln -s $save_to_default $save_to_used");
  if($ret){&log("failed to create link from $save_to_default to $save_to_used\n");}
  end(0);
}

my $save_to_tmp_g = '';

### download pics with timeout setting
eval {
    local $SIG{ALRM} = sub { die "timeout\n" };

    my $to = $timeout - $random_delay;
    $to = $timeout if $to <= 0;
    alarm $to * 60; 
    &log("send alarm singal to timeout after $to minutes\n");

    #download 
    my $r = 1;
    $r = download_pics($img_list,$save_to_current,1);
    if(!$r){
      &save_current_version($version);
      &log("download successfully\n");
      end(0);
    }else{
      &log_error("download failed,will exit\n");
      end(1);
    }
    
    # restet alarm
    alarm 0;
    1;
} or do {
    if( $@ eq "timeout\n"){
      &log_error("download timeout,exit\n");
      &log("download fail, remove tmp $save_to_tmp_g\n");
      system("rm -rf $save_to_tmp_g") if -e "$save_to_tmp_g";
      end(1);
    }else{
      &log("download failed for reason $@, will exit\n"); 
      &log("download fail, remove tmp $save_to_tmp_g\n");
      system("rm -rf $save_to_tmp_g") if -e "$save_to_tmp_g";
      end(1);
    }
    alarm 0;
};

### end
end(1);


### common functions
sub download_pic{
  my ($img,$filename) = @_;
  $ua->timeout (120);  # 2 minutes for eery image download 
  my $rc = getstore($img, $filename);
  if (is_error($rc)) {
    return 1, "download <$img> failed with $rc\n";
  }else{
    return 0, "download $img successfully to $filename\n";
  }
}
sub download_pics{
  my ($img_list,$save_to_dir,$is_update_used_link) = @_;
  my $guid = Data::GUID->new;
  my $tmp = $guid->as_string; 
  my $save_to_tmp = dirname($save_to_dir) . '/' . $tmp;
  if(!-e "$save_to_tmp") { make_path("$save_to_tmp");}
  $save_to_tmp_g = $save_to_tmp;
  my $i = 0;
  my $s = 0; # suceesful
  for my $img (@$img_list){
    my $filename = "$save_to_tmp/$i".".jpg";
    my ($r, $m) = download_pic($img,$filename);
    &log($m);
    if($r){$s = -1; &end(1);}
    my $r2 = &large_enough_p($filename);
    if(!$r2){
      &log_error("too small for the image $filename\n");
      $s = -1;
      &end(1);
     }else{
       &log("the image size is ok\n");
     } 
    $i++;
  }
  if($s == 0){
    my $ret = 1;
    &log("remove ${save_to_dir}.bak\n");
    #remove_tree("${save_to_dir}.bak");
    $ret = system("rm -rf ${save_to_dir}.bak");
    if($ret){ &log("failed to remove ${save_to_dir}.bak\n")};

    &log("rename from $save_to_dir to ${save_to_dir}.bak\n");
    #rename($save_to_dir, "${save_to_dir}.bak");
    $ret = system("mv $save_to_dir ${save_to_dir}.bak");
    if($ret){&log("failed to move from $save_to_dir to ${save_to_dir}.bak\n");}

    &log("rename from $save_to_tmp to $save_to_dir\n");
    #rename($save_to_tmp,$save_to_dir);
    $ret = system("mv $save_to_tmp $save_to_dir");
    if($ret){&log("failed to move from $save_to_tmp to $save_to_dir\n");}
    
    if($is_update_used_link){
      &log("symlink from $save_to_dir to $save_to_used\n");
      if ( -l "$save_to_used" ) {
         #unlink("$save_to_used") or &log("failed to remove file $save_to_used: $!\n");
         $ret = system("rm -rf $save_to_used");
         if($ret){&log("failed to remove link $save_to_used\n");}
      } 
      #symlink($save_to_dir, $save_to_used);  
      $ret = system("ln -s $save_to_dir $save_to_used");
      if($ret){&log("failed to create link from $save_to_dir to $save_to_used\n");}
    }
    return 0;
  }else{
    &log("download fail, remove tmp $save_to_tmp\n");
    system("rm -rf $save_to_tmp") if -e "$save_to_tmp";
    return 1;
  }
}

sub end{
  my $code = shift;
  if( -e "$run_flag"){ system("rm $run_flag"); &log("remove running flag $run_flag\n");}
  my $end_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
  &log("end time: $end_time\n");
  if($code){
    &log("FAIL\n");
  }else{
    &log("SUCCESS\n");
  }
  close $fh;
  exit $code;
}
sub log{
  my $msg = shift;
  print $fh $msg if defined $fh;
  if($debug){print $msg;}
}
sub log_error{
  my $msg = shift;
  print $fh $msg if defined $fh;
  if($debug){print STDERR $msg;}
}
sub get_current_version(){
  if(!-e "$version_file") { return -1;}
  open(my $f, '<', $version_file);
  if(!defined($f)){ 
    &log("Could not open file '$version_file' with the error $!");
    return -1;
  }
  while (my $row = <$f>) {
  chomp $row;
  if(defined($row) && $row >=0 ){ close($f);return $row;}
  }
  close($f);
  return -1;
}
sub save_current_version($){
 my $version = shift;
 my $lock = File::NFSLock->new($version_file,LOCK_EX,60);
 if(!$lock){ &log("cannot lock for version file write\n");}
 open(my $f, "+>", "$version_file");
 if(!defined($f)){
   &log("Error:failed to save version.\n");
   return;
 }
 #flock($f, LOCK_EX);
 print $f "$version";
 close($f);
 $lock->unlock() if $lock;
 &log("current version $version was saved in $version_file\n");
}
 
sub large_enough_p($) {
  my ($file) = @_;

  my ($w, $h) = image_file_size ($file);

  if (!defined ($h)) {
    &log("$file: unable to determine image size\n");
    # Assume that unknown files are of good sizes: this will happen if
    # they matched $good_file_re, but we don't have code to parse them.
    # (This will also happen if the file is junk...)
    return 1;
  }

  if ($w < $min_image_width || $h < $min_image_height) {
    &log("$file: too small ($w x $h)\n");
    return 0;
  }

  print STDERR " $file: $w x $h\n" if ($verbose);
  return 1;
}



# Given the raw body of a GIF document, returns the dimensions of the image.
#
sub gif_size($) {
  my ($body) = @_;
  my $type = substr($body, 0, 6);
  my $s;
  return () unless ($type =~ /GIF8[7,9]a/);
  $s = substr ($body, 6, 10);
  my ($a,$b,$c,$d) = unpack ("C"x4, $s);
  return (($b<<8|$a), ($d<<8|$c));
}

# Given the raw body of a JPEG document, returns the dimensions of the image.
#
sub jpeg_size($) {
  my ($body) = @_;
  my $i = 0;
  my $L = length($body);

  my $c1 = substr($body, $i, 1); $i++;
  my $c2 = substr($body, $i, 1); $i++;
  return () unless (ord($c1) == 0xFF && ord($c2) == 0xD8);

  my $ch = "0";
  while (ord($ch) != 0xDA && $i < $L) {
    # Find next marker, beginning with 0xFF.
    while (ord($ch) != 0xFF) {
      return () if (length($body) <= $i);
      $ch = substr($body, $i, 1); $i++;
    }
    # markers can be padded with any number of 0xFF.
    while (ord($ch) == 0xFF) {
      return () if (length($body) <= $i);
      $ch = substr($body, $i, 1); $i++;
    }

    # $ch contains the value of the marker.
    my $marker = ord($ch);

    if (($marker >= 0xC0) &&
        ($marker <= 0xCF) &&
        ($marker != 0xC4) &&
        ($marker != 0xCC)) {  # it's a SOFn marker
      $i += 3;
      return () if (length($body) <= $i);
      my $s = substr($body, $i, 4); $i += 4;
      my ($a,$b,$c,$d) = unpack("C"x4, $s);
      return (($c<<8|$d), ($a<<8|$b));

    } else {
      # We must skip variables, since FFs in variable names aren't
      # valid JPEG markers.
      return () if (length($body) <= $i);
      my $s = substr($body, $i, 2); $i += 2;
      my ($c1, $c2) = unpack ("C"x2, $s);
      my $length = ($c1 << 8) | $c2;
      return () if ($length < 2);
      $i += $length-2;
    }
  }
  return ();
}

# Given the raw body of a PNG document, returns the dimensions of the image.
#
sub png_size($) {
  my ($body) = @_;
  return () unless ($body =~ m/^\211PNG\r/s);
  my ($bits) = ($body =~ m/^.{12}(.{12})/s);
  return () unless defined ($bits);
  return () unless ($bits =~ /^IHDR/);
  my ($ign, $w, $h) = unpack("a4N2", $bits);
  return ($w, $h);
}


# Given the raw body of a GIF, JPEG, or PNG document, returns the dimensions
# of the image.
#
sub image_size($) {
  my ($body) = @_;
  return () if (length($body) < 10);
  my ($w, $h) = gif_size ($body);
  if ($w && $h) { return ($w, $h); }
  ($w, $h) = jpeg_size ($body);
  if ($w && $h) { return ($w, $h); }
  # #### TODO: need image parsers for TIFF, XPM, XBM.
  return png_size ($body);
}

# Returns the dimensions of the image file.
#
sub image_file_size($) {
  my ($file) = @_;
  my $in;
  if (! open ($in, '<', $file)) {
    &log(" $file: $!\n") ;
    return undef;
  }
  binmode ($in);  # Larry can take Unicode and shove it up his ass sideways.
  my $body = '';
  sysread ($in, $body, 1024 * 50);  # The first 50k should be enough.
  close $in;			    # (It's not for certain huge jpegs...
  return image_size ($body);	    # but we know they're huge!)
}
