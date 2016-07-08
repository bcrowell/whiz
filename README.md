Introduction
============

Whiz is software that performs a suite of functions related to
assigning homework from my physics textbooks. The "wh" in "whiz" is
meant to evoke "hw" for "homework." I run it on Linux, and it should
also work on MacOS X.

The basic idea is that you write an input file listing "streams" of
problems. For example, if you do a topic such as statics, the stream
for that topic might consist of some easy topics to be assigned on one
homework, then some medium-hard ones for the next homework, and then
some very hard ones assigned as extra credit. The streams happen in
parallel, as suggested by this diagram:

    hw 16  torque
    hw 17     |     statics
    hw 18     |        |
    hw 19              |

This design makes it easy to fiddle with the problem sets without a lot
of tedious cutting and pasting. Each stream is offset in time from the preceding
stream by some amount. In the example above, the statics stream starts
one meeting after the torque stream starts. The problems from a specific
stream that are assigned on a specific problem set are referred to as
a "chunk," e.g., in the example above, the chunk of easy problems on
torque is assigned on hw 16.

Problems are referred to by symbolic
names rather than numbers, so that you can look at the input file and
understand what's what. If I renumber problems in the books, your input
file still works correctly.

There are facilities that allow you, if you wish, to assign
different problems randomly to different students.

Sample input file
=================

Here is a short sample file:

     1	- stream: measurement, conversions, and significant figures
     2	  delay: 0
     3	  chunks:
     4	  - "geometric-mean|triangle-formula,sars|pretzels ; o:furlongs,micrograms|estrogen"
     5	- stream: velocity in one dimension
     6	  delay: 0
     7	  chunks:
     8	  - "bounce-graph,chain-rule-units ; o:honeybeecalculus"
     9	  - "eowyn|decel-accel-frames ; o:door-closer,observable-universe ; *o:gamma-derivation"
    10	  gamma-derivation: Extra-credit problem $$ assumes that you have read optional section 2.7.
    11	- stream: estimation
    12	  delay: 1
    13	  chunks:
    14	  - "jelly-beans,liter-cube|square-mm-to-cm|light-bucket|martini,bodyvolume|grass|e-coli"
    15	  - "richter,apartments|hairmass ; o:lasf|cd-hole|insect-x-ray|seti-volume|mars-land-area|golf-ball-packing"
    16	  - "*:et-tu|plutonium-in-oceans"
    17	- stream: acceleration in one dimension
    18	  delay: 0
    19	  chunks:
    20	  - "stupid,honeybeeaccel,x-graph-to-v-graph"

The format is a general-purpose data-description language called [YAML](https://en.wikipedia.org/wiki/YAML).
The indentation is mandatory.

Four streams are defined in this example. The first two strams, on
measurement and velocity, start simultaneously with the first homework
assignment.  Line 12 causes a delay before the stream on estimation
starts: it will start on the second homework assignment. The stream on
acceleration also starts on hw 2.

Line 4 defines a chunk of problems which is the only chunk in the measurement
stream. The strings such as geometric-mean are mnemonic names for homework
problems. The translation between mnemonics and numbers is given
[here](https://github.com/bcrowell/lm/blob/master/data/problems.csv).
The vertical bars mean that different students will randomly be assigned different
problems. For example, every student will be assigned either geometric-mean or triangle-formula.
The semicolon separates online problems from problems that are human-graded. The problems
before the semicolon are human-graded (the default). After the semicolon, the prefix "o:"
says that these problems are online. Problems can also be marked with a star to show that
they are extra credit, as in line 9, where the prefix "*o:" says that the problem
gamma-derivation is an extra-credit online problem.

It is possible to place notes in the homework printout that the student receives. An example is
at line 10. Lines defining notes are placed at the end of the stream, after all the chunks.
In this example, if the problem gamma-derivation is chapter 2, #18, then a note will be placed
below the list of problems for the relevant homework assignment reading "Extra-credit problem 2-18 assumes..."

Installing
==========

The following instructions are written for Linux, but should also work
with minor modifications for MacOS X.

Install the following open-source software: git, ruby, m4, gnu make, latex. On a debian-based
system, this can be done with the following command:

    sudo apt-get install git-core ruby m4 make texlive-full texlive-math-extra 

If you're using MacOS, you may have BSD make installed. I don't know if that works. If it
doesn't, you need to install gnu make, and invoke it using "gmake" rather than "make" as
in the examples below.

Download whiz:

    git clone https://github.com/bcrowell/whiz.git

If you want to generate handouts of solutions, download their source code. To get access to this,
you will need to create an account on github and then email me to give your account access.

    git clone https://github.com/bcrowell/lm-solutions

Download the data file problems.csv giving the names of all the problems:

    curl -L -O https://raw.githubusercontent.com/bcrowell/lm/master/data/problems.csv

You should now have directories called whiz and lm-solutions inside your current working directory.
In the whiz directory, there should be a file whiz.config containing a line like this:

    "problems_csv":"~/Documents/writing/books/physics/data/problems.csv"

Change the filename so that it points to the place where you downloaded the file problems.csv
earlier.

Get into the directory whiz/sample. Edit the file Makefile. Near the top are two lines like this:

    WHIZ =  ~/foo/whiz/whiz.rb            
    SOLNS_DIR = ~/foo/lm-solutions

Change "foo" to whatever is appropriate so that these point to the file whiz.rb and the
directory in which you've downloaded the solutions. Make whiz.rb executable by doing something
like this:

    chmod +x ~/foo/whiz/whiz.rb

(changing "foo" as appropriate).


Doing a sample file
===================

The sample input file hw.yaml contains a simple example. (There are some other sample
files called hw*.yaml.) Do the command

    make

to read the input file hw.yaml and produce a file hw_table.pdf that shows what problems
are assigned on which homeworks. Because the homework assignments in the simple example
file don't contain any individualized homework, this file is something you could hand out
to your students to tell them what they're assigned. However, it also contains some notations
that are meant to be convenient for you. A subscript S means that the problem has a solution
in the back of the book. Underlining means that the problem has to be graded
by hand because it's not something that can be checked by a computer and it's not a problem whose
solution is in the back of the book. A notation like "online 2+1" means that in the online homework,
2 problems are required and 1 is extra credit.

To generate solutions handouts, do:

    make solutions

The output is in the file solns221.pdf.

Fancy features
==============

There is more fancy functionality such as individualized homework and interfacing to my
open-source gradebook program OpenGrade. This functionality is only documented in the
comments at the top of the source code for Whiz.
