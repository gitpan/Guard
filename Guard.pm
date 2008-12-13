=head1 NAME

Guard - safe cleanup blocks

=head1 SYNOPSIS

 use Guard;

=head1 DESCRIPTION

This module implements so-called "guards". A guard is something (usually
an object) that "guards" a resource, ensuring that it is cleaned up when
expected.

Specifically, this module supports two different types of guards: guard
objects, which execute a given code block when destroyed, and scoped
guards, which are tied to the scope exit.

=head1 FUNCTIONS

This module currently exports the C<scope_guard> and C<guard> functions by
default.

=over 4

=cut

package Guard;

BEGIN {
   $VERSION = '0.1';
   @ISA = qw(Exporter);
   @EXPORT = qw(guard scope_guard);

   require Exporter;

   require XSLoader;
   XSLoader::load Guard, $VERSION;
}

our $DIED = sub { warn "$@" };

=item scope_guard BLOCK

Registers a block that is executed when the current scope (block,
function, method, eval etc.) is exited.

The description below sounds a bit complicated, but that's just because
C<scope_guard> tries to get even corner cases "right": the goal is to
provide you with a rock solid clean up tool.

This is similar to this code fragment:

   eval ... code following scope_guard ...
   {
      local $@;
      eval BLOCK;
      eval { $Guard::DIED->() } if $@;
   }
   die if $@;

Except it is much faster, and the whole thing gets executed even when the
BLOCK calls C<exit>, C<goto>, C<last> or escapes via other means.

See B<EXCEPTIONS>, below, for an explanation of exception handling
(C<die>) within guard blocks.

Example: Temporarily change the directory to F</etc> and make sure it's
set back to F</> when the function returns:

   sub dosomething {
      scope_guard { chdir "/" };
      chdir "/etc";

      ...
   }

=item my $guard = guard BLOCK

Behaves the same as C<scope_guard>, except that instead of executing
the block on scope exit, it returns an object whose lifetime determines
when the BLOCK gets executed: when the last reference to the object gets
destroyed, the BLOCK gets executed as with C<scope_guard>.

The returned object can be copied as many times as you want.

See B<EXCEPTIONS>, below, for an explanation of exception handling
(C<die>) within guard blocks.

Example: acquire a Coro::Semaphore for a second by registering a
timer. The timer callback references the guard used to unlock it again.

   use AnyEvent;
   use Coro::Semaphore;

   my $sem = new Coro::Semaphore;

   sub lock_1s {
      $sem->down;
      my $guard = guard { $sem->up };

      my $timer;
      $timer = AnyEvent->timer (after => 1, sub {
         # do something
         undef $sem;
         undef $timer;
      });
   }

The advantage of doing this with a guard instead of simply calling C<<
$sem->down >> in the callback is that you can opt not to create the timer,
or your code can throw an exception before it can create the timer, or you
can create multiple timers or other event watchers and only when the last
one gets executed will the lock be unlocked.

=item Guard::cancel $guard

Calling this function will "disable" the guard object returned by the
C<guard> function, i.e. it will free the BLOCK originally passed to
C<guard >and will arrange for the BLOCK not to be executed.

This can be useful when you use C<guard> to create a fatal cleanup handler
and later decide it is no longer needed.

=cut

1;

=back

=head1 EXCEPTIONS

Guard blocks should not normally throw exceptions (e.g. C<die>), after
all, they are usually used to clean up after such exceptions. However, if
something truly exceptional is happening, a guard block should be allowed
to die. Also, programming errors are a large source of exceptions, and the
programmer certainly wants to know about those.

Since in most cases, the block executing when the guard gets executes does
not know or does not care about the guard blocks, it makes little sense to
let containing code handle the exception.

Therefore, whenever a guard block throws an exception, it will be caught,
and this module will call the code reference stored in C<$Guard::DIED>
(with C<$@> set to the actual exception), which is similar to how most
event loops handle this case.

The code reference stored in C<$Guard::DIED> should not die (behaviour is
not guaranteed, but right now, the exception will simply be ignored).

The default for C<$Guard::DIED> is to call C<warn "$@">.

=head1 AUTHOR

 Marc Lehmann <schmorp@schmorp.de>
 http://home.schmorp.de/

=head1 THANKS

To Marco Maisenhelder, who reminded me of the C<$Guard::DIED> solution to
the problem of exceptions.

=cut

