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
use Tournaments::Config;

my $days_shift=$ARGV[0]; # Скачивать партии не текущего месяца, а предыдущего
my $tags=CNF('game.tags');

Tournaments::Controller::Root->download_all($days_shift);
Tournaments::Controller::Root->parse_all;
Tournaments::Controller::Root->process_tournament($tags);
Tournaments::Controller::Root->update_coefficients;

