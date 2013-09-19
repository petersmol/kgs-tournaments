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
use Tournaments::Controller::Root;
use Tournaments::Model::DB;
use Tournaments::Config;

my $tournament=CNF('game.tournament');
my $tags=CNF('game.tags');

Tournaments::Model::DB->clearPlayers($tournament);
Tournaments::Model::DB->refreshGames($tags);
Tournaments::Model::DB->clearLog;
Tournaments::Model::DB->importPlayers($tournament);
Tournaments::Controller::Root->update_coefficients;

