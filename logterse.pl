SYNOPSIS
    logterse [prefix char] [loglevel level]

    This plugin is not a logging replacement, but rather an adjunct to the
    normal logging plugins or builtin logging functionality. Specify it in
    config/plugins not config/logging or you'll get "interesting" results.

    The idea is to produce a one-line log entry that summarises the outcome
    of a transaction. A message is either queued or rejected (bizarre
    failure modes are not of interest). What is of interest is the details
    of the sending host and the message envelope, and what happened to the
    message. To do this we hook_deny and hook_queue and grab as much info as
    we can.

    This info is then passed to the real logging subsystem as a single line
    with colon-separated fields as follows:

    1. remote ip
    2. remote hostname
    3. helo host
    4. envelope sender
    5. recipient (comma-separated list if more than one)
    6. name of plugin that called DENY, or the string 'queued' if message
    was accepted.
    7. return value of DENY plugin (empty if message was queued).
    8. the DENY message, or the message-id if it was queued.

    As with logging/adaptive, a distinctive prefix (the backquote character
    by default) is used to make it easy to extract the lines from the main
    logfiles, or to take advantage of multilog's selection capability as
    described in the logging/adaptive plugin:

TYPICAL USAGE
    If you are using multilog to handle your logging, you can replace the
    system provided log/run file with something like this:

      #! /bin/sh
      export LOGDIR=./main
  
      exec multilog t n10 \
        $LOGDIR \
        '-*' '+*` *' $LOGDIR/summary

    which will have the following effects:

    1. All lines will be logged in ./main as usual.
    2. ./main/summary will contain only the lines output by this plugin.

AUTHORS
    Written by Charles Butcher who took a lot from logging/adaptive by John
    Peacock.

VERSION
    This is release 1.0

charlesb@ncc:/var/smtpd/local/src$ cat logterse.pl
=pod

=head1 SYNOPSIS

logterse [prefix char] [loglevel level]

This plugin is not a logging replacement, but rather an adjunct to the normal logging
plugins or builtin logging functionality.  Specify it in config/plugins not
config/logging or you'll get "interesting" results.

The idea is to produce a one-line log entry that summarises the outcome of a
transaction.  A message is either queued or rejected (bizarre failure modes are
not of interest).  What is of interest is the details of the sending host and the
message envelope, and what happened to the message.  To do this we hook_deny and
hook_queue and grab as much info as we can.

This info is then passed to the real logging subsystem as a single line with
colon-separated fields as follows:

=over 4

=item 1. remote ip

=item 2. remote hostname

=item 3. helo host

=item 4. envelope sender

=item 5. recipient (comma-separated list if more than one)

=item 6. name of plugin that called DENY, or the string 'queued' if message was accepted.

=item 7. return value of DENY plugin (empty if message was queued).

=item 8. the DENY message, or the message-id if it was queued.

=back

As with logging/adaptive, a distinctive prefix (the backquote character by default) is
used to make it easy to extract the lines from the main logfiles, or to take advantage
of multilog's selection capability as described in the logging/adaptive plugin:

=head1 TYPICAL USAGE

If you are using multilog to handle your logging, you can replace the system
provided log/run file with something like this:

  #! /bin/sh
  export LOGDIR=./main
  
  exec multilog t n10 \
    $LOGDIR \
    '-*' '+*` *' $LOGDIR/summary

which will have the following effects:

=over 4

=item 1. All lines will be logged in ./main as usual.

=item 2. ./main/summary will contain only the lines output by this plugin.

=back


=head1 AUTHORS

Written by Charles Butcher who took a lot from logging/adaptive by John Peacock.

=head1 VERSION

This is release 1.0

=cut

#
# I chose tab as the field separator to help with human-readability of the logs and hopefully minimal
# chance of a tab showing up _inside_ a field (although they are converted if they do).
# If you change it here, remember to change it in qplogsumm.pl as well.
#
my $FS = "\t";


sub register {
    my ( $self, $qp, %args ) = @_;

    $self->{_prefix} = '`';
    if ( defined $args{prefix} and $args{prefix} =~ /^(.+)$/ ) {
        $self->{_prefix} = $1;
    }
 
    $self->{_loglevel} = LOGALERT;
    if ( defined( $args{loglevel} ) ) {
        if ( $args{loglevel} =~ /^\d+$/ ) {
            $self->{_loglevel} = $args{loglevel};
        }
        else {
            $self->{_loglevel} = log_level( $args{loglevel} );
        }
    }
}


sub hook_deny {
    my ( $self, $transaction, $prev_hook, $retval, $return_text ) = @_;
    
    my $disposition = join($FS, 
                            $prev_hook,
                            $retval,
                            $return_text,
            );

    $self->_log_terse($transaction, $disposition);
    return DECLINED;
}

sub hook_queue { 
    my ( $self, $transaction ) = @_;

    my $msg_id = $transaction->header->get('Message-Id') || '';
    $msg_id =~ s/[\r\n].*//s;  # don't allow newlines in the Message-Id here
    $msg_id = "<$msg_id>" unless $msg_id =~ /^<.*>$/;  # surround in <>'s
    my $disposition = "queued$FS$FS$msg_id";

    $self->_log_terse($transaction, $disposition);
    return DECLINED;
}

sub _log_terse {
    my ( $self, $transaction, $disposition ) = @_;

    my $recipients = join(',', $transaction->recipients);
  
    my $remote_ip   = $self->qp->connection->remote_ip()   || '';
    my $remote_host = $self->qp->connection->remote_host() || '';
    my $hello_host  = $self->qp->connection->hello_host()  || '';
    my $tx_sender   = $transaction->sender()               || '';
 
    my @log_message;

    push(@log_message,
           $remote_ip,
           $remote_host,
           $hello_host,
           $tx_sender,
           $recipients,
        );

    #
    # Escape any $FS characters anywhere in the log message
    #
    map {s/$FS/_/g} @log_message;

    push(@log_message, $disposition);

    $self->log($self->{_loglevel}, $self->{_prefix}, join($FS, @log_message));
}
