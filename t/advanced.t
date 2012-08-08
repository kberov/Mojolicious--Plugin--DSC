use Mojo::Base -strict;
use utf8;

# Disable IPv6 and libev
BEGIN {
  $ENV{MOJO_NO_IPV6} = 1;
  $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
  use lib qw(t/lib);
}

use Test::More tests => 10;

package main;

use Mojolicious::Lite;
use Test::Mojo;
use Data::Dumper;
plugin('Charset', {charset => 'UTF-8'});
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


my $my_groups_table = <<"TAB";
CREATE TABLE my_groups(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  "group" VARCHAR(12),
  "is' enabled" INT DEFAULT 0
  )
TAB


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

post '/edit/user' => sub {
  my $c    = shift;
  my $user = My::User->find($c->param('id'));
  $user->login_password($c->param('login_password'));
  $user->save;
  $c->render_text(
    'New password for user ' . $user->login_name . ' is ' . $user->login_password);
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200);
$t->content_is('Hello ' . $user->login_name . ' from group ' . $group->group . '!');

$t->post_form_ok('/edit/user', {id => 1, login_password => 'alabala123'})
  ->status_is(200);
$t->content_is('New password for user петър is alabala123');
