#!/usr/bin/perl
#==============================================================================#
# Implentation of a full linux client for the Twisplay                    v0.01a
#==============================================================================#
#
# Take full Control of an NS-500UA LED Marquee, aka "Twisplay"
#
#
#
#==============================================================================#
#
# Copyright 2010   Gavin McDonald.  < me@gavitron.com >
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#==============================================================================#
#
use utf8;
use CGI;
use JSON;
use Encode;
use Net::Twitter;
use Data::Dumper;
use HTML::Entities qw(decode_entities);
use Text::Unidecode;

#==============================================================================#
#  Configuration Settings

my $false = (2==1);
my $true = not $false;

# TODO: clean this up to use Config::Ini
require 'config.pl'

#==============================================================================#
#  Global Variable Initialization

$prop=chr(0xEF);

# run Modes
%mode =(
    'cyclic'		=> chr(0x01),
    'immediate'		=> chr(0x02),
    'openleft'		=> chr(0x03),
    'openright'		=> chr(0x04),
    'openctr'		=> chr(0x05),
    'opentoctr'		=> chr(0x06),
    'cvrctr'		=> chr(0x07),
    'coverleft'		=> chr(0x08),
    'coverright'	=> chr(0x09),
    'cvrtoctr'		=> chr(0x0A),
    'scrollup'		=> chr(0x0B),
    'scrolldn'		=> chr(0x0C),
    'interlace1'	=> chr(0x0D),
    'interlace2'	=> chr(0x0E),
    'coverup'		=> chr(0x0F),
    'coverdown'		=> chr(0x10),
    'scanline'		=> chr(0x11),
    'explode'		=> chr(0x12),
    'pacman'		=> chr(0x13),
    'stack'			=> chr(0x14),
    'shoot'			=> chr(0x15),
    'flash'			=> chr(0x16),
    'random'		=> chr(0x17),
    'slidein'		=> chr(0x18),
    'auto'			=> chr(0x19),
);

# insertable "special characters"
%token = (
    'sun'			=> $prop.chr(0x60),
    'cloud'			=> $prop.chr(0x61),
    'rain'			=> $prop.chr(0x62),
    'clock'			=> $prop.chr(0x63),
    'phone'			=> $prop.chr(0x64),
    'specs'			=> $prop.chr(0x65),
    'tap'			=> $prop.chr(0x66),
    'rocket'		=> $prop.chr(0x67),
    'bug'			=> $prop.chr(0x68),
    'key'			=> $prop.chr(0x69),
    'shirt'			=> $prop.chr(0x6A),
    'heli'			=> $prop.chr(0x6B),
    'car'			=> $prop.chr(0x6C),
    'tank'			=> $prop.chr(0x6D),
    'house'			=> $prop.chr(0x6E),
    'teapot'		=> $prop.chr(0x6F),
    'trees'			=> $prop.chr(0x70),
    'duck'			=> $prop.chr(0x71),
    'moped'			=> $prop.chr(0x72),
    'bike'			=> $prop.chr(0x73),
    'crown'			=> $prop.chr(0x74),
    'hearts'		=> $prop.chr(0x75),
    'arrowR'		=> $prop.chr(0x76),
    'arrowL'		=> $prop.chr(0x77),
    'arrowDL'		=> $prop.chr(0x78),
    'arrowUL'		=> $prop.chr(0x79),
    'cup'			=> $prop.chr(0x7A),
    'chair'			=> $prop.chr(0x7B),
    'shoe'			=> $prop.chr(0x7C),
    'glass'			=> $prop.chr(0x7D),
);
@token_subset = qw/clock phone specs rocket key shirt heli car tank house teapot trees duck moped bike hearts cup shoe glass/;

%sys = (
    'time'			=> $prop.chr(0x80),
    'date'			=> $prop.chr(0x81),
    'temp'			=> $prop.chr(0x82), # Doesn't work on the NS-500UA
);

# 8 built-in animations
%anim = (
    'MERRYXMAS'			=> $prop.chr(0x90),
    'HAPPYNEWYEAR'		=> $prop.chr(0x91),
    '4THJULY'			=> $prop.chr(0x92),
    'HAPPYEASTER'		=> $prop.chr(0x93),
    'HALLOWEEN'			=> $prop.chr(0x94),
    'DONTDRINKDRIVE'	=> $prop.chr(0x95),
    'NOSMOKING'			=> $prop.chr(0x96),
    'WELCOME'			=> $prop.chr(0x97),
);

