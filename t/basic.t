use Mojo::Base -strict;

# Disable IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}

use Test::More tests => 9;

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
  $config,
  { 'database'       => ':memory:',
    'DEBUG'          => 1,
    'load_classes'   => [],
    'namespace'      => '',
    'dbh_attributes' => {},
    'driver'         => 'SQLite'
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

#warn Dumper($config);

get '/' => sub {
  my $self = shift;
  $self->render_text('Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');
