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

Tournaments::Controller::Root->download_all($days_shift);