# Manual says "six" fonts, not 7.  TODO: test to 0xAF
%font = (
    'small'	=> $prop.chr(0xA0), # Small
    'boxy'	=> $prop.chr(0xA1), # Boxy
    'norm'	=> $prop.chr(0xA2), # Normal
    'p.fat'	=> $prop.chr(0xA3), # Pretty Fat
    'fat'	=> $prop.chr(0xA4), # Fat
    'v.fat'	=> $prop.chr(0xA5), # Super fat
    'tiny'	=> $prop.chr(0xA6), # Small fonts
);

# The NS-500UA supports only one color.  I guess ours isn't the 500UA...?
%color = (
'BrightRed'        => $prop.chr(0xB0),
'DarkRed'          => $prop.chr(0xB1),
'Orange'           => $prop.chr(0xB2),
'Yellow'           => $prop.chr(0xB3),
'DarkYellow'       => $prop.chr(0xB4),
'BrightYellow'     => $prop.chr(0xB5),
'DarkGreen'        => $prop.chr(0xB6),
'Green'            => $prop.chr(0xB7),
);
# these colors don't look as nice as the solids, so I split them out.
%inv_color = (
'CandyCorn'        => $prop.chr(0xB8),
'Jamaica'          => $prop.chr(0xB9),
'Portugal'         => $prop.chr(0xBA),
'XMAS'             => $prop.chr(0xBB),
'GreenOnRed'       => $prop.chr(0xBC),
'RedOnGreen'       => $prop.chr(0xBD),
'YellowOnRed'      => $prop.chr(0xBE),
'YellowOnGreen'    => $prop.chr(0xBF),
);
# As a Canuck, I have to do this:
%colour = \%color;
%inv_colour = \%inv_color;

%speed = (
    'fastest'	=> $prop.chr(0xC0),
    'faster'	=> $prop.chr(0xC1),
    'fast'		=> $prop.chr(0xC2),
    'average'	=> $prop.chr(0xC3),
    'normal'	=> $prop.chr(0xC4),
    'slow'		=> $prop.chr(0xC5),
    'slower'	=> $prop.chr(0xC6),
    'slowest'	=> $prop.chr(0xC7),
);

%pause = (
    'PAUSE1'	=> $prop.chr(0xC8),
    'PAUSE2'	=> $prop.chr(0xC9),
    'PAUSE3'	=> $prop.chr(0xCA),
    'PAUSE4'	=> $prop.chr(0xCB),
    'PAUSE5'	=> $prop.chr(0xCC),
    'PAUSE6'	=> $prop.chr(0xCD),
    'PAUSE7'	=> $prop.chr(0xCE),
    'PAUSE8'	=> $prop.chr(0xCF),
);

%graphic = (
    'USER0'		=> $prop.chr(0xD0),
    'USER1'		=> $prop.chr(0xD1),
    'USER2'		=> $prop.chr(0xD2),
    'USER3'		=> $prop.chr(0xD3),
    'USER4'		=> $prop.chr(0xD4),
    'USER5'		=> $prop.chr(0xD5),
    'USER6'		=> $prop.chr(0xD6),
    'USER7'		=> $prop.chr(0xD7),
    'CITYSCAPE'	=> $prop.chr(0xD8),
    'TRAFFIC'	=> $prop.chr(0xD9),
    'TEAPARTY'	=> $prop.chr(0xDA),
    'TELEPHONE'	=> $prop.chr(0xDB),
    'SUNSET'	=> $prop.chr(0xDC),
    'CARGOSHIP'	=> $prop.chr(0xDD),
    'SWIMMERS'	=> $prop.chr(0xDE),
    'MOUSE'		=> $prop.chr(0xDF),
);

%beep = (
    'BEEP1'		=> $prop.chr(0xE0), # 3 beeps
    'BEEP2'		=> $prop.chr(0xE1), # 3 short beeps
    'BEEP3'		=> $prop.chr(0xE2), # Short beep
    'BEEP4'		=> $prop.chr(0xE3), # More beeps
    'BEEP5'		=> $prop.chr(0xE4), # Short beep
    'BEEP6'		=> $prop.chr(0xE5), # Long beep
    'BEEP7'		=> $prop.chr(0xE6), # More beeps
    'BEEP8'		=> $prop.chr(0xE7), # Continuous beeping long
    'BEEP9'		=> $prop.chr(0xE8), # Continuous beeping short
    'BEEP10'	=> $prop.chr(0xE9), # Beeps
    'BEEP11'	=> $prop.chr(0xEA), # Really long beep
);

#==============================================================================#
#  Function Definitions.                                                       #
#==============================================================================#

