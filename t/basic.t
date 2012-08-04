use Mojo::Base -strict;

# Disable IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
  use lib qw(t/lib);
}

use Test::More tests => 7;

package main;
use Mojolicious::Lite;
use Test::Mojo;
use Data::Dumper;

my $config = {};
like(
  (eval { plugin 'DSC' }, $@),
  qr/Please choose and set a database driver/,
  ' no driver'
);
$config->{driver} = 'SQLite';
is((eval { plugin 'DSC', $config }, $@), 'Please set "database"!', 'no database');
$config->{database} = ':memory:';
is_deeply(
  plugin('DSC', $config)->config,
  { database       => ':memory:',
    DEBUG          => 1,
    load_classes   => [],
    namespace      => '',
    dbh_attributes => {},
    driver         => 'SQLite',
    onconnect_do   => [],
    dbix_helper    => 'dbix',
    host           => 'localhost',
    dsn            => 'dbi:SQLite:database=:memory:;host=localhost'
  },
  'default minimal config'
);
is(eval { plugin 'DSC', $config; 1; }, 1, 'database');

$config = {dsn => 'garbage'};
like((eval { plugin 'DSC', $config }, $@), qr/Can't parse DBI DSN/, 'dsn');
$config = {dsn => 'dbi:SQLite:dbname=:memory:', load_classes => 'someclass'};
like(
  (eval { plugin 'DSC', $config }, $@),
  qr/must be an ARRAY reference /,
  'load_classes'
);
$config->{load_classes} = ['My::User'];

like((eval { plugin 'DSC', $config }, $@), qr/Please define namespace/, 'namespace');
