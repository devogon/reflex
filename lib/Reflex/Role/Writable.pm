package Reflex::Role::Writable;
use MooseX::Role::Parameterized;

# TODO - Reflex::Role::Readable and Writable are nearly identical.
# Can they be abstracted further?

use Scalar::Util qw(weaken);

parameter handle => (
	isa     => 'Str',
	default => 'handle',
);

parameter active => (
	isa     => 'Bool',
	default => 0,
);

parameter cb_ready => (
	isa       => 'Str',
	default   => sub {
		my $self = shift;
		"on_" . $self->handle() . "_writable";
	},
	lazy      => 1,
);

parameter method_pause => (
	isa       => 'Str',
	default   => sub {
		my $self = shift;
		"pause_" . $self->handle() . "_writable";
	},
	lazy      => 1,
);

parameter method_resume => (
	isa       => 'Str',
	default   => sub {
		my $self = shift;
		"resume_" . $self->handle() . "_writable";
	},
	lazy      => 1,
);

role {
	my $p = shift;

	my $h             = $p->handle();
	my $active        = $p->active();

	my $cb_name       = $p->cb_ready();
	my $pause_name    = $p->method_pause();
	my $resume_name   = $p->method_resume();
	my $setup_name    = "_setup_${h}_writable";

	method $setup_name => sub {
		my ($self, $arg) = @_;

		# Must be run in the right POE session.
		return unless $self->call_gate($setup_name, $arg);

		my $envelope = [ $self ];
		weaken $envelope->[0];
		$POE::Kernel::poe_kernel->select_write(
			$self->$h(), 'select_ready', $envelope, $cb_name,
		);

		return if $active;

		$POE::Kernel::poe_kernel->select_pause_write($self->$h());
	};

	method $pause_name => sub {
		my $self = shift;
		$POE::Kernel::poe_kernel->select_pause_read($self->$h());
	};

	method $resume_name => sub {
		my $self = shift;
		$POE::Kernel::poe_kernel->select_resume_read($self->$h());
	};

	after BUILD => sub {
		my ($self, $arg) = @_;
		$self->$setup_name($arg);
	};

	# Turn off watcher during destruction.
	after DEMOLISH => sub {
		my $self = shift;
		$POE::Kernel::poe_kernel->select_write($self->h(), undef);
	};

	# Part of the POE/Reflex contract.
	method deliver => sub {
		my ($self, $handle, $cb_member) = @_;
		$self->$cb_member( { handle => $handle, } );
	};

	# Default callbacks that re-emit their parameters.
	method emit_by_default($cb_name, "${h}_writable");
};

1;

__END__

=head1 NAME

Reflex::Role::Writable - add writable-watching behavior to a class

=head1 SYNOPSIS

	use Moose;

	has socket => ( is => 'rw', isa => 'FileHandle', required => 1 );

	with 'Reflex::Role::Writable' => {
		handle   => 'socket',
		cb_ready => 'on_socket_writable',
		active   => 1,
	};

	sub on_socket_writable {
		my ($self, $arg) = @_;
		print "Socket $arg->{handle} is ready for data.\n";
		$self->pause_socket_writabe();
	}

=head1 DESCRIPTION

Reflex::Role::Writable is a Moose parameterized role that adds
writable-watching behavior for Reflex-based classes.  In the SYNOPSIS,
a filehandle named "socket" is watched for writability.  The method
on_socket_writable() is called when data becomes available.

TODO - Explain the difference between role-based and object-based
composition.

=head2 Required Role Parameters

=head3 handle

The C<handle> parameter must contain the name of the attribute that
holds the handle to watch.  The name indirection allows the role to
generate methods that are unique to the handle.  For example, a handle
named "XYZ" would generates these methods by default:

	cb_ready      => "on_XYZ_writable",
	method_pause  => "pause_XYZ_writable",
	method_resume => "resume_XYZ_writable",

This naming convention allows the role to be used for more than one
handle in the same class.  Each handle will have its own name, and the
mixed in methods associated with them will also be unique.

=head2 Optional Role Parameters

=head3 active

C<active> specifies whether the Reflex::Role::Writable watcher should
be enabled when it's initialized.  All Reflex watchers are enabled by
default.  Set it to a false value, preferably 0, to initialize the
watcher in an inactive or paused mode.

Writability watchers may be paused and resumed.  See C<method_pause>
and C<method_resume> for ways to override the default method names.

=head3 cb_ready

C<cb_ready> names the $self method that will be called whenever
C<handle> has space for more data to be written.  By default, it's the
catenation of "on_", the C<handle> name, and "_writable".  A handle
named "XYZ" will by default trigger on_XYZ_writable() callbacks.

	handle => "socket",  # on_socket_writable()
	handle => "XYZ",     # on_XYZ_writable()

All Reflex parameterized role callbacks are invoked with two
parameters: $self and an anonymous hashref of named values specific to
the callback.  C<cb_ready> callbacks include a single named value,
C<handle>, that contains the filehandle from which has become ready
for writing.

C<handle> is the handle itself, not the handle attribute's name.

=head3 method_pause

C<method_pause> sets the name of the method that may be used to pause
the watcher.  It is "pause_${handle}_writable" by default.

=head3 method_resume

C<method_resume> may be used to resume paused writability watchers, or
to activate them if they are started in an inactive state.

=head1 EXAMPLES

TODO - I'm sure there are some.

=head1 SEE ALSO

L<Reflex>
L<Reflex::Role::Readable>
L<Reflex::Role::Streaming>

L<Reflex/ACKNOWLEDGEMENTS>
L<Reflex/ASSISTANCE>
L<Reflex/AUTHORS>
L<Reflex/BUGS>
L<Reflex/BUGS>
L<Reflex/CONTRIBUTORS>
L<Reflex/COPYRIGHT>
L<Reflex/LICENSE>
L<Reflex/TODO>

=cut
