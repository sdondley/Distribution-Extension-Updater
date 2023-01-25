use File::Find;
use Proc::Easier;
unit class Distribution::Extension::Updater;
has IO::Path $.dir is required where *.d;
has IO::Path $!meta;
has Bool $.quiet;
has Bool $.dry-run;
has %.ext;

my @ext = qw ( t pm pm6 p6 pod6 pod );
my %ext-updates = (t => 'rakutest', pm => 'rakumod', pm6 => 'rakumod',
                   p6 => 'rakumod', pod6 => 'rakudoc', pod => 'rakudoc');

method new(Str $d = '', :d(:$dir) = $d || '.', Bool :$quiet = False, Bool :$dry-run = False,  *%_ ()) {
    self.bless(dir => $dir.IO, :$quiet, :$dry-run);
}

method has-legacy-extensions(*@exts where @exts ⊆ @ext) {
    %.ext = {};
    self.find($_) for @ext;
    my $array = @exts || @ext;
    for $array.list {
        return True if %.ext{$_};
    }
    return False;
}

method update-extensions(*@exts where @exts ⊆ @ext) {
    # make sure we have a meta file before proceeding
    my $has-meta = self.get-meta;
    die "No META json file detected. Aborting." if !$has-meta;

    %.ext = {};
    self.find($_) for @ext;

    # make sure we don't stomp on existing files before moving them
    my %updates;
    for @exts || @ext {
        my $new-extension = '.' ~ %ext-updates{$_};
        for %.ext{$_} -> $file {
            my $new-file = $file.subst(/\. $_ $/, $new-extension);
            die "Cannot proceed. Duplicate '$new-file' files will be created." if %updates{$new-file};
            %updates{$new-file} = $file if $file;
        }
    }

    # make the actual file moves with git if available
    my $has-git = self.has-git();
    my $updates-made = False;
    my $meta-content = slurp $!meta.Str;
    $meta-content ~~ /('"provides"' ':' \s* '{' \s* ('"' .*? '"' \s* ':' \s* '"' .*? '"' \s* ','? \s*)+ '}')/;
    my $provides = $0.Str;
    my $new-provides = $provides;
    for %updates.keys -> $k {
        my $search = %updates{$k}.Str;
        $new-provides.=subst(/$search '"'/, "$k\"");

        my $action = $!dry-run ?? 'Will' !! 'Attempting to';
        if $has-git {
            my $cmd = $!dry-run ?? False !! cmd "git mv %updates{$k} $k";
            say "$action move file '%updates{$k}' to '$k' with git" unless $!quiet;
            if $cmd && $cmd.exitcode {
                warn "Moving file '%updates{$k}' to '$k' with git FAILED";
                say '' unless $!quiet;
                say "Attempting to move file '%updates{$k}' to '$k' without git" unless $!quiet;
                my $success = move %updates{$k}, $k;
                warn "Failed to move '$k" if !$success;
                $updates-made = True if $success;
                say "File successfully moved\n" if $success && !$!quiet;
            } else {
                say "File successfully moved\n" unless $!quiet || $!dry-run;
                $updates-made = True;
            }
        } else {
            say "$action move file '%updates{$k}' to '$k'" unless $!quiet;
            if !$!dry-run {
                my $success = move %updates{$k}, $k;
                if $success {
                    say "File successfully moved\n" unless $!quiet;
                    $updates-made = True;
                } else {
                    warn "Failed to move '$k" if !$success;
                }
            }
        }
    }
    $meta-content.=subst($provides, $new-provides);
    say "Updating meta file" unless $!quiet || $!dry-run;
    say "Meta file will be updated to:" if $!dry-run && !$!quiet;
    say $meta-content if !$!quiet;
    spurt $!meta, $meta-content unless $!dry-run;
}

# find the meta file
method get-meta() {
    my @options = qw ( META6.json META.info META.json META.INFO META.info );
    for @options -> $o {
        $!meta = "$!dir/$o".IO;
        return "$!dir/$o".IO if ($!dir.add: $o).e;
    }
    return False;
}

method has-git() {
    return False if !"$!dir/.git".IO.d || cmd('git --version').exitcode;
    return True;
}

method report() {
    self.has-legacy-extensions;
    for @ext -> $e {
        say ".$e extensions: " ~ %.ext{$e}.elems;
    }
}

