package Mojolicious::Plugin::DSC;
use Mojo::Base 'Mojolicious::Plugin';
use DBIx::Simple::Class;
use Mojo::Util qw(camelize);
use Carp;

our $VERSION = '0.997';

#some known good defaults
my $COMMON_ATTRIBUTES = {
  RaiseError => 1,
  AutoCommit => 1,
};

has config => sub { {} };

sub register {
  my ($self, $app, $config) = @_;

  # This stuff is executed, when the plugin is loaded
  # Config
  $config ||= {};
  $config->{load_classes} ||= [];
  $config->{DEBUG} //= ($app->mode =~ /^dev/ ? 1 : 0);
  $config->{dbh_attributes} ||= {};

  #prepared Data Source Name?
  if (!$config->{dsn}) {
    $config->{driver}
      || croak('Please choose and set a database driver like "mysql","SQLite","Pg"!..');
    $config->{database} || croak('Please set "database"!');
    $config->{host} ||= 'localhost';
    $config->{dsn} = 'dbi:'
      . $config->{driver}
      . ':database='
      . $config->{database}
      . ';host='
      . $config->{host}
      . ($config->{port} ? ';port=' . $config->{port} : '');
    $config->{database} =~ m/(\w+)/x and do {
      $config->{namespace} ||= camelize($1);
    };
    $config->{namespace} ||= camelize($config->{database});
  }
  else {
    my ($scheme, $driver, $attr_string, $attr_hash, $driver_dsn) =
      DBI->parse_dsn($config->{dsn})
      || croak("Can't parse DBI DSN! dsn=>'$config->{dsn}'");
    $config->{driver} = $driver;
    $scheme =~ m/(database|dbname)=\W?(\w+)/x and do {
      $config->{namespace} ||= camelize($2);
    };
    $config->{dbh_attributes} =
      {%{$config->{dbh_attributes}}, ($attr_hash ? %$attr_hash : ())};
  }

  croak('"load_classes" configuration directive '
      . 'must be an ARRAY reference containing a list of classes to load.')
    unless (ref($config->{load_classes}) eq 'ARRAY');
  $config->{onconnect_do} ||= [];

  #Postpone connecting to the database for the first helper call.
  my $helper_builder = sub {

    #ready... Go!
    my $dbix = DBIx::Simple->connect(
      $config->{dsn},
      $config->{user}     || '',
      $config->{password} || '',
      {%$COMMON_ATTRIBUTES, %{$config->{dbh_attributes}}}
    );
    if (!ref($config->{onconnect_do})) {
      $config->{onconnect_do} = [$config->{onconnect_do}];
    }
    for my $sql (@{$config->{onconnect_do}}) {
      $dbix->dbh->do($sql) if $sql;
    }
    my $DSCS   = $config->{namespace};
    my $schema = Mojo::Util::class_to_path($DSCS);
    if (eval { require $schema; }) {
      $DSCS->DEBUG($config->{DEBUG});
      $DSCS->dbix($dbix);
    }
    else {
      DBIx::Simple::Class->DEBUG($config->{DEBUG});
      DBIx::Simple::Class->dbix($dbix);
    }
    return $dbix;
  };

  #Add $dbix as attribute and helper where needed
  my $dbix_helper = $config->{dbix_helper} ||= 'dbix';
  $app->attr($dbix_helper, $helper_builder);
  $app->helper($dbix_helper, $helper_builder);
  $self->_load_classes($config);
  $self->config($config);
  return $self;
}    #end register

sub _load_classes {
  my ($self, $config) = @_;
  if ($config->{namespace} && @{$config->{load_classes}}) {
    my @classes   = @{$config->{load_classes}};
    my $namespace = $config->{namespace};
    $namespace .= '::' unless $namespace =~ /:{2}$/;
    foreach my $class (@classes) {
      if ($class =~ /$namespace/) {
        my $e = Mojo::Loader->load($class);
        carp($e) if ref $e;
        next;
      }
      my $e = Mojo::Loader->load($namespace . $class);
      carp($e) if ref $e;
    }
  }
  elsif ($config->{namespace} && !@{$config->{load_classes}}) {
    my @classes = Mojo::Loader->search($config->{namespace});
    foreach my $class (@classes) {
      my $e = Mojo::Loader->load($class);
      croak($e) if ref $e;
    }
  }
}
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
and they will be loaded so you do not have to C<use My::Table>.
The configuration is pretty flexible:

  # in Mojolicious startup()
  $self->plugin('DSC', {
    dsn => 'dbi:SQLite:database=:memory:;host=localhost'
  });
  #or
  $self->plugin('DSC', {
    driver => 'mysqlPP',
    database => 'mydbname',
    host => '127.0.0.1',
    user => 'myself',
    password => 'secret',
    onconnect_do => [
      'SET NAMES UTF8',
      'SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO"'
    ],
    dbh_attributes => {AutoCommit=>0},
    namespace => 'My',
    
    #will load My::User, My::Content, My::Pages
    load_classes =>['User', 'Content', 'My::Pages'],
    
    #now you can use $app->DBIX instead of $app->dbix
    dbix_helper => 'DBIX' 
  });

=head1 METHODS

L<Mojolicious::Plugin::DSC> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head2 config

This plugin own configuration. Returns a HASHref.

  #debug
  $app->log->debug($app->dumper($plugin->config));

=head1 SEE ALSO

L<DBIx::Simple::Class>, L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicio.us>.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Красимир Беров (Krasimir Berov).

This program is free software, you can redistribute it and/or
modify it under the terms of the Artistic License version 2.0.

See http://dev.perl.org/licenses/ for more information.

=cut
