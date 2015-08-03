# collect a channel vote, like those done in #spi
#
# (C) 2006 by Joerg Jaspert <joerg@debian.org>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; only version 2 of the License..
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this script; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use Irssi;

use vars qw($VERSION %IRSSI @chans %votes);


$VERSION = '0.0.0.0.1.alpha.0.1';
%IRSSI = (
    authors     => 'Joerg Jaspert',
    contact     => 'joerg@debian.org',
    name  => 'vote',
    description => 'Collect channel votes.',
    license     => 'GPL v2 (and no later)',
);

########################################################################
########################################################################

sub start_vote {
  my ($arg, $server, $channel) = @_;
  my $window = Irssi::active_win();

  my $channame = $channel->{name};
  my $found=1;

  if ($votes{$channame}{runs}) {
	$window->print("Already one vote running in this channel");
	return;
  }

  my ($reason, $nicklist) = split(/:/, $arg);
  $nicklist=lc($nicklist);

  my $i=0;
  $votes{$channame}=();
  foreach $a (split(/,/, $nicklist)) { # Collect who is allowed to vote and also count how many are allowed to vote.
	$votes{$channame}{voters}{$a}=$i++;
  }
  $votes{$channame}{runs}=1;
  $votes{$channame}{reason}=$reason;

  my $message = "Voting started, $i people ($nicklist) allowed to vote on $reason. - You may vote yes/no/abstain only, type !vote \$yourchoice now.";
  $votes{$channame}{count}=--$i;

  Irssi::active_win()->command("msg $channame $message"); # Mention that vote started.

  Irssi::signal_add_last('message own_public',  'process_vote_own'); # Process all incoming messages now
  Irssi::signal_add_last('message public',      'process_vote'); # looking for votes
}


### The following is sick, but we get different parameters for own and for other msgs
sub process_vote {
  my ($server, $text, $nick, $host, $channame) = @_;
  if (not defined($votes{$channame}{runs})) {return;}     # Gets run on *every* message, so stop as early as possible on non-vote chans
  calc_vote($server, lc($nick), lc($text), $channame);
}

sub process_vote_own {
  my ($server, $text, $channame) = @_;
  if (not defined($votes{$channame}{runs})) {return;}    # Gets run on *every* message, so stop as early as possible on non-vote chans
  calc_vote($server, lc($server->{nick}), lc($text), $channame);
}

# so lets record the votes
sub calc_vote {
  my ($server, $nick, $text, $channame) = @_;
  return if not $text =~ m/^!vote.*/;
  return if not exists $votes{$channame}{voters}{$nick};
  $text =~ s/^!vote //;
  if (($text eq "yes") || ($text eq "no") || ($text eq "abstain")) {
	$votes{$channame}{voters}{$nick}=$text;
  }
}


sub vote_result {
  my ($arg, $server, $channel) = @_;
  my $window = Irssi::active_win();
  my $channame = $channel->{name};

  if (not defined($votes{$channame}{runs})) {
	$window->print("No vote running here");
	return;
  }

  my $yes=0; my $no=0; my $abstain=0; my $novote=0; my $missnicks="";
  while (my ($key, $value) = each (%{%votes->{$channame}{voters}})) {
	if ($votes{$channame}{voters}{$key} eq "yes") {
	  $yes++;
	} elsif ($votes{$channame}{voters}{$key} eq "no") {
	  $no++;
	} elsif ($votes{$channame}{voters}{$key} eq "abstain") {
	  $abstain++;
	} else {
	  $novote++;
	  $missnicks .= " $key ";
	}
  }
  Irssi::active_win()->command("msg $channame Current voting results for \"$votes{$channame}{reason}\": Yes: $yes, No: $no, Abstain: $abstain, Missing: $novote ($missnicks)");
  return;
}

sub force_vote {
  my ($arg, $server, $channel) = @_;
  my $window = Irssi::active_win();
  my $channame = $channel->{name};

  if (not defined($votes{$channame}{runs})) {
	$window->print("No vote running here");
	return;
  }
  my ($nick, $text) = split(/ /, $arg);
  $votes{$channame}{voters}{$nick}=lc($text);
  Irssi::active_win()->command("msg $channame Forced vote $text on $nick");
}

sub real_stop_vote {
  my ($arg, $server, $channel) = @_;
  my $window = Irssi::active_win();

  my $channame = $channel->{name};
  if (not defined($votes{$channame}{runs})) {
	$window->print("No vote running here");
	return;
  }
  vote_result($arg, $server, $channel);
  Irssi::signal_remove('message own_public',  'process_vote'); # And stop looking at every pub message
  Irssi::signal_remove('message public',      'process_vote');
  $window->command("msg $channame Voting for \"$votes{$channame}{reason}\" closed.");
  $votes{$channame}=();
}

Irssi::command_bind('vote_start', 'start_vote');
Irssi::command_bind('vote_result', 'vote_result');
Irssi::command_bind('vote_stop', 'real_stop_vote');
Irssi::command_bind('vote_force', 'force_vote');
