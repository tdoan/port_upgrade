port_upgrade
2008-07-14

Copyright (C) 2008 Tony Doan (tdoan@tdoan.com)

= port_upgrade

* http://portupgrade.rubyforge.org/

== DESCRIPTION:

A clean way to keep your MacPorts up to date.

== FEATURES/PROBLEMS:

Updates your MacPorts while also removing old dependent versions of libraries and applications.

== SYNOPSIS:

  1) Update your ports database from macports.org
  sudo port selfupdate (or sync)
  2) Run port_upgrade to generate a shell script
  port_upgrade -output upgrade.sh
  3) Run the shell script to update your ports tree
  sudo ./upgrade.sh
  4) There is no step 4

== REQUIREMENTS:

* ruby-sqlite3 gem
* bz2 gem
* optiflag gem

== INSTALL:

* sudo gem install port_upgrade

== LICENSE:

Copyright (c) 2008 Tony Doan <tdoan@tdoan.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
