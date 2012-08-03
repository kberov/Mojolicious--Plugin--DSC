use Mojo::Base -strict;

# Disable IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
}

use Test::More tests => 5;
package main;
use Mojolicious::Lite;
use Test::Mojo;

my $config = {};
like((eval { plugin 'DSC' }, $@), qr/Please choose and set a database driver/, 'driver');
$config->{driver} = 'SQLite';
is((eval { plugin 'DSC',$config }, $@), 'Please set "database"!','database');

get '/' => sub {
  my $self = shift;
  $self->render_text('Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

