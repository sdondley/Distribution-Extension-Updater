[![Actions Status](https://github.com/sdondley/Distribution-Extension-Updater/actions/workflows/test.yml/badge.svg)](https://github.com/sdondley/Distribution-Extension-Updater/actions)

NAME
====

Distribution::Extension::Updater - Update legacy file extensions in a Raku distribution.

SYNOPSIS
========

```raku
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
```

DESCRIPTION
===========

Distribution::Extension::Updater searches a distribution on a local machine for legacy Perl 6 file extensions and updates them to the newer Raku extensions. The following file types and extensions can be updated:

  * modules with `.pm`, `.p6`, and `.pm6` extensions

  * documentation with `.pod` and `.pod6` extensions

  * tests with the `.t` extension

This module also updates the META6.json file as unobtrusively as possible without reorganizing it by swapping out the `provides` section of the file with an updated version containing the new file extensions.

If the module determines that the git command is available and the distribution has a .git directory, it will `git mv` the files. Otherwise, it will move the files with Raku's `move` command.

After the module updates the extensions, the changes can be added and committed to the local git repo and then uploaded to the appropriate ecosystem manually. This module does not attempt to modify the `Changes` file.

The module does not update files located in the `resources` directory or the `.precomp` directory.

The module is designed to be run from the command line with the `rdeu` command but also provides an API for running it from a script or other module.

Command line operation
======================

rdeu [ path/to/distro ]
-----------------------

Updates the test, documentation, and module files found in the distribution with the following extensions: `.t, .pm, .p6, .pm6, .pod, .pod6`. If no path is given, the command is run in the current directory.

### Options

#### -d|--dry-run

Performs a dry-run to give a user a chance to preview what will be changed.

#### -q|--quiet

Suppresses messages to standard output. Warnings will still be printed.

#### -h

Provides help for the `rdeu` command.

#### --/mods|modules --/documentation|docs --/tests

These three options can be used alone or in combination, can be used to prevent the updating of certain types of legacy extensions.

##### `--mods` turns off the updating of files with extension of `.p6, .pm, .pm6`.

##### `--tests` turns off the updating of files with extension of `.t`.

##### `--docs` turns off the updating of files with extension of `.pod6, .pod`. rdeu --/tests # don't upgrade test extensions rdeu --/mods # don't update module extensions

METHODS
=======

As mentioned, the module can also be used from within Raku code using the following methods.

Construction
------------

### new(Str $d = '', :d(:$dir) = $d || '.', Bool :$quiet = False, Bool :$dry-run = False, *%_ ())

Creates a new D::E::U object. If no directory is provided either with a positional argument or a named argument, defaults to the current directly, '.'. Boolean arguments, `:quiet` and `:dry-run` determine whether output messages are printed and whether changes are made.

Methods
-------

### has-legacy-extensions

Returns a boolean value `True` if legacy extensions are found, `False` otherwise.

### update-extensions( @exts );

Perform the upgrade on files with the extensions passed in `@exts`. Only `.p6`, `.pm`, `.pm6`, `.t`, `.pod` and `.pod6` extensions are allowed.

### report

Get a simple report of legacy extensions found.

### get-meta

Returns the `Path::IO` object to the meta json file if found, `False` otherwise.

### has-git

Return `True` if it determines git is installed, `False` otherwisek.

### find( Str:D $ext )

Creates a key in the `%.ext` object attribute that points to a list of files with the extension supplied by `$ext`.

AUTHOR
======

Steve Dondley <s@dondley.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2023 Steve Dondley

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