#==============================================================================#
# initialize the serial port to sign-specific settings.
# Takes:	nothing
# Returns:	nothing
#
sub initPort {
	$realPort = shift || '/dev/twisplay';
		print "Initializing Serial Port ".$default{'port'}." as $realPort\n";
		system "sudo rm $realPort";
		system "sudo ln -s ".$default{'port'}." $realPort";
		system "sudo chmod 777 $realPort";
		system "sudo stty -F ".$default{'port'}." raw speed 2400 -crtscts cs8 -parenb -cstopb ";
}

sub initLock {
		print "Clearing LockDir\n";
		system "sudo rm -rf $lockDir";
		system "sudo mkdir -p $lockDir";
		system "sudo chown $< $lockDir";
}

#==============================================================================#
# helper function to return a random byte from the given lookup table
# Takes:   a hash name
# Returns: the bytes for a random symbol in the given hash
#

sub randByte {
	$type=shift;
	@tags=keys %$type;
	return $$type{$tags[int(rand(@tags))]};
}

#==============================================================================#
# helper functions to wrap the above function into no-argument functions
# Takes:   nothing
# Returns: a random byte from the named hash.
#
sub randMode { return $mode{'random'}; }
sub randToken { return randByte('token'); }
sub randSubsetToken { return $token{$token_subset[rand(@token_subset)]};}
sub randAnim { return randByte('anim'); }
sub randFont { return randByte('font'); }
sub randColor { return randByte('color'); }
sub randInv_color {	return randByte('inv_color'); }
sub randSpeed {	return randByte('speed'); }
sub randPause {	return randByte('pause'); }
sub randGraphic { return randByte('graphic'); }
sub randBeep { return randByte('beep'); }

my $rs = \&randToken;

#==============================================================================#
# send raw bytes over the serial port
# Takes:   String Data
# Returns: nothing
#
sub sendBytes {
	$port = $default{'real'} || '/dev/twisplay';
	if (open(PORT,">".$port)) {
		print PORT @_;
		close PORT;
	} else {
		print STDERR $prog_name.": unable to open ".$port." for writing!\n";
	}
}

#==============================================================================#
# Upload a custom graphic to the sign
# Takes:   sign data
# Returns: nothing
#
sub b2d {
    return chr(unpack("N", pack("B32", substr("0" x 32 . shift, -32))));
}

sub b2c {
	$bin=shift;
	$out='';
	$len=length($bin);
	$num=$len/8;
#	print "$len $num \n";
	for ($i=0;$i<(length($bin)/8);$i++) {
#		print substr($bin, 8*$i, 8);
		$out.= b2d(substr($bin, 8*$i, 8));
	}
    return $out;
}

sub setGfx {
	my $out = "";
	# Start Data Frame
	$out.=chr(0x00); # Leading code for sign addresses
	$out.=chr(0xFF).chr(0xFF); # For all signs
	$out.=chr(0x00); # clear messages = 0x01
	# sign-list Frame
	$out.=chr(0x0B).chr(0x01).chr(0xFF);  #these be magic bytes, don't lose them!

	# set gfx code
	$out.=chr(0x09);

	$out.='0';  #USER0 ?
###########

#Red1
$out.=b2c('00111111111111110000000111111111111111111111111111111111111111111111111111111100');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
$out.=b2c('00000000000000000000000000000000000000000000000000000000000000000000000000000000');
#Red2
$out.=b2c('00111111111111110000000111111111111111111111111111111111111111111111111111111100');
$out.=b2c('00000000100001110000000111000000100000000001000000000010000001000000000100000110');
$out.=b2c('00000000100001110000000111000000100000000001000000000010000001000000000100000110');
$out.=b2c('00000000100001110011100111000000100000000001000000000010000001111110000111111100');
$out.=b2c('00000000100001110111110111000000100000000001000000000010000001000000000100000110');
$out.=b2c('00000000100000111110111110000000100000000001000000000010000001000000000100000110');
$out.=b2c('00000000100000011100011100111100111110000001000000000010000001111111100100000110');
#Green
$out.=b2c('00111111111111110000000111111111111111111111111111111111111111111111111111111100');
$out.=b2c('00000010000001110000000111000010000000000100000000001000000100000000010000010010');
$out.=b2c('00000010000001110000000111000010000000000100000000001000000100000000010000010010');
$out.=b2c('00000010000001110011100111000010000000000100000000001000000100111110010011111100');
$out.=b2c('00000010000001110111110111000010000000000100000000001000000100000000010000010010');
$out.=b2c('00000010000000111110111110000010000000000100000000001000000100000000010000010010');
$out.=b2c('00000010000000011100011100111110011110000100000000001000000100111111110000010010');
#Green
$out.=b2c('00111111111111110000000111111111111111111111111111111111111111111111111111111100');
$out.=b2c('00000001000001110000000111000001000000000010000000000100000010000000001000001010');
$out.=b2c('00000001000001110000000111000001000000000010000000000100000010000000001000001010');
$out.=b2c('00000001000001110011100111000001000000000010000000000100000010111110001111111100');
$out.=b2c('00000001000001110111110111000001000000000010000000000100000010000000001000001010');
$out.=b2c('00000001000000111110111110000001000000000010000000000100000010000000001000001010');
$out.=b2c('00000001000000011100011100111101011110000010000000000100000010111111101000001010');

##########
	# End of File(s) Frame
	$out.= chr(0xFF);
	# End of Data Frame
	$out.= chr(0x00);
	sendBytes($out);
}

