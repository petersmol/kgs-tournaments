#!/usr/bin/perl
#
# Скрипт получает список игроков и скачивает все их партии
#
# Created by Peter Smolovich (pub@petersmol.ru) 10.09.2013
use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Tournaments::Model::DB;
use Tournaments::Model::KGS;

my $players = Tournaments::Model::DB->getTournamentPlayers;

# Set timeshift in days to download prevous month games
my $days_shift=$ARGV[0];

foreach my $name (keys %$players){
    my $res = Tournaments::Model::KGS->downloadArchive($name, $days_shift);

    print "$name ".$res->{code}." ".$res->{url}."\n";
    die Dumper ($res) if ($res->{code} eq 'error');
    sleep 10;
}
