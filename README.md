qpsmtpd-logterse
================

Logterse plugin for qpsmtpd

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