method find(Str:D $ext) {
    # filter our files in .precomp and resources;
    my $dir = $.dir;
    %.ext{$ext} = find(dir => $.dir,
            exclude => / $dir '/' resources || .precomp  '/' /,
            name => / \. $ext $/);
}

=begin pod

=head1 NAME

Distribution::Extension::Updater - Update legacy file extensions in a Raku distribution.

=head1 SYNOPSIS

=begin code :lang<raku>

# On the command line...
# upgrade all legacy extensions in a distribution directory, defaults to '.'
rdeu [ '/path/to/distro' ]

# do a dry run, don't change anything
rdeu -d

rdeu --/tests         # don't upgrade test extensions
rdeu --/mods          # don't update module extensions
rdeu --/tests --/docs # don't update tests or docs

# don't display messages to stdout
rdeu -q

# In a module...
use Distribution::Extension::Updater;
my $distro = Distribution::Extension::Updater.new('/path/to/dir');
my $bool = $distro.has-legacy-extensions;
$distro.report;

# perform the upgrade on files with the etensions passed
$distro.update-extensions( <t p6 pm pm6 pod pod6> );

=end code

=head1 DESCRIPTION

Distribution::Extension::Updater searches a distribution on a local machine
for legacy Perl 6 file extensions and updates them to the newer Raku extensions.
The following file types and extensions can be updated:

=item modules with C<.pm>, C<.p6>, and C<.pm6> extensions
=item documentation with C<.pod> and C<.pod6> extensions
=item tests with the C<.t> extension

This module also updates the META6.json file as unobtrusively as possible without
reorganizing it by swapping out the C<provides> section of the file with an
updated version containing the new file extensions.

If the module determines that the git command is available and the distribution
has a .git directory, it will C<git mv> the files. Otherwise, it will
move the files with Raku's C<move> command.

After the module updates the extensions, the changes can be added and committed
to the local git repo and then uploaded to the appropriate ecosystem manually.
This module does not attempt to modify the C<Changes> file.

The module does not update files located in the C<resources> directory or the
C<.precomp> directory.

The module is designed to be run from the command line with the C<rdeu> command
but also provides an API for running it from a script or other module.

=head1 Command line operation

=head2 rdeu [ path/to/distro ]

Updates the test, documentation, and module files found in the distribution with
the following extensions: C<.t, .pm, .p6, .pm6, .pod, .pod6>. If no path is given,
the command is run in the current directory.

=head3 Options

=head4 -d|--dry-run

Performs a dry-run to give a user a chance to preview what will be changed.

=head4 -q|--quiet

Suppresses messages to standard output. Warnings will still be printed.

=head4 -h

Provides help for the C<rdeu> command.

=head4 --/mods|modules --/documentation|docs --/tests

These three options can be used alone or in combination, can be used to prevent
the updating of certain types of legacy extensions.

=head5 C<--mods> turns off the updating of files with extension of C<.p6, .pm, .pm6>.
=head5 C<--tests> turns off the updating of files with extension of C<.t>.
=head5 C<--docs> turns off the updating of files with extension of C<.pod6, .pod>.
rdeu --/tests         # don't upgrade test extensions
rdeu --/mods          # don't update module extensions

=head1 METHODS

As mentioned, the module can also be used from within Raku code using the following
methods.

=head2 Construction

=head3 new(Str $d = '', :d(:$dir) = $d || '.', Bool :$quiet = False, Bool :$dry-run = False,  *%_ ())

Creates a new D::E::U object. If no directory is provided either with a positional
argument or a named argument, defaults to the current directly, '.'. Boolean
arguments, C<:quiet> and C<:dry-run> determine whether output messages are printed
and whether changes are made.

=head2 Methods

=head3 has-legacy-extensions

Returns a boolean value C<True> if legacy extensions are found, C<False> otherwise.

=head3 update-extensions( @exts );

Perform the upgrade on files with the extensions passed in C<@exts>. Only
C<.p6>, C<.pm>, C<.pm6>, C<.t>, C<.pod> and C<.pod6> extensions are allowed.

=head3 report

Get a simple report of legacy extensions found.

=head3 get-meta

Returns the C<Path::IO> object to the meta json file if found, C<False> otherwise.

=head3 has-git

Return C<True> if it determines git is installed, C<False> otherwisek.

=head3 find( Str:D $ext )

Creates a key in the C<%.ext> object attribute that points to a list of files
with the extension supplied by C<$ext>.

=head1 AUTHOR

Steve Dondley <s@dondley.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2023 Steve Dondley

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
