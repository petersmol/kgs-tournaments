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

my $days_shift=$ARGV[0]; # Скачивать партии не текущего месяца, а предыдущего
my $tag='Бойцы Вейцы 2013';

Tournaments::Controller::Root->download_all($days_shift);
Tournaments::Controller::Root->parse_all;
Tournaments::Controller::Root->process_tournament($tag);
Tournaments::Controller::Root->update_coefficients;

