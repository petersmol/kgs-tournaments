#!/usr/bin/perl
#
# Created by Peter Smolovich (pub@petersmol.ru) 14.09.2013
use strict;
use warnings;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Tournaments::Model::DB;

Tournaments::Model::DB->clearGames;