#==============================================================================#
# Set the sign time.  Can't send messages immediately after this data frame.
# Takes:   nothing
# Returns: nothing
#
sub setTime {
	my $out = "";
	# Start Data Frame
	$out.=chr(0x00); # Leading code for sign addresses
	$out.=chr(0xFF).chr(0xFF); # For all signs
	$out.=chr(0x00); # clear messages = 0x01
	# sign-list Frame
	$out.=chr(0x0B).chr(0x01).chr(0xFF);  #these be magic bytes, don't lose them!


	# set date flag
	$out.=chr(0x08);

	$out.='3'; # Day of week, 0=Sun
	$out.=chr(0x00);  # 0=24-hour mode
	$out.='101103205500'; #  YYMMDDHHMMSS

	# End of File(s) Frame
	$out.= chr(0xFF);
	# End Data Frame
	$out.= chr(0x00);
	sendBytes($out);
}

#==============================================================================#
# wrap a message with the required control bytes, then pass it to sendBytes
# Takes:   Message String, File Number. (usually file "01")
# Returns: nothing
#
sub sendMessage {
	my $out = "";
	# Start Data Frame
	$out.=chr(0x00); # Leading code for sign addresses
	$out.=chr(0xFF).chr(0xFF); # For all signs
	$out.=chr(0x00); # clear messages = 0x01
	# sign-list Frame
	$out.=chr(0x0B).chr(0x01).chr(0xFF);  #these be magic bytes, don't lose them!
	# start File(s) frame
	$out.=chr(0x01);
	# Which file to use.
	#$out.=$default{'file'};
	$out.='01';
	# Send the actual 'file' to display,
	foreach $frame (@_) {
		$out.=$frame;
	}
	# End of File(s) Frame
	$out.= chr(0xFF);
	# End Data Frame
	$out.= chr(0x00);
	sendBytes($out);
}

#==============================================================================#
# wrap a message with the required control bytes, then pass it to sendBytes
# Takes:   Message String, File Number. (usually file "01")
# Returns: nothing
#
sub makeFrame {
	my $msg = shift;
	my $fnt = shift || randFont();
	my $clr = shift || randColor();
	my $run = shift || $mode{'auto'};

	return $run.$clr.$fnt.$msg.chr(0xFF);
}

#==============================================================================#
# grab a list of tweets matching $hashtag via the twitter API
# Takes:	the hashtag to search for (no leading # sign...)
# Returns:	an array of strings, each containing a from:msg pair
#

sub getTweets {
	my $hashtag = shift || "gavitron";
	$hashtag=CGI::escape($hashtag);
	my @results;

	my $nt = Net::Twitter->new(
		ssl                 => 1,  ## enable SSL! ##
        traits   => [qw/API::RESTv1_1/],
		consumer_key        => $default{'consumer_key'},
		consumer_secret     => $default{'consumer_secret'},
		access_token        => $default{'token'},
		access_token_secret => $default{'token_secret'},
	);

	my $tweets = $nt->search({
						q => $hashtag,
						result_type => "recent",
						count => $default{'tweet_count'},
						include_entities => $false,
					} );
	if (defined $tweets) {
		if ( @{$$tweets{'errors'}} ) {
			foreach $element ( @{$$tweets{'errors'}}) {
				my $tweet = "ERROR ${$element}{'code'}: ${$element}{'message'}";
				#unescape html encoded characters:
				$tweet = decode_entities($tweet);
				# strip unicode chars, and swap with random symbols.
				#$tweet =~ s/[^[:ascii:]]+/$rs->()/ge;
				push @results, $token{'crown'}.unidecode($tweet);
				print $tweet."\n";
			}
		}
		if ( @{$$tweets{'statuses'}} ) {
			foreach $element ( @{$$tweets{'statuses'}}) {
				my $tweet = "\@${$element}{'user'}{'screen_name'}: ${$element}{'text'}";
				#unescape html encoded characters:
				$tweet = decode_entities($tweet);
				# strip unicode chars, and swap with random symbols.
				#$tweet =~ s/[^[:ascii:]]+/$rs->()/ge;
				push @results, randSubsetToken().unidecode($tweet);
				print $tweet."\n";
			}
		}
	} else {
		push @results, $token{'crown'}."ERROR: unable to parse response as JSON";
	}
	return @results;
}

