#!/bin/bash

# This is the Refactr Runner install script!
#
# Are you looking at this in your web browser, and would like to install Refactr Runner?
#
# LINUX:
#   Just open up your terminal and type:
#
#     curl <URL HERE> | sh
#
#   Refactr Runner currently supports:
#       - Architecture: x86_64 systems
#       - Flavor:
#           CentOS 7
#           CentOS 8
#
# WINDOWS:
#   Not currently supported


# We wrap this whole script in a function, so that we won't execute
# until the entire script is downloaded.
installIt ()
{

# This always does a clean install of the latest version of Refactr Runner into your
# /opt/refactr-runner, replacing whatever is already there.


trap - EXIT
}

installIt