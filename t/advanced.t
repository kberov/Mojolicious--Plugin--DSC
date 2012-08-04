use Mojo::Base -strict;
use utf8;

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
my $config = {
  database       => ':memory:',
  DEBUG          => 0,
  namespace      => 'My',
  load_classes   => ['Groups'],
  dbh_attributes => {},
  driver         => 'SQLite',
  onconnect_do   => [],
  dbix_helper    => 'dbix',
  host           => 'localhost',
  dsn            => 'dbi:SQLite:database=:memory:;host=localhost'
};

isa_ok(plugin('DSC', $config), 'Mojolicious::Plugin::DSC');


my $my_groups_table = <<"T";
CREATE TABLE my_groups(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  "group" VARCHAR(12),
  "is' enabled" INT DEFAULT 0
  )
T


$config->{load_classes} = ['My::User', 'Groups'];

isa_ok(plugin('DSC', $config), 'Mojolicious::Plugin::DSC');
ok(app->dbix->query($my_groups_table), 'app->dbix works');

ok(app->dbix->query('INSERT INTO my_groups ("group") VALUES(?)', 'pojo'),
  'app->dbix->query works');
my $group = My::Groups->find(1);
my $user  = My::User->new(
  group_id       => $group->id,
  login_name     => 'петър',
  login_password => 'secretpass12'
);
$user->save;

get '/' => sub {
  my $self = shift;
  $self->render_text(
    'Hello ' . $user->login_name . ' from group ' . $group->group . '!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)
  ->content_is('Hello ' . $user->login_name . ' from group ' . $group->group . '!');