sub do_oauth {
	my $nt = Net::Twitter->new(
        traits   => [qw/API::RESTv1_1/],
		consumer_key        => $default{'consumer_key'},
		consumer_secret     => $default{'consumer_secret'},
	);

	# The client is not yet authorized: Do it now
    print "Authorize this app at ", $nt->get_authorization_url, " and enter the PIN#\n";

    my $pin = <STDIN>; # wait for input
    chomp $pin;

    my($access_token, $access_token_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $pin);

	print "my \$twitterId = '$user_id'; # $screen_name\n";
	print "my \$token = '$access_token'; # $screen_name\n";
	print "my \$token_secret = '$access_token_secret'; # $screen_name\n";
	exit 0;
}

#==============================================================================#
#  Begin the main block.                                                       #
#==============================================================================#
$|=1;	# Set autoflush to true.
my $sem=0;
die "locked!\n" if -e $lockDir."lockfile";
system ("touch",$lockDir."lockfile");
$sem=1;
my $arg = shift;
my @hash = $default{'hash'};
my @messages;

if (($arg eq "-h") || ($arg eq "--help")) {
	print "-h --help\n";
	print "-i --init\n";
	print "-D --deps\n";
	print "-l --lock\n";
	print "-m --message\n";
	print "-g --gfx\n";
	print "-s --settime\n";
	print "-t --hashtag\n";
	print "-d --debug\n";
	print "\n";
	exit 0;
} elsif (($arg eq "-D") || ($arg eq "--deps")) {
	`apt-get install libjson-perl libnet-twitter-perl libtext-unidecode-perl`;
	exit 0;
} elsif (($arg eq "-i") || ($arg eq "--init")) {
	initPort();
	initLock();
	exit 0;
} elsif (($arg eq "-l") || ($arg eq "--lock")) {
	initLock();
	exit 0;
} elsif (($arg eq "-m") || ($arg eq "--message")) {
	push @messages, makeFrame(join(" ",@ARGV));
} elsif (($arg eq "-g") || ($arg eq "--gfx")) {
	setGfx();
	exit 0;
} elsif (($arg eq "-s") || ($arg eq "--settime")) {
	setTime();
	exit 0;
} elsif (($arg eq "-o") || ($arg eq "--oauth")) {
	do_oauth();
	exit 0;
} elsif (($arg eq "-t") || ($arg eq "--hashtag")) {
	foreach $tweet (getTweets(join(" ",@ARGV))) {
		push @messages, makeFrame($token{'duck'}.$tweet,$font{'tiny'});
	}
} elsif (($arg eq "-d") || ($arg eq "--debug")) {
	#foreach $type (sort keys %graphic) {
#		push @messages, makeFrame("$type: $graphic{$type}",$font{'tiny'},0,$mode{'auto'});
#	}
#	foreach $type (sort keys %token) {
#		push @messages, makeFrame("$type: $token{$type}",$font{'tiny'},0,$mode{'auto'});
#	}
#	foreach $type (sort keys %mode) {
#		push @messages, makeFrame("$type",$font{'tiny'},0,$mode{$type});
#	}
	#push @messages, makeFrame("time is $sys{'time'}",$font{'tiny'},0,$mode{'auto'});
	#push @messages, makeFrame("date is $sys{'date'}",$font{'tiny'},0,$mode{'auto'});
	#push @messages, makeFrame($graphic{'USER0'},$font{'tiny'},0,$mode{'auto'});
#	foreach $type (sort keys %token) {
	foreach $type (@token_subset) {
		$typestr.="$token{$type}  ";
	}
	push @messages, makeFrame("$typestr",$font{'tiny'},0,$mode{'auto'});

} else {
#	if (rand(10) <= 1) {
#		push @messages, makeFrame("Feed me a Stray Cat",$font{'tiny'},0,$mode{'flash'});
#	}
	foreach $item (@hash) {
		foreach $tweet (getTweets($item)) {
			push @messages, makeFrame($tweet,$font{'tiny'});
		}
	}
}

if (@messages) {
	sendMessage @messages;
}

exit 0;
#==============================================================================#
#  The end of the main block.                                                  #
#==============================================================================#

# force a cleanup, no matter how we die.
END{
	system ("rm",$lockDir."lockfile") if ($sem);
}
