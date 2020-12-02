#!/usr/bin/perl
#==============================================================================#
# Reference Implentation of a linux client for the Twisplay
#==============================================================================#
#
# Send tweets to an NS-500UA LED Marquee
#
# Put this script in your crontab for regular updates.
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
use JSON;
use Encode;

#==============================================================================#
#  Configuration Settings

my $defaultFile	= "01";				# This shouldn't really change
my $hashtag		= "gavitron";		# Don't actually put '#' here, we take care of that elsewhere
my $port		= "/dev/twisplay";  # to make this, do:
									# cd /dev/
									# sudo ln -s ttyUSB0 twisplay
									# sudo chmod 777 twisplay
									# sudo stty -F /dev/ttyUSB0 raw speed 2400 -crtscts cs8 -parenb -cstopb

#==============================================================================#
#  Global Variable Initialization

%byte = (

	# Control bytes
    'START' => chr(0xFF),
    'END'	=> chr(0xEF).chr(0xB0).chr(0xEF).chr(0xA2), # Default color and font
    "\n"	=> chr(0xFF),	# Line break

	# Animation Modes
    'CYCLIC'			=> $byte{'START'}.chr(0x01).$byte{'END'},
    'IMMEDIATE'			=> $byte{'START'}.chr(0x02).$byte{'END'},
    'OPENFROMRIGHT'		=> $byte{'START'}.chr(0x03).$byte{'END'},
    'OPENFROMLEFT'		=> $byte{'START'}.chr(0x04).$byte{'END'},
    'OPENFROMCENTER'	=> $byte{'START'}.chr(0x05).$byte{'END'},
    'OPENTOCENTER'		=> $byte{'START'}.chr(0x06).$byte{'END'},
    'COVERFROMCENTER'	=> $byte{'START'}.chr(0x07).$byte{'END'},
    'COVERFROMRIGHT'	=> $byte{'START'}.chr(0x08).$byte{'END'},
    'COVERFROMLEFT'		=> $byte{'START'}.chr(0x09).$byte{'END'},
    'COVERTOCENTER'		=> $byte{'START'}.chr(0x0A).$byte{'END'},
    'SCROLLUP'			=> $byte{'START'}.chr(0x0B).$byte{'END'},
    'SCROLLDOWN'		=> $byte{'START'}.chr(0x0C).$byte{'END'},
    'INTERLACE1'		=> $byte{'START'}.chr(0x0D).$byte{'END'},
    'INTERLACE2'		=> $byte{'START'}.chr(0x0E).$byte{'END'},
    'COVERUP'			=> $byte{'START'}.chr(0x0F).$byte{'END'},
    'COVERDOWN'			=> $byte{'START'}.chr(0x10).$byte{'END'},
    'SCANLINE'			=> $byte{'START'}.chr(0x11).$byte{'END'},
    'EXPLODE'			=> $byte{'START'}.chr(0x12).$byte{'END'},
    'PACMAN'			=> $byte{'START'}.chr(0x13).$byte{'END'},
    'STACK'				=> $byte{'START'}.chr(0x14).$byte{'END'},
    'SHOOT'				=> $byte{'START'}.chr(0x15).$byte{'END'},
    'FLASH'				=> $byte{'START'}.chr(0x16).$byte{'END'},
    'RANDOM'			=> $byte{'START'}.chr(0x17).$byte{'END'},
    'SLIDEIN'			=> $byte{'START'}.chr(0x18).$byte{'END'},
    'AUTO'				=> $byte{'START'}.chr(0x19).$byte{'END'},

    # Effects 1D-1F : nothing

    # Unknown 00-0F
    # Unknown 10-1F
    # Unknown 20-2F
    # Unknown 30-3F
    # Unknown 40-4F

    # Unknown 50-5F

    # Symbols 60-7D
    'SUN'			=> chr(0xEF).chr(0x60),
    'CLOUDY'		=> chr(0xEF).chr(0x61),
    'RAIN'			=> chr(0xEF).chr(0x62),
    'CLOCK'			=> chr(0xEF).chr(0x63),
    'PHONE'			=> chr(0xEF).chr(0x64),
    'SPECS'			=> chr(0xEF).chr(0x65),
    'FAUCET'		=> chr(0xEF).chr(0x66),
    'ROCKET'		=> chr(0xEF).chr(0x67),
    'BUG'			=> chr(0xEF).chr(0x68),
    'KEY'			=> chr(0xEF).chr(0x69),
    'SHIRT'			=> chr(0xEF).chr(0x6A),
    'CHOPPER'		=> chr(0xEF).chr(0x6B),
    'CAR'			=> chr(0xEF).chr(0x6C),
    'DUCK'			=> chr(0xEF).chr(0x6D),
    'HOUSE'			=> chr(0xEF).chr(0x6E),
    'TEAPOT'		=> chr(0xEF).chr(0x6F),
    'TREES'			=> chr(0xEF).chr(0x70),
    'SWAN'			=> chr(0xEF).chr(0x71),
    'MBIKE'			=> chr(0xEF).chr(0x72),
    'BIKE'			=> chr(0xEF).chr(0x73),
    'CROWN'			=> chr(0xEF).chr(0x74),
    'STRAWBERRY'	=> chr(0xEF).chr(0x75),
    'ARROWRIGHT'	=> chr(0xEF).chr(0x76),
    'ARROWLEFT'		=> chr(0xEF).chr(0x77),
    'ARROWDOWNLEFT'	=> chr(0xEF).chr(0x78),
    'ARROWUPLEFT'	=> chr(0xEF).chr(0x79),
    'CUP'			=> chr(0xEF).chr(0x7A),
    'CHAIR'			=> chr(0xEF).chr(0x7B),
    'SHOE'			=> chr(0xEF).chr(0x7C),
    'GLASS'			=> chr(0xEF).chr(0x7D),

    # 7E : Blank
    # 7F : Blank

    # Time . Date 80 - 83
    'TIME'			=> chr(0xEF) . chr(0x80),
    'DATE'			=> chr(0xEF) . chr(0x81),
    'TEMP'			=> chr(0xEF) . chr(0x82), # Doesn't work on the NS-500UA


    # 90-97: Cartoons
    'MERRYXMAS'			=> chr(0xEF) . chr(0x90),
    'HAPPYNEWYEAR'		=> chr(0xEF) . chr(0x91),
    '4THJULY'			=> chr(0xEF) . chr(0x92),
    'HAPPYEASTER'		=> chr(0xEF) . chr(0x93),
    'HALLOWEEN'			=> chr(0xEF) . chr(0x94),
    'DONTDRINKDRIVE'	=> chr(0xEF) . chr(0x95),
    'NOSMOKING'			=> chr(0xEF) . chr(0x96),
    'WELCOME'			=> chr(0xEF) . chr(0x97),


    # 98-9F: same graphics again

    # A0-A6: Fonts
    'FONT1'	=> chr(0xEF) . chr(0xA0), # Small
    'FONT2'	=> chr(0xEF) . chr(0xA1), # Boxy
    'FONT3'	=> chr(0xEF) . chr(0xA2), # Normal
    'FONT4'	=> chr(0xEF) . chr(0xA3), # Pretty Fat
    'FONT5'	=> chr(0xEF) . chr(0xA4), # Fat
    'FONT6'	=> chr(0xEF) . chr(0xA5), # Super fat
    'FONT7'	=> chr(0xEF) . chr(0xA6), # Small fonts
    # A7-AF: Missing fonts, mem glitches


    # B0-BF: Colors
    # The NS-500UA supports only one color
    'COLOR1'	=> chr(0xEF) . chr(0xB0),
    'COLOR2'	=> chr(0xEF) . chr(0xB1),

    # C0-C7: Speeds
    'SPEED0'	=> chr(0xEF) . chr(0xC0), # Fastest
    'SPEED1'	=> chr(0xEF) . chr(0xC1),
    'SPEED2'	=> chr(0xEF) . chr(0xC2),
    'SPEED3'	=> chr(0xEF) . chr(0xC3),
    'SPEED4'	=> chr(0xEF) . chr(0xC4),
    'SPEED5'	=> chr(0xEF) . chr(0xC5),
    'SPEED6'	=> chr(0xEF) . chr(0xC6),
    'SPEED7'	=> chr(0xEF) . chr(0xC7), # Slowest


    # C8-CF: Pauses
    'PAUSE1'	=> chr(0xEF) . chr(0xC8),
    'PAUSE2'	=> chr(0xEF) . chr(0xC9),
    'PAUSE3'	=> chr(0xEF) . chr(0xCA),
    'PAUSE4'	=> chr(0xEF) . chr(0xCB),
    'PAUSE5'	=> chr(0xEF) . chr(0xCC),
    'PAUSE6'	=> chr(0xEF) . chr(0xCD),
    'PAUSE7'	=> chr(0xEF) . chr(0xCE),
    'PAUSE8'	=> chr(0xEF) . chr(0xCF),

    # D0-D7: User graphics
    # D8-DF: These graphics
    'CITYSCAPE'	=> chr(0xEF) . chr(0xD8),
    'TRAFFIC'	=> chr(0xEF) . chr(0xD9),
    'TEAPARTY'	=> chr(0xEF) . chr(0xDA),
    'TELEPHONE'	=> chr(0xEF) . chr(0xDB),
    'SUNSET'	=> chr(0xEF) . chr(0xDC),
    'CARGOSHIP'	=> chr(0xEF) . chr(0xDD),
    'SWIMMERS'	=> chr(0xEF) . chr(0xDE),
    'MOUSE'		=> chr(0xEF) . chr(0xDF),


    # Beep E0 - E2
    'BEEP1'		=> chr(0xEF) . chr(0xE0), # 3 beeps
    'BEEP2'		=> chr(0xEF) . chr(0xE1), # 3 short beeps
    'BEEP3'		=> chr(0xEF) . chr(0xE2), # Short beep
    'BEEP4'		=> chr(0xEF) . chr(0xE3), # More beeps
    'BEEP5'		=> chr(0xEF) . chr(0xE4), # Short beep
    'BEEP6'		=> chr(0xEF) . chr(0xE5), # Long beep
    'BEEP7'		=> chr(0xEF) . chr(0xE6), # More beeps
    'BEEP8'		=> chr(0xEF) . chr(0xE7), # Continuous beeping long
    'BEEP9'		=> chr(0xEF) . chr(0xE8), # Continuous beeping short
    'BEEP10'	=> chr(0xEF) . chr(0xE9), # Beeps
    'BEEP11'	=> chr(0xEF) . chr(0xEA), # Really long beep
);

