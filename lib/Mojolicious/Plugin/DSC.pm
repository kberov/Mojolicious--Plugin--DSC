package Mojolicious::Plugin::DSC;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Simple::Class;


our $VERSION = '0.03';

#some known good defaults
my %COMMON_ATTRIBUTES = (
  RaiseError  => 1,
  HandleError => sub { Carp::croak(shift) },
  AutoCommit  => 1,
);

my $DRIVER_ATTRIBUTES = {
  'mysql'  => {mysql_enable_utf8 => 1, mysql_bind_type_guessing => 1},
  'SQLite' => {sqlite_unicode    => 1},
  'Pg'     => {pg_enable_utf8    => 1}
};

my $MEx = 'Mojo::Exception';
has config =>sub{{}};
sub register {
  my ($self, $app, $config) = @_;

  # This stuff is executed, when the plugin is loaded
  # Config
  $config                 ||= {};
  $config->{load_classes} ||= [];
  $config->{namespace}    ||= '';
  $config->{DEBUG} //= ($app->mode =~ /^dev/ ? 1 : 0);
  $config->{dbh_attributes} ||= {};

  #prepared Data Source Name?
  if (!$config->{dsn}) {
    $config->{driver}
      || $MEx->throw(
      'Please choose and set a database driver like "mysql","SQLite","Pg"!..');
    $config->{database} || $MEx->throw('Please set "database"!');
    $config->{host} ||= 'localhost';
    $config->{dsn} = 'dbi:'
      . $config->{driver}
      . ':database='
      . $config->{database}
      . ';host='
      . $config->{host};
  }

  #check if it is ok
  DBI->parse_dsn($config->{dsn})
    || $MEx->throw("Can't parse DBI DSN! dsn=>'$config->{dsn}'");


  $MEx->throw('"load_classes" configuration directive '
      . 'must be an ARRAY reference containing a list of classes to load.')
    unless (ref($config->{load_classes}) eq 'ARRAY');
  if (@{$config->{load_classes}} && !$config->{namespace}) {
    $MEx->throw('Please define namespace for your model classes!');
  }
  DBIx::Simple::Class->DEBUG($config->{DEBUG});

  #ready... Go!
  my $dbix = DBIx::Simple->connect(
    $config->{dsn},
    $config->{user},
    $config->{password},
    { %COMMON_ATTRIBUTES, %{$DRIVER_ATTRIBUTES->{$config->{driver}} || {}},
      %{$config->{dbh_attributes}}
    }
  );
  $config->{onconnect_do} ||= [];
  if (!ref($config->{onconnect_do})) {
    $config->{onconnect_do} = [$config->{onconnect_do}];
  }
  for my $sql (@{$config->{onconnect_do}}) {
    $dbix->dbh->do($sql) if $sql;
  }
  DBIx::Simple::Class->dbix($dbix);    #do not forget
  $config->{dbix_helper} ||= 'dbix';
  $app->helper($config->{dbix_helper}, $dbix);    #add helper dbix


  if ($config->{namespace} && @{$config->{load_classes}}) {
    my @classes   = @{$config->{load_classes}};
    my $namespace = $config->{namespace};
    $namespace .= '::' unless $namespace =~ /\:\:$/;
    foreach my $class (@classes) {
      if ($class =~ /$namespace/) {
        my $e = Mojo::Loader->load($class);
        $MEx->throw($e) if $e;
        next;
      }
      my $e = Mojo::Loader->load($namespace . $class);
      $MEx->throw($e) if $e;
    }
  }
  elsif ($config->{namespace} && !@{$config->{load_classes}}) {
    my @classes = Mojo::Loader->search($config->{namespace});
    foreach my $class (@classes) {
      my $e = Mojo::Loader->load($class);
      $MEx->throw($e) if $e;
    }
  }
  $self->config($config);
  return $self;
}    #end register


1;

__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::DSC - use DBIx::Simple::Class in your application.

=head1 SYNOPSIS

  #load
  # Mojolicious
  $self->plugin('DSC', $config);

  # Mojolicious::Lite
  plugin 'DSC', $config;

  #use
  my $user = $app->dbix->query('SELECT * FROM users WHERE user=?','ivan');
  
  #...and if you added My::User to 'load_classes' (see below)
  my $user = My::User->query('SELECT * FROM users WHERE user=?','ivan');
  
=head1 DESCRIPTION

Mojolicious::Plugin::DSC is a L<Mojolicious> plugin that helps you
use L<DBIx::Simple::Class> in your application.
It also adds a helper (C<$app-E<gt>dbix> by default) which is a DBIx::Simple instance.

=head1 CONFIGURATION

You can add all classes from your schema to the configuration 
and they will be loaded when the plugin is registered.
The configuration is pretty flexible:

  # in Mojolicious startup()
  $self->plugin('DSC', {
    driver => 'SQLite',
    database =>':memory:',
  });
  #or
  $self->plugin('DSC', {
    driver => 'mysql',
    database => 'mydbname',
    host => '127.0.0.1',
    user => 'myself',
    password => 'secret',
    onconnect_do => ['SET NAMES UTF8','SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO"'],
    dbh_attributes => {RaiseError=>0, AutoCommit=>0},
    namespace => 'My',
    #will load My::User, My::Content, My::Pages
    load_classes =>['User', 'Content', 'Pages'],
    #now you can use $app->DBIX instead of $app->dbix
    dbix_helper => 'DBIX' 
  });

=head1 METHODS

L<Mojolicious::Plugin::DSC> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 config

This plugin own configuration. Returns a HASHref.

  #debug
  $app->log->debug($app->dumper($plugin->config));

=head1 SEE ALSO

L<DBIx::Simple::Class>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Красимир Беров (Krasimir Berov).

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

See http://dev.perl.org/licenses/ for more information.

=cut
