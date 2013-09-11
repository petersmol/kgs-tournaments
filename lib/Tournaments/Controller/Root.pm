#
# Основной функционал 
#
# Created by Peter Smolovich (pub@petersmol.ru) 11.09.2013.
package Tournaments::Controller::Root;
use strict;
use warnings;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Model::KGS;
use Tournaments::Model::DB;


# Получает список игроков турнира и скачивает все их партии
sub download_all {
    my ($self, $days_shift)=@_; # Set timeshift in days to download prevous month games

    my $players = Tournaments::Model::DB->getTournamentPlayers;

    foreach my $name (keys %$players){
        my $res = Tournaments::Model::KGS->downloadArchive($name, $days_shift);

        print "$name ".$res->{code}." ".$res->{url}."\n";
        die Dumper ($res) if ($res->{code} eq 'error');
        sleep 10; # KGS server-friendly delay
    }
}

1;