#==============================================================================#
#  Function Definitions.                                                       #
#==============================================================================#

#==============================================================================#
# helper function to return a random symbol from the symbol table
# Takes:   nothing
# Returns: two bytes for a random symbol on the display
#
sub cryptUTF {
  return chr(0xEF).chr(rand(0x1D)+0x60);
}
my $rr = \&cryptUTF;

#==============================================================================#
# send raw bytes over the serial port
# Takes:   String Data
# Returns: nothing
#
sub sendBytes {
	if (open(PORT,">".$port)) {
		print PORT @_;
		close PORT;
	} else {
		print STDERR $prog_name.": unable to open ".$port." for writing!\n";
	}
}

#==============================================================================#
# wrap a message with the required control bytes, then pass it to sendBytes
# Takes:   Message String, File Number. (usually file "01")
# Returns: nothing
# TODO: add default value for $file
#
sub sendMessage {
	my $message = shift;
	my $file=shift;
	my $out = "";
	# Send the initialization bytes
	$out.=chr(0x00);
	$out.=chr(0xFF);
	$out.=chr(0xFF);
	$out.=chr(0x00);
	$out.=chr(0x0B);

	# Some more init bytes.
	$out.=chr(0x01);
	$out.=chr(0xFF);

	# Start of message? This byte seems to indicate what to do:
	# 1 : Program sign file <- that's the one we care about
	# 2 : Schedule
	# 5 : Hourly alarm
	# 8 : Set time and date
	$out.=chr(0x01);

	# Which file to use.
	$out.=$file;

	# Set to default color and font
	$out.= $byte{'COLOR1'}. $byte{'FONT3'};

	# Send the actual text to display,
	# TODO: regex any control codes with their %byte{} equivalents
	$out.=$message;

	# End of message
	$out.=chr(0xFF) . chr(0xFF) . chr(0x00);

	sendBytes($out);
}

#==============================================================================#
#  Begin the main block.                                                       #
#==============================================================================#

$|=1;	# Set autoflush to true.

my $raw= `curl -s http://search.twitter.com/search.json?q=%23$hashtag&rpp=20&page=1&show_user=true&result_type=recent`;
my $tweets =  decode_json($raw);

my $message = "";
foreach $element ( @{$$tweets{'results'}}) {
	my $from = ${$element}{'from_user'};
	my $text = ${$element}{'text'};
	# strip unicode chars, and swap with random symbols.
	$from =~ s/[^[:ascii:]]+/$rr->()/ge;
	$text =~ s/[^[:ascii:]]+/$rr->()/ge;
	# too bad there's no bird icon, and DUCK looks like a tank.
	$message.= "$byte{'SWAN'} $from: $text          ";
}

# the actual meat of this thing.
sendMessage $message, $defaultFile;

exit 0;

#==============================================================================#
#  The end of the main block.                                                  #
#==============================================================================#


