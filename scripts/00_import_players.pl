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

my $tournament='9may2013';

Tournaments::Model::DB->clearPlayers($tournament);
Tournaments::Model::DB->importPlayers($tournament);
